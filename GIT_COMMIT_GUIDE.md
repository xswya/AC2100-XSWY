# Git提交和编译指南

## 已修改的文件

1. `scripts/customize.sh` - 修复了ShellCrash透明代理的iptables规则
2. `SHELLCRASH_FIX_README.md` - 新增,包含详细的问题分析和修复说明

## 方法1: 使用Git命令行(推荐)

在项目目录 `D:\AC2100-XSWY` 下打开命令行或Git Bash,执行:

```bash
# 1. 查看修改状态
git status

# 2. 添加修改的文件
git add scripts/customize.sh
git add SHELLCRASH_FIX_README.md

# 3. 提交修改
git commit -m "fix: 修复ShellCrash透明代理导致路由器管理界面无法访问的问题

主要修复:
- 在iptables规则中排除路由器管理IP
- 使用mangle表标记路由器自身流量并跳过代理
- 完善清理规则,停止服务时清理mangle表
- 修复路由器DNS请求超时问题

Fixes:
- 路由器管理界面(192.168.123.1)无法访问
- ShellCrash状态显示异常
- 测速功能失败
- DNS超时(dial tcp 119.29.29.29:53: i/o timeout)"

# 4. 推送到GitHub
git push origin main
# 如果分支不是main,可能是master,请根据实际情况调整:
# git push origin master
```

## 方法2: 使用GitHub Desktop

1. 打开GitHub Desktop
2. 选择 `AC2100-XSWY` 仓库
3. 在左侧看到修改的文件列表
4. 勾选 `scripts/customize.sh` 和 `SHELLCRASH_FIX_README.md`
5. 在下方输入提交信息:
   - Summary: `fix: 修复ShellCrash透明代理问题`
   - Description: 复制下面的内容
   ```
   主要修复:
   - 在iptables规则中排除路由器管理IP
   - 使用mangle表标记路由器自身流量并跳过代理
   - 完善清理规则,停止服务时清理mangle表
   - 修复路由器DNS请求超时问题
   
   Fixes:
   - 路由器管理界面(192.168.123.1)无法访问
   - ShellCrash状态显示异常
   - 测速功能失败
   - DNS超时问题
   ```
6. 点击 "Commit to main"
7. 点击 "Push origin"

## 方法3: 直接在GitHub网页上操作

1. 访问 https://github.com/xswya/AC2100-XSWY
2. 点击 `scripts/customize.sh` 文件
3. 点击右上角的编辑图标(铅笔)
4. 将本地修改的内容复制粘贴进去
5. 滚动到页面底部,填写提交信息:
   - Commit message: `fix: 修复ShellCrash透明代理问题`
   - Extended description: 详细描述(同上)
6. 选择 "Commit directly to the main branch"
7. 点击 "Commit changes"
8. 重复步骤2-7上传 `SHELLCRASH_FIX_README.md` 文件(选择 "Create new file")

## 触发GitHub Actions编译

推送完成后,有两种方式触发编译:

### 自动触发
由于修改了 `scripts/` 目录下的文件,GitHub Actions会自动触发编译(工作流配置了paths触发)。

### 手动触发
1. 访问 https://github.com/xswya/AC2100-XSWY/actions
2. 点击左侧的 "Build Padavan for Redmi AC2100 (RM2100)"
3. 点击右侧的 "Run workflow" 下拉按钮
4. 选择 `main` 分支(或 `master`,根据实际情况)
5. 确保 "是否发布到 GitHub Releases" 选项勾选(默认true)
6. 点击绿色的 "Run workflow" 按钮

## 查看编译进度

1. 访问 https://github.com/xswya/AC2100-XSWY/actions
2. 点击最新的工作流运行记录
3. 查看编译进度和日志
4. 编译大约需要10-15分钟

## 下载固件

编译完成后:

1. **从Releases下载(推荐)**:
   - 访问 https://github.com/xswya/AC2100-XSWY/releases
   - 找到最新的Release(标签类似 `RM2100-20260917_XXXX`)
   - 下载 `.trx` 固件文件

2. **从Artifacts下载**:
   - 在Actions页面点击编译成功的工作流
   - 滚动到底部的 "Artifacts" 区域
   - 下载 `RM2100-Padavan-1000MHz-XXXXXXXX` 压缩包
   - 解压得到 `.trx` 固件文件

## 刷机

1. 进入Breed Web恢复控制台(192.168.1.1)
2. 选择"固件更新"
3. 上传下载的 `.trx` 文件
4. 等待刷机完成
5. 路由器自动重启

## 验证修复

刷机后重新配置ShellCrash订阅,然后验证:

```bash
# SSH连接到路由器
ssh admin@192.168.123.1

# 检查iptables规则
iptables -t nat -L CLASH -n -v
iptables -t mangle -L CLASH_MARK -n -v

# 检查Mihomo是否运行
ps | grep CrashCore

# 测试管理界面访问
curl -I http://192.168.123.1

# 测试Mihomo API
curl http://127.0.0.1:9999/version
```

应该能够:
- ✅ 正常访问路由器管理界面
- ✅ ShellCrash Web面板正常访问
- ✅ 测速功能正常工作
- ✅ 代理功能正常(国内直连,国外走代理)

## 常见问题

**Q: 推送时提示需要认证?**
A: 需要配置GitHub凭据。使用GitHub Desktop或配置SSH密钥。

**Q: 推送失败提示 "Permission denied"?**
A: 确保你有仓库的写入权限,或者fork后推送到自己的仓库。

**Q: 编译失败?**
A: 查看Actions日志,通常是依赖下载问题,重新运行即可。

**Q: 修改没有自动触发编译?**
A: 手动触发编译,或检查 `.github/workflows/build-padavan.yml` 中的paths配置。
