# macOS probe — results (ticket #11)

Throwaway spike answering what macOS actually permits, exposes and costs for Smart Paste.
All payloads synthetic (`JEVPROBE-*`). No content was ever logged: lengths, UTI types and
SHA prefixes only. No network, no Jev, no TCC manipulation.

Environment: macOS 26.6.2 (25G83), Apple Silicon, CLT-only Swift 6.3.3, ad-hoc signed
`MacOSProbe.app` (`com.jevpaste.macos-probe`). Evidence: `probe-transcript.log` (session 3)
and `probe-transcript.session2.log` (session 2), both gitignored and never committed.

---

## 1. Headline answers

1. **The global hotkey needs no permission at all.** Carbon `RegisterEventHotKey` fires with
   zero TCC grants, including while secure input is active.
2. **Everything else needs exactly one grant.** Accessibility alone unlocked AX reading,
   event posting and event listening. No second prompt, no Input Monitoring row.
3. **Pasteboard swap (path A) is the only insertion that works across the board.** It worked
   on all five Targets.
4. **The AX setter (path B) is native-AppKit-only, and `settable` lies.** Three of five apps
   report `settable=true`, return `success`, and do nothing.
5. **A too-short restore delay is a safety bug, not a timing bug.** In four measured cases the
   Target received *the user's previous clipboard* instead of the intended Paste Result.
6. **Read-back verification is invalid on three of five Targets**, and silently produced false
   negatives that misled this spike twice.

---

## 2. Permissions

| Capability | Grant required | Evidence |
|---|---|---|
| Carbon `RegisterEventHotKey` (⌘⇧V) | **none** | fires with zero grants; still fires when `IsSecureEventInputEnabled()==true` |
| `CGEventTap` / `NSEvent` global monitor | Accessibility | registers once Accessibility is on |
| AX read (`AXUIElement*`) | Accessibility | `AXIsProcessTrusted=true` |
| `CGEventPost` (synthetic ⌘V) | Accessibility | `CGPreflightPostEventAccess=true` |
| Event listening | Accessibility | `CGPreflightListenEventAccess=true` |
| Pasteboard read | **none** | `accessBehavior=alwaysAllow` on a never-seen ad-hoc bundle; no privacy alert ever shown |

**Input Monitoring is not a separate hurdle.** Verified visually: the probe appears under
Bedienungshilfen/Accessibility only, and is *absent entirely* from Eingabeüberwachung/Input
Monitoring — while both post- and listen-event preflights return true. One grant, one row,
one user click.

Accessibility took effect **live in the running process**, no relaunch needed.
`CGRequestPostEventAccess` / `CGRequestListenEventAccess` returned true with no dialog.

**The grant is bound to the cdhash.** Rebuilding an ad-hoc signed bundle silently orphans it:
System Settings still shows the toggle ON while `AXIsProcessTrusted()` returns false, across
relaunch and direct execution. Only removing and re-adding the entry restores it.
Consequence for shipping: every update must be signed with a stable identity, or every user
loses Accessibility on upgrade with no visible indication.

Hotkey note: Carbon and a CGEventTap both observe the same press, so a ~400 ms dedup window is
required if both are registered.

---

## 3. Target matrix

| Target | Engine | Path A | Path B | Cold floor | Read-back | Target Context |
|---|---|---|---|---|---|---|
| Chrome | Chromium | works | **lies** | 40 ms *(regime unlabelled; 0 ms loses paste)* | valid | rich — 223 nodes / 143 text / ~3.9k chars |
| Ghostty + Herdr | native | works, bracketed | honest refusal (`settable=false`) | 20 ms *(warm only)* | **invalid** | whole-window scrape only |
| TextEdit | AppKit | works | **works** | 20 ms *(warm; 0 ms = wrong content)* | exact | n/a |
| WhatsApp | **Catalyst** | works | **lies** | **>20 ms cold** | lags | 88 nodes / 62 text / 4616 chars |
| ChatGPT | **Chromium** | works | **lies** | **20–25 ms cold** (20 fails, 25 OK) | lags | **28 nodes / 21 chars — none** |

