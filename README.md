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
   - 替换 OpenSSH 为极轻量的 **Dropbear**（启用快速对称算法）。
   - 保留与优化：SFE（Shortcut-FE 快捷转发，千兆跑满）、IPv6/NAPT66、HTTPS、IPSet、TTYD 网页终端。

2. **CPU 硬件超频至 1000 MHz**：
   - 内置内核驱动补丁，精准配置 MT7621 PLL 锁相环倍频寄存器。
   - 双核四线程 CPU 锁定在 **1000 MHz (1.0 GHz)** 高频稳定运行，大幅提升加密解密吞吐量与高并发带机量。

3. **开箱即用科学上网 (Shadowsocks & Xray)**：
   - **Shadowsocks / SSR**：Web 界面原生支持，支持 GFWList 与大陆 IP 绕过（Chnroute）分流模式。
   - **Xray**：内置最新 MIPSLE 架构优化版 Xray 核心 (`/usr/bin/xray`)，支持 VLESS / VMess / Trojan / REALITY 等现代协议。
   - **透明代理助手**：内置 `/usr/bin/xray-run.sh`，可一键挂载 iptables 透明代理转发规则，并自动结合 IPSet 大陆白名单分流。

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
   - **后台管理地址**：`http://192.168.123.1`
   - **管理员账号**：`admin`
   - **管理员密码**：`admin`
   - **默认 Wi-Fi 密码**：`1234567890`

---

## 科学上网使用说明

### 推荐方案：一键启用 ShellCrash (Clash Meta / Mihomo 核心，强烈推荐)
这是目前在 Padavan 路由器上**体验最完美、功能最强大**的科学上网方式：
- **支持所有订阅链接**：直接粘贴机场提供的 Clash / V2Ray / 通用订阅链接，自动拉取节点并定时更新。
- **全协议支持**：支持 Shadowsocks、VLESS (REALITY/Vision)、VMess、Trojan、Hysteria2 等现代主流协议。
- **自带精美 Web 图形面板**：通过浏览器直接可视化测速、切换节点、实时查看网络延迟与流量。

#### 安装与使用步骤：
1. **打开终端**：
   - 登录路由器 Web 管理页面（`192.168.123.1`），进入左侧菜单：**「高级设置」->「系统管理」->「终端」 (TTYD)**（或者电脑使用 SSH 连接 `192.168.123.1`，账号 `admin`，密码 `admin`）。
2. **执行一键安装命令**：
   在终端中粘贴以下命令并回车：
   ```bash
   export url='https://fastly.jsdelivr.net/gh/juewuy/ShellCrash@master' && sh -c "$(curl -kfsSl $url/install.sh)" && source /etc/profile &> /dev/null
   ```
   > 如遇网络波动，可使用备用安装源：
   > ```bash
   > export url='https://gh.jwsc.eu.org/master' && sh -c "$(curl -kfsSl $url/install.sh)" && source /etc/profile &> /dev/null
   > ```
3. **安装选项选择**：
   - 安装路径选择：输入数字推荐的选项（通常选小内存设备的 `/tmp` 或 `/etc/storage` 对应选项）。
   - 安装完成后，在终端直接输入 `crash` 并回车即可呼出管理菜单。
4. **导入订阅与启动**：
   - 在菜单中选择 `[1] 导入配置文件/订阅` -> 选择 `[1] 在线获取完整配置文件`。
   - 粘贴您的机场订阅链接，回车确认。
   - 配置获取成功后，按提示启动服务。
5. **打开 WebUI 图形化面板**：
   - 在局域网任意电脑或手机浏览器打开：`http://192.168.123.1:9999/ui`
   - 可以在页面上自由切换节点、测速、选择「规则模式 / 全局模式」，所有连接本路由器的设备自动实现智能分流翻墙！

---

### 备用方案：使用原生单节点配置 (Shadowsocks / Xray)

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
