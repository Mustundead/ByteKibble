# Apple Design optimization acceptance

## Build 45 published — 2026-09-13

Source commit9fd5f3017f288513a7b2125b27be2c4f802fc112 pushed main and tagv1.2.0-build45; public prerelease published2026-09-13T04:19:35Z. All four assets uploaded and GitHub SHA256 digests match local hashes. Release app release.fkCXJR and installer.MH5ZiJ; Developer ID hardened-runtime timestamp signing verified including mounted DMG app, version45. DMG and bothZIP integrity pass;20 automated tests pass. Five README languages updated with explicitly synthetic QA screenshot and build45 links. Old43 release unchanged. Not notarized, not installed for user. Unrelated local files left untracked.

## Selected option C implemented — 2026-09-13 QA build 45 revision

User selected C from imagegen comparison. Reused bag raster with230-point frame, bottom-trailing offset60/40, card-clipped right/bottom edges. No rotation or gradient fade; uniform dark/light opacity0.14/0.12. Native qa.I8fdiY light/dark Normal inspected against selected C composition; original400x802 window retained. UI consistency review verified non-layout background and foreground data readability. Screenshot option-c-dark.png. Local implementation only, not uploaded or packaged for distribution.

## Grayscale background refinement — 2026-09-13 QA build 45 revision

Reduced image frame156 to144, refined bottom/right spacing, faded upper portion with gradient alpha to reduce interference with progress/total. Dark/light opacity0.13/0.11; warnings multiply by0.65. UI consistency review: native qa.V3xIwJ light/dark Normal and dark Critical visually checked; original Normal window400x802 retained. Screenshot refined-bag-dark.png. Existing gray/unrotated artwork retained. Local preview, not published.

## Theme-adaptive grayscale bag — 2026-09-13 QA build 45 revision

Removed rotation. Native rendering saturation zero; light theme brightness -0.55, dark theme original luminance; opacity remains 0.14. Source raster unchanged, bag shading/paw preserved. UI consistency review checked qa.DldDbp light/dark; original 400x802 QA window and layout retained. Screenshot gray-bag-dark.png. Local preview only, no release publication.

## App icon artwork background — 2026-09-13 QA build 45 revision

User proposed app icon instead of paw. Reused exact existing Resources/ByteKibble.icon/Assets/bag.png as bundled QuotaBag.png, without the icon plate. Replaces rejected paw watermark, 156-point image frame, -12-degree tilt, opacity 0.14, bottom-right non-layout background clipped to card. UI consistency review: native qa.o8xwBp light/dark inspected; original 400x802 QA window retained and foreground data readable. Screenshot app-icon-background-dark.png. Local preview only, not published or installed.

## Original card size restored — 2026-09-13 QA build 45 revision

User rejected expanded card. Removed decorative row; paw is now non-layout background at bottom trailing, 104 points, +20 degrees, opacity 0.045. Fresh native qa.LBYWet light/dark checked: full QA window restored from 932 to 802 points high. Watermark sits behind lower-right information, text remains foreground. Screenshot compact-paw-dark.png. UI consistency review fixed layout ownership rather than forcing card height. Includes local below-10-percent danger threshold; not published.

## Bottom-right hero paw preview — 2026-09-13 QA build 45 revision

Moved paw out of the quota heading into a dedicated bottom-right row, enlarged 64 to 104 points, opacity 0.065. Preserved circular pad and rounder toes with slightly increased spacing. UI consistency review: fresh native light/dark QA qa.Byg2Mv shows no text/progress overlap; card grows 130 points to reserve artwork space. Screenshot hero-paw-dark.png. Local preview only; published release and build44 ZIP unchanged.

## Rounder toes preview — 2026-09-13 QA build 45

Retained circular central pad; changed toes from 20x28 to 23x25, moved them closer to the pad and angled the side toes outward 30 degrees. Both BrandPawTests pass. Fresh native QA qa.gnZ3IT checked in light and dark; screenshot rounder-paw-dark.png. UI consistency review limited changes to geometry; position and opacity unchanged. Preview only, not published or packaged for distribution. Previous build 44 ZIP does not include this refinement.

## Circular paw correction — 2026-09-13 build 44 local

