# ShellCrash 问题修复方案 v2

## 问题总结

从你提供的截图和日志分析,发现以下问题:

### 1. 广告节点未被过滤
所有流量都走向"闪电⚡ / 自动选择 / 防失联 sdfabu.com"这个广告节点,而不是实际的代理节点。

### 2. 测速功能失败
Yacd面板中所有节点都没有显示延迟数据,点击测速按钮无响应。

### 3. WebUI状态显示不同步
管理界面显示ShellCrash关闭,但实际服务在运行(Mihomo核心正常工作)。

### 4. 路由器管理界面可能无法访问
之前的iptables规则会导致访问路由器管理IP时进入死循环。

## 根本原因分析

**问题1的原因:**
- 机场订阅中包含广告节点(名称含"防失联"、"官网"等关键词)
- 原配置没有过滤这些节点
- 代理组默认选择了第一个节点(恰好是广告节点)

**问题2的原因:**
- Yacd面板需要通过Mihomo API测速
- 可能是DNS配置问题导致测速请求无法到达节点
- 或者是路由器自身流量被劫持导致API请求失败

**问题3的原因:**
- WebUI的状态检测脚本使用简单的端口检测
- 没有真正检查Mihomo核心是否正常运行
- nvram变量ss_enable与实际服务状态不同步

**问题4的原因:**
- 透明代理规则把路由器自身流量也劫持了
- 访问192.168.123.1时被重定向到Clash端口导致死循环

## 已应用的修复

我已经修改了`scripts/customize.sh`,包含以下修复:

### 修复1: iptables规则优化
```bash
# 排除路由器管理IP
LAN_IP="$(nvram get lan_ipaddr || echo 192.168.123.1)"
iptables -t nat -A CLASH -d "${LAN_IP}" -j RETURN

# 标记路由器自身流量并跳过代理
iptables -t mangle -N CLASH_MARK
iptables -t mangle -A CLASH_MARK -j MARK --set-mark 0xff
iptables -t mangle -A OUTPUT -j CLASH_MARK
iptables -t nat -I CLASH 1 -m mark --mark 0xff -j RETURN
```

### 修复2: 广告节点过滤
添加了Python脚本自动过滤订阅配置中的广告节点:
```python
ad_keywords = ['防失联', '官网', '订阅', '网址', 'sdfabu', '续费', '流量', '套餐']
# 过滤proxies列表和proxy-groups中的广告节点
```

### 修复3: DNS配置优化
保持了完整的DNS配置,包括fake-ip和fallback设置,确保测速功能正常。

## 需要额外修复的问题

虽然我已经修改了customize.sh,但还有一些问题需要进一步优化:

### 问题A: WebUI状态检测逻辑

当前Shadowsocks.asp中的状态检测只是简单地检测9999端口:
```javascript
img.src = 'http://' + host + ':9999/version?_t=' + Date.now();
```

这个方法不够可靠。建议改为:
```javascript
// 检测Mihomo API是否真正响应
fetch('http://' + host + ':9999/version')
    .then(r => r.json())
    .then(data => {
        if (data.version) {
            显示运行中
        }
    })
    .catch(() => 显示未运行);
```

但这需要修改ASP文件,当前customize.sh中已经有这个文件的完整重写,可以在下次编译时包含这个改进。

### 问题B: 默认节点选择

即使过滤了广告节点,还需要确保代理组的默认选择逻辑正确。当前配置可能需要添加:
```yaml
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - 自动选择
      - DIRECT
  - name: 自动选择
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
```

## 下一步操作

### 方案1: 重新编译固件(推荐)

1. 提交修改到GitHub:
```bash
cd D:\AC2100-XSWY
git add scripts/customize.sh
git commit -m "fix: 修复ShellCrash广告节点过滤和透明代理问题"
git push
```

2. 触发GitHub Actions编译(修改scripts目录会自动触发)

3. 下载新固件并刷入

### 方案2: 临时修复(在当前固件上测试)

如果你想在当前固件上快速测试,可以SSH连接路由器执行:

