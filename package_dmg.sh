#!/usr/bin/env bash
#
# Builds Clipfield.app (release) and packages it into a distributable DMG.
#
# This produces an *unsigned / ad-hoc* DMG suitable for local testing. To ship it
# to other Macs without Gatekeeper warnings you must sign and notarize it with
# your Apple Developer ID — see the steps printed at the end.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/Clipfield.app"
DMG="$ROOT/Clipfield.dmg"
STAGING="$ROOT/.dmg-staging"

echo "==> Building release app"
"$ROOT/build_app.sh" release

echo "==> Staging DMG contents"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"   # drag-to-install target

echo "==> Creating DMG"
hdiutil create \
    -volname "Clipfield" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG"

rm -rf "$STAGING"
echo "==> Done: $DMG"

cat <<'NOTES'

------------------------------------------------------------------------
To distribute to other Macs (requires an Apple Developer account):

  1. Sign the app with your Developer ID + hardened runtime:
       codesign --force --deep --options runtime \
         --sign "Developer ID Application: Your Name (TEAMID)" Clipfield.app

  2. Re-create the DMG (re-run this script after replacing the ad-hoc sign
     in build_app.sh with the Developer ID identity), then notarize it:
       xcrun notarytool submit Clipfield.dmg \
         --apple-id you@example.com --team-id TEAMID --password <app-specific-pw> \
         --wait

  3. Staple the ticket so it validates offline:
       xcrun stapler staple Clipfield.dmg

Without steps 1–3, recipients must right-click → Open (or run
`xattr -dr com.apple.quarantine Clipfield.app`) the first time.
------------------------------------------------------------------------
NOTES
