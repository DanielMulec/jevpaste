# Brief — ticket #13: signing identity that keeps the Accessibility grant across rebuilds

You are a fresh Pi session in worktree `~/.pi/worktrees/jevpaste/signing`, branch
`spike/signing-identity` (forked from `spike/macos-probe`), launched by the supervisor as
`pi --model anthropic/claude-opus-5:high`. Your supervisor is the Pi session with cwd
`/Users/danielmulec/Projekte/experiments/jevpaste` — run `intercom list` once to find its
session id, then reach it with `intercom` (`ask` when you need an answer, `send` for progress). Daniel is going to sleep; the
supervisor speaks for him. Standing approval already given for: creating a self-signed cert in
the login Keychain, signing bundles, launching the probe. The ONLY thing that needs a human is
the Accessibility toggle click — see step 4.

Ticket: https://github.com/DanielMulec/jevpaste/issues/13 (read it with `gh issue view 13`).
Evidence you build on: `RESULTS.md` §2 (grant bound to cdhash; ad-hoc rebuild orphans it).

## Question to answer, precisely

Does an app signed with a **self-signed code-signing identity** keep its Accessibility grant
(`AXIsProcessTrusted() == true`) after the binary is rebuilt and re-signed with the **same
identity**? Secondary: does it also survive a change of the executable's *content* (not just a
re-sign of identical bytes) — i.e. a real code change?

## Rules

- Synthetic content only, no network, no Jev, never read `~/.config/jevpaste/env`.
- No `tccutil reset`, no TCC.db edits, no SIP changes.
- Do **not** touch `~/Desktop/MacOSProbe.app` (the ad-hoc granted bundle) — it is evidence.
- Use a **new bundle id** `com.jevpaste.signing-probe` so the old grant row is untouched.
- 400 lines/file ceiling. Report facts; implications only as options.
- Never print secrets or the cert's private key. Cert name and commands are fine.

## Steps

1. **Create the identity** (login keychain, non-interactively). Suggested: a config file for
   `openssl req` with `extendedKeyUsage = codeSigning`, then
   `openssl pkcs12 -export` and `security import ... -T /usr/bin/codesign`, or
   `certtool`. Name: `jevpaste-dev`. Verify with
   `security find-identity -v -p codesigning`. If macOS prompts a GUI dialog for the keychain
   ACL, tell the supervisor — do not guess. Record the exact commands in the results.
2. **Build + sign.** Copy `scripts/make-app.sh` to `scripts/make-signed-app.sh`
   (or add a `SIGN_IDENTITY` env var to the existing script — your call, keep it small),
   bundle id `com.jevpaste.signing-probe`, output `build/SigningProbe.app`, `codesign --force
   --sign "jevpaste-dev" --options runtime` is NOT required (no notarization) — plain
   `--sign "jevpaste-dev"` is enough. Copy the bundle to `~/Desktop/SigningProbe.app` (TCC
   keys on path + requirement; keep the path constant across rebuilds). Record `cdhash` and the
   designated requirement (`codesign -d -r- ...`) — the requirement is what should now be
   identity-anchored instead of cdhash-anchored.
3. **Launch** via the FIFO pattern from `HANDOFF.md`, run `perm`, confirm
   `AXIsProcessTrusted=false` and that the app appears in System Settings → Privacy & Security
   → Accessibility (use `ask-ax` to trigger the prompt).
4. **Grant** — the one human step. `intercom ask` the supervisor: "SigningProbe needs the
   Accessibility toggle ON. Ready." The supervisor will forward to Daniel or, if he's asleep,
   reply `parked` — then stop, write everything so far into `SIGNING-RESULTS.md`, commit, and
   end your turn with a clear "waiting for grant" message. After the grant, verify `perm` →
   `AXIsProcessTrusted=true` live.
5. **Rebuild A — identical source.** Re-run the build script (new build, same source), copy
   over `~/Desktop/SigningProbe.app`, relaunch, `perm`. Record cdhash before/after and whether
   `AXIsProcessTrusted` survived.
6. **Rebuild B — changed source.** Make a trivial real code change (e.g. bump a version string
   printed by `env`), rebuild, copy, relaunch, `perm`. Record the same.
7. **Control (only if A or B survived):** also re-sign the *same* bundle ad-hoc (`--sign -`)
   and confirm the grant is lost — proves the identity is what preserved it.
8. If it did **not** survive: try `codesign --preserve-metadata=requirements` is irrelevant;
   instead test whether the grant survives when only `Contents/MacOS/MacOSProbe` is replaced
   and the bundle is re-signed with the same identity in place (no `rm -rf` of the bundle).
   Report; the fallback decision belongs to the supervisor.

## Reporting

- Write `spikes/macos-probe/SIGNING-RESULTS.md` (≤ 200 lines): environment, exact commands,
  a table (build | cdhash | requirement anchor | AXIsProcessTrusted after relaunch), verdict,
  options. Commit on `spike/signing-identity`; `intercom ask` the supervisor with the path +
  sha before pushing.
- `intercom send` a one-line progress after steps 1, 2, 5, 6.
- Anything unexpected (GUI prompt, keychain ACL dialog, build failure) → `ask` first.
