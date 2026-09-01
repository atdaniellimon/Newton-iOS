#!/bin/bash
set -e

echo "=== Building Newton for macOS (Monterey 12.0+) ==="

APP_DIR="build/Newton.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

rm -rf "$APP_DIR" "build/Newton-Mac.zip" "build/Newton-Mac.dmg"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# 1. Compile Swift sources
SWIFT_FILES=$(find mac/NewtonMac -name "*.swift")

swiftc -O \
  -target x86_64-apple-macos12.0 \
  -sdk $(xcrun --show-sdk-path) \
  -framework SwiftUI \
  -framework AppKit \
  -framework SceneKit \
  -framework AVFoundation \
  -framework PDFKit \
  -framework QuickLook \
  -o "$MACOS_DIR/Newton" \
  $SWIFT_FILES

# 2. Generate Info.plist
cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Newton</string>
    <key>CFBundleIdentifier</key>
    <string>com.newton.mac</string>
    <key>CFBundleName</key>
    <string>Newton</string>
    <key>CFBundleDisplayName</key>
    <string>Newton</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Newton. All rights reserved.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Newton requires microphone access for hands-free voice mode.</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

# 3. Create .icns icon
if [ -f "mac/NewtonMac/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" ]; then
    mkdir -p build/icon.iconset
    sips -z 16 16     mac/NewtonMac/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png --out build/icon.iconset/icon_16x16.png
    sips -z 32 32     mac/NewtonMac/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png --out build/icon.iconset/icon_16x16@2x.png
    sips -z 32 32     mac/NewtonMac/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png --out build/icon.iconset/icon_32x32.png
    sips -z 64 64     mac/NewtonMac/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png --out build/icon.iconset/icon_32x32@2x.png
    sips -z 128 128   mac/NewtonMac/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png --out build/icon.iconset/icon_128x128.png
    sips -z 256 256   mac/NewtonMac/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png --out build/icon.iconset/icon_128x128@2x.png
    sips -z 256 256   mac/NewtonMac/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png --out build/icon.iconset/icon_256x256.png
    sips -z 512 512   mac/NewtonMac/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png --out build/icon.iconset/icon_256x256@2x.png
    sips -z 512 512   mac/NewtonMac/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png --out build/icon.iconset/icon_512x512.png
    sips -z 1024 1024 mac/NewtonMac/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png --out build/icon.iconset/icon_512x512@2x.png
    iconutil -c icns build/icon.iconset -o "$RESOURCES_DIR/AppIcon.icns"
    rm -rf build/icon.iconset
fi

# 4. Ad-hoc codesign
codesign --force --deep --sign - "$APP_DIR"

# 5. Create ZIP and DMG packages
cd build
zip -r -y "Newton-Mac.zip" "Newton.app"
hdiutil create -volname "Newton" -srcfolder "Newton.app" -ov -format UDZO "Newton-Mac.dmg"

echo "=== Newton macOS App built successfully at build/Newton.app and build/Newton-Mac.dmg ==="
