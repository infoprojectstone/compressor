#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Compressor.app"
TEMP_ROOT="$(mktemp -d /tmp/compresor-build.XXXXXX)"
trap 'rm -rf "$TEMP_ROOT"' EXIT
export CLANG_MODULE_CACHE_PATH="$TEMP_ROOT/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$TEMP_ROOT/swift-module-cache"

cd "$PROJECT_DIR"
swift build -c release --disable-sandbox --scratch-path "$TEMP_ROOT/swift-build"
TEMP_APP="$TEMP_ROOT/Compressor.app"
mkdir -p "$TEMP_APP/Contents/MacOS" "$TEMP_APP/Contents/Resources" "$TEMP_ROOT/AppIcon.iconset"
cp "$TEMP_ROOT/swift-build/release/CompresorUnificado" "$TEMP_APP/Contents/MacOS/CompresorUnificado"
cp "$PROJECT_DIR/Resources/Info.plist" "$TEMP_APP/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/AppIconSource.png" "$TEMP_APP/Contents/Resources/AppIconSource.png"
for SIZE in 16 32 128 256 512; do
  sips -s format png -z "$SIZE" "$SIZE" "$PROJECT_DIR/Resources/AppIconSource.png" --out "$TEMP_ROOT/AppIcon.iconset/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE_SIZE=$((SIZE * 2))
  sips -s format png -z "$DOUBLE_SIZE" "$DOUBLE_SIZE" "$PROJECT_DIR/Resources/AppIconSource.png" --out "$TEMP_ROOT/AppIcon.iconset/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$TEMP_ROOT/AppIcon.iconset" -o "$TEMP_APP/Contents/Resources/AppIcon.icns"
find "$TEMP_APP" -name ".DS_Store" -delete 2>/dev/null || true
xattr -cr "$TEMP_APP"
codesign --force --deep --sign - "$TEMP_APP"
codesign --verify --deep --strict "$TEMP_APP"

mkdir -p "$BUILD_DIR"
rm -rf "$APP_DIR" "$BUILD_DIR/Compressor-1.2.zip"
ditto "$TEMP_APP" "$APP_DIR"
xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
codesign --verify --deep --strict "$APP_DIR"

export COPYFILE_DISABLE=1
(cd "$BUILD_DIR" && zip -qry -X "Compressor-1.2.zip" "Compressor.app")

echo "Aplicación creada en: $APP_DIR"
echo "Zip empaquetado en: $BUILD_DIR/Compressor-1.2.zip"
