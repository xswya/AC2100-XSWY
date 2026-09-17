# ShellCrash 问题修复说明

## 问题分析

从你提供的日志来看,发现了以下问题:

1. **路由器管理界面无法访问** - 启用ShellCrash后,路由器管理页面(192.168.123.1)打不开
2. **状态显示异常** - WebUI中ShellCrash状态一直显示"启用中"
3. **DNS超时** - 日志显示 `dial tcp 119.29.29.29:53: i/o timeout`
4. Mihomo核心本身运行正常(节点列表能正常获取,流量也在转发)

**根本原因:**

透明代理的iptables规则存在问题,把路由器自身发起的流量也劫持到Clash了,导致:
- 访问路由器管理IP时进入死循环
- 路由器自己的DNS请求被转发导致超时
- 测速功能失败(Yacd面板访问Mihomo API也被劫持)

## 已应用的修复

我已经修改了 `scripts/customize.sh` 文件,主要修复内容:

### 修复1: 排除路由器管理IP
在iptables规则的最前面添加了对路由器自身管理IP的排除:
```bash
LAN_IP="$(nvram get lan_ipaddr || echo 192.168.123.1)"
iptables -t nat -A CLASH -d "${LAN_IP}" -j RETURN
```

### 修复2: 标记路由器自身流量
使用mangle表标记路由器自己发起的流量,然后在nat表中跳过这些流量:
```bash
# 在mangle表中标记
iptables -t mangle -N CLASH_MARK 2>/dev/null || iptables -t mangle -F CLASH_MARK
iptables -t mangle -A CLASH_MARK -j MARK --set-mark 0xff
iptables -t mangle -A OUTPUT -j CLASH_MARK

# 在nat表中跳过标记的流量
iptables -t nat -I CLASH 1 -m mark --mark 0xff -j RETURN
```

### 修复3: 完善清理规则
在停止ShellCrash时也清理mangle表的规则:
```bash
iptables -t mangle -D OUTPUT -j CLASH_MARK 2>/dev/null || true
iptables -t mangle -F CLASH_MARK 2>/dev/null || true
iptables -t mangle -X CLASH_MARK 2>/dev/null || true
```

## 如何应用修复

### 方法1: 重新编译固件(推荐)

1. 修改已经应用到 `scripts/customize.sh` 文件
2. 提交更改到GitHub仓库:
```bash
git add scripts/customize.sh
git commit -m "fix: 修复ShellCrash透明代理导致路由器管理界面无法访问的问题"
git push
```
3. 在GitHub Actions中手动触发编译
4. 刷入新固件

### 方法2: 在现有固件上手动修复(临时)

如果你想在当前固件上临时测试修复,可以SSH连接到路由器执行:

```bash
# 1. 停止ShellCrash
/usr/bin/shellcrash-service.sh stop

# 2. 备份原始脚本
cp /usr/bin/shellcrash-service.sh /tmp/shellcrash-service.sh.bak

# 3. 下载修复后的脚本(需要先上传到某个可访问的地址)
# 或者手动编辑 /usr/bin/shellcrash-service.sh 文件

# 4. 重启ShellCrash
/usr/bin/shellcrash-service.sh start
```

## 验证修复

修复后,你应该能够:

1. ✅ 正常访问路由器管理界面 (http://192.168.123.1)
2. ✅ ShellCrash Web面板正常访问 (http://192.168.123.1:9999/ui)
3. ✅ 测速功能正常工作
4. ✅ 代理功能正常(国内直连,国外走代理)
5. ✅ 路由器自己的DNS请求不会超时

## 其他建议优化

1. **DNS配置优化** - 当前配置中SmartDNS和Mihomo的DNS可能有冲突,建议:
   - 让局域网设备使用Mihomo的DNS (5353端口)
   - SmartDNS作为上游供Mihomo使用

2. **状态检测优化** - WebUI中的状态检测可以改进为:
   - 检测Mihomo API是否响应 (curl http://127.0.0.1:9999/version)
   - 检测iptables规则是否正确加载

3. **日志轮转** - 当前日志会无限增长,建议限制大小或定期清理

## 技术细节说明

**为什么要用mark 0xff标记:**
- Linux内核的OUTPUT链处理本机发起的流量
- 在mangle表的OUTPUT链打标记
- 在nat表的PREROUTING链匹配标记并跳过
- 这样路由器自己的DNS/NTP/更新等流量就不会被劫持到Clash

**为什么要排除路由器管理IP:**
- 访问192.168.123.1时,如果被重定向到7892端口
- Clash会尝试连接192.168.123.1:80
- 但这个请求又会被iptables劫持,形成死循环
- 直接排除目标地址是最简单的解决方案

## 问题排查

如果修复后仍有问题,可以通过SSH执行以下命令检查:

```bash
# 检查Mihomo是否运行
ps | grep CrashCore

# 检查iptables规则
iptables -t nat -L CLASH -n -v
iptables -t mangle -L CLASH_MARK -n -v

# 检查Mihomo日志
tail -f /tmp/ShellCrash/crash.log

# 测试Mihomo API
curl http://127.0.0.1:9999/version

# 测试DNS
nslookup google.com 127.0.0.1
```

## 联系与反馈

如果修复后仍有问题,请提供:
1. 新的日志输出
2. iptables规则输出
3. 具体的错误现象描述
