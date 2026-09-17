# 红米 AC2100 (RM2100) Padavan 极简高性能固件自动化编译

本仓库用于通过 **GitHub Actions** 自动化编译适配于**红米 AC2100 (Redmi Router AC2100 / RM2100)** 的 Padavan (老毛子) 固件。

- **源码上游**：[hanwckf/rt-n56u](https://github.com/hanwckf/rt-n56u)
- **官方交叉编译工具链**：[hanwckf/padavan-toolchain](https://github.com/hanwckf/padavan-toolchain)

---

## 固件特性与深度定制

1. **极致精简 (Lean & Fast)**：
   - 物理无 USB 接口，彻底裁撤所有 USB 驱动与守护进程（降低系统调用开销与内核内存）。
   - 剥离 Samba/WINS、Aria2、Transmission、MiniDLNA、Firefly、xUPNPd 等重型文件共享/媒体服务。
   - 剥离各种校园网认证协议客户端（Dogcom, MinieAP, MentoHUST 等）。
   - 采用官方验证最成熟的 **OpenSSH**（集成 sftp-server 支持，WinSCP 可直接可视化拖拽管理系统文件）。
   - 保留与优化：SFE（Shortcut-FE 快捷转发，千兆跑满）、IPv6/NAPT66、HTTPS、IPSet、TTYD 网页终端。

2. **CPU 硬件超频至 1000 MHz**：
   - 内置内核驱动补丁，精准配置 MT7621 PLL 锁相环倍频寄存器。
   - 双核四线程 CPU 锁定在 **1000 MHz (1.0 GHz)** 高频稳定运行，大幅提升加密解密吞吐量与高并发带机量。

3. **全协议科学上网 (全内置 ShellCrash + Mihomo + Yacd)**：
   - **全协议支持**：内置深度优化的 Mihomo (Clash Meta) 核心，支持 SS/SSR/VMess/VLESS/Trojan/Hysteria2 全协议。
   - **原生界面直控**：左侧菜单直达「科学上网」，利用 Padavan 纯原生表单无缝保存订阅。
   - **图形化控制台**：内置 Yacd Web 控制面板 (`http://192.168.2.1:9999/ui`)，图形化一键测速、分流与节点切换。

4. **DNS 防污染与并发加速 (SmartDNS)**：
   - 内置 SmartDNS 极速解析引擎，并发多上游测速（腾讯+阿里+114）。
   - 与 Mihomo Fake-IP 紧密协同，国内域名直连秒开，国外域名防污染，体验质变提升。

5. **广告拦截与网络内核调优**：
   - 集成 Anti-AD 规则集，轻量拦截常见弹窗、追踪与流氓域名。
   - 网络高并发参数优化：扩大网络连接跟踪表 (`nf_conntrack_max=65536`)、开启 TCP Fast Open 与连接复用。

---

## 如何触发 GitHub Actions 编译？

### 方式一：手动触发 (推荐)
1. 访问您在 GitHub 上的仓库页面：[AC2100-XSWY](https://github.com/xswya/AC2100-XSWY)
2. 点击顶部的 **Actions** 选项卡。
3. 在左侧选择 **Build Padavan for Redmi AC2100 (RM2100)**。
4. 点击右侧的 **Run workflow** 下拉框，选择 `main` 分支，点击绿色按钮即可开始自动编译。
5. 编译耗时大约在 **10~15 分钟** 左右。编译完成后，固件 `.trx` 文件将自动发布在 **Releases** 和 **Artifacts** 中。

### 方式二：自动触发
向本仓库推送任何对 `configs/`、`patches/`、`scripts/` 或工作流文件的修改时，GitHub Actions 会自动触发构建。

---

## 刷机指南

1. **进入 Breed Web 恢复控制台**：
   - 路由器断电，用卡针按住 Reset 键不放，插上电源线。
   - 保持按住 Reset 约 5 秒，直到指示灯闪烁后松开。
   - 电脑网线连接路由器 LAN 口，浏览器打开 `192.168.1.1` 进入 Breed 控制台。
2. **备份与刷入**：
   - 建议在 Breed 中先备份 `EEPROM`。
   - 在 Breed 的「固件更新」页面中选择编译生成的 `RM2100_1000MHz_Slim_*.trx` 文件进行刷入。
   - 刷完自动重启。
3. **默认管理信息**：
   - **后台管理地址**：`http://192.168.2.1`
   - **管理员账号**：`admin`
   - **管理员密码**：`admin`
   - **默认 Wi-Fi 密码**：`1234567890`
   > ⚠️ 如果您已在 Breed 中修改过 LAN IP，请将上述地址替换为您的实际 IP。

---

## 科学上网使用说明 (固件全内置 ShellCrash + Web 控制台)

**本固件现已直接在 ROM 中预装 ShellCrash 全套资产（含 Mihomo 软浮点核心与 Yacd 图形面板），无需登录终端敲任何命令，直接在网页上即可完成一切操作！**

### 极简使用流程（只需两步）：
1. **登录路由器管理后台**：
   - 浏览器打开 `192.168.2.1`，登录后台；
   - 点击左侧导航栏菜单：**「科学上网」**。
2. **粘贴机场订阅并启用**：
   - 在 **「订阅链接」** 输入框中粘贴您的 Clash / 通用订阅地址；
   - 开启 **「启用 ShellCrash」** 开关；
   - 点击底部的 **「应用本页面设置」**（会自动保存并触发拉取节点与启动服务）。
3. **可视化节点测速与选择**：
   - 点击页面上的 **「在新窗口打开 Web 控制面板」**，或者直接访问 `http://192.168.2.1:9999/ui`；
   - 点选您想要使用的节点，所有连接路由器的手机、电脑、电视即可享受智能分流高速翻墙！

---

## 验证 CPU 超频 1000MHz

SSH 连接路由器后台后，执行以下命令即可查看 CPU 实时主频：
```bash
cat /proc/cpuinfo
```
其中的 BogoMIPS 提升约 14%（相比默认 880MHz），系统启动日志中会明确输出：
```text
CPU/OCP/SYS frequency: 1000/250/250 MHz
```
