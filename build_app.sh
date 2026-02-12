#!/bin/bash
set -e

APP_NAME="OppoEncoMonitor"
BUNDLE_ID="com.anmol.$APP_NAME"
SRC_DIR="/Users/anmolthakur/Desktop/untitled folder 2/OppoEncoMonitor"
BUILD_DIR="$SRC_DIR/Build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

# Clean up previous build
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "Compiling Swift files..."
swiftc "$SRC_DIR/OppoEncoMonitorApp.swift" "$SRC_DIR/BatteryMonitor.swift" \
    -O -gnone \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    -target arm64-apple-macos13.0 \
    -sdk $(xcrun --show-sdk-path)

echo "Creating Info.plist..."
cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>This app needs Bluetooth to monitor your earbuds' battery level.</string>
</dict>
</plist>
EOF

echo "Signing app (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Build complete: $APP_BUNDLE"
open "$BUILD_DIR"
