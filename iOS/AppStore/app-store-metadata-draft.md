# ByteKibble 0.1.0 (1) — App Store metadata draft

Local preparation only. Do not paste the URLs below into App Store Connect until
the public pages have been verified from the release account.

## Product

- Name: ByteKibble
- Subtitle (English): Subscription usage, at a glance
- 副标题（简体中文）：订阅流量，一处查看
- Primary category: Utilities (confirm in App Store Connect)
- Secondary category: Productivity (optional; confirm)
- Keywords (English, <=100 chars): `subscription,quota,traffic,allowance,iCloud,usage,Clash,Surge`
- 关键词（简体中文，<=100 字符）：`订阅,流量,额度,用量,到期,iCloud,Clash,Surge`
- Copyright: `© 2026 MU Labs` only if the rights holder confirms this exact form.

## Description — English

See the allowance your subscription provider reports, in one focused place.
ByteKibble shows remaining data, used data, expiry information and recorded
history when those fields are available. Add an HTTPS subscription, or receive
selected subscriptions from ByteKibble for macOS through iCloud. When iCloud
isn’t available, import an encrypted transfer file.

ByteKibble is not a VPN client. It does not create a tunnel, change proxy
settings or read another app’s configuration. Subscription links stay in the
device Keychain unless you choose iCloud sync. Queries go directly to the
subscription provider; ByteKibble has no MU Labs analytics or credential
backend. Missing provider fields remain unavailable rather than being guessed.

## 描述 — 简体中文

查看服务商返回的订阅流量，一处掌握剩余额度、已用流量、到期信息和历史读数。添加 HTTPS 订阅，或通过 iCloud 接收 macOS 版 ByteKibble 中选择的订阅；无法使用 iCloud 时，也可以导入加密传输文件。

ByteKibble 不是 VPN 客户端，不建立隧道、不修改代理设置，也不会读取其他 App 的配置。订阅链接默认保存在本机钥匙串，只有选择同步时才会使用 iCloud。查询会直接发送到订阅服务商；ByteKibble 没有 MU Labs 分析服务或凭据后端。服务商未提供的字段会显示为不可用，不会自行推算。

## Review notes — factual flow

1. Launch the app. The first screen explains the product and offers “Add Your First Subscription” or “Skip for Now”.
2. The app has no account login and no MU Labs account. A reviewer can inspect the empty state and the “Usage & Privacy” page without entering credentials.
3. To inspect populated screens without a real subscription, open Settings → Experience Demo. The demo uses synthetic local data only: it does not read Keychain credentials, subscription links, iCloud, widgets, reminders, or background refresh, and all changes are discarded on exit.
4. iCloud is opt-in. The Mac version must first enable iCloud and select subscriptions; both devices must use the same Apple Account and iCloud Keychain. If there is no Mac data, the iOS app truthfully shows that iCloud has no subscriptions yet.
5. The app does not require a personal subscription URL, token, or account to inspect the onboarding, privacy explanation, empty state, manual-transfer explanation, settings and history-export explanation.

## Privacy / support fields still required

- Support URL: not confirmed in this repository.
- Privacy Policy URL: not confirmed in this repository.
- Marketing URL: optional; verify an existing public ByteKibble page before use.
- App privacy answers must cover direct provider requests, local Keychain storage,
  optional CloudKit private-database metadata, optional iCloud Keychain links,
  local notifications, and widget App Group snapshots. Do not claim “no data
  collected” solely because MU Labs has no analytics server.

## Candidate screenshot set

These are acceptance captures, not yet approved marketing screenshots. Review
each in App Store Connect’s device frame and remove any capture with personal
status-bar/context data before publishing.

- iPhone 6.7-inch: `output/ios-welcome-captures/705D8092-A194-4D68-A21E-7FAB2E75E10E.png`
- iPhone 6.7-inch English sync: `output/ios-sync-ui-english-captures/CA2B790F-DEEE-4AD1-9915-4BBC1202A64C.png`
- iPhone 6.7-inch Chinese settings: `output/ios-device-final-captures/A057D045-8F69-4A77-871E-48A7292E8739.png`
- History export: `output/ios-history-accepted-captures/56E539FF-AADD-4D43-B35C-C0482EE6A061.png` (synthetic preview; use only if acceptable as a clearly representative screen)

The Chinese sync capture with a “Messages” back label is excluded from the
recommended set because it contains device navigation context.
