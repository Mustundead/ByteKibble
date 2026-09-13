#!/bin/bash
# Prepare isolated QA 46 -> 47 fixtures. Never touches /Applications or production preferences.
set -euo pipefail
cd "$(dirname "$0")/.."
qa_app="${1:?Pass the absolute QA app path}"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$qa_app/Contents/Info.plist")" = com.bytekibble.acceptance
fixture=$(mktemp -d "$PWD/output/acceptance/ota.XXXXXX")
mkdir -p "$fixture/installed" "$fixture/feed"
for location in installed target; do
  app="$fixture/$location/ByteKibble QA.app"
  ditto "$qa_app" "$app"
  plist="$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Add :SUFeedURL string http://localhost:8087/preview.xml' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :SUPublicEDKey string FFo6GQ0easmXdjP3wlXJCN9l/cD7jBHPT3SwXLA1yuY=' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :SUEnableAutomaticChecks bool false' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :SUAllowsAutomaticUpdates bool false' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :SUVerifyUpdateBeforeExtraction bool true' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity dict' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity:NSExceptionDomains dict' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity:NSExceptionDomains:localhost dict' "$plist"
  /usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity:NSExceptionDomains:localhost:NSExceptionAllowsInsecureHTTPLoads bool true' "$plist"
  if [ "$location" = installed ]; then
    /usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 46' "$plist"
  else
    /usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 47' "$plist"
  fi
  bash scripts/sign-release.sh "$app"
done
ditto -c -k --sequesterRsrc --keepParent "$fixture/target/ByteKibble QA.app" "$fixture/feed/ByteKibble-QA-47.zip"
.build-audit/artifacts/sparkle/Sparkle/bin/generate_appcast --account mu-labs.bytekibble --maximum-deltas 0 --download-url-prefix http://localhost:8087/ "$fixture/feed"
printf 'Fixture: %s\nServe only its feed directory on localhost:8087; launch installed/ByteKibble QA.app with --updater-acceptance.\n' "$fixture"
