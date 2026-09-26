# JevGateway — the `DecisionService` adapter

Slice: [Implement the JevGateway adapter](https://github.com/DanielMulec/jevpaste/issues/21). Contract:
[Choose Jev context and excerpt-selection semantics](https://github.com/DanielMulec/jevpaste/issues/7) and the
`spike/jev-contract` spikes (`abstention/` for the batched questions, `context/` for the Target Context fields).

Since Narrowing ([#50](https://github.com/DanielMulec/jevpaste/issues/50)) this adapter sends one Narrowing step
per call; what the request holds, its wordings and its size are Core's — [narrowing.md](narrowing.md).

## Request — one `POST https://ai-gateway.vercel.sh/v1/evaluate` per `evaluate(_:reply:)`
Headers: `Authorization: Bearer <key>`, `Content-Type: application/json`. Body: `{"model":"typesafe-ai/jev",
"state":…,"questions":…}` — `state` and `questions` exactly as Core renders them (`NarrowingRequest.stateJSON` /
`questionsJSON`, one ordered compact JSON writer, `OrderedJSON`), member order kept; the adapter adds only `model`.
- N choice questions (`type: "choice"`) per step, each with up to 255 options: the unchanged piece, the pieces,
  `nothing_fits`, `ask_user`. Option descriptions go in full and verbatim, real line breaks included — no
  255-character cut (it was never Jev's limit), no cap, no local wording. No `boolean` question remains.
- `state` = `source_document`, `target_context` (nil strings and empty values left out; `app_name`, `window_title`
  screened in Core like `surrounding_text`; the bundle id is never sent) and, in the excerpt-id form, `excerpts`.

## Response parsing (`EvaluateResponse`, own ordered parser)
For every question asked: `answers.<id>.choice` (must be one of that question's option ids) and
`answers.<id>.probabilities` (numbers in 0…1), kept **in the order Jev listed them** — it breaks ties in Core.
Everything else (`confidence`, `usage`, `providerMetadata`) is ignored.

## Mapping to `NarrowingReply`
| HTTP / body | reply |
|---|---|
| 200, every question answered with an offered id and valid probabilities | `.answered([questionID: ChoiceAnswer])` |
| 200, a question missing, an unknown choice id, a probability outside 0…1, JSON malformed | `.failed` |
| 429 with `retry-after: <seconds>` (integer or decimal ≥ 0) | `.rateLimited(retryAfter: .seconds(min(n, 60)))` |
| 429 without a finite, non-negative `retry-after` | `.rateLimited(retryAfter: .seconds(1))` |
| 400 carrying `{"error_type":"max_tokens_exceeded"}` — as `error.message` / `error.param.error`, or inside any `providerAttempts[].error` (the Gateway's "typesafe returned status 400" form) | `.tooLarge` |
| any other status (other 400s included), transport error | `.failed` |
| key file missing/unreadable, or no non-empty `AI_GATEWAY_API_KEY=` line | `.failed`, no call |

Byte-exact checks, the follow-up rule and every outcome stay in Core; the adapter only reports. No retry and no
timeout here: the Paste Attempt drops late replies itself.

## Error taxonomy (diagnostics only)
`JevGatewayFailure`: `missingKey`, `transport`, `httpStatus(Int)`, `malformedResponse`, `unknownChoice`. Each
`.failed` logs one line through `os.Logger` (subsystem `jevpaste`, category `JevGateway`); every reply logs the
status, the question and option counts, the request bytes and the latency. Never logged: the key, source document,
Target Context, excerpts, request or response body, and no filesystem path: `missingKey` carries nothing (review
finding, 2026-09-26).

## Seams
- `JevGatewayDecisionService(credentials:transport:)`, `Sendable` struct. `evaluate` starts one
  `Task`, awaits the transport, then calls `reply` exactly once on the main actor (`await reply(result)`).
- `HTTPTransport: Sendable { func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) }`;
  production `URLSessionTransport` (`URLSession.shared`). Unit tests inject a stub that records the request
  and returns canned status/headers/body — no network.
- `GatewayCredentials(envFile: URL)` reads the key at each call (a later Keychain slice replaces it); tests
  point it at a temporary file. Default: `~/.config/jevpaste/env`. Accepts an optional `export ` prefix and
  surrounding quotes. `hasAPIKey` tells the live test (and later the shell) whether a key exists.
- Files: `JevGatewayDecisionService.swift` (orchestration), `EvaluateRequestBody.swift` (encoding),
  `EvaluateResponse.swift` (decoding + mapping), `GatewayCredentials.swift`, `HTTPTransport.swift`,
  `JevGatewayFailure.swift`, `JevRefusal.swift` (the 400 size refusal), `OrderedJSONParser.swift` (+`Lookup`),
  `RateLimit.swift` (`retry-after`). Tests: `NarrowingRequestEncodingTests`, `NarrowingReplyTests`,
  `NarrowingReplayTests`, `JevGatewayRateLimitAndKeyTests` (`JevGatewayRateLimitTests`, `JevGatewayKeyTests`).

## Live test
`JEVPASTE_LIVE_JEV=1` and a readable key → one real step-1 request with a synthetic document (name/email/city lines,
target `Email address`), expects `.answered` with a piece holding the email and reports the wall-clock latency.
Otherwise skipped via `.enabled(if:)`, so `make check` stays offline.

## Open questions
1. HTTP-date `retry-after` values are treated as absent (1 s). Not observed in the spikes.
