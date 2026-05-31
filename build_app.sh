#!/usr/bin/env bash
#
# Builds the Clipfield SwiftPM executable and assembles a proper .app bundle,
# then ad-hoc code-signs it. Ad-hoc signing keeps the Accessibility permission
# grant stable across rebuilds (the grant is keyed to the code signature).
#
# Usage:
#   ./build_app.sh            # release build
#   ./build_app.sh debug      # debug build
#
set -euo pipefail

# SwiftData / SwiftUI rely on closed-source macro plugins (SwiftDataMacros,
# PreviewsMacros) that ship only inside full Xcode — the standalone Command Line
# Tools toolchain lacks them. Point the build at Xcode's developer dir so the
# macro plugins resolve. Override by exporting DEVELOPER_DIR yourself.
if [[ -z "${DEVELOPER_DIR:-}" ]] && [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

CONFIG="${1:-release}"
APP_NAME="Clipfield"
BUNDLE_NAME="Clipfield.app"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/.build/$CONFIG"
APP="$ROOT/$BUNDLE_NAME"

echo "==> swift build ($CONFIG)"
swift build -c "$CONFIG"

echo "==> Assembling $BUNDLE_NAME"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Copy any SwiftPM resource bundles (e.g. KeyboardShortcuts) next to the binary
# and into Resources so Bundle.module resolution works from inside the .app.
shopt -s nullglob
for bundle in "$BUILD_DIR"/*.bundle; do
    cp -R "$bundle" "$APP/Contents/Resources/"
    cp -R "$bundle" "$APP/Contents/MacOS/"
done
shopt -u nullglob

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP"

echo "==> Done: $APP"
