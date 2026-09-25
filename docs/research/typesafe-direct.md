# Jev direct from TypeSafe vs through the Vercel AI Gateway: primary-source research

- Ticket: [Establish Typesafe's direct Jev API versus the Vercel AI Gateway](https://github.com/DanielMulec/jevpaste/issues/44) (map: [#1](https://github.com/DanielMulec/jevpaste/issues/1); blocks [#45](https://github.com/DanielMulec/jevpaste/issues/45))
- Branch: `research/typesafe-direct` (base `cc4257e`); report at `docs/research/typesafe-direct.md`
- Predecessor: `docs/research/jev-vercel.md` on branch `research/jev-vercel` (not merged to `main`). This report reuses its structure and re-checks every number it depends on.
- Research date: 2026-09-25. All sources were retrieved live in this session. Prices, limits and aliases are marked as dynamic by both vendors.
- Scope: direct endpoint and auth, request/response shape against what `JevGateway` sends and reads today, rate limits, pricing and free tier, and documented latency. No account was created, no key was read or used, and no billable call was made. This is research only; nothing here is an architecture decision.
- Evidence classes: **[fact]** means a first-party source states it or a live unauthenticated probe showed it. **[inference]** means it is reasoned from facts. **[unknown]** means no authoritative source was found. **[secondary]** means only third-party write-ups say it, so no conclusion rests on it.

## 1. Verdict (short)

1. **[fact]** Direct endpoint: `POST https://api.typesafe.ai/v1/systemone`, with `Authorization: Bearer <API_KEY>` and `Content-Type: application/json`. Keys come from the TypeSafe console at `https://console.typesafe.ai/keys`. The SDKs read the key from `TYPESAFE_API_KEY` (and an optional base URL from `TYPESAFE_BASE_URL`). The key format is not documented.
2. **[fact]** The **envelope is the same** (`model`, `state`, `questions`, then `answers`). Choice questions and answers are identical. **Yes/no questions are not the same:** the direct API has no `boolean` type. It is named `noul` in the question (`"type": "noul"`) and the answer carries its probability in a field named `noul`, not `probability`. TypeSafe's OpenAPI discriminator accepts only `noul`, `choice` and `score`. Our `contains_value` and `free_text` questions would therefore fail validation, and the two probabilities that Core needs would have to be read from a renamed field. The `model` value changes from `typesafe-ai/jev` to `jev-latest` or a pinned `jev-1.13.0`. `usage` switches to snake_case, and `providerMetadata` is gone. See §3 for every field.
3. **[fact]** Rate limits on the direct API are **250,000 tokens/s and 1,200 requests/min**, "adjusting dynamically… can change without notice". A request over either limit returns `429`. The docs say the SDKs "honor the `retry-after` header **when the response carries one**", so the header is optional. The direct API also documents **`529 Overloaded`** (retry with backoff), which the Gateway docs don't mention. The Gateway's paid tier adds no limit of its own (the provider's limits still apply). Its free tier has lower per-model limits whose numbers are not published.
4. **[fact]** The **price is identical**: $0.042 per 1M input tokens, and output is free, both direct and through the Gateway (which charges no markup). What differs is how billing works. The Gateway's free tier includes **$5/month** of credit. TypeSafe direct runs on **prepaid credits**: they expire after 12 months, auto-refill is optional, and TypeSafe may issue "Promotional Credits" at its discretion. **[unknown]** TypeSafe doesn't publish a direct free-credit amount. **[secondary]** Third-party write-ups say new accounts get $5 and that the waitlist was removed around 2026-09-20/21.
5. **[fact]** TypeSafe's documented latency comes only from vendor self-reports: "most queries complete in about 100 ms", "70ms–500ms end-to-end", and cookbook means of 111–114 ms. Neither vendor publishes a direct-vs-Gateway comparison, and Vercel's own latency metrics for Jev are `null`. **[fact, measured here, unauthenticated]** `api.typesafe.ai` resolves to AWS **us-west-2** (Oregon). From this Mac, a cold TLS handshake to it takes about 0.53–0.63 s, against about 0.08 s to Vercel's `fra1` edge. See §6.
6. **[fact] New since the #2 research:** the Gateway now lists a **second provider for `typesafe-ai/jev`: DigitalOcean**, added 2026-09-24, and DigitalOcean is marked ZDR-ineligible. The model-level catalog entry now reads `"zdr": "none"`, where the earlier research recorded `"all"`. Our Gateway requests don't send `providerOptions`, so **[unknown]** which provider actually serves them is now open. Going direct removes that ambiguity.

## 2. Endpoint and authentication

| | TypeSafe direct | Vercel AI Gateway (what the app uses today) |
| --- | --- | --- |
| Evaluate | `POST https://api.typesafe.ai/v1/systemone` | `POST https://ai-gateway.vercel.sh/v1/evaluate` |
| List models | `GET https://api.typesafe.ai/v1/models` (lists aliases; versioned IDs are accepted even when unlisted) | `GET https://ai-gateway.vercel.sh/v1/models` |
| Header | `Authorization: Bearer <API_KEY>` (OpenAPI `securitySchemes.HTTPBearer`) | `Authorization: Bearer <AI_GATEWAY_API_KEY>` |
| Where keys come from | TypeSafe console, `https://console.typesafe.ai/keys` | Vercel dashboard → AI Gateway → API Keys |
| Conventional env var | `TYPESAFE_API_KEY` (SDK constant `API_KEY_ENV`); `TYPESAFE_BASE_URL` defaults to `https://api.typesafe.ai` | `AI_GATEWAY_API_KEY` |
| Key format / expiry / scopes | **[unknown]** not documented | Gateway keys "never expire unless you revoke them" (per #2 research) |
| Request id in response | `x-typesafe-request-id` header (SDK exposes it as `request_id`; observed live on a 403) | `x-vercel-id` observed; whether the TypeSafe id is forwarded is **[unknown]** |

Sources: https://docs.typesafe.ai/api, https://docs.typesafe.ai/introduction/quickstart, https://api.typesafe.ai/openapi.json, https://docs.typesafe.ai/sdk/python/api/constants, https://docs.typesafe.ai/sdk/javascript/api/interfaces/TypeSafeClientConfig, https://docs.typesafe.ai/models, https://vercel.com/docs/ai-gateway/modalities/evaluation.

- **[fact]** The official JS SDK (`@typesafe-ai/sdk@0.6.0`, `dist/index.mjs`) sends `Authorization: Bearer …`, `Accept: application/json`, `Content-Type: application/json`, `User-Agent`/`X-TypeSafe-SDK: typesafe-sdk/<v>`, `X-TypeSafe-Runtime`, and on retries `X-TypeSafe-Retry-Count`. Only the Bearer header is documented as required. Our current headers (Bearer + Content-Type) are enough.
- **[fact, probe]** An unauthenticated `POST /v1/systemone` and `GET /v1/models` return **`403`** with the body `{"detail":{"error_type":"authentication_error","message":"Must supply an API key! …"}}`. The API reference only lists `401` ("Missing or invalid API key"). So a **missing** key gets `403` in practice. **[unknown]** whether an **invalid** key gets `401` or `403` (not probed: no key-like value was sent).
- **[fact]** The Gateway also offers a TypeSafe-compatible pass-through, `POST https://ai-gateway.vercel.sh/typesafe/v1/systemone`. It uses TypeSafe's request and response shapes but authenticates with the **Gateway** key and `model: "typesafe-ai/jev"`. https://vercel.com/docs/ai-gateway/sdks-and-apis/typesafe
- **[fact]** Access: the TypeSafe homepage now shows "Sign in" and "Contact sales" in its navigation and describes Jev as "in early access". The homepage FAQ's answer to "How do I get started?" still reads "Join the waitlist!". Issue #44 states Daniel can now get an account, so gating is not investigated further. **[secondary]** Third-party write-ups report that the waitlist was dropped around 2026-09-20/21.

## 3. Field-by-field: what `JevGateway` sends and reads vs TypeSafe direct

Legend: **same** means byte-identical on the wire. **renamed** means same meaning, different field name or value. **absent** means not present on direct. **new** means present on direct only. "Read?" says whether the adapter uses the value today.

Direct-side sources: the OpenAPI schema at https://api.typesafe.ai/openapi.json (`SystemOneRequest`, `NoulQuestion`, `ChoiceQuestion`, `SystemOneResponse`, `NoulAnswer`, `ChoiceAnswer`, `Usage`, `HTTPValidationError`) and https://docs.typesafe.ai/api. Gateway-side sources: `Sources/JevGateway/*.swift`, `docs/design/jev-gateway.md` and https://vercel.com/docs/ai-gateway/modalities/evaluation.

### 3.1 Transport (`JevGatewayDecisionService.swift`, `GatewayCredentials.swift`)

| Item | Today (Gateway) | Direct | Status |
| --- | --- | --- | --- |
| URL | `https://ai-gateway.vercel.sh/v1/evaluate` | `https://api.typesafe.ai/v1/systemone` | **renamed** |
| Method | `POST` | `POST` | same |
| `Authorization` | `Bearer <AI_GATEWAY_API_KEY>` | `Bearer <TypeSafe key>` | same scheme, **different credential** |
| `Content-Type` | `application/json` | `application/json` | same |
| Key source | `AI_GATEWAY_API_KEY=` line in `~/.config/jevpaste/env` | any name the app picks; the vendor convention is `TYPESAFE_API_KEY` | **renamed** (app-side choice) |

### 3.2 Request body (`EvaluateRequestBody.swift`)

| JSON path | Today | Direct | Status |
| --- | --- | --- | --- |
| `model` | `"typesafe-ai/jev"` | `"jev-latest"` (alias, moves without notice), `"jev-preview"`, or pinned `"jev-1.13.0"`; required | field same, **value renamed** |
| `state` | object | `string \| object \| array`; required | same |
| `state.source_document` | string | free-form content inside `state` (no schema) | same |
| `state.target_context` (`field_label`, `placeholder`, `section_heading`, `sibling_field_labels`, `surrounding_text`, `app_name`, `window_title`; empty ones omitted) | object | free-form content inside `state` | same |
| `questions` | map of 3 | `map<string, Question>`, `minProperties: 1`; the keys "are not sent to the underlying model" | same |
| `questions.paste.type` | `"choice"` | `"choice"` | same |
| `questions.paste.instructions` | string | `string \| object \| array \| null` | same |
| `questions.paste.criteria` (`c000`…`c253`, `none_of_these` → string) | map ≤ 255 | `map<string, string\|object\|array\|null>`; "maximum of 255 options per Choice" | same (same 255 limit) |
| `questions.contains_value.type` | `"boolean"` | **`"noul"`**. `boolean` is not in the discriminator mapping (`noul`/`choice`/`score`) | **renamed**. Sending `boolean` is a validation error |
| `questions.contains_value.instructions` | string | string (optional in OpenAPI, required in prose docs) | same |
| `questions.contains_value.criteria.true` / `.false` | strings | `NoulCriteria.true` / `.false` | same |
| `questions.free_text.type` | `"boolean"` | **`"noul"`** | **renamed** |
| `questions.free_text.instructions` | string | string | same |
| `questions.free_text.criteria.true` / `.false` | strings | `NoulCriteria` | same |
| `providerOptions` | not sent | not part of the schema | absent (n/a) |

### 3.3 Response body on `200` (`EvaluateResponse.swift`)

| JSON path | Gateway `/v1/evaluate` | Direct | Status | Read? |
| --- | --- | --- | --- | --- |
| `model` | `"typesafe-ai/jev"` | versioned id that answered, e.g. `"jev-1.13.0"`; required | field same, **value renamed** | no |
| `answers` | map keyed by question id | same; required, `minProperties: 1` | same | yes |
| `answers.paste.type` | `"choice"` | `"choice"` | same | no |
| `answers.paste.choice` | option id string | option id string ("highest-probability option") | **same** | **yes** |
| `answers.paste.probabilities` | map option → number | map option → number (sums to ≈ 1); required | same | no |
| `answers.paste.confidence` | not in the Gateway-native doc example (the AI SDK exposes it as `providerMetadata.typesafe.confidence`) | number 0–1; required | **new** | no |
| `answers.contains_value.type` | `"boolean"` | **`"noul"`** | **renamed** | no |
| `answers.contains_value.probability` | number 0–1 | **absent**, replaced by `answers.contains_value.noul` (number 0–1) | **renamed**: breaking for the decoder | **yes** |
| `answers.free_text.type` | `"boolean"` | **`"noul"`** | **renamed** | no |
| `answers.free_text.probability` | number 0–1 | **absent**, replaced by `answers.free_text.noul` | **renamed**: breaking for the decoder | **yes** |
| `usage.inputTokens` / `usage.outputTokens` | camelCase | `usage.input_tokens` / `usage.output_tokens`; required | **renamed** | no |
| `providerMetadata.gateway.*` (routing, cost, generationId) | present | — | **absent** | no |

### 3.4 Non-`200` responses (`JevGatewayDecisionService.swift`, `RateLimit.swift`)

| Case | Gateway | Direct | Status |
| --- | --- | --- | --- |
| Missing key | `401` (Gateway docs); the gateway validates the body first (an empty body got `400` in the probe) | **`403`** observed, `{"detail":{"error_type":"authentication_error",…}}`; docs say `401` | **different code** |
| Invalid key | `401` | `401` per docs; **[unknown]** in practice | — |
| Body validation (e.g. 256 options, unknown type) | `400` (observed in the #21 spike for 256 options) | **`422`**, FastAPI-style `{"detail":[{"loc","msg","type",…}]}` | **renamed** |
| Rate limit | `429`, `{"error":{"message","type":"rate_limit_exceeded"}}`, `retry-after` sometimes | `429`; `retry-after` "when the response carries one"; the SDK also honors `retry-after-ms` and HTTP-date values; body shape undocumented | same status, **different body**; `retry-after-ms` **new** |
| Overloaded | not documented | **`529 Overloaded`**: retry after a short delay | **new** |
| Out of money | `402` (no credit balance, or `quota_for_entity_exceeded` budget) | **[unknown]** status; the MCA says TypeSafe "may decline to generate Output" when the credit balance hits zero | **different / undocumented** |
| Other | `403` for free-tier or allowlist or verification problems | SDK error classes exist for `400`/`403`/`404`/`422`/`429`/`5xx` | — |

**[inference]** Today's mapping (only `200` and `429` are special, everything else is `.failed`) stays safe on the direct API. `403`/`422`/`529` all become `.failed`. Whether `529` should map to `.rateLimited` is an implementation choice for #45.

**[inference] Minimal code delta for #45** (Core untouched, because it sees only `DecisionService`): endpoint literal; `EvaluateRequestBody.model`; `"boolean"` → `"noul"` in `containsValueGate` and `freeTextTarget`; `BooleanAnswer.probability` → `noul`; key name in `GatewayCredentials`; and the `RateLimit.defaultRetryAfter` rationale ("free tier ≈ 1 call/s" is a Gateway free-tier assumption). The same TypeSafe-shaped body would also work against the Gateway's `/typesafe/v1/systemone` pass-through with `model: "typesafe-ai/jev"` and the Gateway key, so the shape change and the host change can land separately.

## 4. Rate limits and retry semantics

| Topic | TypeSafe direct | Vercel AI Gateway | Source |
| --- | --- | --- | --- |
| Limits | **250,000 tokens/s; 1,200 requests/min** for `jev-1.13.0`. "Rate limits are adjusting dynamically… can change without notice." Higher limits on custom or enterprise plans | Paid tier: none from the Gateway (provider limits still apply). Free tier: "lower limit per model", **number not published** ("contact Vercel") | https://docs.typesafe.ai/models; https://vercel.com/docs/ai-gateway/rate-limits |
| Over limit | `429 Too Many Requests` | `429`, from the Gateway or passed through from the provider | same |
| `retry-after` | SDKs "honor the `retry-after` header when the response carries one" (so it's optional); the SDK parses `retry-after-ms` first, then `Retry-After` as seconds or an HTTP date | "Some `429` responses include a `retry-after` header"; seconds or HTTP date | https://docs.typesafe.ai/models; `@typesafe-ai/sdk@0.6.0` `parseRetryAfter`; https://vercel.com/docs/ai-gateway/rate-limits |
| Overload | `529`, retry with exponential backoff | not documented | https://docs.typesafe.ai/api |
| SDK default retry | 2 retries, backoff 0.5 s doubling to 5 s, 25 % jitter; retries 408, 429 and 5xx; honors server delay ≤ 60 s; per-attempt timeout 10 s (JS) | AI SDK `maxRetries` 2 | https://docs.typesafe.ai/sdk/javascript/api/interfaces/RetryPolicy, …/TypeSafeClientConfig |
| Spend cap | none documented; prepaid credits bound spend | budgets → `402 quota_for_entity_exceeded` | https://typesafe.ai/legal/mca §8.2; https://vercel.com/docs/ai-gateway/faq |

**[unknown]** Whether the direct limits apply per account or per key, and whether a promotional-credit account gets lower limits. **[inference]** At 1,200 req/min, one person pasting will not hit the request limit. The ~1 s default wait in `RateLimit.swift` was sized for the Gateway free tier.

## 5. Pricing and free tier

| | TypeSafe direct | Vercel AI Gateway |
| --- | --- | --- |
| Jev price | $0.042 / 1M input tokens ($42 / 1B); output free | same list price, "no markup and no platform fee on tokens" |
| Free allowance | **[unknown] first-party.** The MCA allows discretionary "Promotional Credits". **[secondary]** $5 per new account | **$5/month** included on the free tier. Jev is `availableToFreeTier: true` for both providers. Buying credits moves the team to the paid tier and the monthly credit stops |
| Billing model | prepaid **Credits**: expire 12 months after purchase, optional auto-refill, non-refundable; at zero balance TypeSafe "may decline to generate Output" | pay-as-you-go AI Gateway Credits; payment-processing fees may apply |
| Data handling | Not trained on customer data. **ZDR only for enterprise** | Provider `typesafe-ai`: ZDR-capable. Provider `digitalocean`: ZDR-ineligible. Model-level catalog now `"zdr": "none"`. Per request, `providerOptions.gateway.zeroDataRetention` / `only` are available |

Sources: https://docs.typesafe.ai/models, https://typesafe.ai (FAQ: "We can serve Jev profitably at our current prices"), https://typesafe.ai/legal/mca §8.2 (last updated 2026-09-23), https://docs.typesafe.ai/legal, https://vercel.com/docs/ai-gateway/pricing, https://vercel.com/docs/ai-gateway/faq, live `GET https://ai-gateway.vercel.sh/v1/models`, embedded model data on https://vercel.com/ai-gateway/models/jev.

**[inference]** Cost does not decide between the two routes: the per-token price is the same. What does differ is the billing model (monthly free credit vs prepaid expiring credits), who holds the account (Vercel team vs TypeSafe console), and data handling (TypeSafe-only serving vs a Gateway that may route to DigitalOcean).

## 6. Latency

| Claim | Class | Source |
| --- | --- | --- |
| "Most queries complete in about 100 ms." | vendor statement | https://docs.typesafe.ai/concepts/how-to-build-with-system-one |
| "Frontier intelligence at real-time speeds (150ms)" | vendor statement | https://docs.typesafe.ai/concepts/use-case-map |
| "End-to-end response time is 70ms-500ms for TypeSafe" | vendor self-report | https://typesafe.ai/blog/introducing-system-one-models-and-jev |
| Cookbook mean round-trip: `typesafe_choice` 114 ms, `typesafe_noul` 111 ms (vendor's environment) | vendor-measured | https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook, …/consistency_noul_cookbook |
| Vercel throughput/TTFT metrics for `typesafe-ai/jev` (both providers) are `null` | first-party data | embedded data on https://vercel.com/ai-gateway/models/jev |
| No direct-vs-Gateway latency comparison published | — | — |

**[fact, measured from this Mac on 2026-09-25, unauthenticated, 3 samples each]**

| Target | IP / location | TCP connect | TLS done | TTFB of the auth error |
| --- | --- | --- | --- | --- |
| `api.typesafe.ai` | `100.20.85.248` / `44.227.31.201`, AWS **us-west-2** EC2 (per `ip-ranges.amazonaws.com`) | 0.211–0.213 s | 0.53–0.63 s | 0.74–0.85 s |
| `ai-gateway.vercel.sh` | Vercel edge `fra1` | 0.025–0.026 s | 0.079–0.083 s | 0.13–0.14 s |

For comparison, `docs/design/jev-gateway.md` records a spike median of 360 ms (two questions) and 436 ms (three questions) for authenticated Gateway calls.

**[inference]** Direct calls from Europe pay the transatlantic RTT (~0.2 s) on each round trip. A **cold** connection costs ~0.5 s of extra handshake compared with the Frankfurt edge. On a warm, reused connection (`URLSession.shared` keeps connections alive), a direct call should cost roughly one RTT plus TypeSafe's processing time. How that compares with the Gateway's warm path (edge → TypeSafe, presumably also us-west-2, or DigitalOcean) is **[unknown]**. An authenticated A/B measurement is needed to settle it, which is out of scope here. The Paste Attempt's 5 s clock is not threatened on either route.

## 7. Discrepancies and unknowns

1. **[fact]** Missing key: the docs say `401`, the live API returns `403`.
2. **[fact]** Validation status: the Gateway returned `400` for a 256-option request (#21). TypeSafe documents `422`.
3. **[fact]** The Gateway catalog changed after #2: DigitalOcean was added as a second Jev provider (2026-09-24), and the model-level `zdr` moved from `all` to `none`. **[unknown]** How the Gateway chooses between providers for our requests (the response's `providerMetadata.gateway.routing.finalProvider` would show it).
4. **[unknown]** The TypeSafe API key format, expiry and scopes; whether limits apply per key or per account.
5. **[unknown]** The HTTP status and body when direct credits run out.
6. **[unknown]** Whether TypeSafe's `429` actually carries `retry-after` or `retry-after-ms` in practice.
7. **[unknown]** First-party free-credit amount for new direct accounts (`$5` is secondary only).
8. **[unknown]** Whether the direct API tolerates unknown extra fields (the OpenAPI doesn't set `additionalProperties: false`). This doesn't matter for us because we send none.
9. **[fact]** TypeSafe's prose docs say `instructions` is required. The OpenAPI and the JS SDK types make it optional. We always send it, so this doesn't affect us.

## 8. Decision implications (for #45; no decision is taken here)

1. **The switch is small and stays inside `JevGateway`.** Endpoint, model id, `boolean`→`noul` in two questions, `probability`→`noul` in the decoder, and the key name. The choice question, the option ids and the whole `state` are unchanged.
2. **Pin the model version.** `jev-latest` moves without notice. Core's thresholds (gate < 0.5, free text ≥ 0.8) were calibrated against `jev-1.13.0`, so send `jev-1.13.0` and log the returned `model`.
3. **Decide the non-200 mapping:** `403`/`422` → `.failed` (as today). For `529` the options are `.failed` or `.rateLimited`. For `429` without a header, the 1 s default was justified by the Gateway free tier, which no longer applies.
4. **Secret handling:** a new key in the env file (or Keychain), with a distinct name so the Gateway key can stay as a fallback. `x-typesafe-request-id` is safe to log for diagnostics.
5. **Measure before committing on latency:** one authenticated A/B run of the existing live test against both routes (warm and cold) from this Mac. That falls under #45's acceptance, not this research.
6. **Privacy posture improves on the direct route:** requests are served only by TypeSafe. Through the Gateway without `providerOptions.gateway.only: ["typesafe-ai"]`, a ZDR-ineligible second provider may now be used.

## 9. Validation performed (read-only; no credentials; no billable calls)

- `gh issue view 44`; read `docs/research/jev-vercel.md` from `origin/research/jev-vercel`; read `Sources/JevGateway/*.swift` and `docs/design/jev-gateway.md`.
- Downloaded raw docs: `https://docs.typesafe.ai/llms.txt`, `llms-full.txt` (910,288 bytes), and the `.md` pages `api`, `models`, `introduction/quickstart`, `concepts/system-one`, `concepts/how-to-build-with-system-one`, `concepts/use-case-map`, `legal`, SDK `retries`/`constants`/`exceptions`/`RetryPolicy`/`TypeSafeClientConfig`/`Usage`, and cookbooks `consistency_choice_cookbook`, `consistency_noul_cookbook`, `parallel_questions`.
- Fetched the live OpenAPI at `https://api.typesafe.ai/openapi.json` (spec version `0.2.0`, linked from `https://api.typesafe.ai/docs`).
- `npm pack @typesafe-ai/sdk` → `0.6.0`; read `dist/index.mjs` (headers, `parseRetryAfter`, error-class mapping, `/v1/systemone` path) and `dist/index.d.mts` (question and answer types). PyPI `typesafe-sdk` latest `0.7.1` (metadata only).
- Unauthenticated probes: `POST https://api.typesafe.ai/v1/systemone` → `403 authentication_error`; `GET /v1/models` → `403`; `POST https://ai-gateway.vercel.sh/v1/evaluate` with `{}` → `400 invalid_request_error`. Connection timings via `curl -w`, 3 samples each; IP-to-region lookup via AWS `ip-ranges.json`.
- Vercel docs (`.md`): `ai-gateway/modalities/evaluation` (updated 2026-09-22), `sdks-and-apis/typesafe` (2026-09-21), `rate-limits`, `pricing`, `authentication-and-byok`, `faq`; the changelog; the rendered `pricing` page (for the `$5/month` table cell); the model page `ai-gateway/models/jev` (embedded provider data); live `GET /v1/models`.
- TypeSafe site: homepage HTML and its Framer module (FAQ answers); `blog/introducing-system-one-models-and-jev`; `legal/mca`; `sitemap.xml` (no waitlist-removal post exists on the site).
- `web_search`, used only to discover leads. Every result about waitlist removal or $5 credit is third-party and appears above only as **[secondary]**. `x.com/typesafeai` returned 403.

### Limitations

- No authenticated call was made on either route, so shape claims about `200` responses rest on the OpenAPI schema and the docs, not on observed bodies.
- Latency numbers are handshake and auth-error timings from one machine at one time, not model latency.
- Limits and prices are explicitly dynamic; re-check them when implementing #45.

## 10. Primary sources

1. TypeSafe API reference: https://docs.typesafe.ai/api
2. TypeSafe OpenAPI (live): https://api.typesafe.ai/openapi.json (UI: https://api.typesafe.ai/docs)
3. TypeSafe models, limits and pricing: https://docs.typesafe.ai/models
4. TypeSafe quick start (key issuance): https://docs.typesafe.ai/introduction/quickstart
5. TypeSafe SDK references: https://docs.typesafe.ai/sdk/python/api/constants, https://docs.typesafe.ai/sdk/python/api/retries, https://docs.typesafe.ai/sdk/python/api/exceptions, https://docs.typesafe.ai/sdk/javascript/api/interfaces/RetryPolicy, https://docs.typesafe.ai/sdk/javascript/api/interfaces/TypeSafeClientConfig
6. TypeSafe JS SDK source: npm `@typesafe-ai/sdk@0.6.0` (`dist/index.mjs`, `dist/index.d.mts`); repo `github.com/typesafe-ai/typesafe-sdk-js`
7. TypeSafe latency statements: https://docs.typesafe.ai/concepts/how-to-build-with-system-one, https://docs.typesafe.ai/concepts/use-case-map, https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook, https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook, https://typesafe.ai/blog/introducing-system-one-models-and-jev
8. TypeSafe commercial terms: https://typesafe.ai/legal/mca (§8.2 Credits), https://docs.typesafe.ai/legal, https://typesafe.ai (FAQ)
9. Vercel AI Gateway: https://vercel.com/docs/ai-gateway/modalities/evaluation, https://vercel.com/docs/ai-gateway/sdks-and-apis/typesafe, https://vercel.com/docs/ai-gateway/rate-limits, https://vercel.com/docs/ai-gateway/pricing, https://vercel.com/docs/ai-gateway/faq, https://vercel.com/ai-gateway/models/jev, `GET https://ai-gateway.vercel.sh/v1/models`
10. App side: `Sources/JevGateway/{JevGatewayDecisionService,EvaluateRequestBody,EvaluateResponse,RateLimit,GatewayCredentials}.swift`, `docs/design/jev-gateway.md`
