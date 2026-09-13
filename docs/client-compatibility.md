# 客户端订阅兼容 / Client subscription compatibility

以下新增导入能力从 build 49 提供，不在 build 47 或已送公证的 build 48 中。
The new import forms below are available starting with build 49, not included in build 47 or the submitted build 48.

## 输入与边界 / Input contract

| 客户端 / Client | 可粘贴内容 / Accepted input |
| --- | --- |
| Stash | 原始 HTTPS 订阅；`stash://install-config?url=…`；`https://link.stash.ws/install-config/…`（无额外 query 参数） |
| Clash 系 | 原始 HTTPS 订阅；`clash://install-config?url=…` |
| Surge | 原始 HTTPS 订阅；`#!MANAGED-CONFIG` 首行；`surge:///install-config?url=…` 与 `surgeconfig` 同类链接 |
| Hiddify | 原始 HTTPS 订阅；`hiddify://import/https://…#名称`；旧式 `install-config` / `install-sub` 的 `url` 参数 |
| Quantumult / Quantumult X、Shadowsocks | 继续使用原始 HTTPS 订阅 / Use the original HTTPS subscription |
| Loon | 原始 HTTPS 订阅；`loon://import?nodelist=…` 或 `loon://import?sub=…`，仅单个参数 |
| sing-box | 原始 HTTPS 订阅；`sing-box://import-remote-profile?url=…` |

以上地址只有在服务商返回可解析的 `Subscription-Userinfo` 或受支持的 SIP008 流量字段时才能显示余额。配置能够导入客户端，不等于配置地址提供套餐流量。这是**订阅数据格式兼容**，不是客户端全部完成实机联测，也不是新增自动发现。

Shadowrocket、v2rayN / v2rayNG 等暂不列为专用接入已验证：可手动尝试原始 HTTPS 订阅，但不接受未经核实的专用导入格式，不承诺账号余额或客户端自动发现。

Original HTTPS subscriptions used with other clients can use the same parser if the provider supplies a valid `Subscription-Userinfo` header or supported SIP008 usage fields. This is data-format compatibility, not verified integration with every client.

- 不打开客户端 URL Scheme；只在本地提取 HTTPS 地址，后续查询仅联系订阅端点，不经第三方转换服务。
- 不执行配置、脚本、模块或代理节点；`ss://`、`vmess://`、`vless://`、`trojan://` 单节点不是流量接口。
- 拒绝 HTTP、内嵌账号密码、重复 `url` 参数和非导入动作。外层名称不作为订阅地址保存。
- 不新增自动发现，不改变系统代理、客户端配置或真实额度。普通 VPN 的账号套餐接口不在本次范围。
- 无流量字段时不会根据节点名称猜余额；无重置字段时可手动设置日期，不以套餐到期日代替重置日。
- Extract HTTPS addresses locally; never launch client commands, execute configuration, or change network settings. Missing usage/reset information remains unknown.

## 依据与验收 / References and verification

- [Stash 官方 URL Schema](https://stash.wiki/en/faq/url-schema)：采用配置导入格式；不采用开关、覆写、图标动作或 HTTP 降级选项。
- [Surge 官方 URL Scheme](https://manual.nssurge.com/tools/url-scheme.html)：只采用配置导入；不采用模块或许可动作。
- [Hiddify 官方 URL Scheme](https://github.com/hiddify/hiddify-app/wiki/URL-Scheme)：采用 HTTPS 订阅包装；拒绝单节点包装。
- [Loon 节点文档](https://nsloon.app/en/docs/Node/)与 [URL Scheme](https://nsloon.app/en/docs/Scheme/)：采用流量头示例测试及节点／配置导入；拒绝插件、规则、解析器和 VPN 开关。未添加其 Universal Links。
- [sing-box 官方远程配置](https://sing-box.sagernet.org/clients/general/)：采用远程配置导入包装；不把运行时流量统计当作套餐余额，不支持内嵌 Basic Auth 凭据。
- [Shadowrocket 开发者官网](https://shadowlaunch.com/)（由 App Store 开发者链接核对）：本次未找到足够的公开导入协议资料；未采用第三方教程猜测实现。
- 2026-09-13：先前 Hiddify 查询参数丢失测试失败已修复；随后 38 项测试通过。新增 Loon / sing-box 回归另行运行，不继承旧结果。
- 解析验证：2026-09-13 20:52，`swift test --scratch-path .build-audit -j 2`，39 项通过；`git diff --check` 通过。未完成客户端实机联测；安装包状态见对应发布说明。
- 回归测试覆盖地址和百分号编码保留、重复参数、危险协议、非配置动作；不使用真实令牌。客户端实机、服务商联测与发布包验收仍需分别完成。
