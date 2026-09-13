#!/bin/bash
# Apple-native layered icon compilation: dynamic Assets.car + legacy ICNS fallback.
set -euo pipefail
project_dir=$(cd "$(dirname "$0")/.." && pwd)
target_dir="${1:?Usage: compile-icon.sh output-directory}"
mkdir -p "$target_dir"
target_dir=$(cd "$target_dir" && pwd)
xcrun actool "$project_dir/Resources/ByteKibble.icon" \
  --compile "$target_dir" --platform macosx --minimum-deployment-target 13.0 \
  --app-icon ByteKibble --output-partial-info-plist "$target_dir/icon-info.plist" \
  --output-format human-readable-text
test -s "$target_dir/Assets.car"
test -s "$target_dir/ByteKibble.icns"
