#!/bin/bash
# Reproducible Mac App Store package. This path never embeds Sparkle or an OTA feed.
# It requires a provisioning profile and App Store distribution identities; it never
# falls back to ad-hoc signing because that artifact cannot be submitted to the store.
set -euo pipefail
cd "$(dirname "$0")/.."

configuration=release
app_name=ByteKibble
bundle_id=com.mulabs.bytekibble
identity="${BYTEKIBBLE_APP_STORE_SIGN_IDENTITY:?Set the Mac App Store distribution signing identity}"
installer_identity="${BYTEKIBBLE_APP_STORE_INSTALLER_IDENTITY:?Set the Mac App Store installer signing identity}"
profile="${BYTEKIBBLE_APP_STORE_PROVISION_PROFILE:?Set the provisioning profile path for com.mulabs.bytekibble}"
test -f "$profile"
profile_plist=$(mktemp)
trap 'rm -f "$profile_plist"' EXIT
security cms -D -i "$profile" > "$profile_plist"
profile_app_id=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' "$profile_plist" 2>/dev/null || /usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$profile_plist")
case "$profile_app_id" in *".$bundle_id") ;; *) echo "Provisioning profile is not for $bundle_id" >&2; exit 2;; esac
if /usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$profile_plist" >/dev/null 2>&1; then
  echo "Provisioning profile is for registered devices, not App Store distribution" >&2; exit 2
fi
if /usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' "$profile_plist" 2>/dev/null | grep -qi '^true$'; then
  echo "Provisioning profile permits debugging and cannot be used for App Store distribution" >&2; exit 2
fi
available_identities=$(security find-identity -v)
case "$available_identities" in *"\"$identity\""*) ;; *) echo "App signing identity is unavailable: $identity" >&2; exit 2;; esac
case "$identity" in "Apple Distribution:"*|"3rd Party Mac Developer Application:"*|"Mac App Distribution:"*) ;; *) echo "App signing identity is not a Mac App Store distribution identity" >&2; exit 2;; esac
case "$available_identities" in *"\"$installer_identity\""*) ;; *) echo "Installer signing identity is unavailable: $installer_identity" >&2; exit 2;; esac
case "$installer_identity" in "Mac Installer Distribution:"*|"3rd Party Mac Developer Installer:"*) ;; *) echo "Installer signing identity is not a Mac App Store installer identity" >&2; exit 2;; esac
scratch=.build-app-store
BYTEKIBBLE_APP_STORE=1 swift build --scratch-path "$scratch" -c "$configuration" -Xswiftc -DBYTEKIBBLE_APP_STORE -j 2
bin_path=$(BYTEKIBBLE_APP_STORE=1 swift build --scratch-path "$scratch" -c "$configuration" --show-bin-path -Xswiftc -DBYTEKIBBLE_APP_STORE)
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
/usr/libexec/PlistBuddy -c 'Add :ByteKibbleCloudEnabled bool true' "$app_path/Contents/Info.plist"
cp "$profile" "$app_path/Contents/embedded.provisionprofile"

# Sign only executable code before the containing application. Resource bundles are
# data in the app bundle and do not receive the app's sandbox entitlement.
codesign --force --options runtime --sign "$identity" "$app_path/Contents/MacOS/ByteKibble"
codesign --force --options runtime --entitlements macOS/AppStore/ByteKibble.entitlements --sign "$identity" "$app_path"
codesign --verify --deep --strict "$app_path"
pkg_path="$candidate_dir/$app_name-$version-$build_number.pkg"
productbuild --component "$app_path" /Applications --sign "$installer_identity" "$pkg_path"
pkgutil --check-signature "$pkg_path"
printf 'Mac App Store package: %s\n' "$pkg_path"
