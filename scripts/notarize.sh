#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:?Usage: $0 <path-to-app>}"
APPLE_ID="${APPLE_ID:?Set APPLE_ID env var}"
APPLE_ID_PASSWORD="${APPLE_ID_PASSWORD:?Set APPLE_ID_PASSWORD env var}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:?Set APPLE_TEAM_ID env var}"

# Create a temporary zip for notarization submission
NOTARIZE_ZIP="$(mktemp -d)/notarize.zip"
echo "Creating zip for notarization..."
ditto -c -k --keepParent "${APP_PATH}" "${NOTARIZE_ZIP}"

echo "Submitting for notarization..."
xcrun notarytool submit "${NOTARIZE_ZIP}" \
  --apple-id "${APPLE_ID}" \
  --password "${APPLE_ID_PASSWORD}" \
  --team-id "${APPLE_TEAM_ID}" \
  --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "${APP_PATH}"

echo "Verifying notarization..."
spctl --assess --type exec --verbose "${APP_PATH}"

rm -f "${NOTARIZE_ZIP}"
echo "Notarization complete!"
