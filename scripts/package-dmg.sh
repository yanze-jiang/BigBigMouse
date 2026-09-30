#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
bash scripts/build.sh "$@"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
if [[ "${1:-}" == "--universal" ]]; then ARCH=universal; else ARCH="$(uname -m)"; fi
DMG="$PROJECT_ROOT/dist/BigBigMouse-$VERSION-$ARCH.dmg"
STAGING="$(mktemp -d "$PROJECT_ROOT/.build/dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto "$PROJECT_ROOT/dist/$VERSION/BigBigMouse.app" "$STAGING/BigBigMouse.app"
ln -s /Applications "$STAGING/Applications"
cp Resources/安装说明.txt "$STAGING/安装说明.txt"
cp Resources/授权故障排查.txt "$STAGING/授权故障排查.txt"
cp LICENSE "$STAGING/LICENSE"
hdiutil create -volname "BigBigMouse" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi
hdiutil verify "$DMG"
(cd "$PROJECT_ROOT/dist" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "Packaged: $DMG"
