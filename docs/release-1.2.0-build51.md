# ByteKibble 1.2.0 (51) · MU Labs

Apple silicon (arm64) **手动安装测试版**。最低 macOS 13。Developer ID 签名、Hardened Runtime 和时间戳已验证；**尚未 Apple 公证**，也不是 App Store 版本。

## 本次变化

- 菜单栏原生圆角弹窗采用不透底的暖灰背景，浅色／深色分别适配；轻微纵向渐层和暖橙氛围保持文字清晰。保留原生小箭头与卡片尺寸。
- 底部同步云朵改为次级图标，缩短与版本文字的可见间距而不缩小点击区域。
- 修复在未配置 iCloud 权限的 Mac 包中点击云朵打开同步窗口时的闪退。此时页面能打开，并在尝试启用 iCloud 时说明权限缺失；加密手动传输入口仍可用。
- macOS 正式 Bundle ID 统一为 `com.mulabs.bytekibble`。源码包含 iOS 开发工程和共享同步核心，但**本次没有发布 iOS App**。

## 升级与同步限制

**不要把此包当作 build 50 的原位更新。** 旧版使用 `com.bytekibble.app`，新标识改变偏好设置域和默认钥匙串身份。现有订阅、选择、手动重置日期、登录项及更新设置的真实迁移尚未验证。保留旧 App 和数据，必要时先备份；本次安装包不删除它们。旧 `preview.xml` 更新源仍指向 build 50，新 `mulabs.xml` 为空，不会跨标识自动推送。

本次可下载的 Mac 包**未配置 iCloud 签名权限，不能使用 iCloud 同步**。可在“同步与传输”中使用加密手动传输；文件和解密密钥分开保管。开发签名环境中的跨设备同步测试，不等于此发行包已具备该能力。

## 下载

- `ByteKibble-1.2.0-51-arm64-installer.zip`：解压得到带自定义 Finder 图标的拖拽安装 DMG。
- `ByteKibble-1.2.0-51-arm64.dmg`：直接打开并将 App 拖到“应用程序”。
- `ByteKibble-1.2.0-51-arm64.zip`：直接包含 App 的归档。
- `SHA256SUMS.txt`：对下载文件核对 SHA-256。以上三个包含同一个 build 51 App。

## 验证范围

2026-09-20 本机 macOS 27.2：共享核心 37 项及 Mac App 55 项自动测试通过。独立合成数据 QA 包中，实际点开同步窗口、确认缺少 iCloud 权限时显示说明；原生 NSPopover 的浅色和深色外观、云朵与版本号间距已检查。发行候选及嵌套 Sparkle 代码的 Developer ID 深度签名、ZIP 完整性和 DMG 校验通过。**未验证** Apple 公证、真实旧版数据迁移、所有 macOS 13–26 环境、GitHub 上的 OTA 安装或发行包的 iCloud 同步。

---

English: Build 51 is an Apple silicon manual-install prerelease for macOS 13+. It uses a new `com.mulabs.bytekibble` bundle identifier, a more legible subtly warm native menu popover, a quieter cloud icon, and a fix for opening Sync without iCloud entitlements. The downloadable Mac app **does not support iCloud sync**; encrypted manual transfer remains available. This is **not an in-place upgrade from build 50**. Keep the old app and its data while migration remains unverified. The old update feed remains on build 50 and the new feed is empty. Developer ID signed with Hardened Runtime and timestamp; **not Apple notarized**. Shared-core 37 and Mac-app 55 tests passed locally, and the native QA popover/sync fallback were inspected. This does not establish notarization, migration, older-system compatibility, GitHub OTA, or iOS App Store release.
