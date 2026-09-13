# ByteKibble 1.2.0 (45) · MU Labs

Apple silicon（arm64）测试版。Developer ID 签名并启用 hardened runtime；**尚未 Apple 公证**。

## 本次更新

- 剩余流量低于 10% 时显示红色预警（原为低于 7%）；10% 至不足 20% 为橙色，20% 及以上保持常规颜色。
- 流量卡片改用 App icon 猫粮袋主体的灰度背景，浅深色适配。图案直立、右下角放大裁切、透明度均匀，无渐淡；卡片尺寸不变。
- 五种语言的说明同步新版阈值及下载入口，展示品牌为 MU Labs。

## 下载与安装

推荐 `ByteKibble-1.2.0-45-arm64-installer.zip`：解压后得到带 App icon 和开盒子角标的 DMG。退出旧版，打开 DMG，将 ByteKibble 拖到 Applications，再从“应用程序”启动。

也提供裸 DMG，以及直接包含 App 的 `ByteKibble-1.2.0-45-arm64.zip`。三者对应同一应用；SHA-256 见 `SHA256SUMS.txt`。裸 DMG 经 HTTP 下载不会保留 Finder 自定义文件图标元数据，installer ZIP 会保留。

## 验证边界

- macOS 27 / Apple silicon 本地 20 项自动测试通过。
- 发布应用及 DMG 内应用的 deep/strict 签名校验通过；DMG 校验和两种 ZIP 的完整性检查通过。
- 本次背景图案在原生隔离 QA 界面的浅色、深色状态下检查；这不是安装后全流程验收。
- 最低部署目标 macOS 13，未覆盖所有旧系统实机；不提供 Intel 二进制。
- 未完成 Apple 公证、真实开机启动以及所有客户端组合的端到端验证。
- 许可范围以仓库 LICENSE 与 LICENSES/MIT-legacy.txt 为准。

## English

Build 45 changes the red warning threshold from below 7% to below 10% remaining. Orange applies from 10% to below 20%. The quota card uses the app's kibble-bag artwork as an upright, grayscale, bottom-right cropped background without increasing card size or applying a gradient fade. Light and dark native QA previews were checked; 20 automated tests passed locally.

Apple silicon only. Developer ID signed with hardened runtime, **not notarized**. The installer ZIP preserves the DMG's custom Finder icon metadata. Compatibility across all older macOS releases, actual login-item execution and all client combinations has not been verified.
