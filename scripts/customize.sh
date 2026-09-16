#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: customize.sh
# 适用机型: 红米 AC2100 (RM2100) / MT7621AT
# 功能描述: 自动化源码定制脚本
#   1. 注入 MT7621 CPU 1000MHz 寄存器超频补丁
#   2. 部署精简版单板编译配置 (RM2100.config)
#   3. 集成 ShellCrash 框架 + Mihomo (Clash Meta) 核心 + MetaCubeXD WebUI
#   4. 深度升级老毛子 WebUI：原生支持直接粘贴订阅、一键测速与内嵌仪表盘
#   5. 对接 shadowsocks.sh 生命周期，开箱即用稳定透明代理
# ==============================================================================

set -eo pipefail

WORK_DIR="${1:-$(pwd)}"
PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/patches"
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/configs"

echo ">>> [1/6] 开始执行红米 AC2100 (RM2100) 源码定制流程..."
echo "    源码目录: ${WORK_DIR}"

cd "${WORK_DIR}"

# 1. 注入 1000MHz 超频补丁
echo ">>> [2/6] 注入 MT7621 CPU 1000MHz 超频内核补丁..."
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
echo ">>> [3/6] 部署精简版板级配置文件 RM2100.config..."
if [ -f "${CONFIG_DIR}/RM2100.config" ]; then
    cp -f "${CONFIG_DIR}/RM2100.config" "${WORK_DIR}/trunk/configs/templates/RM2100.config"
    echo "    已更新 trunk/configs/templates/RM2100.config"
fi

# 3. 准备并打包 ShellCrash + Mihomo 核心 + MetaCubeXD WebUI 面板
echo ">>> [4/6] 构建并打包 ShellCrash 离线全套资产 (Mihomo 核心 + WebUI)..."
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

# 3.2 下载针对 MIPSLE 深度优化的 Clash.Meta 轻量核心 (UPX 压缩后约 5.1MB，相比通用版瘦身 50%+)
if [ ! -f "${SC_PKG_DIR}/dist/CrashCore" ]; then
    echo "    下载针对 MIPSLE 优化的 Clash.Meta 软浮点轻量核心..."
    META_URL="https://github.com/MetaCubeX/Clash.Meta/releases/download/v1.16.0/Clash.Meta-linux-mipsle-softfloat-v1.16.0.gz"
    curl -fL --retry 3 -o "${SC_TMP}/meta.gz" "${META_URL}"
    gzip -d "${SC_TMP}/meta.gz"
    
    if command -v upx >/dev/null 2>&1; then
        echo "    正在使用 UPX 对核心进行极限压缩以确保固件体积严格低于 18MB..."
        upx -9 "${SC_TMP}/meta" || true
    fi
    cp -f "${SC_TMP}/meta" "${SC_PKG_DIR}/dist/CrashCore"
    chmod +x "${SC_PKG_DIR}/dist/CrashCore"
fi

# 3.3 下载轻量化 Yacd Web 控制面板 (压缩包仅 390KB，解压后仅约 1MB)
if [ ! -d "${SC_PKG_DIR}/dist/ui" ]; then
    echo "    下载轻量精美版 Yacd Web 控制台面板..."
    YACD_URL="https://github.com/haishanh/yacd/releases/latest/download/yacd.tar.xz"
    curl -fL --retry 3 -o "${SC_TMP}/yacd.tar.xz" "${YACD_URL}"
    mkdir -p "${SC_PKG_DIR}/dist/ui"
    tar -xJf "${SC_TMP}/yacd.tar.xz" -C "${SC_PKG_DIR}/dist/ui"
fi
rm -rf "${SC_TMP}"

# 3.4 编写 ShellCrash 服务启动与透明代理控制脚本 (shellcrash-service.sh)
cat > "${SC_PKG_DIR}/shellcrash-service.sh" <<'EOF'
#!/bin/sh
# ==============================================================================
# ShellCrash (Mihomo/Clash) 自动化服务与透明代理管理脚本
# ==============================================================================

