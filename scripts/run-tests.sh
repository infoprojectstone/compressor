#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
TEMP_ROOT="$(mktemp -d /tmp/compresor-verify.XXXXXX)"
trap 'rm -rf "$TEMP_ROOT"' EXIT

export CLANG_MODULE_CACHE_PATH="$TEMP_ROOT/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$TEMP_ROOT/swift-module-cache"

echo "Iniciando suite de pruebas automatizadas..."
cd "$PROJECT_DIR"
swift run --disable-sandbox --scratch-path "$TEMP_ROOT/swift-build" VerifyCompression
