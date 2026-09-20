# iOS implementation record

Source: local working tree, 2026-09-14. This is a development candidate, not a released iOS app.

## Resumed physical-device acceptance — 2026-09-14

QR image decoding now checks compressed size (10 MiB), dimensions (16,384 per side) and pixel count (40 million) before Vision decoding. The physical-device unit run `output/ios-qr-image-security.xcresult` passed 21 cases with two explicit cloud probes skipped (23 total). The new test generates and recognizes a synthetic QR through the actual decoder, and rejects invalid bytes, oversized data and excessive dimensions. No real subscription is used. The exported fixture is `output/ios-qr-image-security-attachments/F939A198-9E7C-486C-B477-FD3136DBC90D.png`.

Physical camera opening, background/foreground return and cancellation back to an empty form with Add disabled passed in `output/ios-camera-lifecycle-device.xcresult` (one case, zero failures). This verifies the camera lifecycle, not pointing the hardware camera at a QR, photo-picker selection, or provider access. Those distinctions are retained alongside the system widget and notification-delivery acceptance requirements below.

The camera-cancel screenshot was inspected at `output/ios-camera-lifecycle-device-captures/F41242C1-967B-4BF3-8A87-38535322CFD5.png`. A subsequent normal Chinese app relaunch failed with CoreDevice error 4016 (device usage assertions unavailable); the successful test is not evidence that the app was left running afterward.

With no competing Xcode run, the unchanged welcome iCloud/manual route test passed on the connected iPhone: `output/ios-onboarding-routes-device-resumed.xcresult`. Both screenshots were inspected; Mac prerequisites, native presentation and disabled empty manual-import state are visible. This supersedes the route-verification blocker, not the retained historical failures.

Broader physical regression: 22 security cases (20 passed, two explicit cloud probes skipped), plus 14 UI cases (12 passed, two failed) in `output/ios-full-device-regression.xcresult`. Both failures were investigated. The camera-unavailable test assumed simulator hardware and now explicitly skips physical devices without changing app behavior. The history test did not dismiss the physical file picker before tapping the underlying view; a drag from its top edge and an explicit disappearance assertion correct the test. History preview, system file-picker cancellation and clear-history confirmation passed the focused rerun in `output/ios-system-integration-final.xcresult`; camera unavailability was correctly skipped. Other passing cases include empty overview routes, English welcome, Chinese settings, chart ranges, invalid import, reminders, largest accessibility text, sync/manual transfer, welcome add/review and remembered skip.

A DEBUG-only `--qa-share-presentation` harness invokes the system activity controller with an `example.invalid` fixture. It is absent from Release compilation, never queries a provider and never automatically saves. System Share presentation is tested by opening the ByteKibble extension and cancelling, not by granting access to another destination. Existing Keychain handoff tests separately cover the queued credential contract.

The system Share extension test passed on the physical iPhone in `output/ios-share-extension-device-final.xcresult`: found ByteKibble in the native activity list, opened the extension, confirmed Save was enabled for the synthetic HTTPS URL and cancelled without saving. Screenshot `output/ios-share-extension-device-final-captures/C12EC956-B723-4CCE-A129-DD01DCB72C99.png` was inspected. The initial test queries assumed a button/cell label; the More list exposes an activity-title static element, so the test now targets that observed structure. No production application behavior was changed to satisfy those queries. Actual external Safari-host handoff, camera recognition, system widget placement and notification delivery remain separate acceptance states.

## iCloud-first entry-point correction — 2026-09-14

Contract: welcome and the empty overview offer iCloud first, encrypted manual transfer second, and individual link entry as a separate option. Mac-first setup is explained before proceeding. No opt-in, upload, provider request, theme override or alternate-icon setting is introduced by opening a route. Existing system appearance and the shared icon remain unchanged.

Implemented those routes and the visible Mac prerequisite. Both locales now use device-neutral sync wording on iPad. Chinese graphical settings and English welcome/settings passed physical-device UI tests in `output/ios-cloud-first-polish.xcresult`; the English welcome screenshot was inspected. A dedicated new route test initially matched both underlying and welcome buttons; distinct accessibility identifiers were added rather than changing user-facing labels.

Inventory for the continuing native UI/copy pass: welcome and empty overview (changed), populated quota/detail/history/reset (existing native views and prior focused behavior evidence retained), add/scan (existing secure input and permission recovery), settings/sync/manual transfer (graphical disclosure and current entry routing), widget/reminder/Share extension (implemented, but actual system-host delivery is not established by the main-app screenshots). This is not a claim of complete physical-device acceptance or App Store readiness.

The follow-up route run on the phone was interrupted by another application's foreground activation in the XCTest log. It failed and is retained in `output/ios-onboarding-routes-final.xcresult`. Further phone automation was stopped to avoid competing for the user's device; the dedicated ByteKibble iPad simulator is the isolated route-verification destination instead.

