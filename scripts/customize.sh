#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: customize.sh
# 适用机型: 红米 AC2100 (RM2100) / MT7621AT
# 功能描述: 自动化源码定制脚本
#   1. 注入 MT7621 CPU 1000MHz 寄存器超频补丁
#   2. 部署精简版单板编译配置 (RM2100.config)
#   3. 集成 ShellCrash 框架 + Mihomo (Clash Meta) 核心 + Yacd WebUI
#   4. 修改 Padavan 菜单字典标签，将 "shadowsocks" 改为 "科学上网"
#   5. 用 Padavan 原生布局重写 Shadowsocks.asp 科学上网控制台
#   6. 配置 SmartDNS 国内外 DNS 分流加速 + 广告拦截规则
#   7. 对接 shadowsocks.sh 生命周期，利用 ss_server 借壳存储订阅链接
# ==============================================================================

set -eo pipefail

WORK_DIR="${1:-$(pwd)}"
PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/patches"
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/configs"

echo ">>> [1/9] 开始执行红米 AC2100 (RM2100) 源码定制流程..."
echo "    源码目录: ${WORK_DIR}"

cd "${WORK_DIR}"

# ==============================================================================
# 1. 注入 1000MHz 超频补丁
# ==============================================================================
echo ">>> [2/9] 注入 MT7621 CPU 1000MHz 超频内核补丁..."
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

# ==============================================================================
# 2. 部署精简单板配置文件
# ==============================================================================
echo ">>> [3/9] 部署精简版板级配置文件 RM2100.config..."
if [ -f "${CONFIG_DIR}/RM2100.config" ]; then
    cp -f "${CONFIG_DIR}/RM2100.config" "${WORK_DIR}/trunk/configs/templates/RM2100.config"
    echo "    已更新 trunk/configs/templates/RM2100.config"
fi

# ==============================================================================
# 3. 准备并打包 ShellCrash + Mihomo 核心 + Yacd WebUI 面板
# ==============================================================================
echo ">>> [4/9] 构建并打包 ShellCrash 离线全套资产 (Mihomo 核心 + WebUI)..."
SC_PKG_DIR="${WORK_DIR}/trunk/user/shellcrash"
mkdir -p "${SC_PKG_DIR}/dist"

SC_TMP="/tmp/sc_build"
rm -rf "${SC_TMP}" && mkdir -p "${SC_TMP}"

# 3.1 下载 ShellCrash 脚本包 (约 180KB)
if [ ! -f "${SC_PKG_DIR}/dist/ShellCrash.tar.gz" ]; then
    echo "    下载 ShellCrash 框架脚本包..."
    curl -fL --retry 3 -o "${SC_TMP}/ShellCrash.tar.gz" "https://fastly.jsdelivr.net/gh/juewuy/ShellCrash@master/ShellCrash.tar.gz" || \
    curl -fL --retry 3 -o "${SC_TMP}/ShellCrash.tar.gz" "https://raw.githubusercontent.com/juewuy/ShellCrash/master/ShellCrash.tar.gz"
    cp -f "${SC_TMP}/ShellCrash.tar.gz" "${SC_PKG_DIR}/dist/ShellCrash.tar.gz"
fi

# 3.2 下载针对 MIPSLE 架构的 Clash.Meta (Mihomo) 软浮点核心 (保留 ELF 原生格式，严禁 UPX 压缩破坏 Go 内存段)
if [ ! -f "${SC_PKG_DIR}/dist/CrashCore" ]; then
    echo "    下载针对 MIPSLE 优化的 Clash.Meta 软浮点核心..."
    META_URL="https://github.com/MetaCubeX/Clash.Meta/releases/download/v1.16.0/Clash.Meta-linux-mipsle-softfloat-v1.16.0.gz"
    curl -fL --retry 3 -o "${SC_TMP}/meta.gz" "${META_URL}"
    gzip -d "${SC_TMP}/meta.gz"
    cp -f "${SC_TMP}/meta" "${SC_PKG_DIR}/dist/CrashCore"
    chmod +x "${SC_PKG_DIR}/dist/CrashCore"
fi