User requested a circular paw pad, rejecting the triangular soft pad. Replaced only the central outline with a true 50x50 ellipse; three toes, rotation, opacity and placement unchanged. Added a central-pad circularity regression across square, wide and tall hosts; both BrandPawTests pass. Native isolated QA `qa.MftFSz` light/dark renderer checked, screenshot `circular-paw-dark.png`. UI consistency review constrained the correction to geometry and uniform fitting.

Local candidate `release.uc4FiX/ByteKibble.app`, packaged as `output/acceptance/release.uc4FiX/ByteKibble-1.2.0-44-arm64.zip`. Developer ID signed, hardened runtime/timestamp; deep strict signature and ZIP integrity pass. Not notarized or installed. GitHub still distributes build43; this correction is local and has not replaced published assets.

## GitHub publication and installer file icon — 2026-09-13

User authorized source and installer upload. Published prerelease `v1.2.0` at https://github.com/mustundead/ByteKibble/releases/tag/v1.2.0, commit `0d6b2851e851f05bd2122b58d991e15f318315a8`, 02:50:27 UTC. All five READMEs and CHANGELOG now describe confirmed build43 features, arm64 distribution and the absence of notarization. Remote main/README/tag were read back. Historical private QA files were retained locally, not uploaded.

Added native app-primary DMG file icon with lower-right macOS package badge using `scripts/set-installer-icon.swift`; final icon checked in Finder after ZIP extraction. Installer ZIP retains FinderInfo and ResourceFork. Bare HTTP DMG does not retain these metadata; documented explicitly. DMG data bytes and signed app unchanged. New installer ZIP SHA256: `e559188e6e7d04d1920181b62f77f2edf810db0da507e9bb83c31e418428d3be`.

19 tests freshly passed at10:39 CST. App deep/strict signature, DMG integrity and both ZIPs checked. All four release assets report uploaded; GitHub SHA256 digests match local originals. First proxy upload left incomplete starter assets; interrupted, read back state, replaced only those incomplete uploads via per-process direct connection. No system proxy settings changed. Release is public prerelease, not notarized or a claim of all-client/system acceptance. This supersedes earlier not-uploaded status below.

## Current local test candidate — 2026-09-13 build 43

Deliverable DMG: `output/acceptance/installer.uoKe5B/ByteKibble-1.2.0-43-arm64.dmg`; ZIP: `output/acceptance/release.IOvlKS/ByteKibble-1.2.0-43-arm64.zip`. Source app is `release.IOvlKS/ByteKibble.app`. These supersede all earlier installer trials and build 42 packages below. Developer ID signed, hardened runtime, timestamp; not notarized, uploaded, installed into /Applications, or user-accepted.

Finder native macOS 27 verification: double-clicked final DMG, 720x540 window, complete 720x480 background, app and Applications at (205,180)/(515,180), 96pt icons. No exposed background folder, fseventsd, root readme, white strip or scroll bar. `installer-verified.png` is the exact mounted final DMG screenshot. Background and instructions reside within the signed app Resources. Packaging writes a complete native icon-view record including `icvl` and background bookmark before Finder ever opens the writable image; this supersedes failed AppleScript/cached-layout and incomplete DS_Store attempts (09Fl3I, YbbdmE, OoY9Pn, 2A4SwY, geDdTs). 512pt trial VIJYQr was corrected to 540pt for the native title and path bars.

Final mounted app deep strict signature verified, executable compared identical to signed source, version 43 and Applications link verified. DMG checksum and ZIP integrity passed. SHA256 DMG: `72c682a908f57c3fe37ce0b214e85bba663772e0e4561b9761853a405dcc2da6`; ZIP: `d551eaacec8a9a84209586e63631528d790d7753b0c5d82f04463f77f303baea`.

Native final release welcome opened: clean original-geometry RGBA illustration and 96pt MU LABS footer verified (`release.IOvlKS/welcome-verified.png`). Updated soft three-toe paw checked in current native QA `qa.43lM3Y`, light and dark, synthetic data and isolated preferences; this is renderer evidence, not live provider acceptance. Latest 19 tests passed before packaging. No subscription or proxy settings modified. UI consistency skill focused verification on full background bounds, both placement frames, cutout edges, footer proportion, and paw aspect ratio.

