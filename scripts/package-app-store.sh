#!/bin/bash
# Reproducible Mac App Store candidate. This path never embeds Sparkle or an OTA feed.
set -euo pipefail
cd "$(dirname "$0")/.."

configuration=release
app_name=ByteKibble
bundle_id=com.mulabs.bytekibble
scratch=.build-app-store
swift build --scratch-path "$scratch" -c "$configuration" -Xswiftc -DBYTEKIBBLE_APP_STORE -j 2
bin_path=$(swift build --scratch-path "$scratch" -c "$configuration" --show-bin-path -Xswiftc -DBYTEKIBBLE_APP_STORE)
test -f "$bin_path/ByteKibble"
test -d "$bin_path/ByteKibble_ByteKibble.bundle"

version=$(<VERSION)
build_number=$(<.buildnumber)
build_number=$((build_number + 1))
candidate_dir=$(mktemp -d "$PWD/output/acceptance/app-store.XXXXXX")
app_path="$candidate_dir/$app_name.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/ByteKibble" "$app_path/Contents/MacOS/ByteKibble"
ditto "$bin_path/ByteKibble_ByteKibble.bundle" "$app_path/Contents/Resources/ByteKibble_ByteKibble.bundle"
bash scripts/compile-icon.sh "$app_path/Contents/Resources"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string $app_name" "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $app_name" "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $bundle_id" "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string ByteKibble' "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string APPL' "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $version" "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $build_number" "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSMinimumSystemVersion string 13.0' "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string ByteKibble' "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconName string ByteKibble' "$app_path/Contents/Info.plist"

identity="${BYTEKIBBLE_APP_STORE_SIGN_IDENTITY:--}"
codesign --force --options runtime --entitlements macOS/AppStore/ByteKibble.entitlements --sign "$identity" "$app_path/Contents/Resources/ByteKibble_ByteKibble.bundle"
codesign --force --options runtime --entitlements macOS/AppStore/ByteKibble.entitlements --sign "$identity" "$app_path"
codesign --verify --deep --strict "$app_path"
printf 'Mac App Store candidate (sandboxed; distribution signing still required): %s\n' "$app_path"
