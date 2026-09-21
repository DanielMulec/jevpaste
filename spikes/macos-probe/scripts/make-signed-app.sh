#!/bin/bash
# Ticket #13: same bundle assembly as make-app.sh, but signed with a real (self-signed)
# code-signing identity instead of ad-hoc, and under a SEPARATE bundle id so the existing
# ad-hoc grant row for com.jevpaste.macos-probe stays untouched.
#
#   SIGN_IDENTITY=jevpaste-dev scripts/make-signed-app.sh
#
# TCC keys a grant on (path, bundle id, designated requirement). With an identity the DR is
# "identifier ... and certificate root = H\"...\"" — anchored to the cert, not to the cdhash.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
APP="$ROOT/build/SigningProbe.app"
BUNDLE_ID="com.jevpaste.signing-probe"
SIGN_IDENTITY="${SIGN_IDENTITY:-jevpaste-dev}"

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
  <key>CFBundleName</key><string>jevpaste signing probe</string>
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

codesign --force --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP"
codesign -dv --verbose=2 "$APP" 2>&1 | sed 's/^/  /'
echo "  designated requirement:"
codesign -d -r- "$APP" 2>&1 | grep '^designated' | sed 's/^/  /'

echo "built: $APP"
echo "install: cp -R $APP ~/Desktop/  (keep the path constant across rebuilds)"