Reproduce: `python3 -m pip install --target output/acceptance/dmg-tools ds-store==1.3.1 mac-alias==2.2.2`, then `bash scripts/package-dmg.sh /absolute/path/to/signed/ByteKibble.app`. Open the resulting DMG in Finder to inspect, not just check the image checksum.

2026-09-13 alpha cleanup: user explicitly approved local precision masking via annotation. `scripts/clean-welcome-alpha.py` removes only alpha below the existing lower dark outlines; 11,991 shadow/fringe pixels removed, RGB unchanged. Original retained at `Resources/Installer/welcome-artwork-before-mask.png`. Genuine RGBA output replaces WelcomeArtwork.png. Dark and cream composites inspected under `output/acceptance/alpha-cleanup/`; both exterior shadow tabs and bright lower-edge fringe removed. No generated redraw or API used.

2026-09-13 welcome footer correction: MU LABS proportional frame reduced 144pt to 96pt, visible slot 18pt to 12pt, same original image and theme tint. Native dark welcome inspected in release.WhZyLu (build 43 candidate); centered, legible and subordinate to button. This supersedes Qwh4jD footer sizing. No final installer yet: installer.09Fl3I/layout.dmg staging failed Finder disk lookup and was detached; alpha-art cleanup still awaits the requested non-ImageGen mask-method approval. No installed replacement.

## User test ZIP — 2026-09-13

Packaged current source as `output/acceptance/release.uDiad6/ByteKibble-1.2.0-42-arm64.zip`, app 1.2.0 (42), arm64. Includes connected native rounded popover and original-proportion three-toe watermark. Developer ID signed with hardened runtime and timestamp; deep strict signature verification and ZIP integrity pass; all 19 tests pass. Build counter advanced to 42 only after packaging. Not notarized, uploaded, installed, or user-accepted. Welcome illustration still has the previously reported background-edge defect; this package does not claim that artwork or the custom DMG is complete.

## Paw geometry correction — 2026-09-12 23:20 CST

User reported a deformed watermark. Replaced the approximate proportional ellipse arrangement with the original three-toe geometry in `Resources/catfood.svg`, using a single uniform scale and centered bounds. Preserved 64pt placement, opacity, outer rotation, and all card/data behavior. Added BrandPawTests for aspect ratio and centering in square/wide/tall hosts; focused test passed. Native production popup inspected in `output/acceptance/release.ziH6mY/paw-fixed.png`, macOS 27.0 arm64, app 1.2.0 (42). Candidate `release.ziH6mY` supersedes WaXRU4 for this watermark; local ad-hoc only, no installed replacement or upload. UI consistency review constrained the change to source geometry and proportional fitting.

## Attached rounded popover — 2026-09-12

Final local candidate: `output/acceptance/release.WaXRU4/ByteKibble.app`, 1.2.0 (42). `popover-final.png` and `popover-reopened.png` in the same directory are fresh native production captures. Final 18 tests passed at 23:15 CST. Reopen regression found and fixed: refreshing model during willShow disrupted presentation; moving refresh to didShow preserves the native presentation transition. Final launch, Esc-to-zero-windows, reopen and refreshed readout verified. This candidate supersedes WFYyAm (failed reopen presentation) and prior Q1FXLl (visual/keyboard evidence only). Installed app remains untouched.

User reference: round the entire menu card and join a small rounded arrow directly to its top edge, without a horizontal seam. Keep all subscription/data actions intact. Replaced MenuBarExtra window with NSStatusItem + NSPopover; AppKit owns both the arrow and rounded material outline, with no opaque rectangular content backdrop. Apple NSPopover documentation supports anchoring, transient dismissal, and system placement: https://developer.apple.com/documentation/appkit/nspopover . Adopted native positioning and shared surface; rejected a separately overlaid triangle/border.

