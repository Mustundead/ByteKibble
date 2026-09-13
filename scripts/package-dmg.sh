#!/bin/bash
# Wrap an already signed local candidate. Never overwrite an existing installer.
set -euo pipefail
cd "$(dirname "$0")/.."
app_path="${1:?Pass an absolute ByteKibble.app path}"
case "$app_path" in /*/ByteKibble.app) ;; *) exit 2 ;; esac
test -d "$app_path"
codesign --verify --deep --strict "$app_path"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Contents/Info.plist")
output_dir=$(mktemp -d "$PWD/output/acceptance/installer.XXXXXX")
stage="$output_dir/stage"
mkdir -p "$stage"
ditto "$app_path" "$stage/ByteKibble.app"
ln -s /Applications "$stage/Applications"
volume="ByteKibble $version ($build)"
hdiutil create -srcfolder "$stage" -volname "$volume" -fs HFS+ -format UDRW "$output_dir/layout.dmg"
mount_path="$output_dir/mount"
mkdir "$mount_path"
hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$mount_path" "$output_dir/layout.dmg"
trap 'hdiutil detach "$mount_path" >/dev/null 2>&1 || true' EXIT
PYTHONPATH="$PWD/output/acceptance/dmg-tools" python3 scripts/finalize-dmg-layout.py "$mount_path"
if [ -d "$mount_path/.fseventsd" ]; then
  mv "$mount_path/.fseventsd" "$output_dir/generated-fseventsd"
fi
sync
hdiutil detach "$mount_path"
trap - EXIT
artifact="$output_dir/ByteKibble-$version-$build-arm64.dmg"
hdiutil convert "$output_dir/layout.dmg" -format UDZO -imagekey zlib-level=9 -o "$artifact"
hdiutil verify "$artifact"
swift scripts/set-installer-icon.swift "$app_path/Contents/Resources/ByteKibble.icns" "$artifact"
ditto -c -k --sequesterRsrc "$artifact" "${artifact%.dmg}-installer.zip"
printf 'Local DMG: %s\n' "$artifact"
