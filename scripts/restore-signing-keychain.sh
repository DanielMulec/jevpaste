#!/bin/bash
# Rebuilds the dedicated signing keychain from the jevpaste-dev key and certificate kept outside the repo
# in ~/.config/jevpaste/signing/. Same identity (same certificate root), so the Accessibility grant survives.
# Recipe and background: docs/signing.md. Prints no secrets.
#
# Exit codes: 0 = identity usable for codesign; 1 = key material missing or a security step failed.
set -euo pipefail

readonly CONFIGURATION_DIRECTORY="$HOME/.config/jevpaste"
readonly SIGNING_DIRECTORY="$CONFIGURATION_DIRECTORY/signing"
readonly PASSWORD_FILE="$CONFIGURATION_DIRECTORY/signing-keychain-password"
readonly KEYCHAIN_PATH="$HOME/Library/Keychains/jevpaste-signing.keychain-db"
readonly CERTIFICATE_FILE="$SIGNING_DIRECTORY/jevpaste-dev.cert.pem"
readonly KEY_FILE="$SIGNING_DIRECTORY/jevpaste-dev.key.pem"

for required_file in "$CERTIFICATE_FILE" "$KEY_FILE"; do
    if [[ ! -f "$required_file" ]]; then
        echo "error: missing $required_file — the identity cannot be restored without it (see docs/signing.md)"
        exit 1
    fi
done

if [[ ! -f "$PASSWORD_FILE" ]]; then
    (umask 077 && openssl rand -hex 32 >"$PASSWORD_FILE")
fi
chmod 600 "$PASSWORD_FILE"
keychain_password=$(<"$PASSWORD_FILE")

work_directory=$(mktemp -d)
trap 'rm -rf "$work_directory"' EXIT
bundle_password=$(openssl rand -hex 16)
openssl pkcs12 -export -legacy -inkey "$KEY_FILE" -in "$CERTIFICATE_FILE" -name jevpaste-dev \
    -out "$work_directory/jevpaste-dev.p12" -passout "pass:$bundle_password"

if [[ -f "$KEYCHAIN_PATH" ]]; then
    security delete-keychain "$KEYCHAIN_PATH"
fi
security create-keychain -p "$keychain_password" "$KEYCHAIN_PATH"
security set-keychain-settings "$KEYCHAIN_PATH" # no -lut: locks only on explicit lock or reboot
security unlock-keychain -p "$keychain_password" "$KEYCHAIN_PATH"
security import "$work_directory/jevpaste-dev.p12" -k "$KEYCHAIN_PATH" -P "$bundle_password" \
    -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$KEYCHAIN_PATH" \
    >/dev/null

current_keychains=$(security list-keychains -d user | tr -d '"' | xargs)
if [[ " $current_keychains " != *" $KEYCHAIN_PATH "* ]]; then
    # shellcheck disable=SC2086 # word splitting of the existing list is intended
    security list-keychains -d user -s $current_keychains "$KEYCHAIN_PATH"
fi

security find-identity -p codesigning "$KEYCHAIN_PATH" | grep jevpaste-dev
