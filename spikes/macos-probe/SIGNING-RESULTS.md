# Signing identity vs. the Accessibility grant — results (ticket #13)

**Status: INCOMPLETE — parked at step 4, waiting for the one human click.**
Steps 1–3 are done and reproducible; the verdict (steps 5–7) needs the Accessibility toggle.

Question: does an app signed with a **self-signed code-signing identity** keep its Accessibility
grant (`AXIsProcessTrusted() == true`) across a rebuild + re-sign with the *same* identity?
Builds on `RESULTS.md` §2: with ad-hoc signing the grant is bound to the cdhash and a rebuild
silently orphans it (Settings shows ON, `AXIsProcessTrusted()` false).

Environment: macOS 26.6.2 (25G83), Apple Silicon, CLT-only Swift 6.3.3, no Xcode.
Bundle under test: `com.jevpaste.signing-probe` at `~/Desktop/SigningProbe.app` (new bundle id
and new path, so the ad-hoc grant row of `com.jevpaste.macos-probe` is untouched —
`~/Desktop/MacOSProbe.app` was not modified, verified after every step).
Transcript: `signing-transcript.log` (gitignored, not committed). No network, no Jev, no
`tccutil`, no TCC.db edits, synthetic content only.

---

## 1. What is already established (the mechanism)

The designated requirement changes shape with the signing method. That is the entire hypothesis:

| signing | designated requirement |
|---|---|
| ad-hoc (`--sign -`) | `identifier "…" and cdhash H"…"` — pinned to the *bytes* |
| identity (`--sign jevpaste-dev`) | `identifier "com.jevpaste.signing-probe" and certificate root = H"64cb89c8c7efa62842bdd1aa76a9faf321704f72"` — pinned to the *cert* |

Measured on the actual bundle (`codesign -d -r- ~/Desktop/SigningProbe.app`). No cdhash appears
in the identity-signed requirement, so a rebuild *should* still satisfy it. Whether TCC actually
re-evaluates the stored requirement rather than a stored cdhash is exactly what steps 5–7 test,
and that is **not yet measured**.

## 2. Step 1 — the identity (done, no GUI prompt)

**Deviation, approved by the supervisor: not the login keychain.** A login-keychain import needs
`security set-key-partition-list -k <login password>` to stay prompt-free; without it `codesign`
pops a keychain-ACL dialog. The login password was not available and Daniel was asleep, so the
identity went into a dedicated throwaway keychain added to the user search list. The login
keychain remains the default and was never written to. Functionally identical for signing — TCC
only ever sees the signature on disk, never the keychain.

```bash
mkdir -p /tmp/jevpaste-signing && cd /tmp/jevpaste-signing
cat > openssl-codesign.cnf <<'EOF'
[ req ]
default_md = sha256
distinguished_name = dn
x509_extensions = v3_codesign
prompt = no
[ dn ]
CN = jevpaste-dev
O  = jevpaste spike (throwaway)
C  = DE
[ v3_codesign ]
basicConstraints     = critical,CA:FALSE
keyUsage             = critical,digitalSignature
extendedKeyUsage     = critical,codeSigning
subjectKeyIdentifier = hash
EOF
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config openssl-codesign.cnf -keyout jevpaste-dev.key.pem -out jevpaste-dev.cert.pem
openssl pkcs12 -export -legacy -inkey jevpaste-dev.key.pem -in jevpaste-dev.cert.pem \
  -name jevpaste-dev -out jevpaste-dev.p12 -passout pass:"$P12PASS"

security create-keychain -p "$KCPASS" jevpaste-signing.keychain-db
security set-keychain-settings -lut 21600 jevpaste-signing.keychain-db
security unlock-keychain -p "$KCPASS" jevpaste-signing.keychain-db
security import jevpaste-dev.p12 -k jevpaste-signing.keychain-db -P "$P12PASS" \
  -T /usr/bin/codesign -T /usr/bin/security          # → "1 identity imported."
security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
  -k "$KCPASS" jevpaste-signing.keychain-db          # the step that prevents the GUI dialog
security list-keychains -d user -s $(security list-keychains -d user | tr -d '"' | xargs) \
  "$HOME/Library/Keychains/jevpaste-signing.keychain-db"
```

