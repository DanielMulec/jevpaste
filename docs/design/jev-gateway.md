# JevGateway — the `DecisionService` adapter for every Jev Provider

Slices: [Implement the JevGateway adapter](https://github.com/DanielMulec/jevpaste/issues/21), [Add Typesafe direct as a
Jev Provider](https://github.com/DanielMulec/jevpaste/issues/54). Contract: [Choose Jev context and excerpt-selection
semantics](https://github.com/DanielMulec/jevpaste/issues/7), decision 7 of [Decide how JevPaste supports Typesafe
direct alongside the Vercel AI Gateway](https://github.com/DanielMulec/jevpaste/issues/45) (one module, a per-provider
table, shared encoding and parsing). Since Narrowing ([#50](https://github.com/DanielMulec/jevpaste/issues/50)) one
Narrowing step per call; what the request holds is Core's — [narrowing.md](narrowing.md).

## The provider table (`JevEndpoint.swift`) — the only place a provider differs
| | Vercel AI Gateway | Typesafe direct |
|---|---|---|
| request | `POST https://ai-gateway.vercel.sh/v1/evaluate` | `POST https://api.typesafe.ai/v1/systemone` |
| `model` sent (pinned) | `typesafe-ai/jev` | `jev-1.13.0` (never `jev-latest`: Core's thresholds were set on 1.13.0) |
| overload status → `.rateLimited` | — (not documented) | `529` |
A value per provider (`JevEndpoint.of(_ provider:)`, a `switch`), not a protocol: the providers differ in data, not
in control flow, so one request path serves both. Headers are shared: `Authorization: Bearer <key>`,
`Content-Type: application/json`. Body: `{"model":…,"state":…,"questions":…}` — `state` and `questions` exactly as
Core renders them (`NarrowingRequest.stateJSON` / `questionsJSON`, `OrderedJSON`, member order kept); the adapter adds
only `model`. N choice questions per step, ≤ 255 options each, descriptions in full; no `boolean`/`noul` question
exists, so the research's yes/no difference does not apply.

## Response parsing (`EvaluateResponse`, own ordered parser) — shared
For every question asked: `answers.<id>.choice` (one of that question's option ids) and `answers.<id>.probabilities`
(numbers in 0…1), kept **in the order Jev listed them** — it breaks ties in Core. Everything else is ignored:
`confidence`, `usage` (camelCase on the Gateway, snake_case direct), `providerMetadata` (Gateway only). The answered
`model` is logged (≤ 40 characters, a model id, never payload).

## Mapping to `NarrowingReply` — shared, fixtures per provider
| HTTP / body | reply |
|---|---|
| 200, every question answered with an offered id and valid probabilities | `.answered([questionID: ChoiceAnswer])` |
| 200, a question missing, an unknown choice id, a probability outside 0…1, JSON malformed | `.failed` |
| 429 (both), or the table's overload status (direct `529`) | `.rateLimited(retryAfter:)` — the wait below |
| wait: `retry-after-ms` (≥ 0, ms), else `retry-after` (seconds, integer or decimal ≥ 0), else 1 s; clamped to 60 s | |
| 400 carrying `{"error_type":"max_tokens_exceeded"}` — top level or under `detail` (direct), as `error.message` / `error.param.error` or in any `providerAttempts[].error` (Gateway) | `.tooLarge` |
| 401 / 403 (direct answers a missing key with 403, its docs say 401), 402, 422 (direct validation), other 400s, 5xx, transport error | `.failed` |
| no key for the chosen provider (decided in `JevGatewayAccess`, before a service exists) | Core refusal, no call |
Byte-exact checks, the follow-up rule and every outcome stay in Core; no retry and no timeout here: the Paste Attempt
owns the 5 s clock and retries a `.rateLimited` inside it.

## Error taxonomy (diagnostics only)
`JevGatewayFailure`: `transport`, `httpStatus(Int)`, `malformedResponse`, `unknownChoice`. Each `.failed` logs one
line through `os.Logger` (subsystem `jevpaste`, category `JevGateway`); every reply logs
`Jev <outcome> provider=<raw value> status=… model=… questions=… options=… bytes=… in <latency>`. Never logged: the
key, source document, Target Context, excerpts, request or response body, any filesystem path.

## Seams
- `JevGatewayDecisionService(provider:apiKey:transport:)`, `Sendable` struct, `DecisionService`. `evaluate` starts one
  `Task`, awaits the transport, calls `reply` exactly once on the main actor. It holds `JevEndpoint.of(provider)`.
- `HTTPTransport: Sendable { func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) }`; production
  `URLSessionTransport` (`URLSession.shared`, or an injected session for the cold/warm measurement). Unit tests inject
  a stub that records the request and returns canned status/headers/body — no network.
- `JevGatewayAccess(credentials:chosenProvider:transport:)` (`JevProviderAccess`): at ⌘⇧V reads the chosen Jev
  Provider and its key once and returns that provider's service; no key → `.noKey(provider)`, never the other
  provider. Both providers are built; `builtProviders` and Settings' disabled state are gone.
- Keys: `JevCredentials.apiKey(for:)`, in the app the user-only files `~/.config/jevpaste/keys/<provider raw value>`
  (`FileJevKeyStore`, [menu-and-settings.md](menu-and-settings.md)). Typesafe direct has no env import.
- Settings' Test = `JevGatewayAccess.testConnection(of:)`: one choice question with one option, through the same
  exchange → `.works` | `.failed(reason)`; every result text names the provider.
- `GatewayCredentials(envFile:)` reads `AI_GATEWAY_API_KEY` from `~/.config/jevpaste/env` — only the one-time import.
- Files: `JevEndpoint.swift` (the table), `JevGatewayDecisionService.swift` (orchestration, logging),
  `EvaluateRequestBody.swift` (encoding), `EvaluateResponse.swift` (decoding), `JevRefusal.swift` (size refusal),
  `RateLimit.swift` (the wait), `JevGatewayFailure.swift`, `HTTPTransport.swift`, `JevGatewayAccess.swift`,
  `JevConnectionTest.swift`, `JevCredentials.swift`, `GatewayCredentials.swift`, `OrderedJSONParser.swift` (+`Lookup`).

## Live tests (skipped unless `JEVPASTE_LIVE_JEV=1`; `make check` stays offline)
Keys come from the key files per provider; a provider without a key file is skipped. Output: labelled numbers and
fixture cell ids only — never a key, its length, or any document/excerpt text.
- `JevGatewayLiveTests`: one step-1 request per provider over a synthetic card → a piece holding the email.
- `JevGatewayLiveReplayTests`: the 14 recorded Narrowing cells (`Fixtures/narrowing-replay.jsonl`) driven through
  Core's `Narrowing` with **live** answers per provider → per cell `outcome` (paste/nothing/ask), `same` as recorded,
  chosen `p` of the last call (live and recorded), `calls`, latency. Near-tie cells B06/N03 also accept their one
  observed alternative (run log 2026-09-27). Offline, the harness fed the recorded answers ends every cell as recorded.
- `JevGatewayLiveLimitsTests`: per provider a fresh ephemeral `URLSession` → 1 cold + 5 warm step-1 calls, median;
  one ≈ 400,000-character request → status, `error_type`, `.tooLarge`.

## Open questions
1. HTTP-date `retry-after` values are treated as absent (1 s). Not observed live on either provider.
2. Direct: the status for spent credits and whether an invalid (not missing) key gets 401 or 403 — both `.failed`.
