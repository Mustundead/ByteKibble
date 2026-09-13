> **build 49**：新增 Stash、Clash、Surge、Hiddify、Loon、sing-box 导入链接识别。[兼容范围与限制](docs/client-compatibility.md)。这是订阅地址解析，不是新增自动发现；流量仍取决于服务商数据。

<p align="center">
  <img src="docs/assets/app-icon-light.png" width="128" height="128" alt="字节猫粮：印有猫爪的暖金色粮袋图标">
</p>

<h1 align="center">字节猫粮 · ByteKibble</h1>
<p align="center">由 <a href="https://mustundead.com">MU Labs</a> 出品</p>
<p align="center">订阅流量，抬眼就见。</p>
<p align="center">简体中文 · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.en.md">English</a> · <a href="README.ko.md">한국어</a> · <a href="README.ja.md">日本語</a></p>

字节猫粮是一款原生 macOS 菜单栏订阅流量工具，用来查看**剩余流量、已用流量、套餐到期信息和重置提醒**。它可自动发现受支持的 Clash 系客户端及守候网络（SNTP）订阅，也可手动添加 Quantumult／Quantumult X、Surge 使用的 HTTPS 订阅链接，并解析 Shadowsocks SIP008 流量字段。能显示哪些信息取决于服务商返回的数据，具体条件见下方兼容性说明。

