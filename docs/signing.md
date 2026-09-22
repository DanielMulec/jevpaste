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

## If the key or certificate is lost

Generating a new certificate changes the certificate root and therefore the designated requirement. That is
a migration event: the existing Accessibility grant no longer matches and must be granted again for the new
identity. Recreate with the `openssl req` recipe and config from the signing-identity spike
(`spikes/macos-probe/scripts/codesign-cert.cnf` on branch `spike/signing-identity`), store the new key and
certificate in `~/.config/jevpaste/signing/`, run the recovery script, and update the root hash in this file.
