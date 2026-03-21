#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:?Usage: $0 <path-to-app>}"
APPLE_ID="${APPLE_ID:?Set APPLE_ID env var}"
APPLE_ID_PASSWORD="${APPLE_ID_PASSWORD:?Set APPLE_ID_PASSWORD env var}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:?Set APPLE_TEAM_ID env var}"

NOTARY_AUTH=(--apple-id "${APPLE_ID}" --password "${APPLE_ID_PASSWORD}" --team-id "${APPLE_TEAM_ID}")

NOTARIZE_DIR="$(mktemp -d)"
NOTARIZE_ZIP="${NOTARIZE_DIR}/notarize.zip"
cleanup() { rm -rf "${NOTARIZE_DIR}"; }
trap cleanup EXIT

echo "Creating zip for notarization..."
ditto -c -k --keepParent "${APP_PATH}" "${NOTARIZE_ZIP}"

echo "Submitting for notarization..."
SUBMIT_OUTPUT=$(xcrun notarytool submit "${NOTARIZE_ZIP}" "${NOTARY_AUTH[@]}" --wait 2>&1) || true
echo "${SUBMIT_OUTPUT}"

SUBMISSION_ID=$(echo "${SUBMIT_OUTPUT}" | grep "id:" | head -1 | awk '{print $2}')

if ! echo "${SUBMIT_OUTPUT}" | grep -q "status: Accepted"; then
  echo "Notarization failed!"
  if [ -n "${SUBMISSION_ID}" ]; then
    echo "Fetching log for submission ${SUBMISSION_ID}..."
    xcrun notarytool log "${SUBMISSION_ID}" "${NOTARY_AUTH[@]}" || true
  fi
  exit 1
fi

echo "Stapling notarization ticket..."
xcrun stapler staple "${APP_PATH}"

echo "Verifying notarization..."
spctl --assess --type exec --verbose "${APP_PATH}"

echo "Notarization complete!"
