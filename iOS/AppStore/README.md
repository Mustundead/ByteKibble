# iOS submission preparation — not submitted

This is a local checklist, not an assertion that Apple has approved the app.

## Product facts for review

ByteKibble displays usage data returned by a user's subscription provider. It is not a VPN client, does not establish a tunnel, does not sell a proxy subscription, and cannot measure all network traffic. Missing provider fields remain unknown. Reset dates can be entered manually and do not reset provider usage.

The app supports adding a user's HTTPS subscription. It stores credentials in Keychain, parses responses locally and does not use a MU LABS analytics or credential backend. Optional iCloud synchronization uses the private database for metadata and synchronizable Keychain for links. Local reminders and widget sharing are opt-in. Background execution is controlled by iOS and is not promised at a fixed interval.

## Before uploading an archive

- Development Mac-to-iPhone metadata **and credential** delivery passed with a synthetic fixture, which was then removed (`output/ios-cloud-cross-device.xcresult`). Repeat with the distribution candidate and production environment before release.
- Verify physical-device share-sheet handoff, camera permission/recognition, widget rendering and notification delivery. Simulator tests do not establish these behaviors.
- Review Chinese/English iPad and accessibility layouts using the current binary.
- Choose a release-eligible Xcode/SDK; the workstation's Xcode 27 development toolchain is not evidence of App Store eligibility.
- Confirm production CloudKit schema, distribution entitlements, signing and both embedded extensions. Development environment success is not production acceptance.
- Publish and verify the actual support and privacy URLs before entering them in App Store Connect. Do not use placeholders.
- Complete Apple's privacy, age-rating and encryption questions against the final binary and current policies. The existing encryption declaration is not a legal determination.
- Supply authentic screenshots, app metadata and review instructions. Provide a safe review fixture or an accessible in-app demo; never give a personal subscription token.
- Upload, process and test the same distribution candidate through TestFlight before submission. App Store Connect creation, upload and submission require separate release authorization.

## Draft description — English

Keep track of your subscription allowance in one place. View provider-reported remaining data, expiry dates and recorded history. Add a subscription link, receive selected subscriptions from ByteKibble on your Mac through iCloud, or import an encrypted transfer file.

ByteKibble does not create a VPN connection. Available readings depend on your provider. Notifications, background refresh and iCloud delivery are subject to system availability.

## 描述草稿 — 简体中文

订阅流量，一处查看。查看服务商提供的剩余流量、到期时间和历史读数。添加订阅链接，通过 iCloud 接收 Mac 上选中的订阅，或导入加密传输文件。

ByteKibble 不会建立 VPN 连接。可用读数取决于服务商返回的数据；提醒、后台刷新和 iCloud 传递受系统条件影响。

These drafts must not be published until the capabilities above have passed their release checks.
