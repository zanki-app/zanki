#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=dist/Zanki.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Zanki "$APP/Contents/MacOS/Zanki"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force -s - "$APP"
echo "built: $APP"

if [ "${1:-}" = "install" ]; then
    osascript -e 'quit app "Zanki"' 2>/dev/null || true
    sleep 1
    rm -rf /Applications/Zanki.app
    cp -R "$APP" /Applications/
    open /Applications/Zanki.app
    echo "installed: /Applications/Zanki.app"
fi