Verification on macOS 27.0 (26A428), arm64: real menu-bar production popup and isolated QA light/dark popup inspected; expanded add form grows within the same outline; empty input keeps Add disabled; Esc closes to zero visible windows; reopening and status-item toggle checked. Standard responder-chain edit commands restore Command-A replacement after native entry-point migration. Initial empty Settings window eliminated by using an accessory AppKit entry point. Reopen refresh explicitly belongs to NSPopoverDelegate because a retained SwiftUI view does not repeat onAppear. No subscription was submitted or removed; login setting and installed app were not changed. Source logic tests: 18 passed. QA appearance captures: `output/acceptance/qa.gpnWY7/popover-light.png` and `popover-dark.png`; production expanded capture: `output/acceptance/release.Q1FXLl/popover-expanded.png`. These capture the final visual structure; subsequent lifecycle-only refresh fix is separately runtime checked. Local candidates are ad-hoc signed, not notarized or uploaded. Alpha-art cleanup and final ZIP/DMG/install from earlier scope remain pending, not implied complete by this surface correction.

## Active completion scope — 2026-09-12

User resumed one-page first-launch welcome, ImageGen artwork, custom drag-install DMG, final local ZIP/package/install verification. Upload pause remains: no GitHub application source or installer upload; no notarization upload. New artwork brief corrected by user: byte, kibble, traffic, bytes, data. Generic golden ribbon rejected; pet-food-only scene superseded. Need coherent byte-to-kibble data-flow imagery, matching existing gold/cream three-toe branding.

Acceptance (updated by user): native introduction appears once on first launch; dismissal persists only the app-owned welcome key; NO introduction/replay footer entry; all five locales resolve; data and client settings untouched by introduction; final image present in app and mounted Finder DMG; Applications drag destination; matching app versions/signatures in ZIP/DMG/installed copy; preserve old installed app for rollback. First-launch, dismissal/relaunch, long locale and appearance checks are required. Local signing is not notarization or public release.

Selected design: user chose the hand-drawn installer (`exec-66d1eaef-64fe-4376-a617-7ced4db18c40.png`) with two icon placement panels, arrow and bowl. Native welcome subsequently redesigned from an ImageGen reference (`exec-5f22e2af-4145-45cb-96e5-19355b6c4a34.png`), not a screenshot substituted for UI. User-supplied MU Labs wordmark is copied byte-for-byte and template-tinted for light/dark; original alpha bounds inspected. Plain-text Mustundead footer removed. New native QA `qa.YbZhqZ` light/dark screenshots and logo AX inspected. Production welcome art still awaits corrected alpha cutout; first extraction had yellow shadow tabs; first cleanup returned an opaque checkerboard and is rejected. Final packaging/install verification remains pending.

Licensing update after acceptance ZIP (2026-09-12): user confirmed future source-available, noncommercial-free, commercial-use-by-prior-written-permission terms. Remote `5ebc36a` changes only LICENSE, byte-preserved LICENSES/MIT-legacy.txt and five READMEs. New custom terms are prospective; previously MIT-distributed material and 1.2.0(41) acceptance ZIP remain under MIT. This does not alter that ZIP or release it publicly. App source/package upload pause remains in force.

Current user-requested local acceptance ZIP (2026-09-12 21:43 CST): `output/acceptance/release.r0SJrz/ByteKibble-1.2.0-41-arm64.zip`, containing production `ByteKibble.app` 1.2.0 (41), arm64, bundle ID com.bytekibble.app. Includes latest three-toe watermark, system reset arrow/equal separator gaps, neutral explicit login state, outline plus and prior local UI/data corrections. All 17 tests passed; Developer ID signature with hardened runtime/timestamp and archive integrity verified. SHA-256: `9f0e08015d043472e11d6aa301945a69379d16bdcdff8e1db37263ff5a269692`. Not notarized, not uploaded, not installed; user will perform installed acceptance. Welcome page and generated-art DMG remain absent. License remains MIT pending clarification. Earlier artifact candidates are superseded.

Latest local-only three-toe watermark correction (2026-09-12): replaced the four-toe SF paw background with the native brand PawPrint (three oval toes and rounded main pad), adjusted toward the app icon's proportions. Retained 78pt frame, right-center placement, rotation and 4.5% opacity. Reused QA `qa.pTmGc2` rebuilt and light/dark screenshots inspected; source build/diff check passed. No new installer, code upload or actual installed-app replacement.

