#!/bin/bash
# Assembles and signs build/JevPaste.app (ADR 0001): release build, Info.plist written here, icon from
# Resources/AppIcon.png via sips + iconutil, menu-bar image Resources/StatusItem{,@2x}.png (all three derived by
# scripts/make-icon-images.py), signed with the jevpaste-dev Signing Identity.
#
# Never install an ad-hoc build: macOS Accessibility trust keys on the designated requirement, which is
# anchored to the jevpaste-dev certificate, so rebuilds keep the grant only when signed with it.
# `security find-identity -v` lists 0 identities because the self-signed certificate is not trusted
# (CSSMERR_TP_NOT_TRUSTED); codesign still signs with it.
set -euo pipefail

cd "$(dirname "$0")/.."
readonly APP_NAME="JevPaste"
readonly BUNDLE_IDENTIFIER="com.jevpaste.JevPaste"
readonly SIGNING_IDENTITY="jevpaste-dev"
readonly EXECUTABLE_PRODUCT="JevPasteApp"
readonly APP_PATH="build/$APP_NAME.app"
readonly ICON_SOURCE="Resources/AppIcon.png"
readonly KEYCHAIN_PATH="$HOME/Library/Keychains/jevpaste-signing.keychain-db"
readonly KEYCHAIN_PASSWORD_FILE="$HOME/.config/jevpaste/signing-keychain-password"

# Fail early and clearly instead of codesign's errSecInternalComponent on a locked keychain.
if [[ ! -f "$KEYCHAIN_PASSWORD_FILE" || ! -f "$KEYCHAIN_PATH" ]]; then
    echo "error: signing keychain or its password file is missing; run scripts/restore-signing-keychain.sh"
    exit 1
fi
if ! security unlock-keychain -p "$(<"$KEYCHAIN_PASSWORD_FILE")" "$KEYCHAIN_PATH"; then
    echo "error: cannot unlock $KEYCHAIN_PATH; run scripts/restore-signing-keychain.sh (see docs/signing.md)"
    exit 1
fi

swift build -c release --product "$EXECUTABLE_PRODUCT"
binary_directory=$(swift build -c release --show-bin-path)

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$binary_directory/$EXECUTABLE_PRODUCT" "$APP_PATH/Contents/MacOS/$APP_NAME"

iconset_directory=$(mktemp -d)/AppIcon.iconset
trap 'rm -rf "$(dirname "$iconset_directory")"' EXIT
mkdir -p "$iconset_directory"
for point_size in 16 32 128 256 512; do
    double_size=$((point_size * 2))
    sips -z "$point_size" "$point_size" "$ICON_SOURCE" \
        --out "$iconset_directory/icon_${point_size}x${point_size}.png" >/dev/null
    sips -z "$double_size" "$double_size" "$ICON_SOURCE" \
        --out "$iconset_directory/icon_${point_size}x${point_size}@2x.png" >/dev/null
done
iconutil --convert icns --output "$APP_PATH/Contents/Resources/AppIcon.icns" "$iconset_directory"
# Menu-bar template image; NSImage pairs the @2x file with the 1x one by name.
cp Resources/StatusItem.png Resources/StatusItem@2x.png "$APP_PATH/Contents/Resources/"

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_IDENTIFIER</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>JevPaste reads the focused text field to choose which part of your copied text belongs there, and pastes it for you.</string>
</dict>
</plist>
PLIST
plutil -lint "$APP_PATH/Contents/Info.plist" >/dev/null

codesign --force --sign "$SIGNING_IDENTITY" --identifier "$BUNDLE_IDENTIFIER" "$APP_PATH"
codesign --verify --strict "$APP_PATH"
codesign -d -r- "$APP_PATH" 2>&1 | grep '^designated'
echo "built: $APP_PATH"