> **1.2.0（49）测试版**：提供应用源码、首次使用欢迎页和 Apple silicon（arm64）安装包。已使用 Developer ID 签名，**尚未 Apple 公证**。[下载与完整更新说明](https://github.com/mustundead/ByteKibble/releases/tag/v1.2.0-build49)。`preview/` 中的旧截图为历史资料。

**应用内更新（build 47 起）**：点击底部版本号可检查更新或关闭自动检查，安装需用户确认。build 46 及更早版本须先手动安装一次新版。更新检查联系 GitHub，不发送订阅链接或流量数据；测试版使用独立更新源。

<img src="docs/assets/quota-build46-full-dark.png" width="360" alt="原生菜单弹窗实拍 · 剩余流量 100%（示例数据，非真实订阅）">

原生菜单弹窗实拍 · 剩余流量 100%（示例数据，非真实订阅）

## 一眼看懂流量

- **菜单栏常驻剩余量**：数值显示剩余流量，实心饼图显示剩余比例；有客户端重置数据时显示倒计时。
- **点开查看详情**：套餐名、剩余／已用／总量、上行和下行、预计重置日期、套餐到期日期，以及来源与更新时间。
- **多个订阅，各自清楚**：自动发现可读取的客户端订阅，也可手动添加 HTTPS 订阅链接，切换查看对应读数。
- **有分寸的预警**：剩余不足 20% 时橙色提醒，不足 10% 时红色提醒；流量不足或用尽也有文字说明，不只依赖颜色。
- **原生 macOS 体验**：SwiftUI、浅色／深色外观、等宽数字、减少动态效果适配，以及明确标识开启／关闭状态的开机启动控制。
- **五种界面语言**：简体中文、繁体中文、英文、韩文和日语。

字节猫粮**不是代理客户端、VPN、测速工具或逐应用流量统计器**。它不会代替 Clash／Mihomo 路由网络，也不会改变服务商的套餐额度。

## 颜色与进度怎么读

| 剩余流量占比 | 显示 | 含义 |
| --- | --- | --- |
| ≥20% | 随外观变化的黑／白主色 | 正常 |
| ≥10% 且 <20% | 橙色 | 流量不足 |
| <10% | 红色 | 流量严重不足或已用尽 |

菜单栏饼图表示**剩余比例**；详情卡片的横向进度条表示**已用比例**，与“已用”百分比一致。警告色只表达流量风险，不表示套餐等级、连接状态或是否开启自启动；临近重置本身也不是故障。

## 订阅从哪里来

**当前版本兼容范围**：Quantumult／Quantumult X、Surge 使用的 HTTPS 订阅链接，只要服务商返回 `Subscription-Userinfo` 流量头即可查询；Surge 还可粘贴 `#!MANAGED-CONFIG https://…` 首行。Shadowsocks SIP008 支持 `bytes_used` 和 `bytes_remaining`，未提供上传／下载拆分时显示“— · 未提供”。这些客户端仍需手动添加，未新增自动发现；单个 `ss://` 节点不是流量查询链接。未声明完成所有客户端／服务商联测。

| 来源 | 自动读取内容 | 说明 |
| --- | --- | --- |
| Clash Verge／Clash Verge Rev | 本机 `profiles.yaml` 中的订阅链接 | 查询服务商返回的流量信息 |
| ClashX／ClashX Meta／ClashX Pro | 客户端偏好设置中的订阅链接 | 取决于客户端是否保存了可读取的配置 |
| 守候网络（SNTP） | 订阅链接、套餐和流量缓存、客户端报告的重置天数 | 缓存可能没有可信的原始更新时间 |
| 手动添加 | 粘贴的 HTTPS 订阅链接 | 服务商需提供可解析的流量信息 |

实时读数来自订阅请求的 `subscription-userinfo` 响应头，或无此标头时的 SIP008 JSON 流量字段。**使用 Mihomo 内核不等于支持自动发现**：自动发现针对上表的客户端存储格式，其他客户端可尝试手动添加链接。

字节猫粮不自行计量全部网络流量，读数以服务商／客户端返回值为依据。缺少流量头、关键字段不完整、总额为零或查询失败时，不应把未知数据理解为“剩余零”。旧读数请结合来源和更新时间使用。

### 重置与刷新

- 缺少重置日时，点“流量重置”卡片设置下一次日期。手动日期仅存本机，显示“手动”及 `*` 标记；可清除以恢复订阅信息。日期过后提示“日期已过”，不自动顺延，也不会清零服务商流量。

- 重置天数由客户端报告，不是通用订阅响应头中的标准字段。倒计时和“预计”日期据此推算，**不是服务商确认的重置时刻**；旧缓存可能影响准确性。
- 没有重置数据时不猜测日期。套餐到期与流量重置是两个不同概念。
- 应用运行时定期刷新，也可手动刷新；睡眠、网络和服务商响应可能导致延迟。
- 查询会尝试直连及常见本机代理端口（`7899`、`7890`、`7897`、`6152`），不会启动代理客户端或更改系统代理设置。

## 系统要求与安装

需要 **macOS 13 或更高版本**。原生 Liquid Glass 样式需要 macOS 26 或更高版本；旧系统使用兼容样式。安装包支持的处理器架构、签名和公证状态以对应发布说明为准。

从 [1.2.0（49）发布页](https://github.com/mustundead/ByteKibble/releases/tag/v1.2.0-build49) 下载 DMG 或 ZIP。先退出正在运行的旧版；DMG 打开后将 ByteKibble 拖到 Applications，ZIP 则解压后将应用移入“应用程序”。从“应用程序”启动，不要一直运行磁盘映像内的副本。首次使用会显示欢迎页。

本次二进制仅提供 **Apple silicon（arm64）**，不包含 Intel 版本。本地构建、测试及界面检查在 macOS 27 上完成；最低部署目标为 macOS 13，不代表所有旧系统均已实机验证。

推荐下载 `-installer.zip`：解压得到 DMG，并保留 App 主图与右下角开盒子角标。直接通过 HTTP 下载裸 DMG 不会保留 Finder 自定义图标元数据，安装内容相同。另一个 `-arm64.zip` 包含应用本体。

![1.2.0（43）DMG 实际窗口](docs/assets/installer-1.2.0.png)

如果 macOS 阻止打开，请先核对下载来源、签名和发布说明。仅在确认信任文件时，按 [Apple 官方说明](https://support.apple.com/guide/mac-help/mh40616/mac)在“系统设置 → 隐私与安全性”中处理。**签名不等于已公证**，不要为了安装而关闭系统安全保护。

启动后，确保支持的客户端已导入订阅，或在面板中添加 HTTPS 订阅链接。应用在菜单栏中工作；开机启动是独立选项，并非查看流量的前提。

## 隐私与边界

自动发现只读取本机客户端配置。手动添加的链接保存在字节猫粮的本机偏好设置中；添加、移除和撤销只影响应用自己的列表，**不修改或取消服务商订阅**。

订阅链接可能含访问令牌，请像密码一样保管。查询会联系对应服务商；经本机代理查询时，请求沿该代理配置的线路发送。字节猫粮没有自己的流量中转服务器，也不将订阅链接发送到分析平台。

反馈问题时请遮盖订阅地址、令牌和账户资料，不要在公开 Issue 或截图中粘贴完整链接。

## 从源码构建

安装包含 Swift 工具链的 Xcode 后：

```bash
git clone https://github.com/mustundead/ByteKibble.git
cd ByteKibble
swift build -c release
```

项目没有第三方运行时依赖。运行 `swift test -j 2` 执行测试；`bash scripts/package-local.sh release` 生成本机架构的 ad-hoc 签名应用，输出在 `output/acceptance/`。打包脚本需要带 `actool` 的 Xcode。源码构建不会自动使用发行者的 Developer ID，也不会自动公证。DMG 打包方法见 [发布记录](CHANGELOG.md)。

## 反馈与许可

通过 [Issues](https://github.com/mustundead/ByteKibble/issues) 反馈问题，请附 macOS 版本、应用版本、客户端名称和脱敏后的复现步骤。后续首次按新许可发布的原创内容采用[源码公开、非商业许可](LICENSE)：非商用免费，商用须事先取得 权利人的书面授权。由于含有商业用途限制，不再称为标准开源许可。

### MU Labs

由 [MU Labs](https://mustundead.com) 出品。代码复用、署名与商业授权要求见 [LICENSE](LICENSE)。

**不追溯旧授权。** 此前按 MIT 提供的代码和版本（包括 1.2.0（41）验收包）继续适用[原 MIT 许可](LICENSES/MIT-legacy.txt)，原有商用权限不受影响。新发布内容的适用范围以 [LICENSE](LICENSE) 为准。