Current documentation-only publication and local corrections (2026-09-12): user paused source/package uploads and packaging. GitHub commit `325ca63aee426578e105fdac9b112b23d5d71ee8` contains only five README language versions and two appearance-specific current icon images. Chinese names: 字节猫粮 / 字節貓糧. Remote commit file list verified; no GitHub release exists. Local-only UI now uses undistorted, aspect-fit SF `arrow.clockwise` with arrowhead above (latest user reference supersedes filled/custom glyphs); separator is a 2pt disk with equal 5pt gaps; login state retains explicit text/checkmark with no green background; add icon is outline `plus.circle`. Reused isolated QA `qa.pTmGc2` was rebuilt, and light/dark, login enabled without green, and collapsed/expanded add states inspected. No new distribution package, installed replacement, image generation, welcome implementation or DMG release performed after the pause. Prior release.Q0iTAR and all older installers are stale for these corrections.

Latest correction (2026-09-12): previous symbol knockout was rejected as distorted. Reset disk now uses a directly drawn 1.5pt circular arc and triangular arrow knockout, with no SF image rescaling. Login button explicitly says On/Off (all five locales), uses checkmark plus green selected background when enabled, hollow circle when off, and clock/approval text without selected background when pending. Native isolated QA `qa.wMOElq`: EN/light off and on, ZH/dark on and pending screenshots inspected; accessibility exposes state. Actual system login setting was not changed. Five changed resources linted; release build/signature/diff checks passed. Current candidate `output/acceptance/release.Q0iTAR/ByteKibble.app` supersedes previous candidates; not installed or notarized. Actual menu-bar host remains outside automated verification.

Latest icon/paw refinement (2026-09-12): reset badge now draws a full 17pt disk matching the quota pie, with enlarged 14pt transparent arrow. The current remaining card has a 78pt native pawprint watermark, right-center, 4.5% primary opacity; decorative, excluded from hit testing/accessibility. Existing layout, quota colors and data are unchanged. Native QA `qa.3TfCv0` light/dark screenshots inspected. Current candidate `output/acceptance/release.6Ts7tD/ByteKibble.app` supersedes prior paths; release build/signature/diff checks passed. Not installed or notarized; actual MenuBarExtra remains a manual acceptance boundary.

Latest color-scope optimization (2026-09-12): retained existing remaining-quota thresholds (>=20% neutral, >=7% and <20% orange, <7% red). Warning colors now belong only to quota numbers, usage progress, warning text and menu-bar quota renderer. Header plan glyph, reset countdown, metric tile icons and footer actions stay neutral; add-submit uses standard accent. Reset proximity is not quota risk. No data/threshold/progress-direction change (hero bar is used proportion, menu pie is remaining proportion). Native QA `qa.bfJg14`: normal/light, warning/dark and critical/dark screenshots inspected. Focused boundary test passed including exact 20%, 7%, 8.66% example and exhausted/negative ratios. Current candidate `output/acceptance/release.yTFWM2/ByteKibble.app` supersedes all prior paths; release build/signature/diff checks passed, not installed or notarized.

Latest reset-date addition (2026-09-12): reset tile retains countdown and adds a localized estimated month/day from the existing client-day calculation, explicitly labeled estimated; absent/invalid days produce no date. Five resource bundles linted; native QA `qa.Brsbym` English/light and Chinese/dark screenshots and accessibility text inspected. Focused calendar-date test passed (year rollover, zero, invalid bounds). Current candidate `output/acceptance/release.Ti4ar0/ByteKibble.app` supersedes earlier packages below; release build, ad-hoc signature and diff check passed. No installed-popup or provider-confirmed reset date claim.

Latest icon-only revision (2026-09-12): menu-bar reset glyph now uses `arrow.clockwise.circle.fill` in the existing 15pt slot; popup reset glyphs and countdown semantics are unchanged. Native QA `qa.kwKcvI` light/dark screenshots inspected. Current candidate is `output/acceptance/release.YscN89/ByteKibble.app`, superseding earlier packages below. Release build, ad-hoc signature and diff checks passed. Installed MenuBarExtra remains unverified; no installation or notarization performed.

## Latest screenshot-directed corrections — 2026-09-12

Current candidate: `output/acceptance/release.6Wp6AM/ByteKibble.app` (ad-hoc signed, not notarized or installed). All earlier candidate paths below are historical. Remaining quota now uses a filled pie in the status image, reset arrows are thinner, the header countdown stays on one line, reset tiles use the compact countdown, the add-subscription subtitle wraps fully, and the three footer buttons divide the available row equally. Missing reset data remains unknown; this is not evidence of a repaired network query.

