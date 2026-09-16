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

---

## 三、关键技术点说明

### 1. 为什么红米 AC2100 必须精简 USB 和重型组件？
红米 AC2100 物理上**完全没有 USB 接口**。官方默认固件配置中包含了大量的 USB 主控驱动、文件系统（NTFS/FAT/EXT4）、Samba 文件共享、USB 打印机后台等，这些模块不仅占用 Flash 空间，更会在系统后台常驻无用进程与内核模块，白白消耗珍贵的 CPU 中断与内存。精简后可使路由器保持最低系统开销与极佳的长期稳定性。

### 2. MT7621 CPU 1000MHz 超频原理
MT7621 的基准时钟一般为 20MHz。CPU 频率由锁相环 CPUPLL 寄存器（`0x1E000648`）控制。通过计算反馈分频系数 `fbdiv = 50`，可输出 `20MHz * 50 = 1000MHz`。通过打入内核驱动级补丁，路由器上电即以 1.0 GHz 高主频运行，科学上网性能更上一层楼。
