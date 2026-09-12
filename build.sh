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

echo "==> 生成图标"
mkdir -p Resources/icon.iconset
# 图标源：Resources/AppIcon.icon（Icon Composer）内嵌的浅色图 + 品牌SVG，不再手绘
rm -rf Resources/icon.iconset && mkdir -p Resources/icon.iconset
python3 - <<'PYEOF'
import subprocess, os
src = "Resources/icon_light_1024.png"
sizes = [(16,16,"icon_16x16.png"), (32,32,"icon_16x16@2x.png"), (32,32,"icon_32x32.png"),
         (64,64,"icon_32x32@2x.png"), (128,128,"icon_128x128.png"), (256,256,"icon_128x128@2x.png"),
         (256,256,"icon_256x256.png"), (512,512,"icon_256x256@2x.png"), (512,512,"icon_512x512.png"),
         (1024,1024,"icon_512x512@2x.png")]
for h, w, name in sizes:
    subprocess.run(["sips", "-z", str(h), str(w), src, "--out", os.path.join("Resources/icon.iconset", name)], capture_output=True)
PYEOF
iconutil -c icns Resources/icon.iconset -o Resources/AppIcon.icns
if [ -f Resources/icon.iconset/icon_1024.png ]; then
    sips -z 16 16     Resources/icon.iconset/icon_1024.png --out Resources/icon.iconset/icon_16x16.png     >/dev/null
    sips -z 32 32     Resources/icon.iconset/icon_1024.png --out Resources/icon.iconset/icon_16x16@2x.png  >/dev/null
    sips -z 32 32     Resources/icon.iconset/icon_1024.png --out Resources/icon.iconset/icon_32x32.png     >/dev/null
    sips -z 64 64     Resources/icon.iconset/icon_1024.png --out Resources/icon.iconset/icon_32x32@2x.png  >/dev/null
    sips -z 128 128   Resources/icon.iconset/icon_1024.png --out Resources/icon.iconset/icon_128x128.png   >/dev/null
    sips -z 256 256   Resources/icon.iconset/icon_1024.png --out Resources/icon.iconset/icon_128x128@2x.png >/dev/null
    sips -z 256 256   Resources/icon.iconset/icon_1024.png --out Resources/icon.iconset/icon_256x256.png   >/dev/null
    sips -z 512 512   Resources/icon.iconset/icon_1024.png --out Resources/icon.iconset/icon_256x256@2x.png >/dev/null
    sips -z 512 512   Resources/icon.iconset/icon_1024.png --out Resources/icon.iconset/icon_512x512.png   >/dev/null
    sips -z 1024 1024 Resources/icon.iconset/icon_1024.png --out Resources/icon.iconset/icon_512x512@2x.png >/dev/null
    iconutil -c icns Resources/icon.iconset -o Resources/AppIcon.icns && echo "AppIcon.icns 已生成"
fi

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
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>ASACatalogAssets</key><string>AppIcon</string>
    <key>NSHumanReadableCopyright</key><string>ByteKibble — Traffic monitor designed for Clash, Mihomo, SNTP</string>
</dict>
</plist>
PLIST
echo -n "APPL????" > "$APP/Contents/PkgInfo"

[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"
# macOS 26 Icon Composer 图标（Liquid Glass + 明暗切换）
[ -d Resources/AppIcon.icon ] && cp -R Resources/AppIcon.icon "$APP/Contents/Resources/"

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
