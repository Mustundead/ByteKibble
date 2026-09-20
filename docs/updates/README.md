# Direct-download updates

## New `com.mulabs.bytekibble` identity — manual-install prerelease

The new macOS bundle ID is `com.mulabs.bytekibble`; the iOS app and extensions
already use the `com.mulabs.bytekibble.ios` family. The new direct-download app
uses `mulabs.xml`. The existing `preview.xml` remains the historical
`com.bytekibble.app` feed and must never be changed to advertise a different
bundle ID. Build 51 is distributed as a manual-install prerelease, not an OTA
successor. `mulabs.xml` has no release item yet; no new-identity update is
advertised by this source change.

Changing a bundle ID is not an in-place Sparkle update: its installer checks
that the incoming and installed app IDs match. It also changes the macOS
preferences domain and default Keychain identity. Do not publish the new app
as an OTA successor or claim that existing subscriptions/settings migrated
until a separately signed migration path has been tested against a real old
installation, including its Keychain credentials, selected subscription,
manual reset dates, login item, and updater preferences. Preserve the old app
and its data during that test; never delete the legacy domain or credentials
as part of packaging. The unchanged Keychain service name is intentional for
compatibility, not a formal app bundle identifier.

This decision follows [Apple's bundle identifier guidance](https://developer.apple.com/documentation/xcode/changing-the-bundle-identifier),
[Apple's Keychain access-group model](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps),
and the vendored Sparkle installer check in
`.build-audit/checkouts/sparkle/Autoupdate/AppInstaller.m`.

The direct-download build embeds Sparkle 2.9.6. App Store distributions must not
include this updater. Existing build 46 and earlier must be upgraded manually once.

The version footer opens Check for Updates, automatic-check preferences, and GitHub.
Checks are enabled by default; users can turn them off. Installation requires user
confirmation. Sparkle handles unavailable networks, no-update results, version
comparison, archive verification, replacement, and relaunch. Checks contact GitHub;
subscription URLs, tokens, quota readings and reset dates are not passed to Sparkle.
System profile submission and unattended installation are disabled.

`preview.xml` is exclusively the preview feed. A future stable distribution must
use a separate stable feed rather than silently subscribe stable users to previews.
The feed compares monotonically increasing CFBundleVersion, not just 1.2.0.

## Publish an update

1. Build a Developer ID signed application, including all nested Sparkle code.
   Prefer notarization before distributing. Test the exact signed candidate.
2. Archive only ByteKibble.app as ZIP (not the ZIP containing a DMG).
3. Run Sparkle `generate_appcast --help` and generate an appcast for the archive,
   using Keychain account `mu-labs.bytekibble` and the exact GitHub Release asset URL.
   Never export or commit the private key. Preserve a secure keychain backup.
4. Verify the archive signature, build number, minimum OS, URL and byte length.
5. Upload the archive to the corresponding GitHub Release and read back its digest.
6. Publish the generated feed for the matching bundle identity only after the
   asset is downloadable: `mulabs.xml` for `com.mulabs.bytekibble`, or
   `preview.xml` for legacy `com.bytekibble.app`. Do not advertise a version
   whose package has not been uploaded, and never cross the two feeds.
7. Test from an older updater-enabled copy installed on a writable volume. Verify
   the offered version, cancel path, download, replacement and relaunch. QA preview
   builds deliberately do not start the production updater. An explicit
   `--updater-acceptance` switch enables it only in the QA bundle with fixture
   configuration; `prepare-update-acceptance.sh` creates an isolated localhost
   test pair. Its localhost HTTP exception never enters production packages.

## Current distribution and source status

Build 51 is a separate Developer ID signed Apple silicon manual-install
prerelease, not notarized. The downloadable Mac package does not have the
iCloud entitlement; its sync window supports encrypted manual transfer and
reports the missing entitlement on attempted iCloud opt-in. Neither an
in-place upgrade from build 50 nor a migration of real legacy credentials
and settings has been verified. Keep the old app and data. The old feed
remains on build 50 and the new feed remains empty.

Build 50 is the published prerelease and the preview feed points to its signed
application ZIP. Its release contains the DMG, installer ZIP, application ZIP
and SHA256SUMS.txt. It is Developer ID signed, not Apple notarized.

Build 50 includes Keychain migration, a 2 MiB
response-body limit, retry/backoff/cancellation improvements and same-origin
HTTPS redirects. 55 automated tests and 11 real-Keychain checks inside the
signed candidate passed using isolated dummy subscriptions. The archive is
published before the feed is advanced. This does not establish an actual
GitHub-hosted OTA installation or Apple notarization. See the
[security verification record](../security-hardening.md).

## Historical local OTA acceptance — build 47, 2026-09-13

- 36 tests passed, including build-number comparison and no updater startup in tests.
- Five localization tables parse successfully; Chinese and English native menu
  entries were inspected, keeping the existing card sizes.
- Developer ID signed QA fixtures in `output/acceptance/ota.MtcyGk` completed an
  actual 46 → 47 download, verified extraction, replacement and relaunch using
  localhost. The installed bundle then reported 47 and passed deep/strict signing.
- Closing the update prompt and checking again worked; the upgraded copy reported
  up to date; stopping the fixture server produced the native update error.
- This does not prove a GitHub-hosted production OTA, notarization or all macOS
  versions. The release accessory process loaded Sparkle and remained responsive
  in a sample, but the UI controller could not attach to its windowless state;
  interaction acceptance above uses the native QA host and real Sparkle framework.

References: [Sparkle setup](https://sparkle-project.org/documentation/) for embedding,
signing and feed publication; [programmatic setup](https://sparkle-project.org/documentation/programmatic-setup/)
for lifecycle and observable menu state. Reuse native updater UI rather than a custom
installer, and keep update preferences separate from provider data.
