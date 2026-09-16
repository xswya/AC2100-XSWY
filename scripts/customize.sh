#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: customize.sh
# 适用机型: 红米 AC2100 (RM2100) / MT7621AT
# 功能描述: 自动化源码定制脚本
#   1. 注入 MT7621 CPU 1000MHz 寄存器超频补丁
#   2. 部署精简版单板编译配置 (RM2100.config)
#   3. 集成最新 MIPSLE 架构的 Xray-core 核心与透明代理自动化控制脚本
#   4. 预置 Shadowsocks / Xray 依赖环境与开箱即用规则
# ==============================================================================

set -eo pipefail

WORK_DIR="${1:-$(pwd)}"
PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/patches"
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/configs"

echo ">>> [1/5] 开始执行红米 AC2100 (RM2100) 源码定制流程..."
echo "    源码目录: ${WORK_DIR}"

cd "${WORK_DIR}"

# 1. 注入 1000MHz 超频补丁
echo ">>> [2/5] 注入 MT7621 CPU 1000MHz 超频内核补丁..."
if [ -f "${PATCH_DIR}/001-mt7621-1000mhz.patch" ]; then
    if patch -p1 -N --dry-run < "${PATCH_DIR}/001-mt7621-1000mhz.patch" >/dev/null 2>&1; then
        patch -p1 < "${PATCH_DIR}/001-mt7621-1000mhz.patch"
        echo "    已成功应用 001-mt7621-1000mhz.patch"
    else
        echo "    补丁已应用或已存在对应配置，跳过重复应用。"
    fi
else
    echo "    警告: 未找到 001-mt7621-1000mhz.patch，请检查路径！"
fi

# 2. 部署精简单板配置文件
echo ">>> [3/5] 部署精简版板级配置文件 RM2100.config..."
if [ -f "${CONFIG_DIR}/RM2100.config" ]; then
    cp -f "${CONFIG_DIR}/RM2100.config" "${WORK_DIR}/trunk/configs/templates/RM2100.config"
    echo "    已更新 trunk/configs/templates/RM2100.config"
fi

# 3. 集成 Xray 核心插件
echo ">>> [4/5] 集成 MIPSLE 架构 Xray-core 模块..."
XRAY_DIR="${WORK_DIR}/trunk/user/xray"
mkdir -p "${XRAY_DIR}"

# 检查是否已存在 xray 二进制，若无则拉取官方 Release
if [ ! -f "${XRAY_DIR}/xray" ]; then
    echo "    从官方 Release 下载最新稳定版 Xray-linux-mips32le.zip..."
    XRAY_TMP="/tmp/xray_dl"
    rm -rf "${XRAY_TMP}" && mkdir -p "${XRAY_TMP}"
    
    # 获取最新 release 的下载地址，降级备用链接
    LATEST_TAG=$(curl -sL https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name":' | head -n 1 | cut -d '"' -f 4)
    [ -z "${LATEST_TAG}" ] && LATEST_TAG="v26.3.27"
    XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST_TAG}/Xray-linux-mips32le.zip"
    
    echo "    下载目标版本: ${LATEST_TAG} (${XRAY_URL})"
    curl -sSL -o "${XRAY_TMP}/xray.zip" "${XRAY_URL}"
    unzip -q -o "${XRAY_TMP}/xray.zip" -d "${XRAY_TMP}"
    
    cp -f "${XRAY_TMP}/xray" "${XRAY_DIR}/xray"
    chmod +x "${XRAY_DIR}/xray"
    
    # 尝试使用 UPX 压缩以节约 ROM 空间 (MT7621 解压极快)
    if command -v upx >/dev/null 2>&1; then
        echo "    正在使用 UPX 对 Xray 进行高强度压缩优化..."
        upx -9 "${XRAY_DIR}/xray" || true
    fi
    rm -rf "${XRAY_TMP}"
fi