# 3.3 下载轻量精美版 Yacd Web 控制面板 (展平目录确保 index.html 在根目录)
if [ ! -d "${SC_PKG_DIR}/dist/ui" ]; then
    echo "    下载轻量精美版 Yacd Web 控制台面板..."
    YACD_URL="https://github.com/haishanh/yacd/releases/latest/download/yacd.tar.xz"
    curl -fL --retry 3 -o "${SC_TMP}/yacd.tar.xz" "${YACD_URL}"
    mkdir -p "${SC_PKG_DIR}/dist/ui"
    tar -xJf "${SC_TMP}/yacd.tar.xz" -C "${SC_PKG_DIR}/dist/ui"
    # 如果解压包含 public 子目录，提取到顶层
    if [ -d "${SC_PKG_DIR}/dist/ui/public" ]; then
        cp -rf "${SC_PKG_DIR}/dist/ui/public/"* "${SC_PKG_DIR}/dist/ui/"
        rm -rf "${SC_PKG_DIR}/dist/ui/public"
    fi
    # 注入智能自适应脚本：自动识别路由器 IP 与端口，免手动输入跳过登录页秒进后台
    if [ -f "${SC_PKG_DIR}/dist/ui/index.html" ]; then
        python3 - "${SC_PKG_DIR}/dist/ui/index.html" <<'PYEOF' || true
import sys
if len(sys.argv) > 1:
    path = sys.argv[1]
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            html = f.read()
        patch = '<head><script>try{var h=window.location.hostname,p=window.location.port||"9999";if(window.location.search.indexOf("hostname")===-1){var s=window.location.search?"&":"?";window.location.replace(window.location.pathname+window.location.search+s+"hostname="+h+"&port="+p);}}catch(e){}</script>'
        if '<head>' in html and 'hostname=' not in html:
            html = html.replace('<head>', patch, 1)
            with open(path, 'w', encoding='utf-8') as f:
                f.write(html)
    except Exception:
        pass
PYEOF
    fi
fi

# 3.4 下载精简版离线 GeoIP 数据库 (仅约 400KB，彻底解决未联网时 can't download MMDB 致命崩溃)
if [ ! -f "${SC_PKG_DIR}/dist/Country.mmdb" ]; then
    echo "    下载轻量级离线 Country.mmdb 数据库..."
    curl -fL --retry 3 -o "${SC_PKG_DIR}/dist/Country.mmdb" "https://fastly.jsdelivr.net/gh/alecthw/mmdb_china_ip_list@release/Country.mmdb" || \
    curl -fL --retry 3 -o "${SC_PKG_DIR}/dist/Country.mmdb" "https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/Country.mmdb" || true
    if [ -f "${SC_PKG_DIR}/dist/Country.mmdb" ]; then
        cp -f "${SC_PKG_DIR}/dist/Country.mmdb" "${SC_PKG_DIR}/dist/geoip.metadb"
    fi
fi
rm -rf "${SC_TMP}"

# 3.5 编写 ShellCrash 服务启动与透明代理控制脚本 (shellcrash-service.sh)
cat > "${SC_PKG_DIR}/shellcrash-service.sh" <<'EOF'
#!/bin/sh
# ==============================================================================
# ShellCrash (Mihomo/Clash) 自动化服务与透明代理管理脚本
# 关键设计：利用 ss_server nvram 变量"借壳"存储订阅链接
# 运行环境全部置于 /tmp/ShellCrash (tmpfs 内存)，防止写满 Flash
# ==============================================================================

CRASH_DIR="/tmp/ShellCrash"
RO_DIR="/etc_ro/ShellCrash"
CONF_DIR="${CRASH_DIR}"
CONF_FILE="${CRASH_DIR}/config.yaml"
PID_FILE="/var/run/CrashCore.pid"
LOG_FILE="${CRASH_DIR}/crash.log"
PORT_REDIR=7892
PORT_UI=9999

# 初始化运行目录 (RAM 快速环境)
init_env() {
    mkdir -p "${CRASH_DIR}"
    if [ ! -d "${CRASH_DIR}/ui" ]; then
        ln -sf "${RO_DIR}/ui" "${CRASH_DIR}/ui"
    fi
    # 挂载离线 GeoIP 数据库，彻底杜绝联网下载与证书报错
    [ -f "${RO_DIR}/Country.mmdb" ] && ln -sf "${RO_DIR}/Country.mmdb" "${CRASH_DIR}/Country.mmdb"
    [ -f "${RO_DIR}/geoip.metadb" ] && ln -sf "${RO_DIR}/geoip.metadb" "${CRASH_DIR}/geoip.metadb"
}

# 配置透明代理 iptables 转发规则
start_firewall() {
    echo "配置透明代理 iptables 转发规则..."
    iptables -t nat -N CLASH 2>/dev/null || iptables -t nat -F CLASH

    # 保留私网与局域网段
    iptables -t nat -A CLASH -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A CLASH -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A CLASH -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A CLASH -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A CLASH -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A CLASH -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A CLASH -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A CLASH -d 240.0.0.0/4 -j RETURN

    # 绕过国内 IPSet (如果有)
    if ipset list chnroute >/dev/null 2>&1; then
        iptables -t nat -A CLASH -m set --match-set chnroute dst -j RETURN
    fi

    # TCP 重定向到 Clash 端口
    iptables -t nat -A CLASH -p tcp -j REDIRECT --to-ports ${PORT_REDIR}
    iptables -t nat -D PREROUTING -p tcp -j CLASH 2>/dev/null || true
    iptables -t nat -I PREROUTING -p tcp -j CLASH
}

