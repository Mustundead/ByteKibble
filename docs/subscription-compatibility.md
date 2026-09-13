# Quantumult / Shadowsocks / Surge subscription compatibility

Version: 1.2.0 build 46. Build 45 does not include the SIP008, Surge managed-line or manual reset-date additions.

## Contract

- Enter an HTTPS subscription URL through the existing Add Subscription action. Only ByteKibble's custom subscription preferences change. No client configuration or credentials are modified, exported or logged.
- Read an explicit `Subscription-Userinfo` header first (including Quantumult's documented upload/download/total/optional expiry format). Invalid headers stay errors; the body must not silently replace a contradictory header.
- If no header is supplied, decode SIP008 version 1 JSON with a server array and integer `bytes_used` / `bytes_remaining`. Total is their checked sum. Both values must be nonnegative; total must be positive and fit Int64. Missing/unlimited quota stays unavailable, not zero.
- SIP008 aggregate usage is independent of upload/download. Missing breakdowns show a dash and the existing localized “Not provided” text. Expiry/reset dates are not invented or taken from undocumented custom fields.
- HTTPS/TLS validation, redirect rules, client User-Agent and per-subscription failure isolation are unchanged. Surge's localhost HTTP proxy port 6152 is added to the fallback candidates. A provider requiring a different User-Agent or an unsupported local proxy port may still fail.
- No Quantumult/Quantumult X, Shadowsocks or Surge client automatic discovery was added; no verified local storage contract is available in this task. Single `ss://` links are not quota endpoints. Scripts and node payloads are never executed, and node passwords are not decoded into the quota model or persisted.
- Surge's copied `#!MANAGED-CONFIG` first line is accepted only if its URL passes the same HTTPS validation. Multiline profiles are rejected; only the URL is stored, not options, scripts or node credentials.
- Manual reset dates are explicitly user-owned local overrides, keyed by the existing subscription deduplication key. Save changes only that override; cancel changes nothing; clear restores available client metadata; removal clears the override and undo restores it. Calendar-day countdowns use the Mac's calendar/timezone. Past dates remain past, without rolling forward or changing quota samples. The tile identifies Manual, and header/menu-bar countdowns carry `*`. Preview-only rendering cannot write preferences.

## References and choices

- [Quantumult official subscription header](https://github.com/crossutility/Quantumult/blob/master/extra-subscription-feature.md): reuse the documented header and add its exact sample as a regression test. Do not infer Quantumult X storage or client integration from header compatibility.
- [Shadowsocks SIP008](https://shadowsocks.org/doc/sip008.html): adopt aggregate usage fields and HTTPS; reject invented upload/download splits and inferred unlimited totals. Read only the required quota envelope and server IDs, not node credentials.
- [Surge managed profiles](https://manual.nssurge.com/profile/managed-profile.html): accept the documented first-line URL syntax; deliberately do not interpret its update interval as a quota reset interval.
- [Surge troubleshooting](https://kb.nssurge.com/surge-knowledge-base/guidelines/troubleshooting): add documented localhost HTTP proxy port 6152, without changing system proxy configuration.

## Verification

`swift test --scratch-path .build-audit -j 2` exercises the parser, quota calculations, failure isolation and TLS rejection. `plutil -lint` validates all five changed localization resources.

`bash scripts/package-local.sh qa` produces an isolated native QA app. Launch with `--compat-screenshot` for SIP008 (25 GiB used, 75 GiB remaining), or add `--quantumult` for the official header fixture. Optional `--light` and `--zh` change appearance/language. The fixtures never access a real subscription. The native popover uses the production view without ImageRenderer or retouching.

Real provider/client integration, automatic discovery, notarization and a new public release are not established by these checks.

Final build 46 candidate: 34 tests passed locally on 2026-09-13. All five localization resources passed lint. Native QA `output/acceptance/qa.6fYBXI/ByteKibble QA.app` was used to click the reset tile, open the date sheet, clear the override, save a new date and verify its manual label while usage remained unchanged. Accessibility inspection exposed the date field, Save, Cancel and Clear controls. Capture: `output/acceptance/qa.6fYBXI/manual-reset-dark-zh.png`. Release artifacts and their signing/hash evidence are reported separately in the release notes; earlier captures below are historical and do not validate the new date editor.

2026-09-13 local result: 26 tests passed after the final code/resource changes; all five `.strings` files passed lint. Native QA build 46 at `output/acceptance/qa.CGdvkV/ByteKibble QA.app` was captured as `sip008-dark-en.png` and `quantumult-light-zh.png` in the same directory. Both were visually inspected: SIP008 shows 75 GB remaining, 25 GB used and unavailable directional counters; Quantumult shows the official sample's directional counters and expiry. Original card widths and layout were retained. The pre-existing `Welcome.swift` `redo:` compiler warning remains unrelated. This QA app is ad-hoc signed and uses isolated sample data, not a release installer.
