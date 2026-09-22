# ByteKibble iOS — 商店介绍文案

状态：2026-09-22 编辑稿；用于 0.1.0 build 2，尚未保存至商店。
范围：商店文案和介绍图，不改 App 内文案或构建。

## 简体中文

副标题：订阅流量，一处查看

宣传文本：还剩多少流量，什么时候到期？在 iPhone 上查看服务商提供的订阅用量，保留历史读数，也能导出记录。

描述：

打开 ByteKibble，查看订阅还剩多少流量。

剩余流量、已用流量和到期信息集中呈现，方便查看服务商提供的最新读数。

添加自己的订阅
粘贴受支持的 HTTPS 订阅链接，在 iPhone 上查询用量。无需注册 ByteKibble 账户。

接收 Mac 上选择的订阅
在 Mac 端选择要同步的订阅，通过 iCloud 在 iPhone 上查看。也可使用加密文件手动传输。

留下每次读数
查看已记录的历史用量，按需导出 CSV。导出包含读取时间和流量数字，不包含订阅名称、链接或凭据。

按自己的方式查看
可选择开启小组件和订阅提醒。小组件显示最近保存的读数；提醒依据已有读数，后台刷新和通知可能受系统调度影响，并非实时监控。

先体验，再添加
在设置中打开“体验演示”，无需提供真实订阅即可了解流量卡片、历史记录和导出功能。

使用须知
ByteKibble 是订阅流量查看工具，不提供 VPN 服务，不建立隧道，也不统计设备的全部网络流量。流量和到期信息取决于服务商返回的字段；缺失信息不会显示成零或自行推算。查看时请留意读取时间。

iCloud 同步需要 Mac 端先选择订阅，两端使用同一 Apple 账户并开启 iCloud 钥匙串。订阅链接默认保存在本机钥匙串；选择同步后才会通过 iCloud 钥匙串同步。

## English

Subtitle: Subscription usage at a glance

Promotional text: Check your remaining data and expiry date on iPhone. View provider-reported usage, keep a history of readings, and export your records.

Description:

Open ByteKibble to see how much data your subscription has left.

Find remaining data, used data, and expiry information together, based on the readings your provider supplies.

Add your subscription
Paste a supported HTTPS subscription link to check usage on iPhone. No ByteKibble account is required.

Bring selected subscriptions from your Mac
Choose subscriptions in ByteKibble for macOS and receive them on iPhone through iCloud. Encrypted file transfer is also available.

Keep a record
View saved usage readings and export them as CSV. Exports include reading times and data amounts, without subscription names, links, or credentials.

Choose how you check
Enable widgets and subscription reminders if you want them. Widgets show saved readings. Reminders use available readings, and system scheduling may delay background refreshes or notifications. They are not real-time monitoring.

Try it first
Open Experience Demo in Settings to explore usage cards, history, and export without providing a real subscription.

Before you start
ByteKibble is a subscription-usage viewer, not a VPN service. It does not create a tunnel or measure all network traffic on your device. Usage and expiry information depend on the fields your provider returns. Missing values are not treated as zero or estimated. Check the reading time when reviewing usage.

iCloud sync requires selecting subscriptions on the Mac first, using the same Apple Account on both devices, and enabling iCloud Keychain. Subscription links are stored in the device Keychain and sync through iCloud Keychain only when you choose to sync.

## 介绍图统一设计

- 石墨灰底色，少量暖橙色光线；背景不放假代码、假图表或假界面。
- 标题居中，能用一行就不用两行；最多两行。标题区域与手机中心位置在整组保持一致。
- 截图是主要内容，保留真实比例、原有文字和演示数据标识；不用生成后的 UI 替代原始截图。
- 现有 ImageGen 图仅是设计预览，不能因外观完善而视作准确的上架成品。

| 图 | 中文标题 | English headline | 截图内容 |
|---|---|---|---|
| 1 | 剩余流量，一眼看清 | Your remaining data, at a glance | 真实流量卡片；保留演示标识 |
| 2 | Mac 上选好，iPhone 上查看 | Choose on Mac. Check on iPhone. | 真实 iCloud 同步说明；不虚构已同步状态 |
| 3 | 用量记录，随时导出 | Keep your usage records | 真实 CSV 导出页；不增加虚构记录 |

## 核对依据与验收

- iOS/ByteKibble/Views.swift：设置中的小组件、提醒、数据说明和体验演示。
- 已有真实截图：流量卡片、iCloud 说明、CSV 导出；示例数字不能暗示用户真实余额。
- 尚未验证的 macOS App Store 版本不能宣传为已经上架；iCloud 功能说明不等于当前公开下载包已具备同步权限。
- 发布前检查：副标题不超过 30 字符，宣传文本不超过 170 字符，描述不超过 4000 字符；图片文字与功能一致，无变造 UI，导出尺寸符合对应槽位。
