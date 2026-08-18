# 「芯脉」网络诊断：数据源、条款与隐私边界

最近核查：2026-08-18
适用实现：`ShixinNetworkDiagnosticsCore/NetworkDiagnostics.swift`、`NetworkDiagnosticsController.swift`

## 结论

当前版本不嵌入任何 API Key，也不新增线上后端：

- 国际连通性使用 Apple 原生 `URLSession`、`URLSessionTaskMetrics` 与本机 DNS 解析，只请求固定的轻量 HTTPS 端点。
- 本机网络详情使用 `Network.framework`、`SystemConfiguration`、`getifaddrs` 与 `CoreWLAN`，不经过 Helper，不执行 shell。
- 公网出口地址使用 ipify；地理与 ASN 摘要使用 ipwho.is；VPN、Proxy、Tor、Hosting、受损标签、风险值、供应商置信度与攻击历史使用 proxycheck.io。
- 公网与信誉查询必须由用户主动点击，并在查询前说明第三方会看到当前公网 IP。
- 历史只保存国家代码、ASN、网络类型、数据源与评分摘要，不保存完整公网 IP、本机 IP、MAC、BSSID、SSID 或 DNS 地址。

当前无 Key 路线适合 Beta 与小规模分发，但 ipwho.is 免费端点无 SLA，proxycheck.io 无 Key 限额为每个查询出口每天 100 次。2026-08-18 已按官方页面复核；任何面向大规模用户的正式分发仍应重新核对供应商条款、额度与隐私说明，并由产品负责人决定是否继续直连或启用自有服务端代理。

## Whoer 参考边界

Whoer 的公开页面覆盖公网 IP、粗略位置、VPN/Proxy、黑名单、DNS/WebRTC 泄漏与浏览器环境一致性；其隐私政策也说明这类工具会处理 IP、粗略位置、User-Agent、语言、TLS/HTTP、WebRTC 与 DNS 等诊断信号。

「芯脉」只借鉴“分项、可解释”的产品价值，不复制页面、文案或固定扣分法：

- 原生 App 不读取浏览器 Cookie、账号或私人内容。
- 原生 App 无法证明所有浏览器不存在 WebRTC 泄漏，因此该项明确显示“未验证”。
- 仅列出本机 DNS 服务器不能证明 DNS 泄漏。真正验证需要为本次测试生成唯一域名，并由可控权威 DNS 服务记录实际查询出口；当前未部署此后端，因此不伪造结论。
- 不声称找到了 VPN 隐藏的“真实 IP”；只有 IPv4/IPv6 出口存在可复现差异时，才提示可能分流或 IPv6 绕行。

参考：

