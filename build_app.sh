#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/FloatingTimer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp .build/release/FloatingTimer "$APP/Contents/MacOS/FloatingTimer"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
chmod +x "$APP/Contents/MacOS/FloatingTimer"
touch "$APP"

echo "Built $APP"
echo "Drag it into /Applications, or launch it directly with: open \"$APP\""