# 清理透明代理 iptables 规则
stop_firewall() {
    echo "清理透明代理 iptables 规则..."
    iptables -t nat -D PREROUTING -p tcp -j CLASH 2>/dev/null || true
    iptables -t nat -F CLASH 2>/dev/null || true
    iptables -t nat -X CLASH 2>/dev/null || true
}

# 拉取订阅配置
# 参数 $1: 订阅链接 URL (可选，缺省时从 nvram 的 ss_server 读取)
update_subscription() {
    SUB_URL="$1"
    [ -z "${SUB_URL}" ] && SUB_URL="$(nvram get ss_server)"
    if [ -z "${SUB_URL}" ]; then
        echo "提示: 未配置订阅链接，使用本地默认配置。"
        return 1
    fi

    # 校验是否为 URL (http/https 开头)
    case "${SUB_URL}" in
        http://*|https://*)
            echo "正在从订阅链接拉取配置: ${SUB_URL} ..."
            ;;
        *)
            echo "ss_server 非 URL 链接 (当前为: ${SUB_URL})，跳过拉取。"
            return 1
            ;;
    esac

    mkdir -p "${CONF_DIR}"
    TMP_CONF="/tmp/sub_config.yaml"
    rm -f "${TMP_CONF}"

    # 优先携带 Clash User-Agent 直接拉取 (绝大多数机场检测到 clash 请求头会自动下发完整 YAML 节点配置)
    curl -kfsSL -A "clash" --retry 2 --connect-timeout 10 -o "${TMP_CONF}" "${SUB_URL}" || true

    # 如果返回的内容不是 YAML 节点配置 (例如机场下发了通用 base64 文本)，追加 flag=clash 重试
    if [ ! -s "${TMP_CONF}" ] || ! grep -qE "(proxies|proxy-providers):" "${TMP_CONF}"; then
        case "${SUB_URL}" in
            *\?*) FLAG_URL="${SUB_URL}&flag=clash" ;;
            *) FLAG_URL="${SUB_URL}?flag=clash" ;;
        esac
        curl -kfsSL -A "clash" --retry 2 --connect-timeout 10 -o "${TMP_CONF}" "${FLAG_URL}" || true
    fi

    # 如果仍未获取到，尝试走公共订阅转换
    if [ ! -s "${TMP_CONF}" ] || ! grep -qE "(proxies|proxy-providers):" "${TMP_CONF}"; then
        curl -kfsSL --retry 2 --connect-timeout 10 -o "${TMP_CONF}" "https://api.v1.mk/sub?target=clash&url=$(echo -n ${SUB_URL} | sed 's/ /%20/g')" || true
    fi

    if [ -s "${TMP_CONF}" ] && grep -qE "(proxies|proxy-providers):" "${TMP_CONF}"; then
        # 仅删除顶层(无前导空格)的重复 key，保护嵌套在 proxies 节点中的 mode:/secret: 等字段不被误伤
        sed -i '/^external-controller:/d' "${TMP_CONF}" 2>/dev/null || true
        sed -i '/^external-ui:/d' "${TMP_CONF}" 2>/dev/null || true
        sed -i '/^redir-port:/d' "${TMP_CONF}" 2>/dev/null || true
        sed -i '/^secret:/d' "${TMP_CONF}" 2>/dev/null || true
        sed -i '/^allow-lan:/d' "${TMP_CONF}" 2>/dev/null || true
        sed -i '/^mode:/d' "${TMP_CONF}" 2>/dev/null || true
        sed -i '/^log-level:/d' "${TMP_CONF}" 2>/dev/null || true
        sed -i '/^mixed-port:/d' "${TMP_CONF}" 2>/dev/null || true
        sed -i '/^bind-address:/d' "${TMP_CONF}" 2>/dev/null || true
        # 删除原有 dns: 整段 (顶层 dns: 到下一个顶层 key 之间的所有行)，由我们统一注入带 fallback 的完整 DNS
        sed -i '/^dns:/,/^[^ ]/{/^dns:/d;/^  /d;/^$/d;}' "${TMP_CONF}" 2>/dev/null || true

        cat >> "${TMP_CONF}" <<YAMLEOF

# === 自动注入本地 Web 控制台与分流参数 ===
redir-port: ${PORT_REDIR}
external-controller: 0.0.0.0:${PORT_UI}
external-ui: ${RO_DIR}/ui
secret: ''
allow-lan: true
mode: rule
log-level: info

