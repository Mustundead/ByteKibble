#!/bin/bash
# Local development only. Never distribute this device-bound candidate.
set -euo pipefail
cd "$(dirname "$0")/.."
identity="${BYTEKIBBLE_DEVELOPMENT_SIGN_IDENTITY:?Set BYTEKIBBLE_DEVELOPMENT_SIGN_IDENTITY to an Apple Development code-signing identity}"
xcodebuild -project macOS/Signing/Signing.xcodeproj -scheme ByteKibbleSigning \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath output/mac-signing \
  -allowProvisioningUpdates build
package_log=$(mktemp /tmp/bytekibble-sync-package.XXXXXX)
bash scripts/package-local.sh release | tee "$package_log"
app_path=$(sed -n 's/^Local candidate (ad-hoc signed, not notarized): //p' "$package_log" | tail -n 1)
test -n "$app_path" && test -d "$app_path"
profile_path=output/mac-signing/Build/Products/Debug/ByteKibbleSigning.app/Contents/embedded.provisionprofile
entitlements_path=output/mac-signing/Build/Intermediates.noindex/Signing.build/Debug/ByteKibbleSigning.build/ByteKibbleSigning.app.xcent
test -f "$profile_path" && test -f "$entitlements_path"
cp "$profile_path" "$app_path/Contents/embedded.provisionprofile"
/usr/libexec/PlistBuddy -c 'Add :ByteKibbleCloudEnabled bool true' "$app_path/Contents/Info.plist"
codesign --force --sign "$identity" \
  --options runtime --entitlements "$entitlements_path" "$app_path"
codesign --verify --deep --strict "$app_path"
printf 'Development sync candidate (not for distribution): %s\n' "$app_path"