```bash
# 1. 停止ShellCrash
/usr/bin/shellcrash-service.sh stop

# 2. 手动过滤配置文件中的广告节点
cat > /tmp/filter_ads.py << 'EOF'
import yaml, sys
with open('/tmp/ShellCrash/config.yaml', 'r') as f:
    conf = yaml.safe_load(f)
ad_keywords = ['防失联', '官网', '订阅', '网址', 'sdfabu', '续费', '流量', '套餐']
if 'proxies' in conf:
    original = len(conf['proxies'])
    conf['proxies'] = [p for p in conf['proxies'] 
                       if not any(kw in p.get('name', '') for kw in ad_keywords)]
    print(f'过滤了 {original - len(conf["proxies"])} 个广告节点')
if 'proxy-groups' in conf:
    valid = {p['name'] for p in conf.get('proxies', [])}
    for g in conf['proxy-groups']:
        if 'proxies' in g:
            g['proxies'] = [p for p in g['proxies'] 
                           if p in valid or p in ['DIRECT', 'REJECT']]
with open('/tmp/ShellCrash/config.yaml', 'w') as f:
    yaml.dump(conf, f, allow_unicode=True)
EOF

python3 /tmp/filter_ads.py

# 3. 重启ShellCrash
/usr/bin/shellcrash-service.sh start

# 4. 检查是否正常
curl http://127.0.0.1:9999/proxies | grep -o '"name":"[^"]*"' | head -n 20
```

## 验证步骤

修复后,请验证以下功能:

### 1. 检查节点列表
```bash
ssh admin@192.168.123.1
curl -s http://127.0.0.1:9999/proxies | grep -o '"name":"[^"]*"' | head -n 20
```
应该看到实际的代理节点,而不是"防失联"之类的广告节点。

### 2. 测试路由器管理界面
浏览器访问 http://192.168.123.1 应该正常打开管理页面。

### 3. 测试Yacd面板
访问 http://192.168.123.1:9999/ui 点击节点测速,应该能看到延迟数据。

### 4. 测试代理功能
```bash
# 在连接路由器的电脑上测试
curl -I https://www.google.com
```
应该能正常访问。

### 5. 检查流量走向
在Yacd面板的"连接"标签页查看,流量应该走实际的代理节点,而不是"防失联"节点。

## 常见问题

**Q: 为什么需要Python来过滤节点?**
A: 因为YAML格式比较复杂,用sed/awk难以准确处理嵌套结构,Python的yaml库更可靠。

**Q: 过滤会不会把正常节点也删了?**
A: 只过滤名称中包含特定关键词的节点,正常节点名称一般是"香港01"、"日本Tokyo"这种格式,不会被误删。

**Q: 为什么测速还是失败?**
A: 可能原因:
1. 节点本身延迟太高或无法连接
2. 路由器DNS解析问题
3. 检查 /tmp/ShellCrash/crash.log 查看错误信息

**Q: WebUI状态显示还是不对怎么办?**
A: 这需要修改ASP文件的JavaScript,建议等重新编译固件后测试。临时的话,直接看Yacd面板判断服务是否运行。

## 技术说明

### 为什么要标记路由器自身流量

Linux的iptables有几个处理链:
- OUTPUT链: 处理本机发出的流量
- PREROUTING链: 处理转发流量(来自局域网设备)

透明代理规则在PREROUTING链拦截局域网设备的流量,但如果路由器自己发起DNS查询、访问管理界面等操作,这些流量也会经过OUTPUT链。如果OUTPUT链的流量也被劫持到Clash,就会形成死循环(Clash自己的请求又被转发回Clash)。

解决方法是用mangle表给OUTPUT链的流量打标记(mark 0xff),然后在nat表的CLASH链最前面跳过这些标记的流量。

### 广告节点的识别逻辑

机场为了推广,通常会在订阅中插入一些特殊节点:
- 名称包含"防失联"、"官网"、"续费"等宣传词
- 这些节点要么无法连接,要么跳转到机场网站
- Clash会按配置文件中的顺序选择第一个可用节点
- 如果第一个就是广告节点,所有流量都会失败

通过关键词过滤可以清除这些节点,让代理组只包含真正的代理服务器。

## 联系与反馈

如果修复后仍有问题,请提供:
1. SSH执行 `cat /tmp/ShellCrash/config.yaml | head -n 100` 的输出
2. `iptables -t nat -L CLASH -n -v` 的输出
3. `tail -n 50 /tmp/ShellCrash/crash.log` 的输出
4. Yacd面板的截图

这样能更准确地定位问题。