`$KCPASS` / `$P12PASS` are throwaway values for a spike keychain holding a spike key; they are
not recorded here and the private key is never printed or committed (it lives only in
`/tmp/jevpaste-signing/`, outside the repo).

**Rollback (removes identity, keychain and key material; nothing else is affected):**

```bash
security list-keychains -d user -s "$HOME/Library/Keychains/login.keychain-db"
security delete-keychain jevpaste-signing.keychain-db
rm -rf /tmp/jevpaste-signing
```

Observations:

- No GUI dialog at any point — not on import, not on signing.
- `security find-identity -v -p codesigning` → **0 valid identities**;
  `security find-identity -p codesigning` → `1) 64CB89C8… "jevpaste-dev" (CSSMERR_TP_NOT_TRUSTED)`.
  The cert is a self-signed root with no trust settings, so it fails *trust evaluation*.
  **`codesign` signs with it anyway** (rc=0, silent), and `codesign --verify` reports
  `valid on disk` + `satisfies its Designated Requirement`. So "not trusted" is not a blocker
  for this experiment; adding trust settings (`security add-trusted-cert`) would have required an
  admin/GUI authorisation and was deliberately skipped.
- Cert SHA-1 (= the requirement anchor): `64cb89c8c7efa62842bdd1aa76a9faf321704f72`.

## 3. Step 2 — build + sign (done)

`scripts/make-signed-app.sh` — a small copy of `make-app.sh`: `SIGN_IDENTITY` env var
(default `jevpaste-dev`), bundle id `com.jevpaste.signing-probe`, output
`build/SigningProbe.app`, prints cdhash and designated requirement after signing. Plain
`--sign` (no `--options runtime`; no notarization involved).

```bash
cd ~/.pi/worktrees/jevpaste/signing/spikes/macos-probe
SIGN_IDENTITY=jevpaste-dev ./scripts/make-signed-app.sh
rm -rf ~/Desktop/SigningProbe.app && ditto build/SigningProbe.app ~/Desktop/SigningProbe.app
codesign -dv --verbose=4 ~/Desktop/SigningProbe.app     # Authority / CDHash
codesign -d -r- ~/Desktop/SigningProbe.app              # designated requirement
```

Baseline (build 0): `Authority=jevpaste-dev`, `TeamIdentifier=not set`,
`CDHash=8b1475b32789d0b987c406e6fdd2690220edb967`,
executable sha256 `dea77c144f9193a33ad11de7d23c579cdb29467c077d70e13bb4e5cfaef12316`.
The path `~/Desktop/SigningProbe.app` is held constant across all rebuilds (TCC keys on path +
requirement).

## 4. Step 3 — launch, baseline permission state (done)

```bash
rm -f /tmp/jevsign.in && mkfifo /tmp/jevsign.in && (sleep 100000 > /tmp/jevsign.in &)
open -n ~/Desktop/SigningProbe.app --args --fifo /tmp/jevsign.in --log "$PWD/signing-transcript.log"
echo perm   > /tmp/jevsign.in
echo ask-ax > /tmp/jevsign.in      # triggers the prompt → creates the Settings row
```

Transcript facts: `ENV bundleID=com.jevpaste.signing-probe bundled=true`,
`bundlePath=/Users/danielmulec/Desktop/SigningProbe.app`, pid 34801;
`PERM AXIsProcessTrusted=false`, `CGPreflightPostEventAccess=false`,
`CGPreflightListenEventAccess=false`; `PASTEBOARD accessBehavior=alwaysAllow raw=2` (again no
pasteboard privacy alert, now on an identity-signed bundle too).
`ask-ax` → `AXIsProcessTrustedWithOptions=false`, which is the documented normal result.
The probe was then quit cleanly (`quit` → `bye`); the bundle stays installed on the Desktop.