The isolated simulator route run and its no-rebuild retry failed during automation startup (60-second session setup followed by application-not-running errors). Direct `simctl launch` succeeded; that does not prove the route interactions. Retained results: `output/ios-onboarding-routes-ipad.xcresult` and `output/ios-onboarding-routes-ipad-recheck.xcresult`. This new route test is unverified, not passed. Both localization resources parse with 223 matching keys and no missing counterpart. No further device competition, permission changes or release actions were attempted.

## Current integration and graphical settings — 2026-09-14

This section supersedes the implementation-state statements in the historical increments below.

Implemented both application-store bridges, user-selected iCloud opt-in, account-bound consent, durable metadata reconciliation, explicit conflicts, missing-credential waiting, local retention after remote deletion, encrypted manual transfer and a device-only Share extension handoff. Incoming readings preserve observation timestamps. Mac imports never overwrite an existing unselected subscription. iOS persists selection before staging an upload and prevents a deleted local subscription from reappearing after synchronization. Foreground/relaunch synchronization remains opportunistic, not real-time. The shared replica is the coordinator's durable pending state; the lower-level outbox is separately tested.

Settings now uses a native Mac → iCloud → device illustration, consistent SF Symbol tiles, state symbols and native controls. Detailed widget, reminder, transfer and synchronization explanations are expandable rather than permanent paragraphs. Important confirmations still describe data effects. Simplified Chinese and English are included. The Apple design, interface-copy and consistency skills guided native material, concise controls, preserved disclosure and actual-device verification.

Evidence completed:

- Final physical-device security run: 22 cases, 20 passed and two opt-in cloud probes skipped, in `output/ios-device-final-integration.xcresult`. This includes local deletion staying deleted after cloud reconciliation and restart. Chinese graphical settings passed in the same run; its settled screenshot is `output/ios-device-final-captures/A057D045-8F69-4A77-871E-48A7292E8739.png`. The English navigation test in that run failed after an incoming system notification interrupted the back action; that failure is retained, not counted as a pass.
- iPad Air 13-inch simulator, light appearance and largest accessibility text: graphical settings and expanded sync prerequisites passed in `output/ios-ipad-graphical-accessibility.xcresult`; both captures were visually inspected for clipping and overlap.
- The unchanged English sync/manual-transfer flow passed its focused physical-device rerun (one test, zero failures), `output/ios-device-english-recheck.xcresult`, after the notification interruption. This does not replace the retained failed run above.

- Shared core: 36 tests passed, including account mismatch, delayed credentials, explicit conflict choice, restart and remote-deletion retention (`/tmp/bytekibble-core-final.log`).
- macOS: 55 tests passed after application bridge corrections (`/tmp/bytekibble-mac-final.log`).
- iOS unit/security: 20 cases, 19 passed and one explicit cloud probe skipped, in `output/ios-share-security.xcresult`. Later-added cases require the final rerun below.
- Native simulator UI: 10 cases passed in `output/ios-completion-ui.xcresult`; after the graphical redesign, 3 focused cases passed in `output/ios-graphical-settings.xcresult`.
- Connected iPhone: English sync/transfer test passed in `output/ios-device-sync-ui.xcresult`; graphical Chinese settings and expanded prerequisites passed in `output/ios-device-graphical-settings.xcresult`. Settings screenshot `output/ios-device-graphical-settings-captures/D3183231-E8D4-4379-B235-4D079AF89728.png` was visually inspected. Some immediate navigation screenshots contain incomplete compositing; they are not final visual references.
- Actual Mac-to-iPhone synthetic delivery: the Mac development-signed app uploaded an encrypted metadata fixture and synchronizable Keychain URL. The physical iPhone independently received both and verified the original timestamp and remaining amount: one actual test, no skips, `output/ios-cloud-cross-device.xcresult`. The first Mac attempt received CKError 15; later read-before-write retry and read-back passed. No unsupported diagnosis of that initial server rejection is asserted.
- Only fixture `6BD10B41-A917-47D6-8DF1-379CC4877D25` and its exact Keychain revision were removed afterward; `/tmp/bytekibble-cloud-fixture-cleanup.log` records success. No real subscription was selected or uploaded for QA.

The signing helper only obtains a development profile. `scripts/package-sync-development.sh` embeds it in the real Mac app; the helper is never the product. Current Mac development candidate: `output/acceptance/release.bDyjFt/ByteKibble.app`. It is not for distribution. Main iOS, widget and Share extension have separate entitlements; only the main app can access the cloud credential group, and the widget cannot read subscription URLs.

