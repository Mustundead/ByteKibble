<p align="center">
  <img src="docs/assets/app-icon-light.png" width="128" height="128" alt="ByteKibble: a warm gold kibble bag with a paw mark">
</p>

<h1 align="center">ByteKibble</h1>
<p align="center">Made by <a href="https://mustundead.com">MU Labs, by Mustundead</a></p>
<p align="center">Your subscription allowance, at a glance.</p>
<p align="center"><a href="README.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · English · <a href="README.ko.md">한국어</a> · <a href="README.ja.md">日本語</a></p>

ByteKibble is a native macOS menu bar utility for subscription traffic allowances. For users of Clash-family clients and SNTP, it answers one simple question: **how much data is left on this subscription?** Check usage, expiry and data sources without repeatedly opening a client or provider website.

> **Status: documentation and icon update only.** This page describes the version being refined. The matching app code, first-launch welcome page and ZIP/DMG packages have not been published with this update. Older code and screenshots in `preview/` do not represent the new design described here. Downloads depend on the versions actually published in [Releases](https://github.com/mustundead/ByteKibble/releases).

## What it shows

- **Remaining data in your menu bar.** The number shows remaining allowance; the filled pie shows the remaining proportion. A countdown appears when client reset data is available.
- **Details in one panel.** Plan name, remaining/used/total data, upload and download usage, estimated reset date, subscription expiry, source and update time.
- **Multiple subscriptions.** Discover readable client subscriptions or manually add an HTTPS subscription link, then switch between their readings.
- **Useful warnings.** Orange below 20% remaining; red below 7%. Text identifies low or exhausted allowance, so color is not the only signal.
- **Native macOS behavior.** SwiftUI, light and dark appearances, monospaced numbers, Reduce Motion support and explicit launch-at-login on/off states.
- **Five interface languages.** Simplified Chinese, Traditional Chinese, English, Korean and Japanese.

ByteKibble is **not a proxy client, VPN, speed test or per-app network meter**. It does not route traffic in place of Clash/Mihomo or change your provider's allowance.

## Reading the colors and progress

| Remaining share | Appearance | Meaning |
| --- | --- | --- |
| ≥20% | Adaptive black/white primary color | Normal |
| ≥7% and <20% | Orange | Running low |
| <7% | Red | Very low or exhausted |

The menu bar pie represents **remaining** data. The horizontal bar in the detail card represents **used** data, matching its “Used” percentage. Warning colors describe allowance risk—not plan tier, connectivity or login-item state. An approaching reset is not itself a failure.

## Supported sources

| Source | Read automatically | Notes |
| --- | --- | --- |
| Clash Verge / Clash Verge Rev | Subscription links in local `profiles.yaml` files | Usage is requested from the provider |
| ClashX / ClashX Meta / ClashX Pro | Subscription links in client preferences | Depends on the client saving a readable configuration |
| SNTP | Subscription link, plan and traffic cache, client-reported reset days | The cache may lack a trustworthy original update time |
| Manual entry | An HTTPS subscription link you paste | The provider must supply parseable usage information |

Live readings come from the subscription response's `subscription-userinfo` header. **Using the Mihomo core does not automatically make a client discoverable**: detection supports the storage formats listed above. For other clients, try adding the link manually.

ByteKibble does not measure all network activity itself. Readings depend on the provider or client. Missing headers, incomplete fields, a zero total or a failed query must not be interpreted as a measured zero remaining balance. Check the source and update time when using an older reading.

### Reset dates and refreshes

- Reset days are client-reported, not a standard field in the usual subscription header. The countdown and **estimated** date are derived from those days, not a confirmed provider reset time. Older cache data can affect accuracy.
- No reset date is guessed when the data is unavailable. Subscription expiry and allowance reset are different events.
- The running app refreshes periodically and offers manual refresh. Sleep, connectivity and provider responses can delay updates.
- Queries try a direct connection and common local proxy ports (`7899`, `7890`, `7897`). ByteKibble does not start a proxy client or change system proxy settings.

## Requirements and installation

Requires **macOS 13 or later**. Native Liquid Glass styling requires macOS 26 or later; older systems use compatible styling. Check each package's release notes for processor support, signing and notarization.

Drag-install ZIP/DMG packages and a one-page welcome screen are being prepared. **No new installer accompanies this documentation update.** Once published, get packages from this repository's [Releases](https://github.com/mustundead/ByteKibble/releases). Unzip a ZIP and move the app to Applications, or open a DMG and drag the app onto its Applications shortcut. Launch the installed copy from Applications.

If macOS blocks the app, verify the source, signature and release notes first. Only if you trust the file, follow [Apple's instructions](https://support.apple.com/guide/mac-help/mh40616/mac) in System Settings → Privacy & Security. **Signing is not notarization.** Do not disable system security protections to install it.

Import a subscription into a supported client or add an HTTPS link in ByteKibble. The app lives in the menu bar. Launch at login is optional, not a requirement for viewing your allowance.

## Privacy and boundaries

Automatic discovery reads local client settings. Manually added links are stored in ByteKibble's local preferences. Adding, removing or undoing an entry changes only ByteKibble's list; **it does not modify or cancel the provider subscription**.

A subscription URL can contain an access token: treat it like a password. Queries contact the corresponding provider. When using a local proxy, the request follows that proxy's configured route. ByteKibble has no traffic relay server of its own and does not send subscription links to an analytics platform.

Redact subscription URLs, tokens and account details from public issues and screenshots.

## Build from source

With Xcode and its Swift toolchain installed:

```bash
git clone https://github.com/mustundead/ByteKibble.git
cd ByteKibble
swift build -c release
```

There are no third-party runtime dependencies. A successful source build does not establish signing, notarization or installer validation. This documentation is ahead of the app-code update; the checked-out source determines actual build behavior.

## Feedback and license

Report problems in [Issues](https://github.com/mustundead/ByteKibble/issues) with your macOS version, app version, client name and redacted reproduction steps. Licensed under the [MIT License](LICENSE).

### Author and attribution

Personal website: [mustundead.com](https://mustundead.com). Made by Mustundead's MU Labs.

When reusing code, retain the original copyright notice and license text as required by the existing MIT License. When referencing this project, please also credit “ByteKibble — Mustundead / MU Labs” and link to [this repository](https://github.com/mustundead/ByteKibble).
