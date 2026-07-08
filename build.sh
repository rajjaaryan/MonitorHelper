#!/bin/sh
# Build MonitorHelper.app from the Swift sources with a plain swiftc invocation
# (no Xcode project needed). Produces an ad-hoc-signed, LSUIElement menu-bar app.
set -e
cd "$(dirname "$0")"

APP="MonitorHelper.app"
BIN="MonitorHelper"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"

swiftc -O -parse-as-library \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/$BIN" \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Carbon \
    -framework CoreGraphics \
    -framework ServiceManagement

# Ad-hoc code signature so Gatekeeper is satisfied for local use.
codesign --force --deep --sign - "$APP"

echo "Built $APP"
echo "Run it:   open \"$APP\"    (or move it to /Applications first)"
