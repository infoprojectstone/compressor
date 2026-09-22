#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/Compressor.app"
DMG_PATH="$BUILD_DIR/Compressor-1.2.dmg"
STAGING_DIR="$(mktemp -d /tmp/compresor-dmg.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

# Always rebuild so the disk image cannot silently contain an old app.
"$PROJECT_DIR/scripts/build-app.sh"
ditto "$APP_PATH" "$STAGING_DIR/Compressor.app"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "Compressor" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"
hdiutil verify "$DMG_PATH"

if [ -n "${NOTARY_PROFILE:-}" ]; then
  if [ "${SIGN_IDENTITY:--}" = "-" ]; then
    echo "Error: la notarización requiere SIGN_IDENTITY con Developer ID Application." >&2
    exit 1
  fi
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
else
  echo "Aviso: DMG sin notarizar. Configura SIGN_IDENTITY y NOTARY_PROFILE para distribución pública."
fi

echo "DMG creado en: $DMG_PATH"
ls -lh "$DMG_PATH"
