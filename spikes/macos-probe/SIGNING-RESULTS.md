# Signing identity vs. the Accessibility grant — results (ticket #13)

**Status: COMPLETE.** Daniel granted the toggle; steps 4–7 ran, step 8 was not needed.
**Answer: yes — the grant survives.** An app signed with a self-signed code-signing identity
keeps `AXIsProcessTrusted() == true` across a full rebuild with a new cdhash, including a real
source change, as long as it is re-signed with the same identity at the same path. Re-signing
the very same bundle ad-hoc drops the grant immediately, which isolates the identity as the
cause.

Baseline it is tested against, `RESULTS.md` §2: with ad-hoc signing the grant is bound to the
cdhash, and a rebuild silently orphans it (Settings shows ON, `AXIsProcessTrusted()` false).

Environment: macOS 26.6.2 (25G83), Apple Silicon, CLT-only Swift 6.3.3, no Xcode. Bundle under
test: `com.jevpaste.signing-probe` at `~/Desktop/SigningProbe.app` — new bundle id and new path,
so the ad-hoc grant row of `com.jevpaste.macos-probe` stays untouched. Transcript
`signing-transcript.log` (gitignored). No network, no Jev, no `tccutil`, no TCC.db edits,
synthetic content only.

---

## 1. The mechanism

The designated requirement changes shape with the signing method 
(`codesign -d -r-` on the actual bundle):

| signing | designated requirement |
|---|---|
| ad-hoc (`--sign -`) | `cdhash H"…"` — pinned to the *bytes* |
| identity (`--sign jevpaste-dev`) | `identifier "com.jevpaste.signing-probe" and certificate root = H"64cb89c8c7efa62842bdd1aa76a9faf321704f72"` — pinned to the *cert* |

No cdhash appears in the identity-signed requirement. §5 measures whether TCC actually
re-evaluates that requirement rather than a stored cdhash.

## 2. Step 1 — the identity (no GUI prompt)

**Deviation, approved by the supervisor: not the login keychain.** A login-keychain import needs
`security set-key-partition-list -k <login password>` to stay prompt-free; without it `codesign`
pops a keychain-ACL dialog. The password was not available and Daniel was asleep, so the identity
went into a dedicated throwaway keychain added to the user search list; the login keychain stays
default and untouched. Functionally identical — TCC only sees the signature on disk.

The `openssl req` config is committed as `scripts/codesign-cert.cnf` (`extendedKeyUsage =
critical,codeSigning`, `CA:FALSE`, `digitalSignature`).

