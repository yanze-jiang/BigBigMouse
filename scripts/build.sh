#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Keep compiler caches inside the project; no third-party dependencies.
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_ROOT/.build/ModuleCache"
mkdir -p "$PROJECT_ROOT/.build/ModuleCache" "$PROJECT_ROOT/dist"

if [[ "${1:-}" == "--universal" ]]; then
    ARCHS=(arm64 x86_64)
elif [[ $# -eq 0 ]]; then
    ARCHS=("$(uname -m)")
else
    echo "Usage: bash scripts/build.sh [--universal]" >&2
    exit 1
fi

BINARIES=()
for ARCH in "${ARCHS[@]}"; do
    BUILD_ARGS=(--disable-sandbox --cache-path "$PROJECT_ROOT/.build/cache" -c release --arch "$ARCH")
    swift build "${BUILD_ARGS[@]}" --product BigBigMouse
    BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
    BINARIES+=("$BIN_DIR/BigBigMouse")
done
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
APP="$PROJECT_ROOT/dist/$VERSION/BigBigMouse.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/BigBigMouse"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp LICENSE "$APP/Contents/Resources/LICENSE"
swift scripts/make-icon.swift "$PROJECT_ROOT/.build/AppIcon.iconset"
iconutil -c icns "$PROJECT_ROOT/.build/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
plutil -lint "$APP/Contents/Info.plist"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
    codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"
echo "Built: $APP"
