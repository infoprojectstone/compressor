#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILD_DIR="$PROJECT_DIR/build"
APP_PATH="$BUILD_DIR/Compressor.app"
DMG_PATH="$BUILD_DIR/Compressor-1.2.dmg"
STAGING_DIR="$BUILD_DIR/dmg_staging"

if [ ! -d "$APP_PATH" ]; then
    echo "Compressor.app no encontrado en $BUILD_DIR. Construyendo..."
    "$PROJECT_DIR/scripts/build-app.sh"
fi

echo "Preparando imagen de disco DMG..."
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

# Copiar Compressor.app
ditto "$APP_PATH" "$STAGING_DIR/Compressor.app"

# Crear enlace simbólico a /Applications
ln -s /Applications "$STAGING_DIR/Applications"

# Crear DMG
echo "Generando archivo DMG..."
hdiutil create -volname "Compressor" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

# Firmar ad-hoc el DMG
codesign --force --sign - "$DMG_PATH"

# Limpieza
rm -rf "$STAGING_DIR"

echo "¡DMG creado con éxito!"
echo "Ubicación: $DMG_PATH"
ls -lh "$DMG_PATH"