- [Whoer Privacy Policy](https://whoer.net/privacy_policy)
- [Whoer DNS leak test](https://whoer.net/dns-leak-test)

## 当前采用的数据源

### ipify

用途：分别取得公网 IPv4 与 IPv6。

- 不需要 Key；提供独立 IPv4/IPv6 HTTPS 端点。
- 官方说明不记录访问者信息。
- 只返回 IP，不提供信誉或地理结论。
- App 不缓存完整 IP 到历史，只在当前 Sheet 内默认遮罩显示。

参考：[ipify official site](https://www.ipify.org/)

### ipwho.is

用途：国家/地区、城市、ISP、ASN、ASN 组织与时区摘要。

- 免费端点不需要 Key，标称每天 1,000 次，并明确标注允许商业使用。
- 免费端点不含 VPN、Proxy、Tor 等安全字段，也没有 uptime SLA。
- 条款禁止转售或重新分发其服务/材料；当前 App 只展示本次用户主动查询所需的少量字段，不转存原始响应或构建数据库。
- 条款与产品计划可能变化；大规模商业分发前需要再次核对，必要时取得供应商书面确认。

参考：

- [ipwho.is pricing and field coverage](https://ipwhois.io/pricing)
- [ipwho.is terms](https://ipwhois.io/terms)

### proxycheck.io

用途：VPN、公共代理、Tor、匿名网络、自动化抓取、Hosting、网络类型、风险值、供应商置信度、最近发现时间与攻击历史。

- API v3 已于 2026-06-24 发布稳定版，支持客户端 IP 检查；无 Key 时按查询出口每天 100 次。
- 查询固定启用 `risk=2`，用于取得风险分与攻击历史；若稳定版明确返回空攻击历史，App 按“未发现攻击记录”处理，而不是误写成供应商未提供。
- 解析器按官方 OpenAPI v3.1 结构实现：`detections`、`attack_history`、`operator.services`、`risk` 与 `last_updated`。主界面的八项状态只展示该响应明确提供的字段，其中包含 `anonymous` 与 `scraper`；攻击总量由各攻击类型计数求和；`warning` 状态下若主体数据有效仍可降级使用。
- 住宅代理只在 `operator.services` 明确给出 `residential_proxies` 时展示。v3 当前不提供独立 Relay 或 Anycast 字段，因此它们不进入主状态网格，也不会由 VPN、代理或网络类型反推。
- 请求固定使用 `tag=0`，官方说明这会关闭该次查询的 tagging 与 positive-detection log 保存。
- proxycheck.io 于 2026-08-06 新增账号级 Address Logging 开关，但无 Key 客户端无法依赖账号设置；当前请求继续逐次携带 `tag=0`，官方文档明确该参数仍然有效。
- 条款允许在自有服务中选取少量字段增强结果，但禁止原样转售或公开整个响应。
- 供应商风险分是模型信号，可能误判；App 会把 VPN/Hosting 属性与滥用风险分开，不把 VPN 或数据中心直接判为恶意。
- 当前仅展示选择后的字段，不保存原始响应，不使用或暴露私密 Key。

参考：

- [proxycheck.io API v3](https://proxycheck.io/api/)
- [proxycheck.io GDPR and tag=0](https://proxycheck.io/gdpr/)
- [proxycheck.io privacy](https://proxycheck.io/privacy/)
- [proxycheck.io permitted use](https://proxycheck.io/terms/)

## 已评估但当前未集成

| 数据源 | 能力 | 当前不采用的原因 |
|---|---|---|
| IPinfo Core / Plus | VPN、Proxy、Tor、Relay、Hosting、住宅代理、Anycast | Relay 与 Anycast 等完整字段需要 token 和对应套餐；不能把私密 token 放入桌面 App。若采用，应由用户自带 Key 或使用经确认的服务端代理。 |
| MaxMind GeoIP/Anonymous IP | 本地数据库、地理、匿名网络 | 当前数据库站点许可证主要限定内部用途；分发数据库或向第三方展示需要合适的商业/再分发许可，不能直接捆绑进 App。 |
| IPQualityScore | Proxy/VPN、欺诈风险、行为信号 | API URL 含私密 Key；官方也说明严格度提高会增加误报。只适合服务端代理，不适合硬编码客户端。 |
| AbuseIPDB | 滥用报告、置信度、时间窗口 | API Key 明确应视为私密且不适合客户端调用；免费计划仅供非商业个人/评估。商业发布需付费计划与服务端代理。 |

参考：

- [IPinfo Privacy Detection API](https://ipinfo.io/developers/privacy-standard-api)
- [MaxMind site license overview](https://www.maxmind.com/en/site-license-overview)
- [IPQualityScore Proxy Detection API](https://www.ipqualityscore.com/documentation/proxy-detection-api/overview)
- [IPQualityScore response parameters](https://www.ipqualityscore.com/documentation/proxy-detection-api/response-parameters)
- [AbuseIPDB API documentation](https://docs.abuseipdb.com/)
- [AbuseIPDB legal terms](https://www.abuseipdb.com/legal)

## 若未来启用自有后端

未经产品负责人确认不得部署。获批后应：

1. 保留 Provider 协议与解析器，App 只请求「芯脉」受控端点。
2. Key 仅存在服务端 Secret，不进入源码、Info.plist、App 包或 Git。
3. 以公网 IP 哈希或短期内存键做 5–15 分钟缓存，限制单 IP/设备频率。
4. 不记录完整公网 IP；安全日志仅保留时间、Provider 状态码和匿名限流计数。
5. 对 Provider 设置独立超时、熔断和降级，不因单一服务失败阻塞本机网络详情。
6. DNS 泄漏功能只有在唯一域名、权威 DNS 日志、过期清理和隐私说明全部具备后才能标记“已验证”。

## 评分原则

- 国际连通评分按每个目标的 DNS、TCP、TLS、HTTP、完整响应时间和波动分项计算；缺数据降低完整度与置信度。
- IP 信誉从 100 开始，只对受损/滥用、供应商高风险、公共代理等有解释的信号扣分；VPN 与 Hosting 仅作属性提示。
- 隐私一致性比较 IPv4/IPv6 国家和 ASN、系统时区/地区、代理/隧道与可复现双栈分流；DNS/WebRTC 未验证不作“安全”加分。
- 综合分至少需要两类可用评估；数据不足时返回“数据不足”，不生成虚假满分。
- 每个信号都带影响类型、分值变化和解释，界面显示分数、完整度、置信度、时间与来源。
