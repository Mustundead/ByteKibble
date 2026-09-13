# 更新记录 / Changelog

## 1.2.0（45）— 2026-09-13

- 红色流量预警阈值由剩余不足 7% 调整为不足 10%；剩余 10% 至不足 20% 仍为橙色。
- 剩余流量卡片采用 App icon 猫粮袋的灰度背景，适配浅色和深色外观；图案直立放大，贴右下角裁切，不使用渐淡，保持原卡片尺寸。
- 同步五种语言的预警阈值及新版下载链接；品牌展示使用 MU Labs。
- 本地 20 项自动测试通过；图案在原生隔离测试界面的浅色、深色外观下检查。
- Apple silicon（arm64）测试版；Developer ID 签名，尚未 Apple 公证。未声明覆盖所有旧版 macOS、真实开机启动或所有客户端组合。
- 下载与校验见 [1.2.0（45）发布页](https://github.com/mustundead/ByteKibble/releases/tag/v1.2.0-build45)。旧版 43 的记录和附件保持不变。

## 1.2.0（43）— 2026-09-13

Apple silicon（arm64）测试版。应用已使用 Developer ID 签名并启用 hardened runtime，尚未 Apple 公证。本次源码及安装包包含以下变更。

### 界面与安装

- 菜单栏面板改为原生圆角弹出窗，小圆角箭头与窗体连为一体。
- 更新猫粮袋 App 图标、剩余流量卡片脚印，保持图形等比缩放。
- 新增首次使用欢迎页，采用透明插画与 MU LABS 标识；清理插画底部残留阴影并缩小页脚标识。
- 新增手绘背景拖拽安装 DMG，窗口内只显示 ByteKibble 与 Applications 两项；修正背景裁切、右侧留白及多余文件显示。
- DMG 文件图标以 App icon 为主体，右下角叠加 macOS 开盒子角标。`-installer.zip` 保留 Finder 图标元数据；裸 DMG 的 HTTP 下载不保留这部分元数据。
- 补全简体中文、繁体中文、英文、日文与韩文界面状态文案。

### 流量、状态与安全

- 菜单栏显示剩余流量及剩余比例，详情进度条显示已用比例。
- 剩余不足 20% 显示橙色提醒，不足 7% 显示红色提醒，并提供文字状态。
- 区分实时读数、缓存和查询失败；重新读取缓存不会把它标为刚刚更新。
- 拒绝缺失关键字段、负数、重复字段和无效总量的流量响应，避免把未知读数显示为测得的零余额。
- 请求状态按订阅隔离，切换订阅不被旧请求阻塞；移除订阅后忽略迟到的响应。手动订阅支持移除与撤销。
- 订阅去重包含来源主机与路径，避免不同服务商使用相同 token 时被错误合并。
- 保留系统 TLS 证书验证，拒绝重定向降级到 HTTP；用户可见错误不直接输出含订阅链接的原始网络错误。
- 保留客户端提供的重置倒计时并增加预计日期；该日期不是服务商确认的重置时刻。套餐到期与流量重置分别显示。
- 开机启动按钮区分开启、关闭和等待系统批准状态。

### 下载与安装

1. 推荐下载 `ByteKibble-1.2.0-43-arm64-installer.zip`，解压得到带自定义图标的 DMG。
2. 退出旧版，打开 DMG，将 ByteKibble 拖到 Applications。
3. 从“应用程序”启动，随后可推出磁盘映像。首次使用显示欢迎页。

也提供裸 DMG，以及直接包含 App 的 `ByteKibble-1.2.0-43-arm64.zip`。三种下载对应同一个 1.2.0（43）应用。SHA-256 校验值见发布附件 `SHA256SUMS.txt`。

### 已验证与明确边界

- macOS 27、Apple silicon 本地构建；19 项自动测试通过。
- 已检查真实 DMG 窗口、欢迎页；新版脚印在原生测试界面的浅色与深色外观下检查。
- 应用 deep/strict 代码签名验证、DMG 校验及 ZIP 完整性检查通过。
- 最低部署目标 macOS 13；未覆盖所有旧系统的实机验证。此次不提供 Intel 二进制。
- 尚未公证；未完成真实开机启动和所有客户端组合的端到端验证，不宣称这些验证已通过。
- 许可范围见 [LICENSE](LICENSE) 与 [原 MIT 文本](LICENSES/MIT-legacy.txt)，不改变此前已授予的 MIT 权利。

## English summary

Version 1.2.0 (43) is an Apple silicon prerelease, Developer ID signed with hardened runtime, not notarized. It adds a connected native rounded popover, revised app and paw artwork, a first-use welcome screen with clean transparent illustrations, and a hand-drawn drag-install DMG. The DMG file uses the app icon with a lower-right open-box badge; the installer ZIP preserves its Finder metadata.

Usage states distinguish live data, cache and failures. Parsing rejects incomplete or invalid allowance fields; requests are isolated per subscription; removed subscriptions reject late results. Deduplication includes the provider host and path. TLS validation is retained, HTTPS-to-HTTP redirects are rejected, and raw token-bearing network errors are not displayed. Reset dates remain explicitly estimated from client data. Five interface languages and explicit login-item states are included.

19 automated tests passed on macOS 27. Native installer and welcome screens, light/dark paw rendering, code signatures and archive integrity were checked locally. This does not establish runtime compatibility with every older macOS version, real login-item behavior or every client combination. No Intel binary or Apple notarization is included.

## 本地打包 / Local packaging

```bash
swift test -j 2
bash scripts/package-local.sh release
python3 -m pip install --target output/acceptance/dmg-tools ds-store==1.3.1 mac-alias==2.2.2
bash scripts/package-dmg.sh /absolute/path/to/ByteKibble.app
```

`package-local.sh` uses the host architecture and ad-hoc signing; it does not use the publisher's identity or notarize. Xcode with `actool` is required. `package-dmg.sh` preserves the supplied application's signature, creates the DMG and a metadata-preserving installer ZIP. The build counter is local; a new checkout does not reproduce release build number 43 automatically.