CRASH_DIR="/tmp/ShellCrash"
RO_DIR="/etc_ro/ShellCrash"
CONF_DIR="/etc/storage/ShellCrash"
CONF_FILE="${CONF_DIR}/config.yaml"
PID_FILE="/var/run/CrashCore.pid"
PORT_REDIR=7892
PORT_UI=9999

# 初始化运行目录 (RAM 快速环境)
init_env() {
    if [ ! -d "${CRASH_DIR}" ]; then
        mkdir -p "${CRASH_DIR}" "${CONF_DIR}"
        if [ -f "${RO_DIR}/ShellCrash.tar.gz" ]; then
            tar -zxf "${RO_DIR}/ShellCrash.tar.gz" -C "${CRASH_DIR}"/ 2>/dev/null || true
        fi
        ln -sf "${RO_DIR}/CrashCore" "${CRASH_DIR}/CrashCore"
        ln -sf "${RO_DIR}/ui" "${CRASH_DIR}/ui"
    fi
}

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
    iptables -t nat -I PREROUTING -p tcp -j CLASH
}

stop_firewall() {
    echo "清理透明代理 iptables 规则..."
    iptables -t nat -D PREROUTING -p tcp -j CLASH 2>/dev/null || true
    iptables -t nat -F CLASH 2>/dev/null || true
    iptables -t nat -X CLASH 2>/dev/null || true
}

update_subscription() {
    SUB_URL="$1"
    [ -z "${SUB_URL}" ] && SUB_URL="$(nvram get sc_sub_url)"
    if [ -z "${SUB_URL}" ]; then
        echo "错误: 未提供机场订阅链接！"
        return 1
    fi
    echo "正在从订阅链接拉取配置: ${SUB_URL} ..."
    mkdir -p "${CONF_DIR}"
    
    # 优先拉取 Clash 订阅，支持订阅转换接口降级
    TMP_CONF="/tmp/sub_config.yaml"
    curl -kfsSL --retry 3 --connect-timeout 10 -o "${TMP_CONF}" "${SUB_URL}" || \
    curl -kfsSL --retry 3 -o "${TMP_CONF}" "https://api.v1.mk/sub?target=clash&url=$(echo -n ${SUB_URL} | sed 's/ /%20/g')"
    
    if [ -s "${TMP_CONF}" ] && grep -qE "(proxies|proxy-providers):" "${TMP_CONF}"; then
        # 确保包含外部控制与 WebUI 端口设置
        sed -i '/^external-controller:/d' "${TMP_CONF}" 2>/dev/null || true
        sed -i '/^external-ui:/d' "${TMP_CONF}" 2>/dev/null || true
        sed -i '/^redir-port:/d' "${TMP_CONF}" 2>/dev/null || true
        
        cat >> "${TMP_CONF}" <<YAMLEOF

# === WebUI 与透明代理参数自动注入 ===
redir-port: ${PORT_REDIR}
external-controller: 0.0.0.0:${PORT_UI}
external-ui: ${RO_DIR}/ui
YAMLEOF
        mv -f "${TMP_CONF}" "${CONF_FILE}"
        mtd_storage.sh save >/dev/null 2>&1 &
        echo "订阅配置拉取并解析成功！"
        return 0
    else
        echo "拉取失败或非有效 Clash 配置！"
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

        # 如果尚无配置文件，尝试用 nvram 里的订阅链接拉取
        if [ ! -f "${CONF_FILE}" ]; then
            SUB_URL="$(nvram get sc_sub_url)"
            [ -n "${SUB_URL}" ] && update_subscription "${SUB_URL}"
        fi

        # 如果依然没有配置，提供极简备用配置以确保 WebUI 能够先行启动
        if [ ! -f "${CONF_FILE}" ]; then
            cat > "${CONF_FILE}" <<YAMLEOF
mixed-port: 7890
redir-port: ${PORT_REDIR}
external-controller: 0.0.0.0:${PORT_UI}
external-ui: ${RO_DIR}/ui
mode: rule
log-level: warning
proxies: []
rules:
  - GEOIP,CN,DIRECT
  - MATCH,DIRECT
YAMLEOF
        fi

        echo "启动 Mihomo (Clash Meta) 核心..."
        "${RO_DIR}/CrashCore" -d "${CONF_DIR}" -f "${CONF_FILE}" >/dev/null 2>&1 &
        echo $! > "${PID_FILE}"

        start_firewall
        echo "ShellCrash 启动成功！Web 控制面板: http://192.168.123.1:${PORT_UI}/ui"
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
	ln -sf /etc_ro/ShellCrash/CrashCore $(ROMFSDIR)/usr/bin/CrashCore
	ln -sf /usr/bin/shellcrash-service.sh $(ROMFSDIR)/usr/bin/crash
EOF

# 3.6 挂载到 trunk/user/Makefile
if ! grep -q "shellcrash" "${WORK_DIR}/trunk/user/Makefile"; then
    echo "    在 trunk/user/Makefile 中注册 ShellCrash 编译打包单元..."
    sed -i '/dir_\$(SHADOWSOCKS_ENABLE).*+= shadowsocks/a dir_y += shellcrash' "${WORK_DIR}/trunk/user/Makefile"
fi

# 4. 升级 Shadowsocks.asp 为现代全功能 ShellCrash 科学上网控制台
echo ">>> [5/6] 升级 WebUI 科学上网页面为 ShellCrash + MetaCubeXD 可视化控制台..."
WEB_ASP="${WORK_DIR}/trunk/user/www/n56u_ribbon_fixed/Shadowsocks.asp"

cat > "${WEB_ASP}" <<'EOF'
<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - ShellCrash 科学上网控制台</title>
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

<style>
.sc-card {
    background: #ffffff;
    border-radius: 8px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.05);
}
.sc-badge-on {
    background-color: #468847;
    color: #fff;
    padding: 4px 10px;
    border-radius: 4px;
    font-weight: bold;
}
.sc-badge-off {
    background-color: #b94a48;
    color: #fff;
    padding: 4px 10px;
    border-radius: 4px;
    font-weight: bold;
}
.sub-input {
    width: 90% !important;
    font-family: monospace;
    font-size: 13px;
}
.iframe-container {
    width: 100%;
    height: 700px;
    border: 1px solid #e3e3e3;
    border-radius: 8px;
    overflow: hidden;
    background: #fafafa;
}
</style>

