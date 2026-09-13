# ByteKibble 1.2.0 (46) · MU Labs

## 本次更新

- **手动重置日期**：点“流量重置”卡片，设置下一次重置日期。仅在本机按订阅保存；卡片标注“手动”，顶部／菜单栏倒计时带 `*`。可清除并恢复订阅信息。日期过去会提示“日期已过”，不自动顺延、不修改服务商规则、不清零真实用量。
- **Quantumult / Quantumult X**：手动添加服务商的 HTTPS 订阅；服务商返回 `Subscription-Userinfo` 时可读取上传、下载、总量及可选到期日。已加入 Quantumult 官方格式回归测试。这个格式没有标准重置日字段，套餐到期日不会被当作流量重置日。
- **Shadowsocks SIP008**：新增 version 1 JSON 的 `bytes_used` / `bytes_remaining` 解析。上传和下载未拆分时显示“— · 未提供”；不推测到期日、重置日或无限套餐总额。
- **Surge**：可粘贴 HTTPS 订阅链接或 `#!MANAGED-CONFIG https://…` 托管配置首行。仅提取链接，不执行配置内容；服务商仍需提供流量信息。查询回退新增本机 HTTP 代理端口 `6152`。
- 五种语言的添加提示、重置设置及 README 同步更新。配图为原生运行界面，示例数据明确标注。

## 如何升级和使用

1. 退出旧版 ByteKibble。建议下载 `ByteKibble-1.2.0-46-arm64-installer.zip`，解压后打开 DMG，把 App 拖进 Applications 替换旧版。安装器 ZIP 可保留 Finder 自定义图标；也提供独立 DMG 和 App ZIP。
2. 从 Applications 启动；原有订阅设置不需要重新添加。
3. 如果重置日显示“—”，请在服务商后台确认下一次重置日期，再点重置卡片填写。不要使用套餐到期日代替每月重置日。

## 已验证与边界

- 34 项本地自动测试通过，覆盖订阅解析、非法／缺失字段、溢出、手动日期持久化／清除／订阅隔离／删除撤销／过期处理及 TLS 拒绝。
- DMG 完整性与两个 ZIP 的归档结构已检查；DMG 内 App 版本和签名单独核验。附件提供 SHA-256 校验文件。
- 原生隔离 QA 已点击验证设置、保存与清除手动日期；样例不代表真实服务商联测。
- Quantumult X、Surge 和 Shadowsocks 客户端**未新增自动发现**，也未完成所有客户端／服务商组合联测。服务商限制 User-Agent 或使用其他代理端口时仍可能查询失败。
- Apple silicon（arm64），macOS 13 起；未验证所有旧版系统，不提供 Intel 包。
- Developer ID 签名并启用 Hardened Runtime，**尚未 Apple 公证**。本次不是 App Store 发布。

## English summary

Build 46 adds per-subscription local reset dates, clearly marked Manual and `*`. Dates can be cleared; past dates do not repeat or reset actual usage. It adds Shadowsocks SIP008 aggregate quota parsing and regression coverage for Quantumult headers. Surge users can paste an HTTPS URL or the first `#!MANAGED-CONFIG` line; localhost HTTP proxy port 6152 is included in fallback attempts. These clients still require manual entry and provider-supplied quota metadata. 34 local tests passed. Apple silicon prerelease, Developer ID signed, not notarized.
