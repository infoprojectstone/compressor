#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Compressor.app"
TEMP_ROOT="$(mktemp -d /tmp/compresor-build.XXXXXX)"
trap 'rm -rf "$TEMP_ROOT"' EXIT
export CLANG_MODULE_CACHE_PATH="$TEMP_ROOT/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$TEMP_ROOT/swift-module-cache"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
SDK_PATH="$(xcrun --show-sdk-path)"

cd "$PROJECT_DIR"
SCRATCH="$TEMP_ROOT/swift-arm64"
swift build -c release --disable-sandbox --product CompresorUnificado \
  --triple "arm64-apple-macosx13.0" --sdk "$SDK_PATH" \
  --scratch-path "$SCRATCH" -debug-info-format none
BIN_PATH="$(swift build -c release --disable-sandbox --product CompresorUnificado \
  --triple "arm64-apple-macosx13.0" --sdk "$SDK_PATH" \
  --scratch-path "$SCRATCH" --show-bin-path)"

TEMP_APP="$TEMP_ROOT/Compressor.app"
mkdir -p "$TEMP_APP/Contents/MacOS" "$TEMP_APP/Contents/Resources" "$TEMP_ROOT/AppIcon.iconset"
cp "$BIN_PATH/CompresorUnificado" "$TEMP_APP/Contents/MacOS/CompresorUnificado"
cp "$PROJECT_DIR/Resources/Info.plist" "$TEMP_APP/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/AppIconSource.png" "$TEMP_APP/Contents/Resources/AppIconSource.png"
if [ -d "$PROJECT_DIR/Resources/QuickAction/Comprimir con Compresor.workflow" ]; then
  cp -R "$PROJECT_DIR/Resources/QuickAction/Comprimir con Compresor.workflow" "$TEMP_APP/Contents/Resources/"
fi
for SIZE in 16 32 128 256 512; do
  sips -s format png -z "$SIZE" "$SIZE" "$PROJECT_DIR/Resources/AppIconSource.png" --out "$TEMP_ROOT/AppIcon.iconset/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE_SIZE=$((SIZE * 2))
  sips -s format png -z "$DOUBLE_SIZE" "$DOUBLE_SIZE" "$PROJECT_DIR/Resources/AppIconSource.png" --out "$TEMP_ROOT/AppIcon.iconset/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$TEMP_ROOT/AppIcon.iconset" -o "$TEMP_APP/Contents/Resources/AppIcon.icns"

mkdir -p "$BUILD_DIR"
rm -rf "$APP_DIR" "$BUILD_DIR/Compressor-1.2.zip"
ditto "$TEMP_APP" "$APP_DIR"
xattr -cr "$APP_DIR"
if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --force --deep --sign - "$APP_DIR"
else
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
fi
codesign --verify --deep --strict "$APP_DIR"
ditto -c -k --keepParent "$APP_DIR" "$BUILD_DIR/Compressor-1.2.zip"

if [ -d "$PROJECT_DIR/Resources/QuickAction/Comprimir con Compresor.workflow" ]; then
  rm -rf "$BUILD_DIR/Comprimir con Compresor.workflow"
  cp -R "$PROJECT_DIR/Resources/QuickAction/Comprimir con Compresor.workflow" "$BUILD_DIR/Comprimir con Compresor.workflow"
fi

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR" 2>/dev/null || true
/System/Library/CoreServices/pbs -flush 2>/dev/null || true

echo "Aplicación Apple Silicon creada en: $APP_DIR"
echo "Zip empaquetado en: $BUILD_DIR/Compressor-1.2.zip"