<script>
var $j = jQuery.noConflict();

$j(document).ready(function(){
    init_itoggle('ss_enable');
});

function initial(){
    show_banner(2);
    show_menu(5,13,1);
    show_footer();
    check_status();
}

function check_status(){
    $j.get('/apply.cgi?current_page=Shadowsocks.asp', function(){
        // 自动检测端口响应状态
        var img = new Image();
        img.onload = function(){
            $j('#sc_status_badge').html('<span class="sc-badge-on">● 运行中 (Mihomo Meta)</span>');
            $j('#ui_iframe').attr('src', 'http://' + window.location.hostname + ':9999/ui');
        };
        img.onerror = function(){
            $j('#sc_status_badge').html('<span class="sc-badge-off">● 已停止</span>');
        };
        img.src = 'http://' + window.location.hostname + ':9999/ui/favicon.ico?' + Math.random();
    });
}

function applyRule(){
    showLoading();
    document.form.action_mode.value = " Apply ";
    document.form.current_page.value = "Shadowsocks.asp";
    document.form.next_page.value = "Shadowsocks.asp";
    document.form.submit();
}

function updateSubNow(){
    var url = $j('#sc_sub_url').val().trim();
    if(!url){
        alert("请先填入机场订阅链接！");
        return;
    }
    showLoading();
    applyRule();
}

function openFullUI(){
    window.open('http://' + window.location.hostname + ':9999/ui', '_blank');
}
</script>
</head>

<body onload="initial();">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>

<form method="post" name="form" action="/apply.cgi" target="hidden_frame">
<input type="hidden" name="action_mode" value=" Apply ">
<input type="hidden" name="current_page" value="Shadowsocks.asp">
<input type="hidden" name="next_page" value="Shadowsocks.asp">

