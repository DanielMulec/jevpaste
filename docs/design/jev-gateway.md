# JevGateway — the `DecisionService` adapter

Slice: [Implement the JevGateway adapter](https://github.com/DanielMulec/jevpaste/issues/21). Contract:
[Choose Jev context and excerpt-selection semantics](https://github.com/DanielMulec/jevpaste/issues/7) and the
`spike/jev-contract` spikes (`abstention/` for the batched questions, `context/` for the Target Context fields).

## Request — one `POST https://ai-gateway.vercel.sh/v1/evaluate` per `requestDecision`
Headers: `Authorization: Bearer <key>`, `Content-Type: application/json`. Body (JSON, keys sorted):
```json
{ "model": "typesafe-ai/jev",
  "state": { "source_document": "<DecisionRequest.sourceDocument>",
             "target_context": { "field_label": "…", "placeholder": "…", "section_heading": "…",
                                 "sibling_field_labels": ["…"], "surrounding_text": "…" } },
  "questions": {
    "paste": { "type": "choice", "instructions": "<choice wording>",
               "criteria": { "c000": "<candidate 0>", "c001": "…", "none_of_these": "<abstain wording>" } },
    "contains_value": { "type": "boolean", "instructions": "<gate wording>",
                        "criteria": { "true": "…", "false": "…" } } } }
```
- `target_context` omits `nil` strings and empty values; the field names are the `TargetContext` properties.
  `surrounding_text` is sent as the resolver bounded it (the adapter does not trim it).
- Option id `c` + 3-digit zero-based index into `DecisionRequest.candidates`. The description is the
  Candidate with line breaks as spaces, cut to 255 characters (Jev's limit); only the id maps back, so a
  cut description never changes the Paste Result.
- Wording of the choice, `none_of_these` and gate questions is taken from `spikes/abstention/run.py`
  (`CHOICE_INSTRUCTIONS`, `GATE_POSITIVE`, `as_criteria`), with `target_field` renamed `target_context`.
- Jev accepts at most 255 options, `none_of_these` included, so at most **254 Candidates**. More → `.failed`
  without a call (a 256-option request is an HTTP 400 anyway).

## Response parsing
Only `answers.paste.choice` (string) and `answers.contains_value.probability` (number in 0…1) are read.
Everything else (`probabilities`, `confidence`, `usage`, `providerMetadata`) is ignored.

## Mapping to `DecisionReply`
| HTTP / body | reply |
|---|---|
| 200, `choice` = `cNNN` with NNN < candidate count | `.decided(Decision(choice: .candidate(candidates[NNN]), containsValueProbability: p))` |
| 200, `choice` = `none_of_these` | `.decided(Decision(choice: .noneOfThese, containsValueProbability: p))` |
| 200, `choice` id unknown or out of range, `p` missing or outside 0…1, JSON malformed | `.failed` |
| 429 with `retry-after: <seconds>` (integer or decimal ≥ 0) | `.rateLimited(retryAfter: .seconds(min(n, 60)))` |
| 429 without a finite, non-negative `retry-after` | `.rateLimited(retryAfter: .seconds(1))` (free tier ≈ 1 call/s) |
| any other status, transport error | `.failed` |
| key file missing/unreadable, or no non-empty `AI_GATEWAY_API_KEY=` line | `.failed`, no call |
| more than 254 Candidates | `.failed`, no call |

The gate threshold (< 0.5) and the verbatim/offered checks stay in Core; the adapter only reports.
No retry and no timeout here: `URLRequest.timeoutInterval` is left at the system default because the Paste
Attempt drops late replies itself.

## Error taxonomy (diagnostics only)
`JevGatewayFailure`: `missingKey(file:)`, `tooManyCandidates(count:)`, `malformedRequest` (encoding),
`transport`, `httpStatus(Int)`, `malformedResponse`, `unknownChoice`. Each `.failed` logs one line through `os.Logger`
(subsystem `jevpaste`, category `JevGateway`) with the case, and `.decided`/`.rateLimited` log the latency and
option count. Never logged: the key, source document, Target Context, Candidates, request or response body.
`missingKey` names the file path (`~/.config/jevpaste/env`), never a value.

## Seams
- `JevGatewayDecisionService(credentials:transport:)`, `Sendable` struct. `requestDecision` starts one
  `Task`, awaits the transport, then calls `reply` exactly once on the main actor (`await reply(result)`).
- `HTTPTransport: Sendable { func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) }`;
  production `URLSessionTransport` (`URLSession.shared`). Unit tests inject a stub that records the request
  and returns canned status/headers/body — no network.
- `GatewayCredentials(envFile: URL)` reads the key at each call (a later Keychain slice replaces it); tests
  point it at a temporary file. Default: `~/.config/jevpaste/env`. Accepts an optional `export ` prefix and
  surrounding quotes. `hasAPIKey` tells the live test (and later the shell) whether a key exists.
- Files: `JevGatewayDecisionService.swift` (orchestration), `EvaluateRequestBody.swift` (encoding),
  `EvaluateResponse.swift` (decoding + mapping), `GatewayCredentials.swift`, `HTTPTransport.swift`,
  `JevGatewayFailure.swift`, `RateLimit.swift` (`retry-after`). Tests split by concern: request shape, reply mapping, rate limit, credentials.

## Live test
`JEVPASTE_LIVE_JEV=1` and a readable key → one real call with a synthetic document (name/email/city lines,
target `Email address`), expects `.decided` with the email Candidate and reports the wall-clock latency.
Otherwise the test is skipped via `.enabled(if:)`, so `make check` stays offline.

## Open questions
1. Candidate derivation caps at 255; with `none_of_these` the adapter can take 254. Cap derivation at 254?
2. HTTP-date `retry-after` values are treated as absent (1 s). Not observed in the spikes.
