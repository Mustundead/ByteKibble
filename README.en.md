<p align="center">
  <img src="docs/assets/app-icon-light.png" width="128" height="128" alt="ByteKibble: a warm gold kibble bag with a paw mark">
</p>

<h1 align="center">ByteKibble</h1>
<p align="center">Made by <a href="https://mustundead.com">MU Labs</a></p>
<p align="center">Your subscription allowance, at a glance.</p>
<p align="center"><a href="README.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · English · <a href="README.ko.md">한국어</a> · <a href="README.ja.md">日本語</a></p>

ByteKibble is a native macOS menu bar utility for subscription traffic allowances. For users of Clash-family clients and SNTP, it answers one simple question: **how much data is left on this subscription?** Check usage, expiry and data sources without repeatedly opening a client or provider website.

> **1.2.0 (46) prerelease**: app source, a first-launch welcome screen, and Apple silicon (arm64) packages. Developer ID signed; **not notarized by Apple**. [Downloads and full release notes](https://github.com/mustundead/ByteKibble/releases/tag/v1.2.0-build46). Images in `preview/` are historical.

<img src="docs/assets/quota-build46-full-dark.png" width="360" alt="Native menu popover screenshot · 100% traffic remaining (sample data, not a real subscription)">

Native menu popover screenshot · 100% traffic remaining (sample data, not a real subscription)

## What it shows

- **Remaining data in your menu bar.** The number shows remaining allowance; the filled pie shows the remaining proportion. A countdown appears when client reset data is available.
- **Details in one panel.** Plan name, remaining/used/total data, upload and download usage, estimated reset date, subscription expiry, source and update time.
- **Multiple subscriptions.** Discover readable client subscriptions or manually add an HTTPS subscription link, then switch between their readings.
- **Useful warnings.** Orange below 20% remaining; red below 10%. Text identifies low or exhausted allowance, so color is not the only signal.
- **Native macOS behavior.** SwiftUI, light and dark appearances, monospaced numbers, Reduce Motion support and explicit launch-at-login on/off states.
- **Five interface languages.** Simplified Chinese, Traditional Chinese, English, Korean and Japanese.

ByteKibble is **not a proxy client, VPN, speed test or per-app network meter**. It does not route traffic in place of Clash/Mihomo or change your provider's allowance.

## Reading the colors and progress

| Remaining share | Appearance | Meaning |
| --- | --- | --- |
| ≥20% | Adaptive black/white primary color | Normal |
| ≥10% and <20% | Orange | Running low |
| <10% | Red | Very low or exhausted |

The menu bar pie represents **remaining** data. The horizontal bar in the detail card represents **used** data, matching its “Used” percentage. Warning colors describe allowance risk—not plan tier, connectivity or login-item state. An approaching reset is not itself a failure.

## Supported sources

**Build 46 support:** HTTPS subscription links used with Quantumult / Quantumult X and Surge work when the provider returns `Subscription-Userinfo`. You can also paste a Surge `#!MANAGED-CONFIG https://…` first line. Shadowsocks SIP008 supports `bytes_used` and `bytes_remaining`; missing directional counters show “— · Not provided”. These clients require manual entry, not automatic discovery. A single `ss://` node is not a quota endpoint. Full client/provider integration coverage is not claimed.

| Source | Read automatically | Notes |
| --- | --- | --- |
| Clash Verge / Clash Verge Rev | Subscription links in local `profiles.yaml` files | Usage is requested from the provider |
| ClashX / ClashX Meta / ClashX Pro | Subscription links in client preferences | Depends on the client saving a readable configuration |
| SNTP | Subscription link, plan and traffic cache, client-reported reset days | The cache may lack a trustworthy original update time |
| Manual entry | An HTTPS subscription link you paste | The provider must supply parseable usage information |

Live readings come from the subscription response's `subscription-userinfo` header, or SIP008 JSON quota fields when that header is absent. **Using the Mihomo core does not automatically make a client discoverable**: detection supports the storage formats listed above. For other clients, try adding the link manually.

ByteKibble does not measure all network activity itself. Readings depend on the provider or client. Missing headers, incomplete fields, a zero total or a failed query must not be interpreted as a measured zero remaining balance. Check the source and update time when using an older reading.

### Reset dates and refreshes

- Click the Resets tile to set the next reset date when it is unavailable. This local override is labeled Manual and `*`; clearing it restores subscription metadata. Past dates show Date passed. Dates do not repeat automatically and never clear provider usage.

- Reset days are client-reported, not a standard field in the usual subscription header. The countdown and **estimated** date are derived from those days, not a confirmed provider reset time. Older cache data can affect accuracy.
- No reset date is guessed when the data is unavailable. Subscription expiry and allowance reset are different events.
- The running app refreshes periodically and offers manual refresh. Sleep, connectivity and provider responses can delay updates.
- Queries try a direct connection and common local proxy ports (`7899`, `7890`, `7897`, `6152`). ByteKibble does not start a proxy client or change system proxy settings.

## Requirements and installation

Requires **macOS 13 or later**. Native Liquid Glass styling requires macOS 26 or later; older systems use compatible styling. Check each package's release notes for processor support, signing and notarization.

Download the DMG or ZIP from the [1.2.0 (46) release](https://github.com/mustundead/ByteKibble/releases/tag/v1.2.0-build46). Quit the older copy first. Open the DMG and drag ByteKibble to Applications, or unzip the ZIP and move the app there. Launch from Applications rather than the mounted disk. A welcome screen appears on first use.

This binary is **Apple silicon (arm64) only**; no Intel package is included. Local builds, tests and UI checks were performed on macOS 27. The deployment target is macOS 13; this does not establish runtime verification on every older system.

Choose `-installer.zip` to preserve the app-primary Finder icon and open-box badge on its extracted DMG. Direct HTTP downloads of the bare DMG do not preserve custom-icon metadata; installation contents are identical. The separate `-arm64.zip` contains the app itself.

![Actual 1.2.0 (43) DMG window](docs/assets/installer-1.2.0.png)

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

There are no third-party runtime dependencies. Run `swift test -j 2` for tests. `bash scripts/package-local.sh release` creates an ad-hoc signed app for the host architecture under `output/acceptance/`; packaging requires Xcode with `actool`. Building from source does not use the publisher's Developer ID or automatically notarize the app. See [CHANGELOG](CHANGELOG.md) for DMG packaging.

## Feedback and license

Report problems in [Issues](https://github.com/mustundead/ByteKibble/issues) with your macOS version, app version, client name and redacted reproduction steps. New original material first distributed under the new terms uses the [source-available noncommercial license](LICENSE): noncommercial use is free; commercial use requires prior written authorization from the rights holder. This commercial restriction means it is not a standard open-source license.

### MU Labs

Made by [MU Labs](https://mustundead.com). See [LICENSE](LICENSE) for code reuse, attribution and commercial authorization requirements.

**Existing permissions are preserved.** Code and versions previously provided under MIT, including the 1.2.0 (41) acceptance package, retain the [legacy MIT terms](LICENSES/MIT-legacy.txt), including commercial-use rights. See [LICENSE](LICENSE) for the scope of the terms covering newly distributed material.
