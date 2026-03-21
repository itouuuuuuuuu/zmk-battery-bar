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
SUBMIT_OUTPUT=$(xcrun notarytool submit "${NOTARIZE_ZIP}" \
  --apple-id "${APPLE_ID}" \
  --password "${APPLE_ID_PASSWORD}" \
  --team-id "${APPLE_TEAM_ID}" \
  --wait 2>&1) || true
echo "${SUBMIT_OUTPUT}"

# Extract submission ID and check status
SUBMISSION_ID=$(echo "${SUBMIT_OUTPUT}" | grep "id:" | head -1 | awk '{print $2}')

if echo "${SUBMIT_OUTPUT}" | grep -q "status: Invalid"; then
  echo "Notarization failed! Fetching log..."
  xcrun notarytool log "${SUBMISSION_ID}" \
    --apple-id "${APPLE_ID}" \
    --password "${APPLE_ID_PASSWORD}" \
    --team-id "${APPLE_TEAM_ID}" || true
  exit 1
fi

if ! echo "${SUBMIT_OUTPUT}" | grep -q "status: Accepted"; then
  echo "Unexpected notarization status. Fetching log..."
  xcrun notarytool log "${SUBMISSION_ID}" \
    --apple-id "${APPLE_ID}" \
    --password "${APPLE_ID_PASSWORD}" \
    --team-id "${APPLE_TEAM_ID}" || true
  exit 1
fi

echo "Stapling notarization ticket..."
xcrun stapler staple "${APP_PATH}"

echo "Verifying notarization..."
spctl --assess --type exec --verbose "${APP_PATH}"

rm -f "${NOTARIZE_ZIP}"
echo "Notarization complete!"