```bash
mkdir -p /tmp/jevpaste-signing && cd /tmp/jevpaste-signing   # key material stays out of the repo
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config <repo>/scripts/codesign-cert.cnf \
  -keyout jevpaste-dev.key.pem -out jevpaste-dev.cert.pem
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

`$KCPASS` / `$P12PASS` are throwaway values for a spike keychain holding a spike key; not recorded
here, and the private key lives only in `/tmp/jevpaste-signing/`, outside the repo.

**Rollback (removes identity, keychain and key material; nothing else affected):**

```bash
security list-keychains -d user -s "$HOME/Library/Keychains/login.keychain-db"
security delete-keychain jevpaste-signing.keychain-db
rm -rf /tmp/jevpaste-signing
```

Observations:

- No GUI dialog at any point — not on import, not on signing.
- `security find-identity -v -p codesigning` → **0 valid identities**;
  `security find-identity -p codesigning` → `1) 64CB89C8… "jevpaste-dev" (CSSMERR_TP_NOT_TRUSTED)`
  — a self-signed root with no trust settings fails *trust evaluation*. **`codesign` signs with
  it anyway** (rc=0, silent) and `--verify` reports `valid on disk` + `satisfies its Designated
  Requirement`. Adding trust (`security add-trusted-cert`) needs admin/GUI auth and was skipped.
- Cert SHA-1 (= the requirement anchor): `64cb89c8c7efa62842bdd1aa76a9faf321704f72`.

## 3. Step 2 — build + sign

`scripts/make-signed-app.sh` — a small copy of `make-app.sh`: `SIGN_IDENTITY` env var (default
`jevpaste-dev`), bundle id `com.jevpaste.signing-probe`, output `build/SigningProbe.app`, prints
cdhash + requirement. Plain `--sign` (no `--options runtime`, no notarization).

```bash
cd ~/.pi/worktrees/jevpaste/signing/spikes/macos-probe
SIGN_IDENTITY=jevpaste-dev ./scripts/make-signed-app.sh
rm -rf ~/Desktop/SigningProbe.app && ditto build/SigningProbe.app ~/Desktop/SigningProbe.app
codesign -dv --verbose=4 ~/Desktop/SigningProbe.app     # Authority / CDHash
codesign -d -r- ~/Desktop/SigningProbe.app              # designated requirement
```

Baseline (build 0): `Authority=jevpaste-dev`, `TeamIdentifier=not set`,
`CDHash=8b1475b32789d0b987c406e6fdd2690220edb967`. The path `~/Desktop/SigningProbe.app` is held
constant across all rebuilds (TCC keys on path + requirement).

## 4. Step 3 — launch, baseline permission state

```bash
rm -f /tmp/jevsign.in && mkfifo /tmp/jevsign.in && (sleep 100000 > /tmp/jevsign.in &)
open -n ~/Desktop/SigningProbe.app --args --fifo /tmp/jevsign.in --log "$PWD/signing-transcript.log"
echo perm   > /tmp/jevsign.in
echo ask-ax > /tmp/jevsign.in      # triggers the prompt → creates the Settings row
```

Transcript facts: `ENV bundleID=com.jevpaste.signing-probe bundled=true`, bundlePath on the
Desktop; `PERM AXIsProcessTrusted=false`, both CG preflights `false`;
`PASTEBOARD accessBehavior=alwaysAllow raw=2` (again no pasteboard privacy alert, now on an
identity-signed bundle too); `ask-ax` → `AXIsProcessTrustedWithOptions=false`, the documented
normal result. Probe quit cleanly (`quit` → `bye`); bundle left installed.

*Not verified:* the row's visible presence in System Settings → Privacy & Security →
Bedienungshilfen — TCC.db is unreadable without Full Disk Access (one read attempted, denied,
nothing written). Daniel reported switching it ON before sleeping; the flip below corroborates.

## 5. Steps 4–7 — the measurements

Every row: bundle at the unchanged path `~/Desktop/SigningProbe.app`, launched fresh via the FIFO
pattern, `perm` read from the transcript. Each rebuild `rm -rf`'d and re-`ditto`'d the whole
bundle; C/D re-signed the installed bundle in place.

| # | build | cdhash | requirement anchor | `AXIsProcessTrusted` after relaunch |
|---|---|---|---|---|
| 0 | baseline, before the click | `8b1475b32789d0b987c406e6fdd2690220edb967` | certificate root `64cb89c8…` | `false` |
| 4 | same bundle, after the click | `8b1475b3…` (unchanged) | certificate root `64cb89c8…` | **`true`** |
| A | re-run of the build script, identical source | `8b1475b3…` **unchanged** | certificate root `64cb89c8…` | `true` *(weak — see below)* |
| A′ | `rm -rf .build` + full recompile, identical source | `52a651fd06dd5db6b97908bfc952b0c92f7599bd` | certificate root `64cb89c8…` | **`true`** |
| B | real source change (`buildTag`), rebuilt | `84d6c84f2df39f3de76333128d7d0d3b09ce31a6` | certificate root `64cb89c8…` | **`true`** |
| C | control: same bundle re-signed ad-hoc | `2c98e6a0fa6073a4c5c46f0e3b6d5c9a55b3c694` | `designated => cdhash H"2c98e6a0…"` | **`false`** |
| D | C re-signed with the identity again, in place | `84d6c84f…` (back) | certificate root `64cb89c8…` | **`true`** |

Row-by-row notes — the corrections matter more than the table:

- **A alone would have been a false positive.** Re-running the build script is a SwiftPM no-op,
  so the cdhash did not change at all (only the on-disk file bytes did, because `codesign`
  stamps a new signing time: exec sha256 `dea77c14…` → `da1fb24c…` with an identical cdhash).
  An ad-hoc bundle would have survived that too. Hence A′.
- **A′ is the real identical-source test.** A clean Swift recompile of unchanged source is *not*
  reproducible: new cdhash `52a651fd…`. The grant still held.
- **B proves the new code is what actually ran**, not a stale binary: the relaunched probe
  printed `ENV bundleID=com.jevpaste.signing-probe bundled=true buildTag=B`, a line that did not
  exist in build 0. Grant held.
- **C is the discriminator.** Same path, same bundle id, same file contents, only the signature
  swapped to ad-hoc → `AXIsProcessTrusted=false` and both CG preflights `false`. Note the ad-hoc
  designated requirement drops the identifier entirely: `designated => cdhash H"…"`.
- **D was not in the brief and is the most useful accident:** re-signing with the identity
  restored the grant *with no human action at all*. The ad-hoc excursion never destroyed the TCC
  row — it simply stopped matching, then matched again. Same mechanism as #11's "Settings shows
  ON while the app is untrusted", seen from the other side.
- Step 8 was not run: it is conditional on A and B failing, and both survived.
- `~/Desktop/MacOSProbe.app` (the ad-hoc evidence bundle) was checked after each step, never
  touched; identifier still `com.jevpaste.macos-probe`.

## 6. Verdict

**TCC matches the stored designated requirement, not a stored cdhash.** With an identity the
requirement is `identifier "com.jevpaste.signing-probe" and certificate root = H"64cb89c8…"`,
which every rebuild signed by the same cert keeps satisfying — so the Accessibility grant, and
with it event posting and event listening, survives updates silently and correctly. The #11
finding ("rebuild orphans the grant") is therefore a property of **ad-hoc signing**, not of TCC,
and it disappears entirely once a signing identity exists. A *self-signed* cert is enough; no
Developer ID, no notarization, no hardened runtime was involved.

Scope limits of this evidence:

- One machine, one macOS version (26.6.2), one bundle id, Accessibility only. Other TCC services
  were not tested.
- The path stayed constant. Whether the grant follows a *move* of the bundle was not tested.
- The identity stayed constant. Rotating or re-issuing the cert changes the root hash, changes
  the requirement, and by the C-row logic must drop the grant — **predicted, not measured.**
- The cert is self-signed and reports `CSSMERR_TP_NOT_TRUSTED`; TCC accepted it anyway.
  Gatekeeper/quarantine on a *downloaded* build is a different question, untested here.
- No secure timestamp in the signature, so cert expiry (3650 d) would eventually invalidate old
  builds. Irrelevant for a spike, relevant for shipping.

## 7. Options (decisions belong to the supervisor)

1. **Sign every jevpaste build with one stable identity** (Developer ID for distribution). The
   user grants Accessibility once and updates keep it. This removes the upgrade cliff described
   in `RESULTS.md` §2 without any extra UX.
2. **Treat identity rotation as a migration event**, not a build detail: whoever changes the
   signing cert must expect every user to lose the grant, and that needs a planned re-grant flow
   (the D row shows a *mismatched* row is repaired by matching again, not by user action).
3. **Keep a runtime self-check regardless.** `AXIsProcessTrusted()==false` while the toggle reads
   ON is a state the user cannot diagnose. Cheap to detect at launch; the response (silent
   re-prompt vs. "remove and re-add" instructions) is a product decision.
4. Optional follow-ups: grant survival across a bundle *move*, and the predicted loss on rotation.

## 8. State left behind

`~/Desktop/SigningProbe.app` is installed, identity-signed (cdhash `84d6c84f…`, build B), still
granted; the probe was quit cleanly. The `jevpaste-dev` identity and its keychain remain in place
for follow-ups — run the §2 rollback when the spike is retired. `Env.swift` carries the
`buildTag` change from step 6 (committed: it is the evidence for row B).
