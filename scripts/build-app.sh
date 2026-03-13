#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ZMKBatteryBar"
BUNDLE_ID="com.zmk-battery-bar.app"
BUILD_DIR=".build/release"
APP_DIR="build/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

echo "Building ${APP_NAME} in release mode..."
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"

# Create Info.plist
cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Bluetooth is required to read battery levels from your keyboard.</string>
</dict>
</plist>
EOF

echo "Done! App bundle created at: ${APP_DIR}"
echo "To install: cp -r ${APP_DIR} /Applications/"