Regime labels matter: **cold** = first paste after app activation (the only regime production
exercises), **warm** = a later paste in the same activation (an artifact of batch testing).
Cells marked *warm only* must not be read as cold-safe.

Engine identification was not what the brief assumed. WhatsApp desktop is **Mac Catalyst**
(`subrole=iOSContentGroup`, `_AXElementForTextInsertionAndDeletion`), not Electron. ChatGPT is
**Chromium/Electron** (`ChromeAXNodeId`, `AXDOMIdentifier`, `AXDOMClassList`, 50 attributes).
So Chrome findings generalise to ChatGPT but not to WhatsApp.

Bundle-id gotcha: `/Applications/ChatGPT.app` has `CFBundleIdentifier = com.openai.codex`.
Any bundle-id allowlist must not assume the id resembles the app name.

---

## 4. Finding the Target

`AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElement)` resolves the Target in
**0.28–8.64 ms** once the tree is awake.

**Chromium trees are asleep until walked.** Chrome returned `noValue` three times before
succeeding after one ordinary `AXChildren` walk. ChatGPT was worse: 7 nodes and
`focusedElementLookup=noValue`, and **four pastes hit no element at all and inserted nothing**.
After ordinary walks the tree grew to 28 nodes and the focused element resolved.

Both documented activation attributes were **rejected on both Chromium apps**:
`AXManualAccessibility=attributeUnsupported`, `AXEnhancedUserInterface=notImplemented`.
Neither is the mechanism; the ordinary walk is. They are unnecessary as well as unavailable.

**A freshly launched Catalyst app does not focus its text field.** After relaunching WhatsApp,
the focused element was the `iOSContentGroup`, not the compose box. An insertion fired at a
just-launched app targets a non-editable group.

