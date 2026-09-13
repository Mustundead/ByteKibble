#!/bin/bash
# Sign nested Sparkle helpers before their containing framework and app.
set -euo pipefail
app_path="${1:?Usage: bash scripts/sign-release.sh /absolute/ByteKibble.app}"
identity="${BYTEKIBBLE_SIGN_IDENTITY:?Set BYTEKIBBLE_SIGN_IDENTITY to a Developer ID Application identity}"
test -d "$app_path/Contents/Frameworks/Sparkle.framework"
framework="$app_path/Contents/Frameworks/Sparkle.framework/Versions/B"
for component in "$framework/Autoupdate" "$framework/Updater.app" \
  "$framework/XPCServices/Installer.xpc" "$framework/XPCServices/Downloader.xpc" \
  "$app_path/Contents/Frameworks/Sparkle.framework" \
  "$app_path/Contents/Resources/ByteKibble_ByteKibble.bundle" "$app_path"; do
  codesign --force --sign "$identity" --options runtime --timestamp "$component"
done
codesign --verify --deep --strict "$app_path"
