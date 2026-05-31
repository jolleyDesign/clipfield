#!/usr/bin/env bash
#
# Builds Clipfield.app (release), signs it with a Developer ID + hardened
# runtime, packages it into a DMG, then notarizes and staples it — producing a
# DMG that installs with a clean double-click on any Mac (no Gatekeeper warning).
#
# Requirements (one-time setup):
#   - A "Developer ID Application" identity in your keychain.
#   - A stored notarytool credential profile. Create it once with:
#       xcrun notarytool store-credentials "clipfield-notary" \
#         --apple-id you@example.com --team-id 2S2W7724TC --password <app-specific-pw>
#
# Overridable via env vars:
#   SIGN_IDENTITY   signing identity (default: the Developer ID below)
#   NOTARY_PROFILE  notarytool keychain profile name (default: clipfield-notary)
#   SKIP_NOTARIZE=1 build + sign + package only; skip notarize/staple (local test)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/Clipfield.app"
DMG="$ROOT/Clipfield.dmg"
STAGING="$ROOT/.dmg-staging"

SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: David Jolley (2S2W7724TC)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-clipfield-notary}"

# Preflight: confirm the notary credential profile exists before a long build,
# unless the caller explicitly opted out of notarization.
if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
    if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        cat >&2 <<EOF
ERROR: notarytool profile "$NOTARY_PROFILE" not found.

Create it once (interactive — needs an app-specific password from
appleid.apple.com), then re-run this script:

  xcrun notarytool store-credentials "$NOTARY_PROFILE" \\
    --apple-id you@example.com --team-id 2S2W7724TC --password <app-specific-pw>

Or run with SKIP_NOTARIZE=1 to produce a signed-but-not-notarized DMG.
EOF
        exit 1
    fi
fi

echo "==> Building + signing release app ($SIGN_IDENTITY)"
SIGN_IDENTITY="$SIGN_IDENTITY" "$ROOT/build_app.sh" release

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

# Sign the DMG itself (not just the app inside). Without this, `spctl` assesses
# the DMG as "no usable signature" even after notarization, and the wrapper
# carries no Developer ID origin. Signing must happen before notarization.
echo "==> Signing DMG"
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
    echo "==> SKIP_NOTARIZE=1 — signed but NOT notarized: $DMG"
    echo "    Recipients will hit a Gatekeeper prompt on first launch."
    exit 0
fi

echo "==> Notarizing (profile: $NOTARY_PROFILE) — this can take a few minutes"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling ticket to DMG"
xcrun stapler staple "$DMG"

echo "==> Verifying Gatekeeper acceptance"
spctl -a -t open --context context:primary-signature -vv "$DMG"

echo "==> Done: $DMG (signed + notarized + stapled)"