**Multiplexers are opaque to AX.** Ghostty exposes exactly one `AXTextArea` for the entire
window. Its `AXValue` is a fixed-size rendered-screen snapshot — pinned at 13265 chars on every
read (≈213 cols × 62 rows, the whole window including Herdr's sidebar and *both* panes), while
its SHA changes every second on its own. Herdr's panes are invisible to accessibility. Jevpaste
cannot know which pane will receive a paste, and any Target Context scraped there includes
unrelated panes and another agent's transcript — a targeting limitation and a privacy concern.

---

## 5. Target Context and the label contract (#7)

Chrome supplies the full contract from ordinary AX: field title, placeholder, fieldset legend
(`AXGroup`), page title (`AXWebArea`), `AXURL`, `AXDOMIdentifier`. Cost: 223 nodes / 143 text
nodes / ~3.9k chars in 54–68 ms; first 2000 chars in 43–54 ms.

| Target | title | placeholder | description | URL / DOM id | ctx cost |
|---|---|---|---|---|---|
| Chrome | yes | yes | — | yes | 54–68 ms, 223 nodes |
| ChatGPT | 15 chars | `AXPlaceholderValue` present | 15 chars | `AXURL`, `AXDOMIdentifier` | 6 ms, **28 nodes / 21 chars** |
| WhatsApp | — | `AXPlaceholderValue` present | 20 chars | — | 117 ms, 88 nodes / 4616 chars |
| TextEdit | — | — | — | — | n/a |
| Ghostty | — | — | — | — | 5–15 ms, whole-window scrape |

**No Target gives both insertion and context.** ChatGPT's focused element is fully exposed
(50 attributes) while its conversation is *never* exposed — ctx stays pinned at 28 nodes / 21
chars permanently. Ghostty is the mirror image: context is the cheapest of any Target, and
insertion cannot be verified at all. Terminals yield essentially no label contract (only
`AXHelp`, 21 chars, and one ancestor group description).

Secure fields: Chrome flags them two independent ways — `AXSecureTextField` subrole and the
global `IsSecureEventInputEnabled`. Both fire independently, so either alone is sufficient
detection. **`AXValue` and `AXSelectedText` are reported settable even on a password field**,
so the refusal to touch secure fields must be ours; the platform will not stop us.

---

## 6. Insertion path A — pasteboard swap + synthetic ⌘V + restore

Works on **all five Targets**. The Active Item is swapped in, ⌘V is posted, the original
pasteboard is restored after a delay.

- Clipboard restored **byte-identical every cycle** across all targets (types and SHAs match;
  Chrome verified 9/9 with 4 UTI types). A restore always advances `changeCount`; content
  equality is the meaningful check.
- Cost outside the restore delay is ~3 ms. Chrome's full battery ran 126–128 ms end to end.
- Ghostty delivers it as a genuine **bracketed paste**: `^[[200~JEVPROBE-A-1^[[201~`.
- Drafts survive an app switch (WhatsApp compose box read 78 chars, switched away and back,
  still 78).
- **The Send button became enabled after insertion on both WhatsApp and ChatGPT.** Each app's
  own state model registered the insertion — not merely rendered glyphs. This is the question
  Chrome's React mirror taught us to ask, and path A passes it on **two different engines**
  (Catalyst and Chromium), on a real messaging app and a real chat app. Confirmed by the user:
  the message was genuinely sendable. Nothing was ever sent — no payload contained a newline,
  consistent with Smart Paste being insert-only.

  Corollary, stated carefully: because the Target becomes genuinely submittable, the safety
  property that keeps Smart Paste insert-only lives in the **insertion mechanism**, not in the
  payload. Jevpaste must never synthesize a Return key event, and must never use an insertion
  path whose content could be interpreted as a key sequence. It is the Return *key event* that
  submits these apps, not a newline character in pasted content. This is *not* a constraint on
  Paste Result content: a Paste Result is a verbatim contiguous excerpt and may legitimately
  contain newlines, which may never be altered to make insertion safer. Multi-line Paste
  Results were out of scope here — see §11.

Testing caveat for terminals: a bare `cat -v` *under-reports* bracketing, because zsh disables
bracketed-paste mode while a foreground command runs. The reader must set DECSET 2004 itself.

---

## 7. Insertion path B — the AX setter

| Target | `settable` claims | set returns | actually happened |
|---|---|---|---|
| TextEdit | `AXValue` ✓ `AXSelectedText` ✓ | success 2.45 ms | **worked** — 75 → 87 chars, exactly +12 |
| Chrome | `AXValue` ✓ (even on password fields) | success 0.1 ms | **nothing** (4×) |
| WhatsApp | `AXSelectedText` **✗** | success 0.08 ms | **nothing** |
| ChatGPT | `AXValue` ✓ `AXSelectedText` ✓ | success 0.08 ms | **nothing** (confirmed with delayed re-read) |
| Ghostty | all **✗** | — | not offered |

Path B is viable **only on native AppKit**. Note WhatsApp returned `success` for an attribute
it had *just declared unsettable*.

**`settable` is misleading in the dangerous direction**, and an AX setter's return value is
worthless. Only read-back establishes whether anything happened — and read-back is itself
invalid on three of five Targets. Ghostty's honest `settable=false` is the better platform
behaviour precisely because it can be trusted.

Untested cell, disclosed: on WhatsApp the `AXValue` path was never exercised, because the probe
only falls back to `AXValue` when the `AXSelectedText` set returns an *error* — a false
`success` short-circuits it. See §10.

---

## 8. Timing and the restore delay (#8)

**The failure mode of a too-short restore delay is not a no-op. It is wrong content.**

Measured: the Target receives the user's *previous clipboard* instead of the intended Paste
Result. Observed on TextEdit (+66 = prior clipboard exactly), Notes (+66, unintended — §10),
WhatsApp (+39 = clipboard) and ChatGPT (+39, three times). If the user's clipboard held a
password, a too-short delay silently inserts that password into whatever app is focused.

Chrome behaves differently and *loses* the paste outright: `valueBefore 24 → valueAfter 24`
against a 21-char clipboard — wrong-content would have read 45. So there are **two distinct
0 ms failure modes**: Chromium appears to read the pasteboard asynchronously after the key
event, while AppKit reads synchronously and our restore still wins the race. Both unacceptable;
the second is dangerous.

**Cold floor is real, reproducible and engine-independent.** ChatGPT, each shot a fresh
activation from another app:

```
cold 120 ms  +13  OK      cold  40 ms  +13  OK
cold 120 ms  +13  OK      cold  30 ms  +13  OK
cold  60 ms  +13  OK      cold  25 ms  +13  OK
                          cold  20 ms  +39  *** WRONG CONTENT ***
```

Tally: **four cold failures at 20 ms across two engines (WhatsApp ×1, ChatGPT ×3), zero cold
successes at 20 ms**, and clean results at every value ≥25 ms cold — and at 20 ms *warm*.

Ruled out by experiment: idle/IPC warm-up. A warm burst followed by a 6 s idle with **no app
switch**, then a 20 ms shot, was clean. The effect is specific to **activation**, and activation
is exactly what jevpaste does every time: the user switches to the Target app, then pastes.
**Every production Smart Paste is a cold paste.**

Strictness ordering of consumers: Chrome > ChatGPT ≈ WhatsApp > Ghostty > TextEdit.

### Options for #8 (decision belongs to #8, not to this spike)

- **(i) Pick the constant from the slowest measured consumer, with margin.** Chrome is the
  binding constraint at 40 ms; 120 ms was clean on all five Targets in both regimes and matches
  Chrome's own 126–128 ms battery. 120 ms is imperceptible to a user.
- **(ii) Bisect Chrome's untested 0–40 ms band.** Cheap, but only lowers a number under no
  performance pressure.
- **(iii) Adaptive per-app constants.** Advised against on this evidence: the failure is silent
  and dangerous, the cold/warm distinction is invisible at runtime, and three of five Targets
  cannot verify read-back, so an adaptive scheme has no reliable feedback signal.
- **(iv) Guard: verify the pasteboard still holds our payload before restoring, and extend
  rather than restore if unconsumed.** Limited — a pasteboard read *cannot* establish
  consumption, because `changeCount` remains ours either way. Needs a separate consumption
  signal: read-back where valid, otherwise a conservative fixed delay.

Only cold numbers should inform the recommendation; warm numbers are evidence that the
distinction exists, nothing more.

---

## 9. Race, drift and visible failure

**Race guard works.** A foreign copy landing 150 ms into a 300 ms window tripped the guard and
the restore was correctly abandoned, preserving the foreign copy.

**Focus drift is not theoretical.** It occurred twice unplanned during this spike, both times
because a human used their own machine during a multi-second window (§10). Idle drift over
800 ms was nil; real drift happens whenever the user switches apps. Target resolution must
therefore happen at hotkey time, and — see §10 — resolution and delivery must be a single
uninterruptible step.

**Visible failure surfaces** (Chrome, focus preserved in all cases): status-item flash
1.7–3.2 ms; non-activating `NSPanel` 8–16 ms. Both are viable for signalling *No Suitable
Match*. Probe bug worth inheriting as a UX lesson: one panel was created per press and only the
last retained, leaking three panels — the indicator must be a single reused instance.

---

## 10. What went wrong

**An unintended write into real user data.** One insertion landed in Apple Notes instead of
TextEdit. The procedure verified the frontmost app, then allowed ~15 s to elapse before firing;
the user switched apps in that gap, entirely reasonably. `AXValue` went 2610 → 2676, i.e. +66 —
the prior clipboard, not the 13-char payload. Content was the user's own clipboard, so nothing
foreign was written and nothing was transmitted; ⌘Z restored it byte-identically (verified:
`chars=2610 sha=a0b470bca3ef`, matching the pre-incident fingerprint).

Insertion census for the session: 6 Ghostty, 6 TextEdit, 4 WhatsApp + 3 no-op, 13 ChatGPT + 4
no-element, **1 Notes (unintended)**. Remediated afterwards: the real clipboard was replaced
with a synthetic marker for the remainder of the spike, so a mistargeted shot could only ever
insert self-identifying probe debris.

**Constraint this produces for #8:** target resolution and delivery must be **one
uninterruptible step**. Any user-visible setup window between "decide the Target" and "deliver
the Paste Result" is unsafe by construction. "Verify frontmost, then fire" must be a single
call, not two.

**Probe design lessons** (all cost real time this session):

- *Never branch on an AX setter's return value; branch on read-back.* The probe's `axinsert`
  falls back to `AXValue` only on error, so a false `success` short-circuits the fallback and
  left a cell untested.
- *Verification must not share a clock with the thing it verifies.* Immediate `valueAfter`
  reads produced false negatives on Ghostty (5/5, including four insertions that demonstrably
  landed), WhatsApp and ChatGPT. On Chromium and Catalyst the AX layer lags; only AppKit is
  immediate (TextEdit's `AXValue` matched its 75-byte file exactly).
- *A guard whose expected value is derived from observation cannot fail.* An abort check that
  set "expected app" to whatever was observed only protected against drift *during* a battery,
  never against a wrong Target at the start.
- *An empty Catalyst text field returns `noValue`, not `""`* — read-back cannot distinguish
  "empty" from "unsupported".

**Conclusions overturned during the spike**, recorded so the evidence trail is honest:

- Ghostty was reported in session 2 as a silent insertion failure. It was a **false negative**;
  path A works there and is bracketed.
- "WhatsApp fails at 20 ms" — wrong; it is not delay-dependent but activation-dependent.
- "`valueBefore=noValue` means the AX tree is asleep" — wrong; it means the field is empty.
- "The ChatGPT battery hit the wrong app" — wrong; `com.openai.codex` *is* ChatGPT.

---

## 11. Not measured

- **Capture from Ghostty, TextEdit, WhatsApp, ChatGPT.** Capture requires a real ⌘C *in* the
  app and the probe can only synthesize ⌘V. Only Chrome's capture row exists: 4 UTI types
  including `org.chromium.source-url` provenance, read in ~2 ms, no nspasteboard.org markers.
- **0 ms floor on Notes, WhatsApp, ChatGPT** — withheld by policy after the Notes incident; the
  0 ms probe inserts the real clipboard and was run only against a scratch file.
- **First paste after app *launch*** (as distinct from activation) on Catalyst.
- **Path B via `AXValue` on WhatsApp** — short-circuited by the probe (§7).
- **Selection replacement via `AXSelectedTextRange`** — the probe has no command to set a
  selection and adding one would require a rebuild, which orphans the Accessibility grant. The
  manual workaround (a human selects a word, then the setter fires at the live selection) was
  defeated by macOS window management: with the driving terminal fullscreen in its own Space,
  the user cannot select text in another app's window without switching Space and destroying
  the frontmost state the test depends on. This is itself a constraint on any
  human-in-the-loop verification of a focus-dependent behaviour.
- **Multi-line Paste Results.** Every payload in this spike was a single line. The expected
  behaviour is that newlines arriving via a pasteboard paste are inserted as line breaks rather
  than submitting the Target — both WhatsApp and ChatGPT submit on the Return key event, not on a
  newline character — but this was never measured and should not be relied on. Worth testing
  before any Paste Result containing a newline is inserted into a send-capable Target.
- **Notes** beyond the single unintended insertion.
- **Code-signing identity experiment** (does a stable signing identity let the grant survive a
  rebuild) — not run.

---

## 12. Reproducing

```
cd spikes/macos-probe
rm -f /tmp/jevprobe.in && mkfifo /tmp/jevprobe.in && (sleep 100000 > /tmp/jevprobe.in &)
open -n ~/Desktop/MacOSProbe.app --args --fifo /tmp/jevprobe.in --log "$PWD/probe-transcript.log"
echo "perm" > /tmp/jevprobe.in
```

Commands: `help env perm ask-ax ask-post ask-listen ladder detectvalues watch unwatch hk arm
id ctx timings paste axinsert race drift wake ind after copytest note quit`.

Do **not** rebuild: ad-hoc re-signing changes the cdhash and orphans the Accessibility grant.