# 编写 Xray 默认配置模版
cat > "${XRAY_DIR}/config.json" <<'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "transparent",
      "port": 12345,
      "protocol": "dokodemo-door",
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "tag": "socks",
      "port": 10808,
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      }
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "example.your-server.com",
            "port": 443,
            "users": [
              {
                "id": "00000000-0000-0000-0000-000000000000",
                "encryption": "none",
                "flow": "xtls-rprx-vision"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "fingerprint": "chrome",
          "serverName": "gateway.icloud.com",
          "publicKey": "YourPublicKeyHere",
          "shortId": "YourShortIdHere",
          "spiderX": ""
        }
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

# 编写透明代理启动与规则管理脚本 xray-run.sh
cat > "${XRAY_DIR}/xray-run.sh" <<'EOF'
#!/bin/sh
# ==============================================================================
# Xray 路由透明代理控制脚本 (支持 TCP 重定向与绕过大陆 IPSet 分流)
# ==============================================================================

CONF_DIR="/etc/storage/xray"
CONF_FILE="${CONF_DIR}/config.json"
PID_FILE="/var/run/xray.pid"
REDIR_PORT=12345

start_rules() {
    echo "正在配置 iptables 透明代理转发规则..."
    iptables -t nat -N XRAY 2>/dev/null || iptables -t nat -F XRAY

    # 1. 忽略局域网及私有 IP 地址
    iptables -t nat -A XRAY -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A XRAY -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A XRAY -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A XRAY -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A XRAY -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A XRAY -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A XRAY -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A XRAY -d 240.0.0.0/4 -j RETURN

    # 2. 如果存在 chnroute IPSet，直接绕过大陆流量
    if ipset list chnroute >/dev/null 2>&1; then
        iptables -t nat -A XRAY -m set --match-set chnroute dst -j RETURN
    fi

    # 3. 其余 TCP 流量转发给本地 Xray 端口
    iptables -t nat -A XRAY -p tcp -j REDIRECT --to-ports ${REDIR_PORT}
    iptables -t nat -I PREROUTING -p tcp -j XRAY
}

stop_rules() {
    echo "正在清理 iptables 透明代理规则..."
    iptables -t nat -D PREROUTING -p tcp -j XRAY 2>/dev/null || true
    iptables -t nat -F XRAY 2>/dev/null || true
    iptables -t nat -X XRAY 2>/dev/null || true
}

case "$1" in
    start)
        mkdir -p "${CONF_DIR}"
        if [ ! -f "${CONF_FILE}" ]; then
            cp /etc_ro/xray_config.json "${CONF_FILE}"
        fi
        
        if [ -f "${PID_FILE}" ] && kill -0 $(cat "${PID_FILE}") 2>/dev/null; then
            echo "Xray 已经在运行中 (PID: $(cat ${PID_FILE}))"
            exit 0
        fi
        
        echo "启动 Xray 服务..."
        /usr/bin/xray run -c "${CONF_FILE}" >/dev/null 2>&1 &
        echo $! > "${PID_FILE}"
        
        start_rules
        echo "Xray 透明代理已成功启动！"
        ;;
    stop)
        echo "停止 Xray 服务..."
        stop_rules
        if [ -f "${PID_FILE}" ]; then
            kill $(cat "${PID_FILE}") 2>/dev/null || true
            rm -f "${PID_FILE}"
        fi
        killall xray 2>/dev/null || true
        echo "Xray 服务已停止。"
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    status)
        if [ -f "${PID_FILE}" ] && kill -0 $(cat "${PID_FILE}") 2>/dev/null; then
            echo "Xray 正在运行 (PID: $(cat ${PID_FILE}))"
        else
            echo "Xray 未运行"
        fi
        ;;
    *)
        echo "使用方法: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF
chmod +x "${XRAY_DIR}/xray-run.sh"

# 编写 Xray 模块的 Makefile
cat > "${XRAY_DIR}/Makefile" <<'EOF'
THISDIR = $(shell pwd)

all:

clean:

romfs:
	$(ROMFSINST) -p +x $(THISDIR)/xray /usr/bin/xray
	$(ROMFSINST) -p +x $(THISDIR)/xray-run.sh /usr/bin/xray-run.sh
	$(ROMFSINST) $(THISDIR)/config.json /etc_ro/xray_config.json
EOF

# 将 Xray 挂载进 trunk/user/Makefile
if ! grep -q "CONFIG_FIRMWARE_INCLUDE_XRAY" "${WORK_DIR}/trunk/user/Makefile"; then
    echo "    在 trunk/user/Makefile 中注册 Xray 编译构建单元..."
    sed -i '/dir_\$(SHADOWSOCKS_ENABLE).*+= shadowsocks/a dir_\$(CONFIG_FIRMWARE_INCLUDE_XRAY) += xray' "${WORK_DIR}/trunk/user/Makefile"
fi

echo ">>> [5/5] 红米 AC2100 定制流程执行完毕，已就绪！"