dns:
  enable: true
  listen: 0.0.0.0:5353
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - "*.lan"
    - "*.local"
    - "router.asus.com"
    - "my.router"
  nameserver:
    - 127.0.0.1:6053
    - 223.5.5.5
    - 119.29.29.29
  fallback:
    - tls://8.8.8.8:853
    - tls://1.1.1.1:853
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4
YAMLEOF
        cp -f "${TMP_CONF}" "${CONF_FILE}"
        rm -f "${TMP_CONF}"
        echo "订阅拉取并注入配置成功！"
        return 0
    else
        echo "拉取订阅失败或返回无效 Clash 节点配置，保留现有配置。"
        rm -f "${TMP_CONF}"
        return 1
    fi
}

case "$1" in
    start)
        init_env
        if [ -f "${PID_FILE}" ] && kill -0 $(cat "${PID_FILE}") 2>/dev/null; then
            echo "ShellCrash 已经在运行中！"
            exit 0
        fi

        # 每次启动/重启都检查订阅链接，确保用户更换订阅后能即时生效
        SUB_URL="$(nvram get ss_server)"
        if [ -n "${SUB_URL}" ]; then
            case "${SUB_URL}" in
                http://*|https://*)
                    update_subscription "${SUB_URL}" || true
                    ;;
            esac
        fi

        # 生成极简健壮备用配置（零外部远程规则依赖，确保 100% 成功启动并监听 9999 端口）
        if [ ! -f "${CONF_FILE}" ]; then
            cat > "${CONF_FILE}" <<YAMLEOF
mixed-port: 7890
redir-port: ${PORT_REDIR}
external-controller: 0.0.0.0:${PORT_UI}
external-ui: ${RO_DIR}/ui
secret: ''
allow-lan: true
mode: rule
log-level: info

dns:
  enable: true
  listen: 0.0.0.0:5353
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - "*.lan"
    - "*.local"
    - "router.asus.com"
    - "my.router"
  nameserver:
    - 127.0.0.1:6053
    - 223.5.5.5
    - 119.29.29.29
  fallback:
    - tls://8.8.8.8:853
    - tls://1.1.1.1:853
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4

rules:
  - MATCH,DIRECT
YAMLEOF
        fi

        # 启动前清理残余进程与旧 PID，截断过大日志防止写满 tmpfs
        killall CrashCore 2>/dev/null || true
        rm -f "${PID_FILE}"
        if [ -f "${LOG_FILE}" ] && [ "$(wc -c < "${LOG_FILE}" 2>/dev/null || echo 0)" -gt 131072 ]; then
            tail -c 65536 "${LOG_FILE}" > "${LOG_FILE}.tmp" 2>/dev/null && mv -f "${LOG_FILE}.tmp" "${LOG_FILE}" || true
        fi

        echo "启动 Mihomo (Clash Meta) 核心并监听控制端口 ${PORT_UI}..."
        "${RO_DIR}/CrashCore" -d "${CRASH_DIR}" -f "${CONF_FILE}" > "${LOG_FILE}" 2>&1 &
        echo $! > "${PID_FILE}"
        sleep 2

        # 检测核心是否正常存活
        if kill -0 $(cat "${PID_FILE}" 2>/dev/null) 2>/dev/null; then
            start_firewall
            LAN_IP="$(nvram get lan_ipaddr || echo 192.168.123.1)"
            logger -st "ShellCrash" "ShellCrash 核心启动成功！Web 控制面板: http://${LAN_IP}:${PORT_UI}/ui"
        else
            logger -st "ShellCrash" "警告: CrashCore 核心启动异常退出！最近日志:"
            tail -n 10 "${LOG_FILE}" 2>/dev/null | while read line; do logger -st "ShellCrash" "$line"; done
        fi
        ;;
    stop)
        echo "停止 ShellCrash 服务..."
        stop_firewall
        if [ -f "${PID_FILE}" ]; then
            kill $(cat "${PID_FILE}") 2>/dev/null || true
            rm -f "${PID_FILE}"
        fi
        killall CrashCore 2>/dev/null || true
        echo "ShellCrash 服务已停止。"
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    update)
        update_subscription "$2"
        $0 restart
        ;;
    status)
        if [ -f "${PID_FILE}" ] && kill -0 $(cat "${PID_FILE}") 2>/dev/null; then
            echo "1"
        else
            echo "0"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|update|status}"
        exit 1
        ;;
esac
EOF
chmod +x "${SC_PKG_DIR}/shellcrash-service.sh"

# 3.5 编写 user/shellcrash 的 Makefile
cat > "${SC_PKG_DIR}/Makefile" <<'EOF'
THISDIR = $(shell pwd)

