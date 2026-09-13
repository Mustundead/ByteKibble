#!/bin/bash
# Local-only candidate, kept apart from dist/ and /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-release}"
case "$mode" in
  release) configuration=release; app_name=ByteKibble; bundle_id=com.bytekibble.app; extra=() ;;
  qa) configuration=debug; app_name="ByteKibble QA"; bundle_id=com.bytekibble.acceptance; extra=(-Xswiftc -DBYTEKIBBLE_ACCEPTANCE) ;;
  *) printf 'Usage: %s [release|qa]\n' "$0" >&2; exit 2 ;;
esac

if [ "$mode" = qa ]; then
  swift build --scratch-path .build-audit -c "$configuration" -j 2 "${extra[@]}"
  bin_path=$(swift build --scratch-path .build-audit -c "$configuration" --show-bin-path "${extra[@]}")
else
  swift build --scratch-path .build-audit -c "$configuration" -j 2
  bin_path=$(swift build --scratch-path .build-audit -c "$configuration" --show-bin-path)
fi
test -f "$bin_path/ByteKibble"
test -d "$bin_path/ByteKibble_ByteKibble.bundle"
mkdir -p output/acceptance
candidate_dir=$(mktemp -d "$PWD/output/acceptance/$mode.XXXXXX")
app_path="$candidate_dir/$app_name.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/ByteKibble" "$app_path/Contents/MacOS/ByteKibble"
mkdir -p "$app_path/Contents/Frameworks"
ditto .build-audit/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework "$app_path/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath @executable_path/../Frameworks "$app_path/Contents/MacOS/ByteKibble"
ditto "$bin_path/ByteKibble_ByteKibble.bundle" "$app_path/Contents/Resources/ByteKibble_ByteKibble.bundle"
bash scripts/compile-icon.sh "$app_path/Contents/Resources"
cp Resources/Installer/installer.png "$app_path/Contents/Resources/InstallerBackground.png"
cp Resources/Installer/Installation.txt "$app_path/Contents/Resources/Installation.txt"
mkdir -p "$app_path/Contents/Resources/Licenses"
cp LICENSE "$app_path/Contents/Resources/Licenses/ByteKibble.txt"
cp LICENSES/MIT-legacy.txt "$app_path/Contents/Resources/Licenses/MIT-legacy.txt"
cp .build-audit/artifacts/sparkle/Sparkle/LICENSE "$app_path/Contents/Resources/Licenses/Sparkle.txt"

version=$(<VERSION)
prior_build=0
if [ -f .buildnumber ]; then prior_build=$(<.buildnumber); fi
case "$prior_build" in ''|*[!0-9]*) printf 'Invalid .buildnumber\n' >&2; exit 2 ;; esac
build_number=$((prior_build + 1))
plist="$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string $app_name" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $app_name" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $bundle_id" "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string ByteKibble' "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string APPL' "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $version" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $build_number" "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDevelopmentRegion string zh-Hans' "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleLocalizations array' "$plist"
for language in zh-Hans zh-Hant en ja ko; do
  /usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations: string $language" "$plist"
done
/usr/libexec/PlistBuddy -c 'Add :LSMinimumSystemVersion string 13.0' "$plist"
/usr/libexec/PlistBuddy -c 'Add :NSHighResolutionCapable bool true' "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string ByteKibble' "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconName string ByteKibble' "$plist"
if [ "$mode" = release ]; then
  /usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :SUFeedURL string https://raw.githubusercontent.com/mustundead/ByteKibble/main/docs/updates/preview.xml' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :SUPublicEDKey string FFo6GQ0easmXdjP3wlXJCN9l/cD7jBHPT3SwXLA1yuY=' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :SUEnableAutomaticChecks bool true' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :SUAutomaticallyUpdate bool false' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :SUAllowsAutomaticUpdates bool false' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :SUSendProfileInfo bool false' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :SUVerifyUpdateBeforeExtraction bool true' "$plist"
fi
codesign --force --sign - "$app_path/Contents/Resources/ByteKibble_ByteKibble.bundle"
codesign --force --sign - "$app_path"
codesign --verify --deep --strict "$app_path"
printf 'Local candidate (ad-hoc signed, not notarized): %s\n' "$app_path"
