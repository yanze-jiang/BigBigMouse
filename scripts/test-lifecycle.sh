#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_ROOT/.build/ModuleCache"
ARCH="$(uname -m)"
BUILD_ARGS=(--disable-sandbox --cache-path "$PROJECT_ROOT/.build/cache" -c release --arch "$ARCH")
swift build "${BUILD_ARGS[@]}" --target ScrollCore
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
SMOKE_DIR="$(mktemp -d "$PROJECT_ROOT/.build/lifecycle-smoke.XXXXXX")"
trap 'rm -rf "$SMOKE_DIR"' EXIT
SMOKE_APP="$SMOKE_DIR/LifecycleSmoke.app"
mkdir -p "$SMOKE_APP/Contents/MacOS"
touch "$SMOKE_DIR/events.log"
cat > "$SMOKE_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>app.bigbigmouse.lifecycle-smoke.$(basename "$SMOKE_DIR")</string>
<key>CFBundleExecutable</key><string>LifecycleSmoke</string>
<key>CFBundleName</key><string>BigBigMouse Lifecycle Test</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
xcrun swiftc -swift-version 6 -parse-as-library -target "$ARCH-apple-macosx13.0" \
  -I "$BIN_DIR/Modules" Sources/BigBigMouse/ApplicationLifecycle.swift \
  Tests/LifecycleSmoke/Smoke.swift "$BIN_DIR/ScrollCore.build/"*.swift.o \
  -o "$SMOKE_APP/Contents/MacOS/LifecycleSmoke"
codesign --force --sign - "$SMOKE_APP"
python3 - "$SMOKE_APP" "$SMOKE_DIR/events.log" <<'PY'
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

app, log = Path(sys.argv[1]), Path(sys.argv[2])
executable = str(app / 'Contents/MacOS/LifecycleSmoke')
try:
    subprocess.run(['open', '-n', str(app), '--args', '--allow-development-location'], check=True, timeout=10)
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        rows = [line.split() for line in log.read_text().splitlines() if len(line.split()) == 3]
        if sum(row[2] == 'terminated' for row in rows) == 2:
            break
        time.sleep(0.1)
    else:
        raise RuntimeError('Relaunch timed out: ' + log.read_text())
    for role in ['parent', 'replacement']:
        events = [row[2] for row in rows if row[1] == role]
        assert events == ['launched', 'ready', 'terminated'], (role, events)
    assert len({row[0] for row in rows}) == 2, rows
    parent_exit = next(i for i, row in enumerate(rows) if row[1:] == ['parent', 'terminated'])
    child_ready = next(i for i, row in enumerate(rows) if row[1:] == ['replacement', 'ready'])
    assert parent_exit < child_ready, rows
    print(log.read_text(), end='')
    print('PASS relaunch: previous process exited before replacement became ready')
finally:
    # Only stop test processes whose exact executable path matches this run.
    for value in {line.split()[0] for line in log.read_text().splitlines() if line.split()}:
        if not value.isdecimal():
            continue
        current = subprocess.run(['ps', '-p', value, '-o', 'comm='], capture_output=True, text=True).stdout.strip()
        if current == executable:
            try:
                os.kill(int(value), signal.SIGTERM)
            except ProcessLookupError:
                pass
PY
