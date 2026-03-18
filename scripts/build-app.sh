#!/usr/bin/env bash
set -euo pipefail

EXECUTABLE_NAME="ZMKBatteryBar"
DISPLAY_NAME="ZMK Battery Bar"
BUILD_DIR=".build/release"
APP_DIR="build/${DISPLAY_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

echo "Building ${EXECUTABLE_NAME} in release mode..."
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_DIR}"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BUILD_DIR}/${EXECUTABLE_NAME}" "${MACOS_DIR}/"
cp Resources/Info.plist "${CONTENTS_DIR}/Info.plist"
cp Resources/AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"

echo "Signing app bundle..."
codesign --force --deep --sign - "${APP_DIR}"

echo "Done! App bundle created at: ${APP_DIR}"
echo "To install: cp -r \"${APP_DIR}\" /Applications/"
