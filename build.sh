#!/bin/bash
# 构建 ByteKibble.app：通用二进制 -> 组装 bundle -> Developer ID 签名 -> 打 zip
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME=ByteKibble
IDENTITY="Developer ID Application: King Edwin (46P646AZCB)"

# 版本号：语义版本由 VERSION 文件维护；build 号自动递增（从已安装版本起步）
SHORT_VERSION=$(cat VERSION 2>/dev/null || echo "1.0.0")
BUILD_NUM=$(cat .buildnumber 2>/dev/null || /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" /Applications/ByteKibble.app/Contents/Info.plist 2>/dev/null || echo 0)
BUILD_NUM=$((BUILD_NUM + 1))
echo "$BUILD_NUM" > .buildnumber


echo "==> 构建二进制 (arm64)"
swift build -c release --scratch-path .build-arm
ARM_BIN=".build-arm/out/Products/Release/$APP_NAME"
[ -f "$ARM_BIN" ] || ARM_BIN=$(find .build-arm -type f -name "$APP_NAME" ! -name "*.o" | head -1)

echo "==> 构建二进制 (x86_64)"
X64_BIN=""
if swift build -c release --arch x86_64 --scratch-path .build-x64 2>/dev/null; then
    X64_BIN=".build-x64/out/Products/Release/$APP_NAME"
    [ -f "$X64_BIN" ] || X64_BIN=$(find .build-x64 -type f -name "$APP_NAME" ! -name "*.o" | head -1)
fi

APP="dist/$APP_NAME.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

if [ -n "$X64_BIN" ] && [ -f "$X64_BIN" ]; then
    lipo -create "$ARM_BIN" "$X64_BIN" -output "$APP/Contents/MacOS/$APP_NAME"
else
    echo "!! x86_64 构建不可用，仅出 arm64 版"
    cp "$ARM_BIN" "$APP/Contents/MacOS/$APP_NAME"
fi
lipo -info "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>ByteKibble</string>
    <key>CFBundleIdentifier</key><string>com.bytekibble.app</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$SHORT_VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUM</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleIconFile</key><string>ByteKibble</string>
    <key>CFBundleIconName</key><string>ByteKibble</string>
    <key>NSHumanReadableCopyright</key><string>ByteKibble — Traffic monitor designed for Clash, Mihomo, SNTP</string>
</dict>
</plist>
PLIST
echo -n "APPL????" > "$APP/Contents/PkgInfo"

# Compile real appearance/material resources instead of copying an uncompiled .icon.
bash scripts/compile-icon.sh "$APP/Contents/Resources"

# SPM 资源包（Bundle.module 依赖，缺了会启动即崩）
RES_BUNDLE=".build-arm/out/Products/Release/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RES_BUNDLE" ]; then
    cp -R "$RES_BUNDLE" "$APP/Contents/Resources/"
    codesign --force --sign "$IDENTITY" "$APP/Contents/Resources/${APP_NAME}_${APP_NAME}.bundle"
else
    echo "!! 未找到 SPM 资源包"
fi

echo "==> 签名"
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign -dv "$APP" 2>&1 | sed -n '1,3p' || true

echo "==> 打包 zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/$APP_NAME.zip"
echo "完成: $APP 和 dist/$APP_NAME.zip"
