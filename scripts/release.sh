#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: $0 <version> [signing-identity]}"
TAG="v${VERSION}"
DISPLAY_NAME="ZMK Battery Bar"
ZIP_NAME="ZMKBatteryBar-${VERSION}.zip"

# Signing identity: pass as second argument, or default to ad-hoc
SIGN_IDENTITY="${2:--}"

# Build the app with signing identity and version
./scripts/build-app.sh "${SIGN_IDENTITY}" "${VERSION}"

# Notarize if using a real signing identity
if [ "${SIGN_IDENTITY}" != "-" ]; then
  echo "Notarizing..."
  ./scripts/notarize.sh "build/${DISPLAY_NAME}.app"
fi

# Create zip archive (after stapling so the ticket is included)
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