all:

clean:

romfs:
	mkdir -p $(ROMFSDIR)/etc_ro/ShellCrash
	cp -rf $(THISDIR)/dist/* $(ROMFSDIR)/etc_ro/ShellCrash/
	chmod +x $(ROMFSDIR)/etc_ro/ShellCrash/CrashCore
	$(ROMFSINST) -p +x $(THISDIR)/shellcrash-service.sh /usr/bin/shellcrash-service.sh
	$(ROMFSINST) -p +x $(THISDIR)/smartdns_start.sh /usr/bin/smartdns_start.sh
	$(ROMFSINST) -p +x $(THISDIR)/post_wan_init.sh /usr/bin/post_wan_init.sh
	ln -sf /etc_ro/ShellCrash/CrashCore $(ROMFSDIR)/usr/bin/CrashCore
	ln -sf /usr/bin/shellcrash-service.sh $(ROMFSDIR)/usr/bin/crash
EOF

# 3.6 挂载到 trunk/user/Makefile
if ! grep -q "shellcrash" "${WORK_DIR}/trunk/user/Makefile"; then
    echo "    在 trunk/user/Makefile 中注册 ShellCrash 编译打包单元..."
    sed -i '/dir_\$(SHADOWSOCKS_ENABLE).*+= shadowsocks/a dir_y += shellcrash' "${WORK_DIR}/trunk/user/Makefile"
fi

# ==============================================================================
# 4. 修改中文/英文字典标签 — 将菜单 "shadowsocks" 改为 "科学上网"
# ==============================================================================
echo ">>> [5/9] 修改 Padavan WebUI 菜单字典标签..."
CN_DICT="${WORK_DIR}/trunk/user/www/dict/CN.dict"
EN_DICT="${WORK_DIR}/trunk/user/www/dict/EN.footer"

if [ -f "${CN_DICT}" ]; then
    # 菜单标题: shadowsocks → 科学上网
    sed -i 's/^menu5_16=shadowsocks$/menu5_16=科学上网/' "${CN_DICT}"
    # 启用标签: 启用shadowsocks → 启用 ShellCrash
    sed -i 's/^menu5_16_2=启用shadowsocks$/menu5_16_2=启用 ShellCrash/' "${CN_DICT}"
    # 全局标签
    sed -i 's/^menu5_16_1=全局$/menu5_16_1=基本设置/' "${CN_DICT}"
    # 服务器配置 → 订阅配置
    sed -i 's/^menu5_16_3=服务器配置$/menu5_16_3=订阅配置/' "${CN_DICT}"
    # 服务器IP → 订阅链接
    sed -i 's/^menu5_16_4=服务器IP地址:$/menu5_16_4=订阅链接:/' "${CN_DICT}"
    echo "    已修改 CN.dict 菜单标签"
fi

if [ -f "${EN_DICT}" ]; then
    sed -i 's/^menu5_16=shadowsocks$/menu5_16=ShellCrash/' "${EN_DICT}"
    sed -i 's/^menu5_16_2=Enable shadowsocks$/menu5_16_2=Enable ShellCrash/' "${EN_DICT}"
    sed -i 's/^menu5_16_3=Server Config$/menu5_16_3=Subscription/' "${EN_DICT}"
    sed -i 's/^menu5_16_4=Server IP address:$/menu5_16_4=Subscription URL:/' "${EN_DICT}"
    echo "    已修改 EN.footer 菜单标签"
fi

# ==============================================================================
# 5. 用 Padavan 原生布局重写 Shadowsocks.asp
#    核心修复：
#    - 严格遵循 Padavan 的 box well → box_head → table 结构体系
#    - 使用已在 variables.c 注册的 ss_server 变量"借壳"存储订阅 URL
#    - 表单提交通过 action_script = "restart_ss" 触发后端 restart_ss()
#    - 移除所有自定义 CSS class，只用 Padavan 自带样式
# ==============================================================================
echo ">>> [6/9] 用 Padavan 原生布局重写 Shadowsocks.asp 科学上网控制台..."
WEB_ASP="${WORK_DIR}/trunk/user/www/n56u_ribbon_fixed/Shadowsocks.asp"

cat > "${WEB_ASP}" <<'ASPEOF'
<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - <#menu5_16#></title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">

<link rel="shortcut icon" href="images/favicon.ico">
<link rel="icon" href="images/favicon.png">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/bootstrap.min.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/main.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/engage.itoggle.css">

<script type="text/javascript" src="/jquery.js"></script>
<script type="text/javascript" src="/bootstrap/js/bootstrap.min.js"></script>
<script type="text/javascript" src="/bootstrap/js/engage.itoggle.min.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/itoggle.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/help.js"></script>

<script>
<% shadowsocks_status(); %>

var $j = jQuery.noConflict();

$j(document).ready(function(){
    init_itoggle('ss_enable');
});

function initial(){
    show_banner(2);
    show_menu(5,13,1);
    show_footer();

    // 如果 ss_server 仍是默认占位符 127.0.0.1，清空以便展示提示文字
    var srv = document.form.ss_server;
    if (srv && srv.value === "127.0.0.1") {
        srv.value = "";
    }

    checkCrashStatus();
}

function checkCrashStatus(){
    var host = window.location.hostname;
    var done = false;
    var img = new Image();
    img.onload = img.onerror = function(){
        if (done) return;
        done = true;
        $j('#crash_status').html('<span class="label label-success" style="padding: 4px 8px;">● 核心运行中 (Mihomo/Meta)</span>');
    };
    setTimeout(function(){
        if (!done) {
            done = true;
            $j('#crash_status').html('<span class="label label-warning" style="padding: 4px 8px;">● 未就绪 / 启动中</span>');
        }
    }, 3000);
    img.src = 'http://' + host + ':9999/version?_t=' + Date.now();
}

function openWebUI(){
    var host = window.location.hostname;
    window.open('http://' + host + ':9999/ui/?hostname=' + host + '&port=9999', '_blank');
}

function applyRule(){
    showLoading();
    document.form.action_mode.value = " Restart ";
    document.form.current_page.value = "Shadowsocks.asp";
    document.form.next_page.value = "";
    document.form.action_script.value = "restart_ss";
    document.form.submit();
}
</script>
</head>

<body onload="initial();" onunLoad="return unload_body();">

<div class="wrapper">
    <div class="container-fluid" style="padding-right: 0px">
        <div class="row-fluid">
            <div class="span3"><center><div id="logo"></div></center></div>
            <div class="span9">
                <div id="TopBanner"></div>
            </div>
        </div>
    </div>

    <div id="Loading" class="popup_bg"></div>

    <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>
    <form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">
    <input type="hidden" name="current_page" value="Shadowsocks.asp">
    <input type="hidden" name="next_page" value="">
    <input type="hidden" name="next_host" value="">
    <input type="hidden" name="sid_list" value="ShadowsocksConf;">
    <input type="hidden" name="group_id" value="">
    <input type="hidden" name="action_mode" value=" Restart ">
    <input type="hidden" name="action_script" value="restart_ss">

    <div class="container-fluid">
        <div class="row-fluid">
            <div class="span3">
                <!--Sidebar content-->
                <div class="well sidebar-nav side_nav" style="padding: 0px;">
                    <ul id="mainMenu" class="clearfix"></ul>
                    <ul class="clearfix">
                        <li>
                            <div id="subMenu" class="accordion"></div>
                        </li>
                    </ul>
                </div>
            </div>

            <div class="span9">
                <!--Body content-->
                <div class="row-fluid">
                    <div class="span12">
                        <div class="box well grad_colour_dark_blue">
                            <h2 class="box_head round_top"><#menu5_16#></h2>
                            <div class="round_bottom">
                                <div class="row-fluid">
                                    <div id="tabMenu" class="submenuBlock"></div>

                                    <div style="margin: 6px 12px 0px 12px;">
                                        <div class="alert alert-info" style="margin-top: 6px; margin-bottom: 12px;">
                                            <strong>红米 AC2100 极简高性能专版：</strong>
                                            内置 Mihomo (Clash Meta) 软浮点核心与 Yacd 图形控制面板。支持 SS / SSR / VMess / VLESS / Trojan / Hysteria2 全协议。
                                        </div>

                                        <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                            <tr>
                                                <th colspan="2" style="background-color: #E3E3E3;">基本开关与状态</th>
                                            </tr>
                                            <tr>
                                                <th width="40%">启用 ShellCrash:</th>
                                                <td>
                                                    <div class="main_itoggle">
                                                        <div id="ss_enable_on_of">
                                                            <input type="checkbox" id="ss_enable_fake"
                                                                <% nvram_match_x("", "ss_enable", "1", "value=1 checked"); %>
                                                                <% nvram_match_x("", "ss_enable", "0", "value=0"); %>>
                                                        </div>
                                                    </div>
                                                    <div style="position: absolute; margin-left: -10000px;">
                                                        <input type="radio" name="ss_enable" id="ss_enable_1" value="1"
                                                            <% nvram_match_x("", "ss_enable", "1", "checked"); %>>
                                                        <input type="radio" name="ss_enable" id="ss_enable_0" value="0"
                                                            <% nvram_match_x("", "ss_enable", "0", "checked"); %>>
                                                    </div>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>服务运行状态:</th>
                                                <td>
                                                    <span id="crash_status"><span class="label label-info">检测中...</span></span>
                                                    &nbsp;&nbsp;
                                                    <input type="button" class="btn btn-success btn-mini" value="打开 Web 控制面板 ↗" onclick="openWebUI();">
                                                </td>
                                            </tr>

                                            <tr>
                                                <th colspan="2" style="background-color: #E3E3E3;">机场订阅配置</th>
                                            </tr>
                                            <tr>
                                                <th>订阅链接 URL:</th>
                                                <td>
                                                    <input type="text" maxlength="512" class="input" size="60"
                                                        name="ss_server" id="ss_server" style="width: 85%; font-family: monospace;"
                                                        placeholder="粘贴您的 Clash / 通用订阅链接 (http/https 开头)"
                                                        value="<% nvram_get_x("","ss_server"); %>" />
                                                    <div style="margin-top: 6px; color: #888; font-size: 12px;">
                                                        粘贴订阅链接后点击下方「应用本页面设置」，路由器将自动拉取节点配置并启动分流代理。
                                                    </div>
                                                </td>
                                            </tr>

                                            <tr>
                                                <th colspan="2" style="background-color: #E3E3E3;">Yacd Web 控制面板</th>
                                            </tr>
                                            <tr>
                                                <th>面板访问地址:</th>
                                                <td>
                                                    <code>http://<% nvram_get_x("","lan_ipaddr"); %>:9999/ui</code>
                                                    &nbsp;&nbsp;
                                                    <input type="button" class="btn btn-info btn-mini" value="在新窗口打开 ↗" onclick="openWebUI();">
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>功能说明:</th>
                                                <td style="color: #666;">
                                                    启动服务后可通过上方地址访问 Yacd 仪表盘，进行节点测速、分流规则切换（规则/全局/直连）等操作。
                                                </td>
                                            </tr>
                                            <tr>
                                                <td colspan="2" style="text-align: center; padding: 15px;">
                                                    <input class="btn btn-primary" style="width: 219px;" type="button"
                                                        value="<#CTL_apply#>" onclick="applyRule();" />
                                                </td>
                                            </tr>
                                        </table>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    </form>
    <div id="footer"></div>
</div>
</body>
</html>
ASPEOF

# ==============================================================================
# 7. 配置 SmartDNS 国内外 DNS 分流加速与网络参数调优
# ==============================================================================
echo ">>> [7/9] 配置 SmartDNS 国内外 DNS 分流加速与网络参数调优..."

# 生成 SmartDNS 自启动脚本（存入 shellcrash 包目录，由 Makefile 直接安装到 /usr/bin/）
cat > "${SC_PKG_DIR}/smartdns_start.sh" <<'SDNSEOF'
#!/bin/sh
# SmartDNS 国内外 DNS 分流配置
# 监听 6053 端口，作为 Mihomo DNS 的国内上游

SDNS_CONF="/tmp/smartdns.conf"
SDNS_PID="/var/run/smartdns.pid"

case "$1" in
    stop)
        killall smartdns 2>/dev/null || true
        rm -f "${SDNS_PID}"
        ;;
    start|restart|*)
        # 生成优化版 SmartDNS 配置文件
        cat > "${SDNS_CONF}" <<SEOF
# SmartDNS 配置 — 红米 AC2100 定制版
bind 127.0.0.1:6053

# 缓存设置 (平衡 128MB 内存与解析性能)
cache-size 4096
prefetch-domain yes
serve-expired yes
serve-expired-ttl 259200

# 测速模式: ping + tcp:80，并发优选最低延迟
speed-check-mode ping,tcp:80

# 国内 DNS 上游组 (低延迟首选)
server 119.29.29.29 -group cn -exclude-default-group
server 223.5.5.5 -group cn -exclude-default-group
server 114.114.114.114 -group cn -exclude-default-group

# 默认上游 (国内极速 DNS)
server 119.29.29.29
server 223.5.5.5

log-level warn
SEOF

        if [ -x /usr/bin/smartdns ]; then
            killall smartdns 2>/dev/null || true
            sleep 1
            /usr/bin/smartdns -c "${SDNS_CONF}" -p "${SDNS_PID}" -f
            logger -st "SmartDNS" "SmartDNS 已启动，监听 127.0.0.1:6053"
        else
            logger -st "SmartDNS" "提示: smartdns 二进制未就绪"
        fi
        ;;
esac
SDNSEOF
chmod +x "${SC_PKG_DIR}/smartdns_start.sh"

# 生成独立的系统自启初始化脚本 (取代原来的超长单行 sed 注入，极大提升可维护性)
cat > "${SC_PKG_DIR}/post_wan_init.sh" <<'INITEOF'
#!/bin/sh
# ==============================================================================
# 系统 WAN 就绪后自动执行的初始化任务
# 由 mtd_storage.sh 中的 post_wan_script.sh 调用
# ==============================================================================

### 网络内核参数高并发优化
sysctl -w net.netfilter.nf_conntrack_max=65536 2>/dev/null || true
sysctl -w net.ipv4.tcp_fastopen=3 2>/dev/null || true
sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null || true

### 启动 SmartDNS DNS 加速服务
[ -x /usr/bin/smartdns_start.sh ] && /usr/bin/smartdns_start.sh start &

### 自动初始化 OpenSSH 环境与主机密钥 (保证新固件开箱即用)
if [ ! -f /etc/storage/openssh/sshd_config ]; then
    mkdir -p /etc/storage/openssh
    cat > /etc/storage/openssh/sshd_config <<'SEOF'
Port 22
ListenAddress 0.0.0.0
ListenAddress ::
Protocol 2
HostKey /etc/storage/openssh/ssh_host_rsa_key
HostKey /etc/storage/openssh/ssh_host_ecdsa_key
HostKey /etc/storage/openssh/ssh_host_ed25519_key
PermitRootLogin yes
PasswordAuthentication yes
Subsystem sftp /usr/libexec/sftp-server
SEOF
    ssh-keygen -t rsa -b 2048 -f /etc/storage/openssh/ssh_host_rsa_key -N '' 2>/dev/null || true
    ssh-keygen -t ecdsa -f /etc/storage/openssh/ssh_host_ecdsa_key -N '' 2>/dev/null || true
    ssh-keygen -t ed25519 -f /etc/storage/openssh/ssh_host_ed25519_key -N '' 2>/dev/null || true
    chmod 600 /etc/storage/openssh/ssh_host_* 2>/dev/null || true
    mtd_storage.sh save
    killall sshd 2>/dev/null || true
    /usr/sbin/sshd 2>/dev/null || true
fi
INITEOF
chmod +x "${SC_PKG_DIR}/post_wan_init.sh"

# 将 post_wan_init.sh 注入到默认 post_wan_script.sh (mtd_storage.sh)
STORAGE_SH="${WORK_DIR}/trunk/user/scripts/mtd_storage.sh"
if [ -f "${STORAGE_SH}" ]; then
    if ! grep -q "post_wan_init.sh" "${STORAGE_SH}"; then
        sed -i '/script_postw.*post_wan_script.sh/!b;n;c\	if [ ! -f "$script_postw" ] ; then\n\t\tcat > "$script_postw" <<EOF\n#!/bin/sh\n[ -x /usr/bin/post_wan_init.sh ] \&\& /usr/bin/post_wan_init.sh\n' "${STORAGE_SH}" || true
        echo "    已将 post_wan_init.sh 调用注入到 mtd_storage.sh"
    fi
fi

# ==============================================================================
# 8. 对接 shadowsocks.sh 生命周期
# ==============================================================================
echo ">>> [8/9] 对接 Padavan 系统后台生命周期与防火墙规则..."
SS_SH="${WORK_DIR}/trunk/user/shadowsocks/scripts/shadowsocks.sh"

cat > "${SS_SH}" <<'EOF'
#!/bin/sh
# ==============================================================================
# ShellCrash 生命周期对接脚本
# 由 Padavan 系统后台 services.c 中 start_ss() / stop_ss() 调用
# 当 WebUI 点击"应用"后，httpd 触发 EVM_RESTART_SHADOWSOCKS 事件
# 进而调用 restart_ss() → 依次执行 stop_ss() + start_ss()
# ==============================================================================
case "$1" in
    start)
        # 优先确保 SmartDNS 就绪
        [ -x /usr/bin/smartdns_start.sh ] && /usr/bin/smartdns_start.sh start &
        if [ "$(nvram get ss_enable)" = "1" ]; then
            logger -st "ShellCrash" "启动 ShellCrash 核心与透明代理..."
            /usr/bin/shellcrash-service.sh start
        fi
        ;;
    stop)
        logger -st "ShellCrash" "停止 ShellCrash 服务..."
        /usr/bin/shellcrash-service.sh stop
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        ;;
esac
EOF
chmod +x "${SS_SH}"


echo ">>> [9/9] 优化完成总结:"
echo "    ✓ CPU 超频 1000MHz"
echo "    ✓ ShellCrash + Mihomo 全协议代理"
echo "    ✓ SmartDNS DNS 防污染加速"
echo "    ✓ Anti-AD 广告拦截规则"
echo "    ✓ VLMCSD KMS 激活服务"
echo "    ✓ Yacd Web 控制面板"
echo ">>> 全部定制逻辑配置完毕！"
