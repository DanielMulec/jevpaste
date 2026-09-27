# Pre-check rules — design

Slice: [Implement Pre-check rules](https://github.com/DanielMulec/jevpaste/issues/20). Spec:
[Choose clipboard-history storage and practical secret protection](https://github.com/DanielMulec/jevpaste/issues/6)
(last comment) and [Choose paste lifecycle, cancellation and clipboard preservation](https://github.com/DanielMulec/jevpaste/issues/8)
§2. No multi-line rule: [Verify multi-line Paste Results insert line breaks without sending](https://github.com/DanielMulec/jevpaste/issues/14).

## Refusals (in this order; each: visible reason, zero Jev calls, zero pasteboard writes)
| # | rule | detection | outcome | test |
|---|---|---|---|---|
| 0 | no editable Target | resolver returns `nil` (coordinator, unchanged) | `.refused(.noEditableTarget)` | existing `eachPreCheckRefuses…` |
| 1 | secure Target | `BoundTarget.isSecureField` (AX secure field or secure event input, MacInterop) | `.secureField` | `LocalPreChecksTests` |
| 2 | concealed/transient item | `ClipboardItem.isConcealed` (markers read in MacInterop, unchanged) | `.suspectedSecret` | `LocalPreChecksTests` |
| 3 | suspected secret in item text | first `SuspectedSecretRule` of `SuspectedSecretRules.standard` that matches | `.suspectedSecret` | `LocalPreChecksTests` + per rule below |

## Suspected-secret rules (gitleaks-style shapes, no entropy; one named `static let` each)
Scanned over the UTF-8 bytes. "Boundary" = the byte before the match is not an ASCII letter, digit, `_` or `-`.
| rule | matches | test (`SuspectedSecretRuleTests`, `PrefixedTokenRuleTests`, `StructuredSecretRuleTests`) |
|---|---|---|
| `pemPrivateKey` | `-----BEGIN ` … `PRIVATE KEY-----` on one line (RSA/EC/OPENSSH/ENCRYPTED/plain) | positive + public-key/certificate negative |
| `awsAccessKey` | boundary `AKIA` + ≥16 `[A-Z0-9]` | positive + short/lowercase negative |
| `gitHubToken` | boundary `ghp_` + ≥36 `[A-Za-z0-9]`; `github_pat_` + ≥82 `[A-Za-z0-9_]` | both + short negative |
| `slackToken` | boundary `xox` + one of `baprs` + `-` + ≥10 `[A-Za-z0-9-]` | positive + `xoxz-` negative |
| `stripeLiveKey` | boundary `sk_live_` + ≥16 `[A-Za-z0-9]` | positive + `sk_test_` is `stripeTestKey`'s, not this |
| `stripeTestKey` | boundary `sk_test_` + ≥16 `[A-Za-z0-9]` (mirror of `stripeLiveKey`) | in a sentence + short negative |
| `openAIStyleKey` | boundary `sk-` + ≥20 `[A-Za-z0-9_-]` (OpenAI, Anthropic); recall over precision — a standalone `sk-` slug is an accepted false positive | positive + `task-…`/short negatives + `OpenAIStyleKeyTradeOffTests` |
| `googleAPIKey` | boundary `AIza` + ≥35 `[A-Za-z0-9_-]` | positive + short negative |
| `vercelAIGatewayKey` | boundary `vck_` + ≥20 `[A-Za-z0-9_-]` (Vercel AI Gateway, documented) | in a sentence + short/`xvck_` negatives |
| `jsonWebToken` | boundary, three `.`-separated base64url segments, first two start `eyJ`, each ≥10 | positive + two-part negative |
| `connectionStringCredentials` | `scheme://user:password@host` — non-empty password (user may be empty, `redis://:pw@`) and host, before the first `/?#`/whitespace; `host:443@other` is accepted userinfo | postgres/mongodb/redis + `https://host/a@b`, user-only, empty-password, empty-host negatives |
| `opaqueToken` | **whole text**, trimmed of ASCII whitespace: ≥16 bytes, only `[A-Za-z0-9_-]`, ≥1 letter and ≥1 digit; **Active Item only** — see below | `OpaqueTokenRuleTests` (issue #56 corpus), `OpaqueTokenTradeOffTests` |

**The whole-text rule.** Every other rule finds its shape *anywhere*; `opaqueToken` asks whether the whole Active Item
*is* one token — a copied API key of any vendor, whatever its prefix
([Refuse any copied API key at ⌘⇧V, whatever its vendor](https://github.com/DanielMulec/jevpaste/issues/56)).
The allow-list excludes whitespace and `.` `/` `@` `:`, so URLs, paths, emails, domains, times, sentences and
structured text never match; a key inside a sentence is left to the prefix rules. What it also catches — git SHAs,
UUIDs, hashes, licence keys, IBANs — has no cut points: Jev's only possible answer is "paste it whole", which ⌘V
does. A false positive costs one keystroke. A digit is required (Gate A, 2026-09-27): hyphenated or snake_case
words, identifiers and branch names are common copies, while a ≥16-byte key without a digit is rare (base62: ~6 %
at 16 bytes, < 0.5 % at 32) — an accepted miss. One pass after trimming: a letter sets one flag, a digit the other,
`-`/`_` neither, any other byte (non-ASCII too) stops the scan. It is last in `standard`, so a named prefix rule
still names the match; deleting that one entry disables it. **Item-only** (Daniel, review 2026-09-27): the Target
Context is screened with `SuspectedSecretRules.anywhere` (= `standard` without it), so surrounding text or a window
title that is one bare token — a commit hash, a ticket id — is sent unchanged: it was not copied, withholding it
would cost Jev context, and a key shown on screen inside text is still caught by the prefix rules
(`OpaqueTokenItemOnlyTests`).

Linear time, no regex: every prefix rule reads at most its fixed minimum body after each prefix hit; the JWT and
connection-string scans start only at boundaries / `://` and stop at the first delimiter, so no byte is re-read
more than a constant number of times. Proof test: adversarial 256 KB inputs (`sk-sk-…`, `eyJ.eyJ.…`,
`a://a://…`, `-----BEGIN -----BEGIN …`, …) finish under 5 s in a debug build (measured 0.1–0.8 s; with the JWT
token-start guard removed the suite ran > 120 s — a quadratic scan fails by orders of magnitude). The whole-text
cases — one 256 KB token `a1a1…` (refused as `opaqueToken`) and the same with one space in the middle (no match) —
take ≈ 0.6 s each serially, 17 ms of it the Opaque Token scan; the rest is the other rules on a text of token starts.

## Types and files (`Sources/SmartPasteCore/PreChecks/`)
- `ScannedText.swift` — UTF-8 bytes + the shared linear scans (`offsets(of:)`, `startsToken(at:)`, capped `run`),
  `ByteClass`. `SuspectedSecretRule.swift` — the rule value (`name`, `matches(_:)`) and the eight prefix-token rules.
- `StructuredSecretShapes.swift` — PEM, JWT, connection-string rules. `OpaqueTokenShape.swift` — the whole-text rule. `SuspectedSecretRules.swift` — the set
  (`anywhere` for the Target Context, `standard` = `anywhere` + `opaqueToken` for the Active Item,
  `firstMatch(in:) -> SuspectedSecretRule?`).
- `LocalPreChecks.swift` — the Core `PreCheck` adapter: refusals 1–3 and the context screening below.
- `Values/ScreenedTargetContext.swift` — `ScreenedTargetContext` + `PasteAttemptNote`.
- Shell: `SmartPasteApplication` composes `LocalPreChecks()`; the interim type and its test are deleted;
  `OutcomeMessage` appends the note. Tests: `Tests/SmartPasteCoreTests/{SuspectedSecretRuleTests,
  StructuredSecretRuleTests, SuspectedSecretRulesTests, LocalPreChecksTests, PasteAttemptContextScreeningTests}
  .swift`; app: `OutcomeMessageTests`, `IndicatorPresenterTests` (note wording and duration).

## GATE A — secrets in the Target Context (not a refusal)
1. **Where:** the `PreCheck` seam gains `screenedContext(of: BoundTarget) -> ScreenedTargetContext`; the
   coordinator calls it once at attempt start, pins the result in `RunningAttempt`, and builds every
   `DecisionRequest` (retries too) from it. A match of an `anywhere` rule (not `opaqueToken`) empties
   `surroundingText`; labels, placeholder, heading and sibling labels are still sent (per the decision; they are not scanned). Since the Free-text Target slice the
   window title is scanned the same way (hit → omitted, note `.windowTitleWithheld` or
   `.surroundingTextAndWindowTitleWithheld`); the app name is not scanned.
2. **Port/outcome change (explicit):** `PasteOutcomePresenter.showOutcome(_:)` becomes
   `showOutcome(_:note:)` with `note: PasteAttemptNote?` (`.surroundingTextWithheld`); `PasteAttemptOutcome` is
   unchanged. Every outcome after screening carries the note (inserted, no match, failed, cancelled); refusals never.
   Empty Candidate extraction ends in `.noSuitableMatch` before screening, with no note: nothing was sent.
3. **Visible note:** the outcome line gets the suffix ` · nearby text withheld (suspected secret)`, e.g.
   "Pasted · nearby text withheld (suspected secret)", shown ≥2.5 s even on success. Log: `note=surroundingTextWithheld`.

## Live-run plan (gated, batched with the other workers)
After `make install`: the supervisor runs `printf 'ghp_JEVPASTE0000000000000000000000000000' | pbcopy`; Daniel
presses ⌘⇧V in a Chrome `data:text/html,<textarea>` → "Suspected secret — blocked", nothing inserted,
`pbpaste` unchanged. Then `printf 'Email: jev.probe@example.org' | pbcopy` → ⌘⇧V → ✓. Evidence:
`log show --last 5m --predicate 'subsystem == "jevpaste"' --style compact` (outcome kinds only, no payloads).
