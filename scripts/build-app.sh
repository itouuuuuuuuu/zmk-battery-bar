#!/usr/bin/env bash
set -euo pipefail

EXECUTABLE_NAME="ZMKBatteryBar"
DISPLAY_NAME="ZMK Battery Bar"
BUILD_DIR=".build/release"
APP_DIR="build/${DISPLAY_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ENTITLEMENTS="Resources/ZMKBatteryBar.entitlements"

# Signing identity: pass as first argument, or default to ad-hoc
SIGN_IDENTITY="${1:--}"
# Version: pass as second argument, or skip version injection
VERSION="${2:-}"

echo "Building ${EXECUTABLE_NAME} in release mode..."
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BUILD_DIR}/${EXECUTABLE_NAME}" "${MACOS_DIR}/"
cp Resources/Info.plist "${CONTENTS_DIR}/Info.plist"
cp Resources/AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"

# Inject version into Info.plist if provided
if [ -n "${VERSION}" ]; then
  echo "Setting version to ${VERSION}..."
  plutil -replace CFBundleShortVersionString -string "${VERSION}" "${CONTENTS_DIR}/Info.plist"
  plutil -replace CFBundleVersion -string "${VERSION}" "${CONTENTS_DIR}/Info.plist"
fi

echo "Signing app bundle with identity: ${SIGN_IDENTITY}"
if [ "${SIGN_IDENTITY}" = "-" ]; then
  codesign --force --deep --sign - "${APP_DIR}"
else
  # Sign the main executable first, then the bundle
  # --deep does not reliably propagate --options runtime and --entitlements
  codesign --force --sign "${SIGN_IDENTITY}" \
    --options runtime \
    --entitlements "${ENTITLEMENTS}" \
    --timestamp \
    "${MACOS_DIR}/${EXECUTABLE_NAME}"

  codesign --force --sign "${SIGN_IDENTITY}" \
    --options runtime \
    --entitlements "${ENTITLEMENTS}" \
    --timestamp \
    "${APP_DIR}"
fi

echo "Done! App bundle created at: ${APP_DIR}"