Native QA window `qa.GZVJpL` hosts the actual MenuView and MenubarLabel with isolated synthetic data. Inspected dark/expanded-add screenshot: 63% remaining pie, compact 4d countdown, complete two-line subtitle and equal-width footer buttons. This verifies the renderer in a native window, not installed MenuBarExtra positioning or real provider responses. Current release build/signature and diff checks passed; all 15 tests passed at 20:56 CST after these edits.

Latest user-requested restoration: menu-bar reset countdown is visible again, with original days > hours > minutes and today presentation based on client-reported reset days and the original midnight convention (not a server-provided reset timestamp). Focused countdown test passed, including days/hours/minutes/today and unchanged source metadata. Current signed local candidate: `output/acceptance/release.ptGxfX/ByteKibble.app`; all earlier paths below are historical. Installed menu-bar rendering remains unverified.

## Current user-directed UI rollback

2026-09-12: user rejected the redesign except the remaining-progress card. Restored the baseline 2799c35 MenuView layout: 380pt panel, header card, two-column information tiles, original add-subscription card and footer buttons. Retained only the newer progress-card content and restored actual native glassEffect rendering. Data/TLS/cache fixes and the new app icon remain. HTTPS validation, truthful unknown reset metadata and guarded login actions remain without changing the restored control layout. This supersedes the earlier visual contract below.

Fresh QA: `qa.wZKJ9Z` native window, normal and low-quota dark screenshots inspected; macOS 27 native glass, original layout verified against source. Current candidate: `output/acceptance/release.hwNnpH/ByteKibble.app`; release build, signature and diff checks passed. No installed replacement, notarization or real MenuBarExtra popup verification claimed. Earlier artifact paths and redesigned-UI screenshots below are historical.

Scope: ByteKibble native macOS menu-bar UI and its subscription data pipeline. Baseline: 2799c35 / 1.1.0. Work started 2026-09-12.

## Contract

- Display measured remaining traffic and its actual freshness. A local cache read never becomes a new measurement.
- Keep each subscription's request/error isolated. Adding or selecting a subscription queries that target. Removing one changes only ByteKibble's custom entry and offers undo.
- Do not change any provider configuration, provider subscription, credentials, system appearance or login-item preference during verification.
- Only accept HTTPS URLs and standard platform TLS validation. Unknown quota fields never become measured zero. Reset day counts without a source timestamp are labeled as client reports, not converted into a precise countdown.
- Preserve native MenuBarExtra and controls. Data has one primary content card, neutral secondary rows, and localized recovery states. Warning colors identify quota risk only.
- Support keyboard operation, meaningful accessible labels, reduced motion, and increased contrast. Five existing languages remain supported.

## Observable checks

1. Re-reading older client cache does not replace a successful live sample.
2. Unknown reset metadata remains unchanged and honestly labeled across midnight; expired plans say expired.
3. Add B while A exists, switch while A is pending, isolate a failed A from successful B, remove and undo without changing provider data.
4. No subscription, first query, refreshing with existing data, failed with data, failed without data, missing quota fields all have distinct truthful output.
5. HTTP/malformed links and bad certificates are rejected. The UI never displays URL tokens in status messages.
6. 0%, low quota and over-quota indicators render meaningfully; percentages include localized percent symbols.
7. Expanded add form and long localized content remain reachable; native focus, Return, refresh shortcut and settings navigation work.
8. Login-item pending/error states are represented without claiming success or modifying the real setting during QA.

## Evidence status

Implemented; local verification completed with the boundaries below. Not yet user-accepted or released. Evidence date: 2026-09-12, macOS 27, Apple Silicon.

