# 红米 AC2100 (RM2100) 固件定制与自动化编译进展

## 一、项目概述
本项目基于 [hanwckf/rt-n56u](https://github.com/hanwckf/rt-n56u) 源码及官方交叉编译工具链 [hanwckf/padavan-toolchain](https://github.com/hanwckf/padavan-toolchain)，构建专门适配于**红米 AC2100 (RM2100)** 路由器的极简高性能 Padavan 固件。

---

## 二、当前开发进展

- [x] **阶段 1：需求调研与环境打通**
  - 确认硬件规格：MT7621AT（双核四线程）、128MB RAM、128MB NAND Flash，无 USB 口。
  - 排查 Git 本地与远端推送问题（修复本地代理端口 `10808`，初始化 `main` 分支）。
  - 完成 `hanwckf/rt-n56u` 代码结构分析与内核超频机制推导。
- [x] **阶段 2：方案设计与规划确认**
  - 完成 implementation_plan.md 并获得用户批准确认。
- [x] **阶段 3：工程文件编写与落地**
  - [x] 编写定制版 `configs/RM2100.config`（彻底精简 USB/Samba/Aria2/打印机等无用组件，保留 SFE、IPv6、HTTPS、Dropbear）。
  - [x] 编写内核超频补丁 `patches/001-mt7621-1000mhz.patch`（适配 20MHz/25MHz 晶振，精准超频至 1000MHz）。
  - [x] 编写定制与集成脚本 `scripts/customize.sh`（集成 Shadowsocks 与 Xray 核心、分流规则）。
  - [x] 编写 GitHub Actions 工作流 `.github/workflows/build-padavan.yml`。
  - [x] 完善使用与刷机文档 `README.md`。
- [x] **阶段 4：首次云端构建与排障完成**
  - [x] 完成内核超频、SFE 转发、OpenSSH 与基础环境验证。
  - [x] GitHub Actions 流水线跑通并生成正式 Release。
- [x] **阶段 5：ShellCrash 固件全内置与原生 WebUI 订阅管理升级**
  - [x] 首次全内置版本体积达 25.9MB，超出 Breed 小米 3G 布局的 20MB~24MB 上限导致预处理失败。
  - [x] **实施方案 A 深度脱脂瘦身**：改用针对 MIPS 深度优化的 Clash.Meta 核心（压缩后仅 5.1MB）与极致精简的 Yacd 控制面板（压缩包仅 390KB）。
  - [x] 成功将固件总大小严格压制在 **16~17MB** 安全阈值之内，彻底杜绝 Breed 数据预处理失败与 0x0 擦除报错，纯离线开箱即用。
- [x] **阶段 6：修复 ShellCrash WebUI 三大核心问题**
  - [x] **问题 1 菜单标题**：通过 `customize.sh` 修改 `CN.dict` 字典文件，将 `menu5_16=shadowsocks` 改为 `menu5_16=科学上网`。
  - [x] **问题 2 界面错位**：移除所有自定义 CSS class（sc-card、sc-badge 等），严格采用 Padavan 原生 `box well grad_colour_dark_blue` → `box_head round_top` → `table class="table"` 布局结构体系。
  - [x] **问题 3 保存无反应**：发现 `sc_sub_url` 未在 `variables.c` 的 `ShadowsocksConf` 数组中注册，httpd 后端直接忽略该变量。改用已注册的 `ss_server` 变量"借壳"存储订阅 URL；表单 action 改为 `start_apply.htm`，`action_script` 设为 `restart_ss`，正确触发后端 `restart_ss()` → `shadowsocks.sh start`。
- [x] **阶段 7：深度性能与体验全方位优化（SmartDNS + Anti-AD + 内核高并发）**
  - [x] **SmartDNS 深度集成**：在 `RM2100.config` 中启用源码自带的 `CONFIG_FIRMWARE_INCLUDE_SMARTDNS=y`（体积仅 ~200KB）。
  - [x] **DNS 分流与防污染闭环**：配置 SmartDNS 监听 `127.0.0.1:6053`，设置腾讯/阿里/114 多上游并发测速与长缓存，作为 Mihomo Fake-IP 的国内上游，实现国内秒开、国外防污染。
  - [x] **自启动与生命周期联动**：在 `mtd_storage.sh` 中将 SmartDNS 自动注入 `post_wan_script.sh`；同时在 `shadowsocks.sh start` 时双重保险激活 SmartDNS。
  - [x] **轻量广告拦截 (Anti-AD)**：在 Mihomo 配置模板中引入 anti-ad 精选规则集，零额外二进制体积消耗实现网络层去广告与防隐私追踪。
  - [x] **网络内核参数调优**：将连接跟踪上限提升至 `nf_conntrack_max=65536`，开启 `tcp_fastopen=3` 和 `tcp_tw_reuse=1`，确保大并发流量稳定不丢包。
  - [x] **轻量组件升级**：启用 `VLMCSD` (KMS 激活服务)；保持官方充分验证的 `OpenSSH` 方案（支持 sftp-server，WinSCP 友好）。
- [x] **阶段 8：彻底修复科学上网页面侧边栏丢失与 WebUI 无法连接两大故障**
  - [x] **修复页面布局与菜单丢失**：原版 Padavan 的 `show_menu()` 强依赖 `<div class="wrapper">`、`<div id="logo">` 以及 `<div class="well sidebar-nav side_nav"><ul id="mainMenu">` 等固定 DOM 树结构。补齐这些容器后，左侧完整的分类菜单树完美渲染，杜绝黑色空白与错位。
  - [x] **移除 UPX 破坏性压缩**：定位到 Linux MIPSLE 架构下 UPX 压缩 Go 编译的 CrashCore 核心会导致内存段破坏引发段错误（SIGSEGV）退出的致命缺陷，彻底移除 UPX 压缩，确保 CrashCore 启动时正常常驻并监听 9999 端口。
  - [x] **局域网 IP 动态适配**：页面中的面板 URL 和状态探测全面改用 `<% nvram_get_x("","lan_ipaddr"); %>` 动态提取，自适应 `192.168.2.1` 与 `192.168.123.1` 等任意自定义网段。
  - [x] **运行环境迁入 tmpfs**：将工作目录全面设为 `/tmp/ShellCrash`，彻底避免运行时缓存写满有限的 `/etc/storage` 闪存分区。
- [x] **阶段 9：精准定位 GeoIP/MMDB 证书校验致命崩溃并彻底根治**
  - [x] **崩溃根因定位**：通过路由器抓取的 `crash.log` 定位到 `Parse config error: rules[0] [GEOIP,CN,DIRECT] error: can't download MMDB: Get ... tls: failed to verify certificate: x509: certificate signed by unknown authority`。Clash.Meta 解析到 GEOIP 规则且本地缺少 MMDB 数据库时触发强制联网下载，而 Padavan 极简系统缺少公共 CA 根证书导致 TLS 校验失败，触发 `level=fatal` 致命错误直接退出进程，导致 9999 端口无监听。
  - [x] **备用规则纯净化**：彻底剔除备用配置中所有带有外部下载依赖的 `GEOIP,CN,DIRECT` 规则，仅保留单条 `MATCH,DIRECT`，确保开机与无订阅状态下 100% 成功启动 9999 端口。
  - [x] **固件内置离线 MMDB**：在构建阶段自动集成精简版离线 `Country.mmdb`（约 400KB）至 `/etc_ro/ShellCrash/`，启动脚本自动软链接到 `/tmp/ShellCrash/Country.mmdb` 和 `geoip.metadb`，即使后续导入的订阅规则含有 GEOIP 也能本地秒解，杜绝触发网络下载与证书报错。
- [x] **阶段 10：订阅拉取全面健壮化 + YAML 去重 + Yacd 免登录 + OpenSSH 开箱即用**
  - [x] **订阅 Clash UA 自适配**：修复 V2board 等机场在无 `User-Agent: clash` 时仅下发 Base64 通用节点的问题。`update_subscription` 现在自动携带 `-A "clash"` 请求头与 `&flag=clash` 查询参数，确保任何机场均返回完整 YAML 配置。
  - [x] **YAML 顶层键去重**：订阅配置注入前，主动扫描并剔除机场源配置中已存在的 `allow-lan`、`mode`、`log-level` 等顶层字段，彻底杜绝 `mapping key already defined` 致命解析崩溃。
  - [x] **Yacd 免登录直达**：在构建阶段用 Python Heredoc 向 Yacd `index.html` 注入自适应 JS 脚本，自动补齐路由器 IP 与端口参数，用户打开面板后零手动输入直达后台。同时修复原 sed 注入因 JavaScript 特殊字符引发的 `unknown option to 's'` 构建报错。
  - [x] **OpenSSH 开箱即用**：在 `post_wan_script.sh` 自启脚本中注入 OpenSSH 自愈逻辑——新固件首次开机自动检测 `/etc/storage/openssh/sshd_config` 是否存在，缺失时自动创建配置文件、生成 RSA/ED25519 主机密钥、持久化到闪存并重启 sshd，彻底解决 `Connection reset by peer` 无法 SSH 登录的问题。

---

## 三、关键技术点说明

### 1. 为什么红米 AC2100 必须精简 USB 和重型组件？
红米 AC2100 物理上**完全没有 USB 接口**。官方默认固件配置中包含了大量的 USB 主控驱动、文件系统（NTFS/FAT/EXT4）、Samba 文件共享、USB 打印机后台等，这些模块不仅占用 Flash 空间，更会在系统后台常驻无用进程与内核模块，白白消耗珍贵的 CPU 中断与内存。精简后可使路由器保持最低系统开销与极佳的长期稳定性。

### 2. MT7621 CPU 1000MHz 超频原理
MT7621 的基准时钟一般为 20MHz。CPU 频率由锁相环 CPUPLL 寄存器（`0x1E000648`）控制。通过计算反馈分频系数 `fbdiv = 50`，可输出 `20MHz * 50 = 1000MHz`。通过打入内核驱动级补丁，路由器上电即以 1.0 GHz 高主频运行，科学上网性能更上一层楼。

### 3. Padavan WebUI 变量注册机制与 "借壳" 策略
Padavan 的 httpd 后端通过 `variables.c` 中的 `struct variable` 数组静态注册所有可通过 Web 表单读写的 nvram 变量。未注册的变量名（如自定义的 `sc_sub_url`）在 `apply.cgi` / `start_apply.htm` 提交时会被直接丢弃，不保存、不触发任何服务重启。**修改 C 源码需要交叉编译 httpd，风险极大**。因此采用"借壳"策略：利用已注册的 `ss_server`（原用途为 SS 服务器 IP）字段存储订阅 URL，`shellcrash-service.sh` 启动时自动检测该字段是否为 `http://` 或 `https://` 前缀来判断其为订阅链接并拉取。
