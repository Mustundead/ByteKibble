# ByteKibble 1.2.0 (49) · MU Labs

Apple silicon（arm64）测试版，Developer ID 签名，**尚未 Apple 公证**。最低 macOS 13。

## 本次更新

- 根据官方文档新增 Stash、Clash、Surge、Hiddify、Loon、sing-box 的订阅／配置导入链接解析。粘贴后仅提取 HTTPS 订阅地址，不执行客户端动作、配置、脚本或插件。
- 保留订阅 token 编码，拒绝 HTTP、内嵌账号密码、重复 URL 参数及非导入动作。
- 原始 HTTPS 订阅仍可查询；服务商须提供可解析的 Subscription-Userinfo 或受支持的 SIP008 流量字段。配置可导入不代表提供流量数据。
- 不新增客户端自动发现、不猜测重置日。Shadowrocket 专用链接尚未确认，不宣称已完成专用接入。
- [逐项支持范围与官方依据](https://github.com/mustundead/ByteKibble/blob/main/docs/client-compatibility.md)。

## 安装与更新

- `-installer.zip`：解压得到 DMG，保留安装器自定义图标。
- `.dmg`：打开后将 App 拖入 Applications。
- `-arm64.zip`：应用本体，也是 Sparkle 签名更新包。
- `SHA256SUMS.txt`：下载校验值。
- build 47 用户可通过底部版本菜单检查更新；安装需确认。build 46 及更早版本需先手动安装新版。
- build 48 是独立公证候选，不包含本次改动。其公证结果不适用于 build 49。

## 验证边界

39 项本地测试通过，涵盖官方格式样例、token 保留、无效协议和非导入动作。未完成所有客户端／服务商实机联测，未声明所有旧 macOS 或真实用户 OTA 升级验收通过。

build 49 的 Developer ID 深层严格签名验证、Hardened Runtime 与时间戳检查、DMG 校验和两个 ZIP 完整性检查通过；OTA ZIP 的 EdDSA 签名已在本地验证。

GitHub 四个附件已上传且摘要与本地一致；从公开地址重新下载应用 ZIP 后，SHA-256 与 EdDSA 验证通过。此为下载与包签名验证，不等同于真实用户 OTA 安装验收。

## English

Adds documented Stash, Clash, Surge, Hiddify, Loon and sing-box import-link parsing. Only the HTTPS subscription address is extracted; client actions and configuration are not executed. Provider quota metadata is still required. No new automatic discovery or verified Shadowrocket-specific integration. 39 local tests passed; not an end-to-end certification of every client or provider. Developer ID signed, Apple silicon prerelease, **not notarized**. Build 48's separate notarization submission does not apply to this build.
