# ByteKibble

> **Traffic monitor designed for Clash、Mihomo、SNTP**

macOS 菜单栏机场流量指示器：实时显示订阅**剩余流量**和**流量重置倒计时**，原生 SwiftUI 编写，单文件通用二进制（Apple Silicon + Intel），无任何第三方依赖。为 Clash 系客户端（Clash Verge、ClashX Meta、Mihomo 内核各分支）设计，同时兼容 SNTP（守候网络）官方客户端。

```
菜单栏：  💲93.2G · ⟳22天        （图标+数值带预警色，⟳ 后为距流量重置天数）
```

- 剩余不足 20% 变橙色，不足 7% 变红色
- 点开面板：套餐名、已用/总量、上行/下行、重置日期与倒计时、套餐到期、渐变进度条

## UI 设计

- 面板采用 **Liquid Glass** 视觉语言（macOS 26+：`glassEffect` 玻璃卡片、玻璃按钮、`GlassEffectContainer` 融合；旧系统自动回退为半透明卡片，尊重「降低透明度」辅助功能设置）
- 数字变化带 `numericText` 滚动过渡；等宽数字避免跳动；深浅色模式自适应
- 菜单栏：图标 + 剩余流量（预警色 <20% 橙 / <7% 红）+ ⟳ 重置倒计时

## 数据来源（自动检测）

| 优先级 | 客户端 | 读取位置 | 能拿到的信息 |
|---|---|---|---|
| 1 | Clash Verge (Rev) | `~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/profiles.yaml` | 订阅链接 |
| 2 | ClashX / ClashX Meta | defaults `kRemoteConfigs` | 订阅链接 |
| 3 | 守候网络（SNTP）官方客户端 | `defaults read com.sntp` 缓存 | 订阅链接 + 流量缓存 + **重置日** + 套餐名 |
| 4 | 手动添加 | 面板内粘贴任意机场订阅链接 | 订阅链接（万能兜底，任何 Clash 客户端通用） |

实时数据统一通过订阅链接的 `subscription-userinfo` 标准响应头查询（所有 Clash 兼容机场都支持）。检测到多个订阅时可在面板里切换。

## 实时查询的实现细节

- 订阅域名直连经常不通：自动依次尝试 **直连 → 127.0.0.1:7899 → 7890 → 7897**（各家客户端默认混合端口），成功端口会被记住
- 部分机场 TLS 配置不规范：对订阅域放行证书校验（与 curl -k、主流客户端行为一致）
- 面板按 User-Agent 下发流量头：请求使用 `clash-verge/1.7.7` UA
- 缓存策略：启动即显示客户端本地缓存；**每 15 分钟自动实时刷新**，失败后 1 分钟自动重试；打开面板必定实时刷新；点「刷新」立即更新；已禁用 App Nap，保证定时器不被系统休眠

## 安装（分享给朋友）

1. 解压 `ByteKibble.zip`，把 `ByteKibble.app` 拖入「应用程序」
2. 首次打开：**右键 → 打开 → 打开**（app 用 Developer ID 签名但未公证，直接双击会被 Gatekeeper 拦截）
3. 确保至少装着一个 Clash 客户端并已导入订阅，或手动粘贴订阅链接
4. 面板里可打开「自启」

## 已知限制

- **流量重置倒计时**只有守候网络客户端能拿到：其 `reset_day` 字段语义是「距下次重置的天数」（与官方客户端显示一致），据此显示「N 天后」并推算重置日期；Clash 标准订阅头不含该字段，其他来源重置行显示「—」。该字段随守候网络客户端同步刷新，若客户端长期未启动，倒计时可能偏大
- 实时刷新要求对应代理客户端正在运行（需要借它的本地端口出海）；客户端没开时显示缓存数据
- 需要 macOS 13+

## 构建

```bash
./build.sh    # 生成图标 → arm64+x86_64 编译 → 组装 .app → Developer ID 签名 → dist/ByteKibble.zip
```

更换签名身份：改 `build.sh` 里的 `IDENTITY`；无证书可改为 `codesign -s -`（ad-hoc）。

## 隐私

所有数据只存在本机：订阅链接（含 token）只写入本应用自己的偏好设置，不经过任何第三方服务器。
