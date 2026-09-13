# README screenshot

Captured on macOS on 2026-09-13 using the native `MenuPopoverController` and unchanged production `MenuView`, not ImageRenderer or an image mockup. The QA toolbar window is excluded from the capture. The screenshot uses the build 45 UI and dark appearance.

The isolated fixture contains 1000 GiB total, zero uploaded/downloaded bytes, a 30-day reset value and an expiry 180 days after capture. Remaining traffic is 100%. These are sample values, not a real subscription or a network fetch. Public captions disclose this. No client configuration, credentials or real subscription data is modified.

Reproduce with `bash scripts/package-local.sh qa`, then launch the resulting QA app with `--readme-screenshot`. This opens the actual menu popover with the fixture. Capture only its window using macOS `screencapture -x -o -l <window-id> <output.png>`. The capture has no QA controls, input focus highlight or image retouching. A future QA package may display a newer build number; do not relabel it as build 45.

The screenshot helper is compiled only with `BYTEKIBBLE_ACCEPTANCE`.

Build 46 refresh: `docs/assets/quota-build46-full-dark.png` was captured from the native popover of `output/acceptance/qa.6fYBXI/ByteKibble QA.app` on 2026-09-13 using the same full-quota fixture. The old build 45 image remains historical. The new screenshot includes the current subscription hint and reset tile; no QA controls, focus ring or image retouching were included.
