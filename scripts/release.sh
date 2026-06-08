#!/usr/bin/env bash
# Build, sign, notarize, and package Standup Buddy for direct distribution.
#
# One-time setup — store your notarization credentials in the keychain:
#   xcrun notarytool store-credentials "StandupBuddy" \
#     --apple-id "you@example.com" \
#     --team-id "3X7YGW6S68" \
#     --password "xxxx-xxxx-xxxx-xxxx"   # app-specific password from appleid.apple.com
#
# Then run:  ./scripts/release.sh
#
# Override the keychain profile name via NOTARY_PROFILE if needed.

set -euo pipefail
cd "$(dirname "$0")/.."

NOTARY_PROFILE="${NOTARY_PROFILE:-StandupBuddy}"
SCHEME="StandupBuddy"
ARCHIVE_PATH="build/StandupBuddy.xcarchive"
EXPORT_DIR="build/export"
APP_PATH="$EXPORT_DIR/StandupBuddy.app"
DMG_PATH="build/StandupBuddy.dmg"

mkdir -p build

echo "→ Generating Xcode project"
xcodegen generate

echo "→ Archiving (Release)"
rm -rf "$ARCHIVE_PATH"
xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive

echo "→ Exporting"
rm -rf "$EXPORT_DIR"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist scripts/exportOptions.plist

echo "→ Creating DMG"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "Standup Buddy" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "→ Notarizing DMG (this may take a few minutes)"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "→ Stapling DMG"
xcrun stapler staple "$DMG_PATH"

echo "→ Verifying Gatekeeper acceptance"
spctl -a -vvv --type exec "$APP_PATH"

echo ""
echo "Done."
echo "  App: $APP_PATH"
echo "  DMG: $DMG_PATH"
