# macOS capabilities for clipboard capture, target context, insertion and secret detection

Ticket: <https://github.com/DanielMulec/jevpaste/issues/3> · Branch: `research/macos-capabilities` (base `cd99be3`) · Date: 2026-09-20

Legend: **[D]** documented in a primary source · **[I]** inference from primary sources (reasoning stated) ·
**[U]** untested on this machine · **[X]** unknown / source-conflicting. Claims without a tag are context, not findings.

## 1. Scope, method, non-goals

Question: which supported macOS mechanisms can (a) observe text clipboard changes, (b) keep history, (c) register a
global shortcut, (d) identify the focused target and read meaningful context, (e) insert text while preserving the
clipboard, and (f) detect secure fields and likely secrets — plus the permissions each needs.

Method: primary sources only. On-machine SDK headers (the headers this toolchain compiles against), Apple
documentation (including Apple's docs JSON endpoints where the HTML is JS-rendered), one Apple technote, and
implementation sources for browsers/managers (Chromium, WebKit, Electron, Maccy, KeyboardShortcuts).

Non-goals honored: no clipboard/history/secret inspection, no code compiled or executed, no installations, no
permission or TCC changes, no provisioning, no paid API calls, no issue/map edits, no pushes.

## 2. Environment (read-only checks on this machine)

| Item | Value |
|---|---|
| OS | macOS 26.6.2, build 25G83 (Darwin 25.6.0, arm64, Apple silicon) |
| Swift / clang | Swift 6.3.3 (swiftlang-6.3.3.1.3), Apple clang 21.0.0 |
| SDK | `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk` (via `xcrun --show-sdk-path`) |
| Xcode | **not installed** — `xcodebuild` fails: "requires Xcode, but active developer directory … is a command line tools instance" |
| Other | node v26.5.0, gh 2.96.0 |

**[D]** A GUI `.app` for this project must be built without `xcodebuild` until Xcode is installed (command-line tools
can still compile and `codesign` manually; `swift build` works, but package-to-bundle wiring, Info.plist and code
signing are then hand-rolled). This is a tooling decision for the parent, not a research blocker.

## 3. Findings

### 3.1 Clipboard observation and history

- **[D]** `NSPasteboard.changeCount` is "the receiver's change count"; Apple's discussion ties it to ownership:
  `clearContents()` and `declareTypes:owner:` return the count, and recording that value to compare with a later one tells
  you "whether you still have ownership". [S1][S2]
- **[D]** AppKit declares **no change notification** for `NSPasteboard`; the notification API exists only on iOS
  (`UIPasteboard.changedNotification`), and this machine's `NSPasteboard.h` contains no change-notification API. Polling
  `changeCount` on a timer is therefore the supported mechanism. [S3][S2]
- **[D]** Reading content requires `string(forType:)` / `data(forType:)` / `pasteboardItems`; there is **no API that
  reports which process wrote the item** — the community convention `org.nspasteboard.source` only works if the writer
  cooperates. [S5][S6]
- **[D]** `NSWorkspace.frontmostApplication` is "the application that will receive key events" (KVO-observable). [S7]
  **[I]** Combining it with a `changeCount` change is a heuristic attribution, not reliable provenance: a background app or Universal Clipboard can write while another app is frontmost. Cooperative source markers provide another signal.
- **[I]** Polling means history starts when the watcher starts and can miss a copy that is overwritten inside one poll
  interval; there is no retroactive history. Interval is a latency/cost trade-off; 500 ms is a widely used default
  (Maccy's is configurable, default 500 ms). [S8]
- **[D]** macOS 26 ships a first-party clipboard history in Spotlight (⌘Space then ⌘4; may need a one-time Allow;
  can be cleared from the More menu; retention is user-configurable per Apple). [S9] **[I]** This overlaps with, but
  does not replace, an in-app history (it is Spotlight-only, has no per-item API for other apps, and is
  system-configured), and it strengthens the case for per-item deletion and clear-all in-app.
- History storage/retention is entirely ours; macOS offers no history API and no persistence of past pasteboard items.

### 3.2 Pasteboard privacy gate (macOS 15.4+ / macOS 26) — the dominant constraint

- **[D]** `NSPasteboard.accessBehavior` (`NSPasteboardAccessBehavior`, `API_AVAILABLE(macos(15.4))`, declared in this
  machine's AppKit header) has cases `default`, `ask`, `alwaysAllow`, `alwaysDeny`. Header text: *"The default behavior
  for the General pasteboard is to ask upon programmatic access. All other pasteboards default to always allow."*
  `.ask` = "notify the user and ask for permission before granting pasteboard access"; `alwaysDeny` = automatic denial.
  In all configured states, "access that is both user originated and paste related will always be allowed, and will not
  result in a notification". After the first alert the app appears in System Settings, where the user chooses. [S10]
- **[D]** Apple's AppKit release notes (April 2025, "macOS pasteboard privacy"): the system "alerts a person using a
  device when your app programmatically reads the general pasteboard… only if the pasteboard access wasn't a result of
  someone's input on a UI element that the system considers paste-related", and a `EnablePasteboardPrivacyDeveloperPreview`
  default existed to test it early. [S11]
- **[D]** The `detect` APIs avoid the alert: `detectPatternsForPatterns:` "only gives an indication of whether the first
  pasteboard item matches a particular pattern, and doesn't allow the app to access the item's contents. As a result, the
  system doesn't notify the person". `detectValuesForPatterns:` — the variant that returns values — *does* notify. [S12][S13]
- **[D]** Detection patterns are a closed set: probable web URL, probable web search, number, links, phone number,
  email address, postal address, calendar event, shipment tracking number, flight number, money amount. **No credential
  or password pattern exists.** [S12]
- **[D]** Chromium gates its own clipboard reads on exactly this API (`@available(macOS 15.4, *)` reading
  `accessBehavior`), with the in-source comment: *"These settings only affect programmatic access - direct user actions
  like ⌘V always work."* Before 15.4 Chromium treats the state as allow. [S14]
- **[D]** Apple has **no API to request full pasteboard access**; a developer report (FB17587626) asks for one. [S15]
- **[I]** Consequences for v1: a background poll that reads text will hit the alert/denial path unless Daniel sets the app
  to *Always Allow*; the app should read `accessBehavior` and surface a visible indicator/instruction (consistent with the
  map's "no silent failure" rule) instead of silently dropping captures.
- **[U]** Whether reading `changeCount` or `types` alone triggers the alert (they are not content reads); whether a read
  performed by our app immediately after our own global-hotkey press counts as "user originated and paste related"
  (a custom ⌘⇧V is probably not a "paste-related UI element"); whether the target app's read caused by our *synthesized*
  ⌘V counts as paste-related. All three are cheap to test and decide the onboarding UX.
- **[X]** Whether the alert is enforced by default on macOS 26.6.2 today: the header states the *default* is ask and the
  release note called it "upcoming"; I did not probe this machine because probing changes app/TCC state.

### 3.3 Sensitivity markers: what is enforceable and what is convention

- **[D]** nspasteboard.org is the canonical owner of the marker types: `org.nspasteboard.TransientType` (don't record in
  history), `org.nspasteboard.ConcealedType` (confidential: obfuscate on screen, avoid writing to a file or encrypt it),
  `org.nspasteboard.AutoGeneratedType` (app-generated, not user-intended), and `org.nspasteboard.source` (bundle id
  string). Legacy/proprietary markers to also honor: `de.petermaurer.TransientPasteboardType`, `com.typeit4me.clipping`,
  `Pasteboard generator type`, and 1Password's `com.agilebits.onepassword`. Handoff items are marked
  `com.apple.is-remote-clipboard`. [S6]
- **[D]** Verified locally: this machine's AppKit headers declare **none** of these constants (grep of `NSPasteboard.h`
  and `NSPasteboardItem.h`). **[I]** They are advisory conventions only — nothing enforces them, only cooperative
  producers set them, and absence proves nothing about sensitivity. Maccy implements exactly this: ignore
  `.autoGenerated`, `.concealed`, `.transient` plus user lists/regexes, and tag its own writes. [S16][S8]
- **[D]** The convention asks observers to check marker types *before* reading content. [S6]
- **[I]** Concealed markers are a high-precision, low-recall signal (password managers) — good for a hard "never persist"
  rule, useless as the only secret defense.
- **[I]** When our app temporarily writes the Paste Result it should write `org.nspasteboard.TransientType` (and
  `AutoGeneratedType`), set `org.nspasteboard.source`, and be ignored by our own watcher; `NSPasteboardContentsCurrentHostOnly`
  prevents pushing the temporary item to Daniel's other devices. [S5][S8]

### 3.4 Global shortcut

- **[D]** Carbon `RegisterEventHotKey` / `UnregisterEventHotKey` (HIToolbox) register a global hot key from a virtual
  keycode plus modifiers; "only one such combination can exist for the current application"; still declared in the macOS 26
  SDK with availability 10.0+, no deprecation attribute, and no permission requirement documented. [S17]
- **[D]** The `KeyboardShortcuts` library (used by Maccy) registers via `RegisterEventHotKey`. [S18][S8]
- **[I]** Therefore ⌘⇧V costs no Accessibility/Input-Monitoring grant, which is the cheapest correct v1 path. Known
  limits: modifier + single key only, no key sequences, no Fn/Globe. [S17]
- **[D]** General key listening is the expensive alternative: `CGEventTap` needs Input Monitoring (`CGPreflightListenEventAccess`
  / `CGRequestListenEventAccess`); `NSEvent` global monitors for key events need Accessibility/Input Monitoring. [S19][S20]
- **[X]** A developer forum thread reports macOS 15 initially restricting Option-only Carbon shortcuts (reportedly
  addressed in 15.2); ⌘⇧V contains ⌘, so it is outside that report's risk class. [S21]
- **[U]** Whether the Carbon hot key still fires while secure event input is active. Apple TN2150 says secure event input
  stops keystrokes reaching *event-monitor* interceptors (event taps, HID seize, `GetKeys`) — a registered hot key is a
  different mechanism, so it probably still fires; a test is required because it decides whether the app can even see
  "smart paste" in a password field (and refuse) versus silently doing nothing. [S22, S17]

### 3.5 Focused target identification and target context

- **[D]** `AXUIElementCreateSystemWide()` + `kAXFocusedUIElementAttribute` yields the focused element system-wide;
  `AXUIElementCreateApplication(pid)` is the per-app alternative. Both require a trusted Accessibility client
  (`AXIsProcessTrusted` / `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt`), and messaging returns
  `kAXErrorAPIDisabled` when the API is not enabled for the caller. [S23][S24]
- **[D]** Attributes available for bounded context (per-element support varies): `AXRole`, `AXSubrole`, `AXTitle`,
  `AXDescription`, `AXHelp`, `AXValue`, `AXSelectedText`, `AXPlaceholderValue`, `AXDocument`, `AXURL`, `AXFocused`. Use
  `AXUIElementIsAttributeSettable` before writing. [S25][S26]
- **[D]** Browsers hide web content by default:
  - Chromium: "Accessibility features in Chrome are off by default and enabled automatically on-demand";
    `--force-renderer-accessibility=[basic|form-controls|complete]` forces it at launch. [S27]
  - Chrome treats `AXEnhancedUserInterface` set on its app element as an activation request from assistive tech —
    in-source comment: *"This is an undocumented attribute that's set when VoiceOver is turned on/off… monitor this
    attribute in case other ATs use it to request accessibility activation."* [S28]
  - Electron adds `AXManualAccessibility` specifically so third-party AT tools can wake Chromium's tree (documented by
    Electron; present in Electron's source). [S29][S30]
  - WebKit/Safari reads `AXEnhancedUserInterface` into the web-process parameters, i.e. Safari gates web content on it
    too. [S31]
- **[D]** What a web text input exposes: Chromium returns `NSAccessibilityPlaceholderValueAttribute` for text fields, and
  returns `NSAccessibilitySecureTextFieldSubrole` when the node is an atomic text field with the `kProtected` state
  (i.e. password fields are a **subrole**, not a distinct role). [S32][S33] WebKit likewise exposes a placeholder-value
  attribute and derives its subrole string from the backing object. [S34]
- **[I]** Practical, cheap-first context ladder for v1: frontmost bundle id → role+subrole → `AXTitle` (the form-field
  label) → `AXPlaceholderValue` → `AXDescription`/`AXHelp` → window `AXTitle` → (web) document/URL if exposed → selected
  text. Deliberately excluded: reading a full `AXValue` from document-sized text views (privacy + cost), and
  `CGWindowListCopyWindowInfo` window names, which require Screen Recording. [S35]
- **[U]** Whether waking Chrome/Electron/Safari AX on macOS 26.6.2 yields the focused web input at all, and whether it
  has side effects. Evidence of side effects elsewhere: Firefox reports `AXEnhancedUserInterface` breaking window
  managers, and a recent report says macOS 15.7.x returns `kAXErrorNotImplemented` for it on some apps — so a fallback
  (window title / placeholder-free context) must exist. [S36][S37]
- **[X]** Whether Chromium exposes the page URL as `AXDocument`/`AXURL` on the web area (not verified in this round).

### 3.6 Secure-field detection and its hard limits

- **[D]** The AppKit/AX constant is `kAXSecureTextFieldSubrole = "AXSecureTextField"` — a subrole. [S33][S38]
  Native `NSSecureTextField` is the AppKit type. [S39]
- **[D]** Secure event input: `EnableSecureEventInput` means "keyboard input will only go to the application with keyboard
  focus, and will not be echoed to other applications that might be using the event monitor target to watch keyboard
  input"; the enable call is reference-counted; `IsSecureEventInputEnabled()` "returns whether secure event input is
  enabled **by any process**, not just the current process". [S22][S40]
- **[D]** Both major browsers enable it while a password field is focused: Chromium's `ScopedPasswordInputEnabler` calls
  `EnableSecureEventInput()` (used from the render-widget host view and `views::Textfield`); WebKit/WebKit2 calls
  `EnableSecureEventInput()` when `editorState().isInPasswordField`. [S41][S42][S43]
- **[I]** So there are two independent signals: AX subrole (precise, per-element, needs a working AX tree) and
  `IsSecureEventInputEnabled()` (coarse, global, works even when AX is unavailable for the target — but it cannot say
  *which* app or field, and is also set by Keychain prompts, sudo, terminal password prompts, etc.).
- Apple's TN2150 defines fair use of secure event input and obliges enabling processes to disable promptly; our app must
  only **read** the state and never enable it. [S22]
- **Why passwords cannot be claimed as always identifiable:**
  1. **[I]** AX role/subrole coverage is app-dependent: custom-drawn UIs, some terminals/editors and
     accessibility-hostile apps expose `AXUnknown`/`AXTextField` with no subrole; a secure app may also expose a plain
     text role without setting the subrole.
  2. **[D]** Apps are not required to call `EnableSecureEventInput`; only cooperative ones (e.g. Chrome, Safari) do. [S22][S41]
  3. **[U]** Whether SwiftUI `SecureField` in a third-party app reports `AXSecureTextField` was not verified.
  4. **[I]** Nested/embedded content (web views inside native apps, cross-origin iframes, canvas-based editors) can hide
     the real focus owner from the AX tree entirely.
  5. **[I]** Therefore v1 must combine signals, refuse on suspicion, and still state that undetected secure targets remain
     possible — never claim completeness. It must never read a value that looks secure (we do not need to: the map blocks
     secure targets in v1).

### 3.7 Insertion while preserving the clipboard, and races

Insertion paths, with evidence and cost:

| Path | Evidence | Cost / limitation |
|---|---|---|
| (a) Write result to pasteboard + synthesize ⌘V | **[D]** documented APIs (`CGEvent(keyboardEventSource:virtualKey:keyDown:)`, flags, `.post(tap:)`); Maccy/Clipy implement exactly this (Maccy checks Accessibility first) [S44][S8] | Needs Accessibility/PostEvent; mutates the user's clipboard temporarily |
| (b) AX write (`kAXValueAttribute` / `kAXSelectedTextAttribute`) | **[D]** `AXUIElementSetAttributeValue`; check `AXUIElementIsAttributeSettable` [S26] | **[U]** AX writes need browser-specific verification. [S45] describes DOM programmatic changes, not the browser's AX setter implementation, so it does not prove AX writes omit input events or fail React-controlled fields; per-target support varies |
| (c) Synthesized Unicode typing (`CGEventKeyboardSetUnicodeString`) | **[D]** Apple warns "application frameworks may ignore the Unicode string in a keyboard event and do their own translation based on the virtual keycode" [S46] | **[U]** Community-reported ~20 UTF-16-unit truncation requiring chunking and slow for long text [S47]; bypasses the clipboard entirely |

- **[D]** Ownership/interference check: record the change count returned by `clearContents()` and compare later — Apple
  documents this as the way to know "whether you still have ownership". [S1][S5]
- **[D]** Snapshot/restore model: enumerate `pasteboardItems`, capture `types` and `data(forType:)` per item, then restore
  with `clearContents()` + `writeObjects(_:)`. Pasteboard data can be **promised/lazy** (`declareTypes:owner:` plus
  `pasteboard:provideDataForType:`), so reading forces the owner to supply data — if the owning process has quit, or the
  type is a file promise, the round trip may not be faithful. [S5]
- **[I]** Named race conditions to design for:
  1. Daniel copies something during our temp-write window → restoring would destroy it. Mitigation: compare `changeCount`
     against the count returned by our own `clearContents()`; if it advanced, do not overwrite. [S1][S5]
  2. Target app reads the pasteboard asynchronously (promised types, slow app) → restoring too early loses the paste.
     There is **no API that signals "paste consumed"**; a delay/heuristic is required. **[X]** Correct timing per target
     class is unmeasured.
  3. Our own temp write re-enters our watcher → must be filtered (transient marker + own source bundle id). [S8]
  4. Universal Clipboard / Handoff traffic can add or replace items mid-window (`com.apple.is-remote-clipboard`). [S6]
  5. Non-text payloads (images, file URLs) are out of v1 scope, but they can still be *on* the pasteboard when we
     snapshot; fidelity of file-URL items across a restore is **[U]**.
- **[I]** Path (a) is a common clipboard-manager approach, not a universal compatibility guarantee. All three paths require tests against actual targets, including paste handlers and focus/clipboard races. This trade-off is a parent decision.

### 3.8 Required permissions

| Capability | Permission / TCC service | Probe API | Notes |
|---|---|---|---|
| Read focused element, role/subrole, labels | Accessibility (trusted AX client) | `AXIsProcessTrusted` / `AXIsProcessTrustedWithOptions(kAXTrustedCheckOptionPrompt)`; `kAXErrorAPIDisabled` on failure [S24] | Required for context *and* secure-field subrole |
| Post synthesized ⌘V | "PostEvent" (Accessibility-adjacent) | `CGPreflightPostEventAccess` / `CGRequestPostEventAccess` [S19] | Needed for insertion path (a) |
| Global key listening (only if we move off Carbon hot keys) | Input Monitoring ("ListenEvent") | `CGPreflightListenEventAccess` / `CGRequestListenEventAccess` [S19] | Not needed for `RegisterEventHotKey` [S17][S18] |
| Read the general pasteboard's contents | Pasteboard access alert (macOS 15.4+), per-app user choice | `NSPasteboard.general.accessBehavior` [S10] | Text capture and the "copy now" flow both hit this |
| Reset grants while testing | — | `tccutil reset PostEvent|ListenEvent|Accessibility <bundle-id>` [S48] | Documented by Apple |
| Code identity for grants | — | — | **[D]** macOS remembers privacy grants via the app's designated requirement; an update that satisfies the original DR keeps the grant [S49]. **[I]** Ad-hoc/unsigned builds effectively pin to that exact code, so each rebuild can look like a new app and re-prompt — use a stable bundle id and a stable signing identity during development |
| Sandbox | — | — | **[D]** A sandboxed app cannot post events to other apps (Apple developer-forum reply) [S50]; **[I]** therefore the app should be non-sandboxed (personal distribution; notarization needs hardened runtime, not sandbox) |
| Screen Recording | **not needed** | — | Only if window *names* were used; AX titles suffice [S35] |

### 3.9 Practical local password/API-key detection

- **[D]** No first-party detector exists for credentials (see §3.2 pattern list). Detection is our own rules. [S12]
- **[D]** Mature rule sets exist and are inspectable: gitleaks' default config has 222 rules with provider-specific
  prefixes and per-rule Shannon `entropy` thresholds (typically ~3.5–4.5) plus allowlists/stopwords [S51];
  detect-secrets pairs entropy plugins (`Base64HighEntropyString`, `HexHighEntropyString`) with explicit heuristic
  filters to suppress false positives [S52]; trufflehog classifies 800+ secret types, and "verified" results mean it
  called the provider API to validate the secret [S53] (network + possible cost — out of scope for a fast local check).
- **[D]** Peer-reviewed benchmark (Basak et al., ESEM 2023; 818 GitHub repositories): gitleaks recall 86% (Case 1) /
  88% (Case 2) at 46% precision; trufflehog 31% / 52% recall at 6% precision; category variance is large (trufflehog 98%
  recall for database/server URLs); false positives come from generic regexes and ineffective entropy calculation, false
  negatives from faulty regexes, skipped file types and incomplete rulesets; the tools find substantially different true
  positives (1533 vs 438 non-overlapping in Case 1), i.e. they are complementary. Enabling trufflehog's API verification
  raised its precision from 6% to 90% in that study, at the cost of contacting provider APIs and with ~10% verification
  failure — provider-verified detection is the high-precision path, but not a local, offline one. [S54]
- **[I]** A clipboard item is a *harder* input than a repository file: no variable name, no file path, no surrounding
  code, often a single token — so recall should be assumed **worse** than the benchmark above. A password copied from a
  manager has no prefix and no checksum, and if human-chosen may have low entropy: such items are **not reliably
  detectable by any rule set**, which is exactly why "passwords are always identifiable" must not be claimed.
- **[I]** Suggested v1 detector shape (parent decides): (1) marker types → never persist; (2) high-confidence structured
  tokens (PEM `-----BEGIN … PRIVATE KEY-----`, AWS `AKIA…`, GitHub `ghp_`/`github_pat_`, Slack `xox[baprs]-`,
  Stripe `sk_live_`, provider-style `sk-`, Google `AIza…`, JWT three-part base64url, connection strings with inline
  credentials); (3) optional entropy check for unprefixed random strings; (4) label results as "suspected secret"
  (visible marker, not a guarantee); (5) keep payloads out of diagnostic logs.
- Residual risk to state in-product: per the map, Daniel accepts that secrets may still reach Jev when detection is
  impractical. Detection quality affects *visibility*, not a hard guarantee.

## 4. Decision implications (options, not decisions)

1. **Prototype pasteboard privacy before finalizing onboarding.** The API documents ask/allow/deny behavior, but enforcement on this Mac remains untested. If capture is denied or prompts apply, provide visible guidance toward the appropriate grant rather than assuming alert-per-read behavior. [S10][S11]
2. **⌘⇧V via Carbon hot key is the permission-light path**; Accessibility is still required for context and for
   synthesized ⌘V insertion. [S17][S24][S19]
3. **Insertion strategy is a real fork**: clipboard-swap+⌘V (uniform, needs ownership/race handling) vs AX write
   (avoids clipboard mutation, browser/framework behavior unverified) vs Unicode typing (clipboard-free, compatibility unverified).
4. **Prototype browser AX activation and context.** Sources establish on-demand activation and special attributes, not that every target requires an undocumented attribute. Try ordinary AX access first; test activation and side effects only where necessary. [S28][S31][S36][S37]
5. **Secure-target blocking must be best-effort and multi-signal**, with an explicit statement that some secure targets
   are undetectable. Never read values from suspected secure fields. [S33][S40][S41]
6. **Toolchain**: no Xcode on this machine; decide install-Xcode vs hand-rolled bundle+codesign before implementation. [§2]
7. **Secret detection is a tagged heuristic**, sized from gitleaks-style prefix rules plus entropy, and must never be
   described as complete. [S51][S54]

## 5. Unknowns and the smallest tests that resolve them

| # | Question | Cheap test |
|---|---|---|
| 1 | Does a background text read alert on 26.6.2? Do `changeCount`/`types` reads avoid it? Is a post-hotkey read "paste related"? | Throwaway probe app; observe alerts for each access kind (this changes TCC/System Settings state, so run it in the prototype phase, not during research) |
| 2 | Does ⌘⇧V still fire while secure event input is on? | Focus a Chrome/Safari password field, press the hot key, log whether the handler ran |
| 3 | Does waking AX on Chrome/Safari/Electron expose the focused web input, and what are the side effects? | Compare AX reads with and without `AXEnhancedUserInterface`/`AXManualAccessibility` |
| 4 | Which attributes exist per app (Safari, Chrome, TextEdit, Notes, Xcode, Terminal, VS Code, Slack)? | Dump role/subrole/title/placeholder/description for the focused element |
| 5 | Does SwiftUI `SecureField` report `AXSecureTextField`? | Focus a SwiftUI secure field, read subrole |
| 6 | Clipboard restore fidelity for text/RTF/HTML/image/file-URL/Handoff items | Snapshot → mutate → restore → compare types+bytes |
| 7 | How long after the synthesized ⌘V is restoring the clipboard safe, per target class? | Timed matrix over native/Chrome/Safari/Electron/terminal |
| 8 | Does AX value-write stick in a React-controlled field? | Write into a known framework-controlled input and observe state/UI divergence |

## 6. Limitations of this research

- No runtime verification: nothing was compiled or executed, and no clipboard, history or secret content was inspected
  (explicitly excluded). All behavior claims are documentation- or source-based.
- Measured on macOS 26.6.2 only; older-version behavior is documented, not measured.
- Apple documentation pages are JS-rendered; I used Apple's documentation JSON endpoints and the local SDK headers where
  possible. Two `developer.apple.com/documentation/...` HTML fetches failed (JS-rendered / 404) and were replaced by the
  JSON equivalents.
- Some capability claims rest on vendor implementation sources (Chromium, WebKit, Electron, Maccy, KeyboardShortcuts)
  rather than Apple documentation; they are cited as implementation evidence, not as API guarantees.
- Items marked **[U]**/**[X]** are exactly the ones a prototype must settle; none of them invalidates the plan, but
  item 1 (pasteboard privacy) and item 3 (browser AX) can change the UX and scope materially.

## 7. Validation performed

- Read-only OS/toolchain checks: `sw_vers`, `uname -a`, `swift --version`, `clang --version`, `xcodebuild -version`
  (fails as noted), `node --version`, `gh --version`, `xcrun --show-sdk-path`.
- Grepped the local macOS 26 SDK headers this toolchain compiles against: `AppKit/NSPasteboard.h`,
  `AppKit/NSPasteboardItem.h`, `AppKit/NSSecureTextField.h`, `AppKit/NSWorkspace.h`, `AppKit/NSRunningApplication.h`,
  `ApplicationServices` `AXUIElement.h` / `AXAttributeConstants.h` / `AXRoleConstants.h` / `AXError.h`,
  `Carbon` `HIToolbox` `CarbonEvents.h` / `CarbonEventsCore.h`, `CoreGraphics/CGEvent.h`.
- Fetched Apple primary documents: `NSPasteboard.accessBehavior` enum + `changeCount` (docs JSON), `NSPasteboard` header
  comments for `detect`, AppKit release notes (April 2025 pasteboard privacy), archived TN2150 (secure event input),
  TN3127 (designated requirements), Apple Support's Spotlight clipboard-history page.
- Read primary implementation sources: Chromium (`clipboard_host_impl_mac.mm`, `secure_password_input.mm`,
  `browser_accessibility_cocoa.mm`, `app_shim_application.mm`, `docs/accessibility/overview.md`), WebKit
  (`WebViewImpl.mm`, `WebAccessibilityObjectWrapperMac.mm`), Electron (`electron_application.mm`), Maccy
  (`Clipboard.swift`), KeyboardShortcuts (`HotKey.swift`), gitleaks `config/gitleaks.toml`, detect-secrets and
  trufflehog READMEs.
- Cross-checked the sensitive-marker question by grepping the SDK (no AppKit constants) against the nspasteboard.org
  specification (markers are community conventions).
- Not validated: anything requiring execution, any TCC/System Settings interaction, and any claim marked **[U]**/**[X]**.

## 8. Sources

Primary (Apple / local SDK):

- [S1] Apple, `NSPasteboard.changeCount` — <https://developer.apple.com/documentation/appkit/nspasteboard/changecount>
- [S2] Local SDK, `AppKit/NSPasteboard.h` (`changeCount`, `accessBehavior`, `detect*`, `clearContents`, `prepareForNewContentsWithOptions:`, `declareTypes:owner:`) — `$(xcrun --show-sdk-path)/System/Library/Frameworks/AppKit.framework/Headers/NSPasteboard.h`
- [S3] Apple, `UIPasteboard.changedNotification` (iOS-only counterpart) — <https://developer.apple.com/documentation/uikit/uipasteboard/changednotification>
- [S5] Local SDK, `AppKit/NSPasteboard.h` / `NSPasteboardItem.h` (lazy "promise" data, `writeObjects:`, `pasteboardItems`)
- [S7] Local SDK, `AppKit/NSWorkspace.h` (`frontmostApplication`)
- [S9] Apple Support, "Search your Clipboard history in Spotlight on Mac" — <https://support.apple.com/guide/mac-help/search-your-clipboard-history-mchl40d5b86b/mac>
- [S10] Apple, `NSPasteboard.AccessBehavior` (enum + cases; `accessBehavior` property; macOS 15.4+) — <https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum>
- [S11] Apple, AppKit updates — "macOS pasteboard privacy" (April 2025) — <https://developer.apple.com/documentation/Updates/AppKit>
- [S12] Apple, `detectedPatterns(for:)` and pasteboard detection patterns — <https://developer.apple.com/documentation/appkit/nspasteboard/detectedpatterns(for:)>
- [S13] Apple, `detectedValues(for:)` — <https://developer.apple.com/documentation/appkit/nspasteboard/detectedvalues(for:)>
- [S17] Local SDK, `HIToolbox/CarbonEvents.h` (`RegisterEventHotKey`, `UnregisterEventHotKey`)
- [S19] Apple, `CGPreflightPostEventAccess` / `CGRequestPostEventAccess` / `CGPreflightListenEventAccess` / `CGRequestListenEventAccess` — <https://developer.apple.com/documentation/coregraphics/cgpreflightposteventaccess()>
- [S20] Apple, `NSEvent.addGlobalMonitorForEvents(matching:)` — <https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:)>
- [S22] Apple, Technical Note TN2150: "Using Secure Event Input Fairly" — <https://developer.apple.com/library/archive/technotes/tn2150/_index.html>
- [S23] Apple, `AXUIElementCreateSystemWide()` and `kAXFocusedUIElementAttribute` — <https://developer.apple.com/documentation/applicationservices/axuielementcreatesystemwide()>
- [S24] Local SDK, `HIServices/AXUIElement.h` (`AXIsProcessTrusted`, `AXIsProcessTrustedWithOptions`, `kAXTrustedCheckOptionPrompt`) and `AXError.h` (`kAXErrorAPIDisabled`)
- [S25] Local SDK, `HIServices/AXAttributeConstants.h` (`AXRole`, `AXSubrole`, `AXTitle`, `AXDescription`, `AXHelp`, `AXValue`, `AXSelectedText`, `AXPlaceholderValue`, `AXDocument`, `AXURL`, `AXFocused`)
- [S26] Local SDK, `HIServices/AXUIElement.h` (`AXUIElementSetAttributeValue`, `AXUIElementIsAttributeSettable`, `AXUIElementCopyAttributeValue`)
- [S33] Local SDK, `HIServices/AXRoleConstants.h` (`kAXSecureTextFieldSubrole`, `kAXTextFieldRole`)
- [S38] Apple, `kAXSecureTextFieldSubrole` — <https://developer.apple.com/documentation/applicationservices/kaxsecuretextfieldsubrole>
- [S39] Local SDK, `AppKit/NSSecureTextField.h`
- [S40] Local SDK, `HIToolbox/CarbonEventsCore.h` (`EnableSecureEventInput`, `DisableSecureEventInput`, `IsSecureEventInputEnabled` with doc comments)
- [S44] Local SDK, `CoreGraphics/CGEvent.h` (`CGEventCreateKeyboardEvent`-family, flags, `CGEventPost`, `CGEventPostToPid`, `CGEventKeyboardSetUnicodeString` doc comment)
- [S45] MDN, `input` event (fired for user edits) + React docs, `<input>` (`value` prop is source of truth) — <https://developer.mozilla.org/en-US/docs/Web/API/Element/input_event>, <https://react.dev/reference/react-dom/components/input>
- [S46] Apple, `CGEventKeyboardSetUnicodeString` local SDK doc comment (frameworks may ignore the Unicode string)
- [S48] Apple, "Resetting access to protected resources in macOS" (`tccutil`) — <https://developer.apple.com/documentation/xcode/resetting-access-to-protected-resources-in-macos>
- [S49] Apple, TN3127: "Inside Code Signing: Requirements" (privacy grants remembered via the designated requirement) — <https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements>
- [S50] Apple Developer Forums thread on sandboxed event posting (Apple reply) — <https://developer.apple.com/forums/thread/103992>
- [S35] Apple, WWDC19 "Advances in macOS Security" (window-name gating) + "Optional Window List Keys" — <https://developer.apple.com/videos/play/wwdc2019/701/>

Implementation evidence (browser/vendor/project source):

- [S6] nspasteboard.org, "Identifying and Handling Transient or Special Data on the Clipboard" — <http://nspasteboard.org/> (source: <https://github.com/NSPasteboard/NSPasteboard.org/blob/main/index.md>)
- [S8] Maccy, `Maccy/Clipboard.swift` — <https://github.com/p0deje/Maccy/blob/master/Maccy/Clipboard.swift>
- [S14] Chromium, `content/browser/renderer_host/clipboard_host_impl_mac.mm` — <https://chromium.googlesource.com/chromium/src/+/refs/heads/main/content/browser/renderer_host/clipboard_host_impl_mac.mm>
- [S15] Developer report FB17587626 (no request API for full pasteboard access) — <https://github.com/feedback-assistant/reports/issues/655>
- [S16] Grep of macOS 26 SDK AppKit headers: no concealed/transient/auto-generated constants (see [S2])
- [S18] sindresorhus/KeyboardShortcuts, `Sources/KeyboardShortcuts/HotKey.swift` (`RegisterEventHotKey`)
- [S27] Chromium, `docs/accessibility/overview.md` (`--force-renderer-accessibility`, "off by default … enabled automatically on-demand") — <https://github.com/chromium/chromium/blob/main/docs/accessibility/overview.md>
- [S28] Chromium, `chrome/app_shim/app_shim_application.mm` (`AXEnhancedUserInterface` activation comment) — <https://github.com/chromium/chromium/blob/main/chrome/app_shim/app_shim_application.mm>
- [S29] Electron, Accessibility tutorial (`AXManualAccessibility`) — <https://www.electronjs.org/docs/latest/tutorial/accessibility>
- [S30] Electron, `shell/browser/mac/electron_application.mm`
- [S31] WebKit, `Source/WebKit/UIProcess/Cocoa/WebProcessPoolCocoa.mm` (`AXEnhancedUserInterface` → web-process params)
- [S32] Chromium, `ui/accessibility/platform/browser_accessibility_cocoa.mm` (placeholder attribute for text fields; `NSAccessibilitySecureTextFieldSubrole` for atomic text field with `kProtected`)
- [S34] WebKit, `Source/WebCore/accessibility/mac/WebAccessibilityObjectWrapperMac.mm` (placeholder-value handler, subrole handling)
- [S41] Chromium, `ui/base/cocoa/secure_password_input.mm` + `content/browser/renderer_host/render_widget_host_view_mac.mm` (`ScopedPasswordInputEnabler` → `EnableSecureEventInput`)
- [S42] Chromium, `ui/views/controls/textfield/textfield.cc` (same enabler for native text fields)
- [S43] WebKit, `Source/WebKit/UIProcess/mac/WebViewImpl.mm` (`editorState().isInPasswordField` → `EnableSecureEventInput()`)
- [S47] Stack Overflow, "CGEventKeyboardSetUnicodeString() only processing up to 20 characters" (empirical; **[U]** here) — <https://stackoverflow.com/questions/48158421/>
- [S51] gitleaks, `config/gitleaks.toml` (222 rules; entropy thresholds; allowlists)
- [S52] Yelp detect-secrets, README (entropy plugins + heuristic filters) — <https://github.com/Yelp/detect-secrets>
- [S53] trufflesecurity/trufflehog, README (800+ detectors; `--results=verified` calls provider APIs)
- [S54] Basak et al., "A Comparative Study of Software Secrets Reporting by Secret Detection Tools", ESEM 2023 — <https://arxiv.org/abs/2307.00714>

Secondary (used only for orientation, always labeled in-text):

- [S21] Apple Developer Forums, "[macOS Sequoia] Using RegisterEventHotKey …" (Option-only Carbon shortcuts) — <https://developer.apple.com/forums/thread/763878>
- [S36] Mozilla bug 1664992, `AXEnhancedUserInterface` breaks window managers — <https://bugzilla.mozilla.org/show_bug.cgi?id=1664992>; Electron issue #7206 — <https://github.com/electron/electron/issues/7206>
- [S37] Automattic/harper PR #3600, `AXEnhancedUserInterface` rejected with `kAXErrorNotImplemented` on macOS 15.7.x — <https://github.com/Automattic/harper/pull/3600>
