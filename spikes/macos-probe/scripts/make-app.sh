#!/bin/bash
# Builds the probe and assembles a minimal .app bundle by hand (no Xcode on this machine).
# TCC attributes Accessibility/Input Monitoring grants to a bundle identity, so a bare SwiftPM
# executable would otherwise be attributed to the launching terminal.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
APP="$ROOT/build/MacOSProbe.app"
BUNDLE_ID="com.jevpaste.macos-probe"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/MacOSProbe" "$APP/Contents/MacOS/MacOSProbe"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>MacOSProbe</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>jevpaste probe</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAccessibilityUsageDescription</key>
  <string>Throwaway probe: reads the focused text field to test jevpaste feasibility.</string>
</dict>
PLIST
echo '</plist>' >> "$APP/Contents/Info.plist"

# Ad-hoc signature. Each rebuild changes the cdhash, which is exactly the TCC re-prompt question
# we want to measure (see RESULTS.md).
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
codesign -dv --verbose=2 "$APP" 2>&1 | sed 's/^/  /'

echo "built: $APP"
echo "run:   PROBE_LOG=$ROOT/probe-transcript.log $APP/Contents/MacOS/MacOSProbe"