- 15 XCTest tests passed after the final logic changes, including cache freshness, unknown reset metadata across midnight, request isolation, removal/undo, preview preference isolation, strict parsing and actual rejection of a self-signed localhost HTTPS certificate. Reproduce: `swift test --scratch-path .build-audit -j 2`.
- All five localization bundles contain the same 69 keys with matching format placeholders, including the newly supplied Simplified Chinese resource bundle.
- Native QA window hosting the actual MenuView was exercised with synthetic data and isolated preferences: normal, warning, critical, dark/increased contrast, first failure, cache failure, long names, Chinese/Japanese, add-link validation and Return submission, removal/undo, and pending login authorization. Screenshots and accessibility trees are recorded in this task. Final QA build rechecked the low-traffic warning in the accessible summary.
- Keyboard focus and accessible labels were checked. Reduced-motion/contrast overrides were exercised; actual system Large Text, spoken VoiceOver and animation-frame timing were not independently certified.
- Real MenuBarExtra popup could not be accessed by the desktop automation (accessory-app and SystemUIServer access timed out). The native QA window is not proof of popup positioning, dismissal or installed-app acceptance. These remain a manual candidate check. Real login-item registration was not changed; pending state was simulated.

## Current artifacts

Icon update 2026-09-12: the current production candidate is now `output/acceptance/release.Vah7Of/ByteKibble.app`, with Apple-compiled Liquid Glass/appearance resources, corrected edge matte, and a repaired bottom-corner junction. See `Resources/ICON.md`. The earlier candidates are superseded for icon acceptance; app logic is unchanged.

- Production candidate: `output/acceptance/release.j0zDEm/ByteKibble.app`, version 1.2.0 (40), arm64, minimum macOS 13.0, LSUIElement enabled. Ad-hoc signature passed `codesign --verify --deep --strict`. Not notarized, not a public release, and not installed over `/Applications/ByteKibble.app`.
- Production executable SHA-256: `21c1df7b13197139ffaca6c450d1925fa7fd1dcbc4ff8e9abd9fa7eff584f04d`.
- Current isolated QA: `output/acceptance/qa.L1uTI1/ByteKibble QA.app`. Its controls and synthetic data are compiled only with BYTEKIBBLE_ACCEPTANCE; production excludes them.
- Reproduce candidates with `bash scripts/package-local.sh release` or `bash scripts/package-local.sh qa`. Each creates a separate staging directory without replacing installed apps, altering provider preferences, committing or publishing.
- Older QA output directories and `preview/*.png` are superseded/historical, not current acceptance evidence. No Intel runtime, older-macOS runtime, signing identity or notarization verification is claimed.

## Failed cases corrected

- Client cache reads falsely appeared fresh; fetch timestamps now remain unknown unless measured, and older cache cannot replace live success.
- Unknown reset age implied a precise countdown; client-reported day counts now retain their evidence boundary.
- Incomplete quota fields could become zero; missing and malformed values are rejected or represented as unknown.
- TLS bypass and token-bearing transport errors were removed; bad-certificate behavior was verified against an actual local TLS endpoint.
- Overlapping requests and removal could leak stale outcomes; target-specific state and request identity now reject late results.
- macOS system Bash rejected an empty build-argument array in release packaging; release/QA invocation paths are now explicit, and both packaged successfully.

Sources used: apple-design skill; Apple HIG Materials and WWDC25 Meet Liquid Glass. Adopted control/content separation and avoidance of nested glass. Retained native menu-bar behavior; did not introduce unrelated drag, inertia or decorative motion.

## 2026-09-12 21:55 CST — hero card screenshot refinement (local only)

Follow-up: menu-bar reset arrow weight increased medium → semibold, retaining 15 pt fitting and spacing; card arrows unchanged. Fresh native QA light/dark screenshots inspected after successful rebuild, diff check passed. Local only, existing ZIP unchanged.

- Request: refine the cropped warning card. Acceptance: no paw/progress overlap, aligned compact warning, unchanged quota semantics and thresholds.
- Moved the three-toe watermark into the number block (64 pt); separated this block from progress. Existing warning/exhausted labels now use a restrained tinted capsule; used percentage is neutral secondary text.
- Final source built successfully. Native isolated QA host screenshots inspected in conversation: light normal, light critical, dark English warning, dark Chinese critical with high contrast/large text. AX quota summary retains values, risk and freshness. Exhausted AX state confirmed; its immediate screenshot remained stale, so not claimed visually verified.
- 17 logic tests passed before the final color-only adjustment; final adjustment rebuilt and visually checked. `git diff --check` passed. No data, preferences, copy or threshold changes.
- QA bundle reuses build 40 metadata but contains this newly compiled source; it is not a distributable release. Prior 1.2.0(41) ZIP does not contain this refinement. No package/source upload, installation, or new ZIP performed.