The native Share extension and Home/Lock Screen widget families are implemented. Actual external-host share-sheet presentation, camera hardware recognition, system notification delivery and system widget scheduling require their own physical interaction checks and are not inferred from unit tests. Production CloudKit schema, distribution signing, release-eligible toolchain, TestFlight and App Store submission are not completed by development signing or this synthetic probe. See `iOS/AppStore/README.md` for the prepared review facts and release prerequisites. No commit, push, publication or store submission was performed.

References: [encrypted user data](https://developer.apple.com/documentation/cloudkit/encrypting-user-data) supports encrypted metadata fields; [serverRejectedRequest](https://developer.apple.com/documentation/cloudkit/ckerror/code/serverrejectedrequest) establishes that error 15 alone is not a diagnosis. No plaintext metadata fields, public database, real subscription fixture or unconditional conflict overwrite was adopted.

## Durable incoming synchronization — 2026-09-14

Acceptance for this increment: commit each downloaded page together with its cursor; retain incoming metadata while its credential is unavailable; reject ambiguous pages; keep newer revisions when an older import finishes; preserve pending work after an expired cursor, failed disk write or cancelled upload. No real subscription upload is authorized by these tests.

Implemented `SyncInbox`, account-scoped protected atomic archives, exact-record acknowledgement, cursor-only reset, and upload-ticket invalidation. `CloudSyncTransport.download` now stages paginated changes in the inbox, securely archives CloudKit tokens, retries individually failed records, checks inbox account identity and prevents concurrent download loops. Pending failed IDs must be excluded from application until recovered; deletion IDs require reconciliation rather than unconditional local deletion. Incoming records are not yet applied to either app's subscription store.

Focused verification: 27 core tests passed, including five new disk/restart/stale-callback cases. Reproduce with `swift test --package-path Packages/ByteKibbleCore`; latest local log is `/tmp/bytekibble-sync-inbox-tests.log`. The inbox is included in the iOS source phase. Device-target compilation is recorded separately in `/tmp/bytekibble-sync-inbox-device-build.log`; compilation alone is not cross-device delivery evidence.

Still required: application-store reconciliation and conflict/deletion decisions, consent/selection and synchronization controls in both apps, Mac runtime signing/shared-Keychain integration, encrypted manual transfer, and actual two-device delivery/failure verification. No iCloud record or synchronizable credential was uploaded in this increment. Existing icon changes are preserved. No release or App Store submission was made.

## Shared macOS/iOS app icon — 2026-09-14

Corrected the iOS target's old flattened/cropped AppIcon PNG selection. Debug and Release now select `ByteKibble`, and the resource phase directly references `../Resources/ByteKibble.icon`, the same source compiled by the Mac packaging script. Original artwork/materials were not edited. Historical PNGs remain in the checkout but are no longer selected as the primary app icon.

Device build passed (`/tmp/bytekibble-shared-icon-build.log`); actool consumed the shared `.icon` and generated `CFBundleIconName = ByteKibble`. Installed `com.mulabs.bytekibble.ios` on the connected iPhone 14 Pro Max. Settled home-screen capture `output/ios-shared-icon-home.png` visually confirms the complete, centered bag in the device's current dark appearance. Earlier `ios-shared-icon-installed.png` contains the temporary installation progress overlay and is not acceptance evidence. Light appearance has not been switched/verified on the phone in this pass. No subscription behavior, cloud data or release changed. The ui-consistency-review pass kept source identity and actual installed appearance as the acceptance criteria.

## Active completion scope — 2026-09-14

Cloud capability and transport increment (12:26): the user's repeated continuation after the specific capability request was treated as confirmation for that same scoped configuration. Registered `iCloud.com.mulabs.bytekibble` (ByteKibble Sync, `A2X8LCJLNK`) and the existing Mac release bundle `com.bytekibble.app` (ByteKibble Mac, `99UX75RN68`). Saved CloudKit container assignments for this Mac App ID and iOS `com.mulabs.bytekibble.ios` (`UA8W42W7YZ`) only. Unrelated apps and the widget's permissions were not expanded. The previous capability-confirmation blocker is resolved.

The iOS main app now has its own `ByteKibble.entitlements`; its signed device build includes the dedicated container, CloudKit service and `46P646AZCB.com.mulabs.bytekibble.sync`, while retaining its original default Keychain group and widget App Group. The widget continues using its original App-Group-only entitlement file. Automatic provisioning/device builds passed in `/tmp/bytekibble-cloud-device-build.log` and `/tmp/bytekibble-cloud-integrated-build.log`. A subsequent physical iPhone read-only account probe passed (1 test, no skips) in `output/ios-cloud-capability-probe.xcresult`; it obtained only an opaque CloudKit account identifier without logging it, reading subscriptions or uploading data. This is development-profile/account availability evidence, not CloudKit record delivery, Keychain cross-device delivery or release signing acceptance.

`CloudSyncTransport.swift` uses a dedicated private zone, encrypted metadata payload, random record IDs, account-generation checks, conditional server-change-tag saves, idempotent retry comparison and paginated changes with per-record failures. It never uploads a subscription URL or accesses the public database. The codec and transport compile in the iOS target; the core's 22-test suite passed before the subsequent stale-session disable guard was added. The later device probe build includes that guard. Both applications still need their subscription-store coordinator, incoming credential handling, durable cursor/conflict state and user-facing sync controls. Mac runtime shared-Keychain entitlements/provisioning and actual two-device synchronization remain unfinished; do not describe this milestone as full synchronization.

Focused references: [encryptedValues](https://developer.apple.com/documentation/cloudkit/ckrecord/encryptedvalues) supports encrypted new metadata fields without public database use; [ifServerRecordUnchanged](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/recordsavepolicy/ifserverrecordunchanged) supplies server change-tag conflict protection. Plain metadata fields and unconditional last-writer-wins saves were deliberately not adopted. Encryption guarantees must not be overstated: Apple's documentation ties exclusive owner access to the user's Advanced Data Protection setting.

Final focused rerun: all 22 core tests passed after the stale-session guard in `/tmp/bytekibble-cloud-core-final.log` (12:26). No cloud record write test was performed.

Durable outbox increment: `SyncOutbox.swift` persists bounded account-scoped metadata atomically before publishing state in memory. Offline edits retain their original merge base. One in-flight ticket per record prevents overlapping uploads; old/repeated success callbacks cannot remove newer edits. Failed uploads retain pending records, including tombstones. Invalid archives are rejected and left untouched. The 20-test core suite passed in `/tmp/bytekibble-outbox-tests.log`, including restart/account isolation, edit-during-upload, retry/deletion, write failure and corrupt archive cases. No live CloudKit calls or subscription credential changes were made. This outbox is not yet wired to app stores or a transport; cross-device behavior remains unverified.

User clarified that iCloud must transfer both subscription credentials and readings, allowing independent iPhone refresh. iCloud is the preferred onboarding route, with manual transfer as fallback; users must first select and sync subscriptions in the Mac app. Opt-in and account isolation remain mandatory. Synced readings retain observation timestamps, not download timestamps. Credentials use a dedicated shared synchronizable Keychain access group, not ordinary CloudKit fields. Names, manual reset dates, recording preference, readings and bounded history are metadata; device notification permissions and widget selections do not automatically activate on another device. Current bilingual scope is Simplified Chinese and English, superseding the initial five-language launch scope. Theme/icon manual controls await clarification of the user's “不上” wording.

Preflight: Apple Developer team `46P646AZCB` currently lists the iOS main and widget App IDs, but not the release Mac bundle `com.bytekibble.app`. The installed iOS entitlement file only contains the existing App Group. Dedicated iCloud and shared credential access require permission configuration; explicit action-time confirmation was requested before changing security-sensitive access. No live subscription has been uploaded and no sync availability is claimed.

Shared-core groundwork: `SyncRecord.swift` preserves unknowns and observation timestamps, validates schema/size/history/numeric bounds, separates immutable credential revisions from metadata, represents deletion, and rejects stale-account work through a generation gate. Three-way reconciliation preserves concurrent revisions as an explicit conflict rather than choosing by wall-clock time. `SyncCredentialVault.swift` scopes synchronizable credentials by account, random record ID and immutable revision; it is not connected to either app yet and no real credentials were uploaded. All 15 core tests passed (`/tmp/bytekibble-sync-core-final.log`), including 6 synchronization tests. Keychain coverage checks query isolation, not real cross-device delivery. This is not a cloud transport, durable outbox, signed two-device synchronization or manual-transfer implementation.

Bilingual UI verification: explicit Simplified Chinese and English resources are included in the app and widget. Two focused simulator UI tests passed in `output/ios-bilingual-layout.xcresult`; current Chinese and English welcome captures were visually checked in `output/ios-bilingual-layout-captures`. The earlier run exposed English fallback in Chinese and English content overlapping bottom actions; explicit Chinese resources, shorter English copy and scroll clipping address these cases. This is focused simulator acceptance, not whole-app localization or current physical-device acceptance. Welcome privacy copy still describes the currently implemented local-only behavior and must change when cloud sync is integrated.

Research: [Apple shared Keychain access](https://developer.apple.com/documentation/security/ksecattraccessgroup) and [synchronizable items](https://developer.apple.com/documentation/security/ksecattrsynchronizable) establish the common access-group and protection requirements; keep current device-only vault entries unchanged during opt-in migration. [Liquid Glass guidance](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass) supports native floating controls, not applying glass indiscriminately to every content surface. Both requested skills guide the native interaction and Chinese/English copy pass; their web examples do not replace SwiftUI controls.

## Welcome layout and copy — 2026-09-14

Follow-up: increased vertical label padding from 8 to 16 points for Add, Skip and review/Done, increasing each button height by 16 points without changing width, glass style or actions. Device build/install passed; settled physical-device capture `output/ios-device-welcome-buttons.png` verifies larger buttons and preserved safe-area clearance, superseding the copy capture for layout. No interaction test rerun is claimed for this padding-only follow-up.

The header and explanatory content are centered in the available space above a bottom safe-area action group. Native Liquid Glass is used for the explanation card and buttons; content remains scrollable when needed. Chinese welcome copy now names provider-supplied readings, device-only link storage, the network requirement and the non-VPN boundary explicitly. Add, Skip and review/Done behavior is unchanged; no data or permission behavior changed.

The device build passed and was installed/launched on the connected iPhone 14 Pro Max. Current dark-mode capture `output/ios-device-welcome-copy.png` was visually checked for complete copy, centered content and unobscured bottom actions, superseding earlier welcome captures. Both welcome Add/review and remembered-Skip UI tests passed in `output/ios-welcome-copy.xcresult`; the Add test also checks bottom placement. This is Chinese welcome-screen verification, not a whole-app copy/localization audit, VoiceOver acceptance or store release.

## Physical-device installation — 2026-09-14

Resolved the App Group signing blocker in Apple Developer team `46P646AZCB`: registered `group.com.mulabs.bytekibble` (ByteKibble Shared) and assigned it only to `com.mulabs.bytekibble.ios` and `com.mulabs.bytekibble.ios.widget`. No unrelated groups/capabilities were changed. Xcode automatic provisioning refreshed the development profiles; the device build succeeded with `DEVELOPMENT_TEAM=46P646AZCB -allowProvisioningUpdates` in `output/ios-device` (log: `/tmp/bytekibble-device-group-build.log`). Signed main-app entitlements include the expected shared group.

Installed and launched `com.mulabs.bytekibble.ios` on the connected physical iPhone 14 Pro Max running iOS 27.0. The native welcome screen was captured and visually inspected at `output/ios-device-welcome.png`; both Add and Skip are visible. No demo argument or real subscription was inserted. This proves development signing, installation and first launch, not complete physical-device camera/widget/background/Files acceptance, iCloud sync, TestFlight or App Store distribution.

## Increment 8: history observation chart

Verification: `output/ios-history-chart.xcresult` passed all 16 unit/security tests and both affected history UI tests. Calendar tests cover a DST-spanning week, inclusive start, future exclusion, chronological ordering, unknown versus known zero, and a 30-day window. Dark-mode single-observation and empty-state screenshots were inspected. The first maximum-accessibility-size run passed interactions but exposed overlapping chart axes (`ios-history-chart-large.xcresult`); chart-internal type now caps at xxxLarge while the original-record list and explanations retain unrestricted Dynamic Type. The corrected light-mode run passed in `output/ios-history-chart-accessible.xcresult`; its screenshot and accessibility hierarchy confirm separated axis labels, selected range, and the observation timestamp/remaining-value semantics. Real VoiceOver speech, dense 2,000-point performance, iPad and physical-device acceptance remain unverified. Simulator appearance/type were restored to dark/large. README and the stale remaining-work list were aligned; no release or macOS changes.

Contract: a separate detail destination shows a rolling 7- or 30-calendar-day window ending at the time the page opens or range changes. Local observations only; no requests, persistence changes, interpolation, daily usage inference, or cycle comparisons. Unknown remaining values stay in the record list but are not plotted; known zero is plotted. Future observations are excluded, time order is explicit, and the existing 90-day/2,000-record retention limit remains. The original detail card dimensions are unchanged. Acceptance covers calendar/DST boundaries, unknown versus zero, range switching, and the cleared-history empty state.

Research: Apple's [PointMark](https://developer.apple.com/documentation/charts/pointmark) supports individual observations, and [chart accessibility labels](https://developer.apple.com/documentation/charts/chartcontent/accessibilitylabel(_:)-5gk8d) support a timestamp and remaining-value description. Adopted discrete points and a text record list; rejected connected lines and inferred daily totals because the source is intermittent and can span quota/cycle changes.

## Increment 7: history controls and CSV export

Verification: 15 unit/security tests and the 6 existing UI tests passed in `output/ios-history-verified.xcresult`; that full run failed the new history UI test because the confirmation dialog did not expose a cancel button. Clear now uses an explicit confirmation/cancel alert. Follow-up runs `ios-history-final.xcresult` and `ios-history-gesture.xcresult` exposed test assumptions about the system file picker (no cancel button at the selected location; multiple back buttons). The corrected, navigation-bar-scoped native dismiss gesture and full preview/cancel/clear flow passed in `output/ios-history-accepted.xcresult`. Preview and cleared-state screenshots under `output/ios-history-accepted-captures` were visually inspected on the dedicated dark iOS 26.5 simulator. The system picker opened successfully and cancellation returned to the preview. Actual file delivery to a real-device storage provider remains unverified; no App Store or release pass is claimed.

The native [file exporter](https://developer.apple.com/documentation/swiftui/view/fileexporter(ispresented:document:contenttypes:defaultfilename:oncompletion:oncancellation:)) owns destination selection; the app does not silently publish to cloud storage. CSV is constructed from typed observations only, never user-entered strings, and preview/export share a frozen row snapshot. No subscription backup capability is claimed.

Contract: per-subscription recording pause preserves current readings, existing history, reset dates and other subscriptions. Clear requires confirmation and affects only selected history; later successful queries may append unless paused. Export freezes a snapshot for preview and the system file exporter, contains only UTC observation timestamps and integer byte fields, preserves unknown as blank, and includes no provider name, UUID, URL or credentials. Visible/exported observations are bounded to 90 days and 2,000 rows; no interpolation or usage comparison is introduced. Existing metadata without the optional pause field continues recording. Test pause/retention, clear isolation/persistence/failure, CSV field allowlist and native preview/clear cancellation.

## Increment 6: unreadable storage and background isolation

Verification: `output/ios-storage-gating.xcresult` passed 13 unit/security tests and 6 UI regression tests on the dedicated iOS 26.5 simulator. New fixtures verify unreadable-source preservation after alert dismissal, explicit disable cleanup, recovery, pre-mutation rejection, serial gate rechecks and cancellation. Fixtures use temporary files and missing test-only Keychain IDs, not provider network requests. The previous background main-actor warnings are absent from `/tmp/bytekibble-storage-gating.log`; the unrelated manual-target-order warning remains. This is a local logic/build regression pass, not evidence of real locked-device execution or system background scheduling. The earlier actor-isolation follow-up noted in Increment 3 is resolved by this increment.

Implementation: source validity now uses `recordsAvailable`, independent of dismissible error text. A shared derived-state coordinator preserves enabled reminders and selected widget snapshots while metadata is unavailable, yet honors explicit opt-out. Add/remove reject an unreadable source before Keychain mutation. The background entry point and refresh gate are explicitly main-actor isolated; serial refresh rechecks cancellation and source validity before each item. [Swift concurrency guidance](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html) supports the explicit isolation contract; no unchecked Sendable workaround or detached UI-state access was introduced.

Acceptance: dismissing a storage error must not make unreadable metadata appear valid; derived reminders and widget snapshots must survive an unavailable source. Explicitly disabling reminders/widgets still clears the owned derived data. Recovery must restore normal reconciliation. Background gating must run on the main actor, serial refresh must recheck the gate before each subscription, and blocked metadata must not initiate credential mutations. No UI redesign or provider request is part of testing.

## Increment 5: first-use welcome

Verification: `output/ios-welcome-verified.xcresult` passed 11 unit/security tests and 6 native UI tests. New cases verify preference isolation, demo/existing-subscription bypass, welcome-to-Add handoff, cancel without importing, Settings review and skip persistence across relaunch. `output/ios-welcome-large.xcresult` repeats Add/review successfully in light appearance at the largest accessibility text size. Native screenshots were inspected: dark normal `output/ios-welcome-captures/705D8092-A194-4D68-A21E-7FAB2E75E10E.png`, light accessibility `output/ios-welcome-large-captures/BA0B76ED-A8E6-491A-89E6-16AC719C1025.png`. Long content scrolls and action buttons remain reachable. Dedicated simulator appearance/text size were restored to dark/large. VoiceOver spoken navigation and iPad/device acceptance remain unverified; no public release was made.

Acceptance: a brief optional native welcome before first import, direct handoff to Add, skip remembered locally, no automatic permission requests or provider queries, existing subscriptions never hidden behind onboarding, and a Settings route to review the same explanation. Verify add/cancel, skip, review, local preference isolation, dark/light and large-text layouts.

[Apple onboarding guidance](https://developer.apple.com/design/human-interface-guidelines/onboarding) informs a brief optional introduction and review entry; no carousel, account creation or advance permission prompts are introduced. Product promises remain limited to implemented provider readings and device-local storage, not VPN service or iCloud availability.

## Increment 4: camera import

Verification: `output/ios-camera-verified.xcresult` completed successfully with 10 iOS unit/security tests and 4 native UI tests. The new UI case opens scanning on unsupported simulator hardware, returns to the unchanged import form, verifies Add remains disabled, and cancels without creating a subscription. Native dark fallback screenshot `output/ios-camera-captures/F0796ECF-7622-4891-9EFE-C7C09AB5BA4C.png` was visually inspected. Camera purpose Info.plist passes plutil. Live recognition, permission-denied/restricted transitions, multi-code tap selection and real camera interruptions remain physical-device acceptance items. No release or remote changes performed.

Contract: explicit camera button requests video permission only; on-device QR recognition; tapping a highlighted QR validates it with the existing HTTPS/wrapper parser and fills the import form. No photo/video persistence, automatic browser opening, credential storage or provider request occurs until the existing Add action. Multiple QR codes require explicit selection rather than choosing the first. Invalid codes remain recoverable; unsupported hardware, denied/restricted permission, temporary unavailability and interruption have an explanation and cancel/fallback path. Leaving the active scene tears down scanning.

Reference: [Apple DataScannerViewController](https://developer.apple.com/documentation/visionkit/datascannerviewcontroller) supplies native highlighting and tap selection; support/availability are checked before presenting the scanner. The example behavior of opening scanned URLs is deliberately not adopted: subscription links remain unexecuted pending input. No camera hardware requirement is added because photo/paste import remains available.

## Increment 3: WidgetKit snapshot boundary

Implemented small/medium WidgetKit target, embedding, matching local App Group entitlements, Settings selection, bounded atomic sanitized snapshot storage, privacy-sensitive numbers, one-hour stale timeline, and removal/reload reconciliation. The extension compiles only its view and snapshot reader, not the subscription client or vault.

Verified on the dedicated iOS 26.5 simulator: 10 unit/security tests and 3 native UI tests passed in `output/ios-widget-verified.xcresult`. New tests cover the actual host App Group container, snapshot field allowlist, stale boundaries, invalid/oversized input, zero quota, opt-in, demo isolation, deduplicated reload, deletion and disable. The embedded extension exists in `ByteKibble.app/PlugIns/ByteKibbleWidget.appex`; project, extension Info and entitlements pass plutil. Native dark Settings screenshot `output/ios-widget-captures/FE150131-3C6C-4E56-9961-A35380C09D93.png` was visually inspected. This screenshot verifies the app's settings, not the Home Screen widget.

Remaining acceptance: Computer Use could not resolve Simulator and it is absent from the available app inventory, so Home Screen addition, small/medium rendering, light/large-text widget layout, system timeline delivery and lock-screen redaction remain unverified. No physical-device App Group provisioning, App Store submission or publication was performed. Existing background-refresh actor-isolation warnings remain a separate follow-up.

Acceptance: opt-in selected subscription; no provider name or URL in the shared file; bounded decoding; unknown is not zero; reads at least one hour old are explicitly stale; deletion/disable removes the shared snapshot. Demo mode must not alter real shared state. Build and exercise the embedded extension plus the native Settings entry. Physical-device provisioning and system scheduling remain separate acceptance steps.

Apple references: [timeline updates](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) informs the stale timeline and reload request, without promising an interval; [WidgetKit strategy](https://developer.apple.com/documentation/WidgetKit/Developing-a-WidgetKit-strategy) informs the shared App Group snapshot, with no provider requests in the extension; [widget backgrounds](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background) informs the native removable container background. No third-party widget SDK or shared Keychain access is introduced.

## Acceptance for the first native vertical slice

- Build a separate iOS 26+ / iPadOS 26+ application without changing the released macOS app.
- Import an HTTPS subscription or supported wrapper without executing client URL schemes.
- Keep subscription credentials in a device-only, unlocked Keychain item; metadata and observations contain no URL.
- Bound network responses, reject insecure / cross-host redirects, keep failed subscriptions independent, preserve prior readings.
- Display unknown fields as unknown, use accurately named GiB units, and keep manual reset dates separate from provider expiration.
- Provide native overview, subscription list, details, history, manual reset and privacy pages. Use system navigation / tab material, readable solid content cards, and the existing upright grayscale bag asset.
- Verify a simulator build, parsing tests, native UI flows and fresh screenshots. Synthetic data must remain labeled and isolated from real storage.

## Scope implemented in the current candidate

- Standalone Xcode project: `iOS/ByteKibble.xcodeproj`.
- Portable Foundation quota/parser package: `Packages/ByteKibbleCore` (macOS integration is not changed yet).
- Native three-tab UI; masked link entry, user-initiated system Paste button, photo QR recognition and bounded text-file import.
- Search, rename and reorder subscriptions.
- Per-subscription query, retained stale readings, history, manual reset and local deletion.
- Local Keychain credential storage with read-back; protected, atomic metadata file writes.
- No iCloud, telemetry, VPN service or update framework in this candidate.

## Remaining product-plan work — not claimed complete

- Share extension and full bilingual runtime acceptance. Simplified Chinese and English resources are implemented; the earlier five-language scope is superseded. Camera/photo/file import and onboarding are implemented; camera hardware, permission and file-provider flows still need device-level acceptance.
- Widget implementation is present; Home Screen installation/layout, physical-device acceptance of local notifications and background scheduling remain.
- iCloud metadata/credential synchronization and signed real-device macOS↔iOS proof of concept. This requires the selected Apple team, configured capabilities and suitable devices; simulator success cannot establish cross-device Keychain behavior.
- Full storage/network failure-injection suite, accessibility/appearance/iPad matrix, migration tests and TestFlight device acceptance.
- App Store privacy/review materials, supported release Xcode selection, signing, archive and submission.

## Reproduction

```sh
swift test --package-path Packages/ByteKibbleCore
xcodebuild -project iOS/ByteKibble.xcodeproj -scheme ByteKibble -sdk iphonesimulator -configuration Debug -derivedDataPath output/ios-derived CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
xcodebuild -project iOS/ByteKibble.xcodeproj -scheme ByteKibble -destination 'platform=iOS Simulator,id=23434E7C-DCAD-4EBA-803C-3B8DBBC74D13' -derivedDataPath output/ios-derived CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

The simulator UUID above is the dedicated ByteKibble device created on this workstation. Choose an available iOS 26+ simulator on other machines. `--demo` launches labeled in-memory sample readings; it does not read or write real subscriptions.

## Evidence

- Foundation package: 8 tests passed, including warning boundaries, wrapper extraction, unknown data, overflow and bounds. Log: `/tmp/bytekibble-ios-core-tests.log` (ephemeral workstation evidence).
- Initial unsigned iOS runtime exposed Keychain failure: 2 storage tests failed. Preserved result: `output/ios-security-tests-v2.xcresult`. Fixed by using ordinary simulator ad-hoc development signing; no insecure fallback was added.
- Signed iOS regression: 5 security/network tests + 2 native UI tests passed, in `output/ios-final-tests.xcresult`. UI cases cover demo detail/manual date and rejection of HTTP import. Security cases exercise real simulator Keychain and local URLProtocol fixtures, not a remote provider.
- A subsequent link-size guard passed the Foundation suite; the final artwork loading correction was rebuilt and checked through native screenshots. These are not claims of an unchanged app binary across every earlier test run.
- Final simulator build succeeded, installed and launched on the dedicated iPhone 17 Pro simulator. Light/dark and maximum Dynamic Type captures are under `output/ios-captures/`; data is explicitly labeled demo data. No iPad or physical-device acceptance is claimed.
- App UI initially failed to resolve the loose PNG by asset name; explicit bundle-file image loading corrected the missing bag, confirmed in `overview-dark-final.png`. Historical `*-current.png` captures before that fix are superseded.
- Toolchain: local Xcode 27.0 (27A266a), simulator iOS 26.5. This does not establish App Store SDK eligibility.

## Increment 2 — reminders and background refresh (2026-09-14)

Acceptance: opt-in system notification authorization; private notification content; stale readings never trigger low-quota alerts; repeated refresh does not duplicate or cancel a pending low-quota alert; disabling/deleting retracts reminders; background expiration uses SwiftUI task cancellation, and locked credentials keep their existing protection. No real provider data, cloud configuration, release or macOS source changes.

Implemented local date/low-quota reminder reconciliation, persisted settings/cooldowns, 32-request cap, coalesced serial scheduling, protected-file reload after unlock, and optional BGAppRefresh scheduling. Native Settings explains denied authorization, scheduling failures and system limitations. Simulator demo mode cannot mutate these options.

Research: [Apple notification permission](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications) supports checking current authorization before scheduling; [earliestBeginDate](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate) establishes that requested start times are not guaranteed. Adopted opt-in and opportunistic execution, rejected fixed-interval/real-time claims. [UserDefaults privacy declaration](https://developer.apple.com/documentation/foundation/userdefaults) informed the bundled privacy manifest.

Testing uses an injected notification delivery service for permission, deduplication, private content and cancellation logic. It does not establish real lock-screen delivery, scheduled wake-ups, Focus behavior or physical-device Keychain availability. Native Settings screenshot and regression results are retained under `output/ios-reminder-final.xcresult` after completion.

Verification: 9 core tests passed; 7 iOS unit/security tests and 3 UI tests passed. The cooldown-storage tightening was subsequently rebuilt and all 7 iOS unit tests passed again (`/tmp/bytekibble-reminder-storage-final.log`). Bundled Info.plist and PrivacyInfo.xcprivacy pass plutil validation. Settings was visually inspected in the native dark-mode simulator. No physical-device scheduling or notification-delivery pass is claimed.

The first targeted final-copy test command omitted the test class and selected zero tests (`ios-reminder-settings-final.xcresult`); its success status is not acceptance evidence. The corrected class-qualified run is `ios-reminder-settings-verified.xcresult`: 1 actual UI test passed, and its final-copy native screenshot was exported and visually checked.
