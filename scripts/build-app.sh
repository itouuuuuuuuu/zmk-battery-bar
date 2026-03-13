#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ZMKBatteryBar"
BUILD_DIR=".build/release"
APP_DIR="build/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

echo "Building ${APP_NAME} in release mode..."
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"
cp Resources/Info.plist "${CONTENTS_DIR}/Info.plist"

echo "Done! App bundle created at: ${APP_DIR}"
echo "To install: cp -r ${APP_DIR} /Applications/"