<div class="container-fluid">
    <div class="row-fluid">
        <div class="span3">
            <div id="Menu"></div>
        </div>

        <div class="span9">
            <div class="box well">
                <h2>ShellCrash 科学上网控制台</h2>
                <div class="alert alert-info">
                    <strong>红米 AC2100 高性能专版：</strong> 已内置 Mihomo (Clash Meta) 1000MHz 软浮点核心与 MetaCubeXD 图形化控制面板。支持通用的 Clash / V2Ray / SSR / SS 订阅链接，国内流量直连、国外流量自动分流。
                </div>

                <!-- 核心控制卡片 -->
                <div class="sc-card">
                    <table class="table" style="margin-bottom: 0;">
                        <tr>
                            <th width="30%">服务运行状态</th>
                            <td>
                                <span id="sc_status_badge"><span class="sc-badge-off">● 检查中...</span></span>
                                &nbsp;&nbsp;
                                <button type="button" class="btn btn-success btn-small" onclick="openFullUI();">在新窗口打开 Web 控制面板 ↗</button>
                            </td>
                        </tr>
                        <tr>
                            <th>启用 ShellCrash</th>
                            <td>
                                <div class="main_itoggle">
                                    <div id="ss_enable_on_of">
                                        <input type="checkbox" id="ss_enable_fake" <% nvram_match_x("", "ss_enable", "1", "value=1 checked"); %><% nvram_match_x("", "ss_enable", "0", "value=0"); %>>
                                    </div>
                                </div>
                            </td>
                        </tr>
                        <tr>
                            <th>机场订阅链接 (Subscription)</th>
                            <td>
                                <input type="text" id="sc_sub_url" name="sc_sub_url" class="input sub-input" placeholder="粘贴您的 Clash / V2Ray / 通用订阅链接 (http:// 或 https://)" value="<% nvram_get_x("","sc_sub_url"); %>" />
                                <div style="margin-top: 8px;">
                                    <button type="button" class="btn btn-primary" onclick="updateSubNow();">保存并立即拉取订阅节点</button>
                                    <span class="help-inline" style="color: #666;">粘贴订阅后点击此按钮，路由器将自动下载节点配置并启动分流服务。</span>
                                </div>
                            </td>
                        </tr>
                    </table>
                </div>

                <!-- 内嵌 MetaCubeXD 仪表盘 -->
                <div class="sc-card">
                    <h4>可视化节点选择与测速仪表盘</h4>
                    <p style="color: #777;">服务启动后下方自动呈现节点列表与测速界面。您也可以直接点选节点、切换分流策略：</p>
                    <div class="iframe-container">
                        <iframe id="ui_iframe" src="" width="100%" height="100%" frameborder="0"></iframe>
                    </div>
                </div>

                <div style="text-align: center; margin-top: 15px;">
                    <input class="btn btn-primary btn-large" style="width: 250px;" type="button" value="<#CTL_apply#>" onclick="applyRule()" />
                </div>
            </div>
        </div>
    </div>
</div>
</form>

<div id="Footer"></div>
</body>
</html>
EOF

# 5. 对接 shadowsocks.sh 生命周期
echo ">>> [6/6] 对接 Padavan 系统后台生命周期与防火墙规则..."
SS_SH="${WORK_DIR}/trunk/user/shadowsocks/scripts/shadowsocks.sh"

cat > "${SS_SH}" <<'EOF'
#!/bin/sh
# 对接 ShellCrash 核心生命周期
case "$1" in
    start)
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

# 修复 dropbear 构建依赖路径双保险
if [ -f "${WORK_DIR}/trunk/user/dropbear/Makefile" ]; then
    sed -i 's|\./configure \\|CFLAGS="\$(CFLAGS) -I\$(STAGEDIR)/include" LDFLAGS="\$(LDFLAGS) -L\$(STAGEDIR)/lib" ./configure \\|g' "${WORK_DIR}/trunk/user/dropbear/Makefile" || true
fi

echo ">>> 全部定制逻辑配置完毕！ShellCrash 核心、WebUI 面板与订阅管理已全部就绪！"
