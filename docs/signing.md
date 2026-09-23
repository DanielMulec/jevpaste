# Signing — the `jevpaste-dev` Signing Identity

Every installed build is signed with the self-signed identity `jevpaste-dev`
(certificate root `H"64cb89c8c7efa62842bdd1aa76a9faf321704f72"`). macOS Accessibility trust keys on the
designated requirement, which is anchored to that certificate, so rebuilds keep the grant. Background:
[Establish a signing identity that keeps the Accessibility grant across rebuilds](https://github.com/DanielMulec/jevpaste/issues/13)
and [ADR 0001](adr/0001-clt-only-swiftpm-app-with-hand-assembled-signed-bundle.md). Never install an ad-hoc build.

Designated requirement of the installed app:

```
identifier "com.jevpaste.JevPaste" and certificate root = H"64cb89c8c7efa62842bdd1aa76a9faf321704f72"
```

## Where the pieces live (all outside the repository, never committed)

| path | what | mode |
|---|---|---|
| `~/.config/jevpaste/signing/jevpaste-dev.cert.pem` | the self-signed code-signing certificate | 600 |
| `~/.config/jevpaste/signing/jevpaste-dev.key.pem` | its private key (unencrypted PEM) | 600, directory 700 |
| `~/.config/jevpaste/signing-keychain-password` | random password of the dedicated keychain | 600 |
| `~/Library/Keychains/jevpaste-signing.keychain-db` | dedicated keychain holding the identity, on the user search list | — |

The keychain has no auto-lock timeout; it locks only on an explicit lock or at reboot. `scripts/make-app.sh`
unlocks it with the stored password before `codesign`, so a locked keychain never blocks a build. If the
password file or keychain is missing, or unlocking fails, it stops with a message pointing here instead of
codesign's `errSecInternalComponent`.

`security find-identity -v` lists 0 valid identities because the certificate is self-signed and untrusted
(`CSSMERR_TP_NOT_TRUSTED`). That is expected; `codesign --sign jevpaste-dev` signs with it anyway.

## Recovery: from key and certificate back to a working keychain

```bash
scripts/restore-signing-keychain.sh
```

It exports a temporary `.p12` from the key and certificate, deletes and recreates the dedicated keychain
(reusing the stored password, or generating one if the file is missing), sets no auto-lock timeout, imports
the identity for `codesign` and `security`, runs `security set-key-partition-list` (prevents the keychain
access dialog), adds the keychain to the user search list, and prints the identity line. Expected output:

```
1 identity imported.
  1) 64CB89C8C7EFA62842BDD1AA76A9FAF321704F72 "jevpaste-dev" (CSSMERR_TP_NOT_TRUSTED)
```

Same certificate, same designated requirement: the Accessibility grant is unaffected.

## Rotating the Signing Identity (a migration event)

Rotation = a **new** certificate, hence a new certificate root and a new designated requirement. The existing
Accessibility grant (its TCC row stores the old requirement) stops matching: `AXIsProcessTrusted()` turns false
while System Settings may still show JevPaste as on. Restoring the *same* key and certificate (above) is not a
rotation and needs none of this.

Rotate only when the key is lost or compromised, or before the certificate expires
(`openssl x509 -enddate -noout -in ~/.config/jevpaste/signing/jevpaste-dev.cert.pem`; today `notAfter=Sep 18
2036`). Never to fix a missing grant — a mismatched row heals by itself once the build is signed with the
identity again (row D of the signing-identity ticket linked at the top).

Steps (Daniel present for step 6; the installed app is shared, so announce it):

1. Quit JevPaste (status-item menu → Quit).
2. Keep the old material until the new grant is proven:
   `mkdir -m 700 ~/.config/jevpaste/signing/retired-$(date +%Y%m%d)` and move both `.pem` files into it.
3. Create the new key and certificate with the spike's config (`CN = jevpaste-dev` keeps the name `codesign`
   and `scripts/make-app.sh` use):
   ```bash
   git show origin/spike/signing-identity:spikes/macos-probe/scripts/codesign-cert.cnf > /tmp/codesign-cert.cnf
   (umask 077 && openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config /tmp/codesign-cert.cnf \
       -keyout ~/.config/jevpaste/signing/jevpaste-dev.key.pem -out ~/.config/jevpaste/signing/jevpaste-dev.cert.pem)
   rm /tmp/codesign-cert.cnf
   ```
4. `scripts/restore-signing-keychain.sh` — replaces the dedicated keychain; note the printed SHA-1: it is the new
   certificate root (lower-case it for the requirement).
5. `make install`, then check the new requirement and the signature:
   `codesign -d -r- ~/Applications/JevPaste.app` (shows `certificate root = H"<new sha-1>"`) and
   `codesign --verify --strict --verbose=2 ~/Applications/JevPaste.app`.
6. TCC migration — drop the stale row and grant afresh:
   `tccutil reset Accessibility com.jevpaste.JevPaste`, `open ~/Applications/JevPaste.app`. The launch grant check
   shows "No Accessibility access — …" (log `grant check at launch trusted=false`). In System Settings ›
   Privacy & Security › Accessibility, add `~/Applications/JevPaste.app` with **+** (JevPaste never prompts, so it
   is not listed by itself) and turn it on. Quit and relaunch JevPaste.
7. Verify: no notice at launch; `log show --last 5m --predicate 'subsystem == "jevpaste"' --style compact` shows
   `grant check at launch trusted=true`; one ⌘⇧V Smart Paste into a Chrome text field shows "Pasted".
8. Replace the root hash in this file (top, designated requirement, expected script output), commit, then delete
   the `retired-…` directory. Rollback before that point: move the retired files back, run step 4 and 5 again
   (the reset row must then be granted again as in step 6).

