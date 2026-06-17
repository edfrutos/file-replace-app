#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Replacer"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/replacer-dmg.XXXXXX")"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build-macos-app.sh"

if [ ! -d "$APP_DIR" ]; then
    echo "No se encontro $APP_DIR" >&2
    exit 1
fi

ditto "$APP_DIR" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
find "$STAGING_DIR" -name .DS_Store -delete

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

hdiutil verify "$DMG_PATH"

echo "DMG creado en: $DMG_PATH"
