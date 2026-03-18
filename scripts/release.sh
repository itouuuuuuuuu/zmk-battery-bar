#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: $0 <version> (e.g. 1.0.0)}"
TAG="v${VERSION}"
DISPLAY_NAME="ZMK Battery Bar"
ZIP_NAME="ZMKBatteryBar-${VERSION}.zip"

# Build the app
./scripts/build-app.sh

# Create zip archive
echo "Creating ${ZIP_NAME}..."
cd build
zip -r "../${ZIP_NAME}" "${DISPLAY_NAME}.app"
cd ..

# Compute SHA256
SHA256=$(shasum -a 256 "${ZIP_NAME}" | awk '{print $1}')
echo "SHA256: ${SHA256}"

# Create GitHub release
echo "Creating GitHub release ${TAG}..."
gh release create "${TAG}" "${ZIP_NAME}" \
  --title "${TAG}" \
  --generate-notes

echo ""
echo "Release ${TAG} created!"
echo "SHA256: ${SHA256}"
echo ""
echo "Update the Cask formula with:"
echo "  version: ${VERSION}"
echo "  sha256:  ${SHA256}"

# Cleanup
rm -f "${ZIP_NAME}"
