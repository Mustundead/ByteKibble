# Security and request hardening — unreleased source

Scope: the four findings from the 2026-09-13 audit. No provider configuration,
real subscription credentials, installed application, GitHub release or update
feed was modified during verification.

## Contracts

- Manual URLs live in the macOS Keychain under the app's service namespace.
  Preferences contain display names and hashed identifiers. Legacy selection
  and reset-date keys are hashed as well, including keys for absent targets.
- Migration replaces legacy preference records only after credential writes
  succeed (the production store reads back each write). A failed migration
  retains the old preference records; readable sources remain available.
  Failed removal preserves the entry and its reset date; failed undo preserves
  the undo record. Undo necessarily retains the removed URL in process memory.
- Keychain failures are surfaced through the existing status area. No raw
  operating-system error or URL is included. Other clients and old backups are
  untouched. Local Keychain storage is not a promise of safety on a compromised
  device. Keychain access can be subject to macOS authorization.
- HTTP response headers are processed through a URLSession data delegate.
  Once quota headers are delivered, remaining download is cancelled. The
  system networking layer may receive an initial body prefix before delivering
  headers; this is not a zero-network-body-byte guarantee.
- SIP008 fallback accumulates at most 2 MiB in the application. Oversized
  declared lengths and streamed bodies are rejected. System transport buffers
  and parser overhead are not included in that application-body limit.
- Only same-host, same-port HTTPS redirects are followed, at most 10 hops.
  Cross-origin users must supply the final provider URL explicitly.
- Only selected transient connection errors try the next local transport.
  HTTP errors (including 401/403/429), TLS failures, malformed quota and body
  size failures stop the current attempt sequence. Cancellation propagates.
- Removing a subscription cancels its active fetch. Automatic failures wait
  1/2/4/8/15 minutes for transient failures or 15 minutes for other errors.
  Menu-triggered refreshes respect this deadline and a 60-second success
  cooldown; explicit manual refresh can bypass it. Normal periodic refresh is
  still 15 minutes. Selecting a different subscription can trigger a refresh.

## Evidence and reproduction

On 2026-09-13, macOS arm64, `swift test --scratch-path .build-audit -j 2`
passed 55 tests with no failures. Added tests cover preference migration,
mixed legacy/secure records, failed writes/removals/undo, missing credentials,
selection/reset persistence, cancellation, retry classification, redirect
policy, declared/actual body limits and SIP008 fallback.

The loopback HTTP fixture advertises a very large body, sends only a 1 KiB
prefix, then stalls. Header-based quota retrieval completes before the body
finishes. Production URL validation remains HTTPS-only. A separate real TLS
fixture confirms rejection of an untrusted certificate. No real subscription
was queried by these tests.

Earlier header-only fixtures without body bytes timed out in the system
networking stack; the failed observation is retained here. URLProtocol with an
explicit content type exercises the no-body callback path, while the real
socket test verifies early cancellation after a small transport prefix. A
delegate-based implementation avoids per-byte application processing.

The release configuration also built successfully with
`swift build --scratch-path .build-audit -c release -j 2`; only the pre-existing
`Welcome.swift` selector warning remained. An earlier build hit a full disk;
available space subsequently recovered without deleting project files.
All five localization resources passed `plutil -lint`. Tests use an injected
memory credential store, not the user's Keychain. The signed-app verification
below additionally exercises real Keychain storage with dummy data.
Authorization/locked-Keychain behavior, new error-message layout,
long-duration energy measurements, notarization and release installation are
not established by these tests and remain distribution acceptance checks.

## Signed candidate Keychain verification

2026-09-13: local build 50 at
`output/acceptance/release.uvngY5/ByteKibble.app` passed
`--verify-credential-store` with 11 checks. This explicit offline mode runs
inside the Developer ID-signed release executable, uses a unique test service
namespace and preference domain, and never scans real client configurations.
It verified real Keychain migration, addition, read-back, removal, undo,
hashed selection restoration, reset-date preservation and cleanup. Both dummy
Keychain items were deleted and the test preference domain was removed.
The full 55-test suite passed again after adding this acceptance entry point.
Its migration-date fixture was corrected to use a calendar-day boundary:
sub-microsecond Date/Unix timestamp conversion had caused flaky exact equality
assertions despite equal displayed dates. No production date behavior changed.
Reopening here means constructing a new ViewModel within the process, not
an installed-version upgrade or full process restart.

`codesign --verify --deep --strict` passed. Signature inspection confirmed
Developer ID, timestamp and Hardened Runtime. This candidate is arm64 and
has not been notarized, installed over the user's app or published as a release.

Reproduce after signing a fresh candidate:

```sh
/absolute/path/ByteKibble.app/Contents/MacOS/ByteKibble --verify-credential-store
```

Only fixed dummy URLs under `acceptance.invalid` are used. No arbitrary URL or
production Keychain service can be supplied to this acceptance command.

## Research decisions

- [Apple Keychain password storage](https://developer.apple.com/documentation/security/adding-a-password-to-the-keychain): adopted system secret storage rather than preference encryption with an embedded key.
- [Keychain synchronization](https://developer.apple.com/documentation/security/ksecattrsynchronizable): synchronization is not enabled; no iCloud credential sharing is introduced.
- [URLSession async interfaces](https://developer.apple.com/videos/play/wwdc2021/10095/): investigated streaming and cancellation; adopted data-delegate chunk processing for explicit response/body handling rather than whole-response `Data` buffering.

Build 49 remains the published version and does not include these changes.
