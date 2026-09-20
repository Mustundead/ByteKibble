# ByteKibble for iOS

Native iOS 26 / iPadOS 26 development companion to ByteKibble for macOS. This directory is not an App Store release.

## Current implementation

- Provider-reported quota, multiple subscriptions, history, manual reset dates, local reminders and optional background refresh.
- iCloud-first onboarding. Select subscriptions on the Mac first; both devices need the same Apple account and iCloud Keychain. Cloud metadata and credentials use separate channels.
- Encrypted manual export/import when iCloud is unavailable. Keep the generated key separate from the file; existing subscriptions are not overwritten.
- Share extension: save one link to a device-only shared Keychain item, then confirm it in the main app. No provider request happens in the extension.
- Simplified Chinese and English, native system appearance and Liquid Glass controls, shared macOS/iOS Icon Composer artwork.
- Opt-in widget snapshots contain quota numbers and observation time, not subscription links or names.

Queries contact the subscription provider. Parsing runs locally; data is not sent to MU LABS. Opting into iCloud uses Apple services. Synced readings keep their original observation time and are not represented as newly refreshed data. Deleting a local subscription preserves iCloud and other devices.

## Build and test

Open `ByteKibble.xcodeproj`, select the ByteKibble scheme and an iOS 26+ destination. Physical-device builds require the configured Apple team and provisioning for the app, widget and share extension. Do not distribute development-signed artifacts.

Run `swift test --package-path Packages/ByteKibbleCore` from the repository root for portable logic tests. The Xcode scheme includes unit/security and native UI tests. Cloud probes are explicitly gated and excluded from ordinary acceptance counts.

See [implementation evidence](../docs/ios-implementation-status.md) for current verification boundaries and [submission preparation](AppStore/README.md) for release prerequisites.
