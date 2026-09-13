#!/bin/bash
# Generate a signed candidate feed; never publishes or changes the live feed.
set -euo pipefail
cd "$(dirname "$0")/.."
app_path="${1:?Usage: bash scripts/prepare-update.sh /absolute/ByteKibble.app}"
plist="$app_path/Contents/Info.plist"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" = com.bytekibble.app
test "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$plist")" = FFo6GQ0easmXdjP3wlXJCN9l/cD7jBHPT3SwXLA1yuY=
codesign --verify --deep --strict "$app_path"
signature_details=$(codesign -dvv "$app_path" 2>&1)
[[ "$signature_details" == *'Authority=Developer ID Application:'* ]]
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")
case "$version-$build" in *[!0-9.-]*) printf 'Invalid version\n' >&2; exit 2 ;; esac
candidate=$(mktemp -d "$PWD/output/acceptance/update.XXXXXX")
archive="$candidate/ByteKibble-$version-$build-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$archive"
bin=.build-audit/artifacts/sparkle/Sparkle/bin
signature=$("$bin/sign_update" --account mu-labs.bytekibble -p "$archive")
"$bin/sign_update" --account mu-labs.bytekibble --verify "$archive" "$signature"
"$bin/generate_appcast" --account mu-labs.bytekibble --maximum-deltas 0 \
  --download-url-prefix "https://github.com/mustundead/ByteKibble/releases/download/v$version-build$build/" "$candidate"
shasum -a 256 "$archive"
printf 'Candidate only: %s\nUpload and verify the archive before publishing preview.xml.\n' "$candidate"