*Not verified:* that the row is visibly present in System Settings → Privacy & Security →
Bedienungshilfen. It cannot be read programmatically (TCC.db is unreadable without Full Disk
Access — a read was attempted once and denied, nothing was written), and nobody was awake to
look. Confirm this visually at resume time.

## 5. Results table (only the baseline row is measured)

| build | source | cdhash | requirement anchor | `AXIsProcessTrusted` after relaunch |
|---|---|---|---|---|
| 0 baseline | original | `8b1475b32789d0b987c406e6fdd2690220edb967` | certificate root `64cb89c8…` | `false` (not granted yet) |
| — after grant | original | `8b1475b3…` | certificate root `64cb89c8…` | **pending** |
| A rebuild | identical | pending | pending | **pending** |
| B rebuild | changed | pending | pending | **pending** |
| C control | ad-hoc re-sign | pending | `cdhash H"…"` (expected) | **pending** |

**Verdict: none yet.** Nothing here supports or refutes the hypothesis; only the mechanism
(§1) is established. Do not quote §1 as a result.

## 6. Resume — one human click, then finish

**Human step (the only one):** System Settings → Privacy & Security → Bedienungshilfen →
switch **"jevpaste signing probe"** (`~/Desktop/SigningProbe.app`) **ON**. Fresh row, so no
remove/re-add is needed. If the row is missing, relaunch the app and run `ask-ax` again.

Then, from `~/.pi/worktrees/jevpaste/signing/spikes/macos-probe` on branch
`spike/signing-identity` (the keychain and identity are already in place; re-run §2 rollback only
when the spike is finished):

```bash
# helper used throughout
launch() { rm -f /tmp/jevsign.in && mkfifo /tmp/jevsign.in && (sleep 100000 > /tmp/jevsign.in &)
           open -n ~/Desktop/SigningProbe.app --args --fifo /tmp/jevsign.in \
                --log "$PWD/signing-transcript.log"; sleep 3; }
cd ~/.pi/worktrees/jevpaste/signing/spikes/macos-probe

# step 4 verify — expect AXIsProcessTrusted=true
launch; echo perm > /tmp/jevsign.in; sleep 2; tail -6 signing-transcript.log
echo quit > /tmp/jevsign.in

# step 5 — rebuild A, identical source
SIGN_IDENTITY=jevpaste-dev ./scripts/make-signed-app.sh        # note the new CDHash
rm -rf ~/Desktop/SigningProbe.app && ditto build/SigningProbe.app ~/Desktop/SigningProbe.app
codesign -dv --verbose=4 ~/Desktop/SigningProbe.app 2>&1 | grep '^CDHash'
codesign -d -r- ~/Desktop/SigningProbe.app 2>&1 | grep '^designated'
launch; echo perm > /tmp/jevsign.in; sleep 2; tail -6 signing-transcript.log
echo quit > /tmp/jevsign.in

# step 6 — rebuild B, changed source (real content change, e.g. a build tag in Env.report()),
#          then repeat the rebuild A block verbatim
# step 7 — control, only if A or B survived: ad-hoc re-sign the SAME installed bundle
codesign --force --sign - --identifier com.jevpaste.signing-probe ~/Desktop/SigningProbe.app
launch; echo perm > /tmp/jevsign.in    # expect AXIsProcessTrusted=false → identity is the cause
# step 8 — only if A and B both failed: replace just Contents/MacOS/MacOSProbe in place and
#          re-sign the bundle without `rm -rf`, to separate "new bytes" from "new bundle".
```

Record cdhash + requirement + `AXIsProcessTrusted` for each row, fill in §5, state the verdict,
and keep implications as options for the supervisor — no decision in this file.
