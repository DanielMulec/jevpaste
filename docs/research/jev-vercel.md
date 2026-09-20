# Jev by TypeSafe AI through Vercel — primary-source research

- Ticket: [Establish Jev's supported integration through Vercel](https://github.com/DanielMulec/jevpaste/issues/2) (map: [#1](https://github.com/DanielMulec/jevpaste/issues/1))
- Branch: `research/jev-vercel`, base `cd99be3` (report committed as `docs/research/jev-vercel.md`)
- Research date: 2026-09-20. All sources retrieved live in this session; version-sensitive numbers (prices, limits, aliases) can change.
- Scope: establish Jev's identity, the actual Vercel route (gateway vs deployment), API/SDK contract, auth, limits, prices, documented latency, access prerequisites. No provisioning, no paid calls, no credentials. This is research, not an architecture decision.
- Evidence classes used below: **[fact]** = stated in a first-party source and/or confirmed by a live probe; **[inference]** = reasoned from facts; **[untested]** = documented but not executed here; **[unknown]** = no authoritative source found.

## 1. Verdict (short)

1. **[fact]** Jev is a real, documented product of **TypeSafe AI** (`typesafe.ai`, docs at `docs.typesafe.ai`): "System One" decision/evaluation models. Jev is the flagship model, current version **`jev-1.13.0`**, aliases `jev-latest` and `jev-preview` (both resolve to `jev-1.13.0`). It does **not** generate text — it returns typed decisions (Noul/yes-no probability, Choice, Score) with probabilities and confidence.
2. **[fact]** The supported Vercel route is **AI Gateway, not deployment**. Jev is not deployed to or hosted on Vercel; Gateway brokers calls to TypeSafe's service. Gateway model ID: **`typesafe-ai/jev`** — confirmed live in the Gateway's model catalog (`GET https://ai-gateway.vercel.sh/v1/models`, 376 models; Jev is the only model of `"type": "evaluation"`).
3. **[fact]** Two Gateway surfaces work, both plain HTTP and both authenticated with a **Vercel AI Gateway credential** (API key or Vercel OIDC):
   - Gateway-native: `POST https://ai-gateway.vercel.sh/v1/evaluate`
   - TypeSafe-compatible passthrough: `POST https://ai-gateway.vercel.sh/typesafe/v1/systemone`
   The AI SDK's `experimental_evaluate` (TypeScript, `ai@7.0.105+`) is a third, TS-only client for the native surface.
4. **[fact]** A third route exists outside Vercel: `POST https://api.typesafe.ai/v1/systemone` with a **TypeSafe** API key. TypeSafe states Jev was released "available today in early access" (2026-09-15) and `typesafe.ai` shows a **Join Waitlist** call to action, so direct TypeSafe access may be gated. **[unknown]** whether signup is currently open.
5. **[fact]** Price: **$0.042 per 1M input tokens, output free**, zero Gateway markup. Gateway metadata also flags Jev `availableToFreeTier: true` (usable with the $5/month free credits at lower rate limits).
6. **[fact]** Gateway advertises a **32,000-token** context window and `max_tokens: 0` (no generated text). TypeSafe documents a 64k budget per request with a stricter 32k budget for "state + longest question".
7. **[inference, important]** Because Jev cannot emit prose, a smart-paste "Paste Result" string must be produced by local/app code (e.g. selecting exact source spans/fields guided by Jev answers). "Jev through Vercel" is verified as an API capability, but it does not by itself provide a text-transformation/generation capability. This constrains ticket [Choose Jev context and transformation semantics](https://github.com/DanielMulec/jevpaste/issues/7).

## 2. Identity of Jev (authoritative primary sources)

| Fact | Source |
| --- | --- |
| Vendor is TypeSafe AI; Jev is its flagship "System One" model; first public model, announced 2026-09-15, "available today in early access"; author of the announcement is "Diogo Almeida, founder, TypeSafe AI" **[fact]** | https://typesafe.ai/blog/introducing-system-one-models-and-jev |
| System One models "make fast, structured decisions for software"; Jev "is not a language model", returns typed answers and probabilities **[fact]** | https://docs.typesafe.ai/concepts/system-one |
| Current model `jev-1.13.0`; aliases `jev-latest` (stable, SDK default) and `jev-preview` (currently identical to `jev-latest`; no preview build) **[fact]** | https://docs.typesafe.ai/models |
| Text only; state may be a string, JSON object, or array of text values; no image/audio/video; English primary, other languages lower accuracy **[fact]** | https://docs.typesafe.ai/models, https://docs.typesafe.ai/concepts/state |
| Not fine-tuned per customer with customer data; "not trained on customer requests or responses"; ZDR available for enterprise **[fact — vendor statement]** | https://docs.typesafe.ai/models |
| Model card on Vercel: id `typesafe-ai/jev`, released 2026-09-15, type `evaluation`, context 32,000, max output tokens 0, pricing input `0.000000042`/token (= $0.042/M), output `0`, `zdr: "all"`, `no_training: "all"`, modalities in/out `text`, spec `v4` **[fact]** | live `GET https://ai-gateway.vercel.sh/v1/models` (2026-09-20) |
| Vercel announcement "TypeSafe AI's Jev now available on AI Gateway" **[fact]** | https://vercel.com/changelog/typesafe-ai-jev-now-available-on-ai-gateway (page metadata `datePublished` 2026-09-16) |
| X handle `@typesafeai` (from the demo tweet) maps to this vendor **[inference]** — the handle itself was not verified in this session (no X access); vendor↔product binding is unambiguous from `typesafe.ai`/`docs.typesafe.ai` and the `typesafe-ai` Gateway namespace | https://x.com/marcus_lowe/status/2101476399488160013 (README) |

**[unknown]** Funding/valuation/customer claims that appear in secondary write-ups (e.g. "raised $40M led by DCVC") were **not** verified against a first-party source here. Secondary write-ups (`flaviocopes.com`, `marktechpost.com`, `langchain.com`, `refix.ai`, `pydantic.dev`, `developers.cloudflare.com`, `docs.litellm.ai`) corroborate that Jev exists and that Jev is listed on other platforms, but they are not used as the basis for any number in this report.

## 3. Supported route through Vercel: Gateway (not deployment)

**[fact]** Vercel's docs describe Jev as an **AI Gateway** model ("Type: evaluation", "Providers: typesafe-ai"), consumed either through Gateway's evaluation API, the TypeSafe-compatible pass-through, or AI Gateway's OpenAI/Anthropic/other endpoints? — **no**: "It is not supported through the OpenAI-compatible, Anthropic-compatible, or Cohere-compatible endpoints."

| Surface | Method + URL | Request naming | Response naming |
| --- | --- | --- | --- |
| Gateway-native evaluation | `POST https://ai-gateway.vercel.sh/v1/evaluate` | `questions[].type`: `choice` \| `score` \| `boolean` | answers `type` + (`choice` \| `score` \| `probability`), `usage.inputTokens`, `providerMetadata.gateway.*` |
| TypeSafe-compatible pass-through | `POST https://ai-gateway.vercel.sh/typesafe/v1/systemone` (base URL `https://ai-gateway.vercel.sh/typesafe`, also `GET /typesafe/v1/models`) | `questions[].type`: `choice` \| `score` \| `noul` | answers `type` + (`choice` + `probabilities` + `confidence` \| `score` + `legend` + `probabilities` + `confidence` \| `noul`), `usage.input_tokens` |
| AI SDK 7 (TypeScript only) | `experimental_evaluate({ model: 'typesafe-ai/jev', state, questions })` from package `ai` (≥ 7.0.105) | same as Gateway-native | `result.answers`, `result.providerMetadata.typesafe.confidence`, `usage`, `warnings`, `response` |

Documented examples (verbatim paths, from first-party docs):

```sh
# Gateway-native (docs: AI Gateway › Evaluation › HTTP API)
curl https://ai-gateway.vercel.sh/v1/evaluate \
  -H "Authorization: Bearer $AI_GATEWAY_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"typesafe-ai/jev","state":"I was charged twice for my subscription.",
       "questions":{"refund":{"type":"boolean","instructions":"Is the customer asking for money back?"}}}'
```

```json
// Documented response shape (Gateway-native)
{"model":"typesafe-ai/jev",
 "answers":{"refund":{"type":"boolean","probability":0.98}},
 "usage":{"inputTokens":275,"outputTokens":20},
 "providerMetadata":{"gateway":{"routing":{"originalModelId":"typesafe-ai/jev","resolvedProvider":"typesafe-ai",
   "canonicalSlug":"typesafe-ai/jev","finalProvider":"typesafe-ai"},
   "cost":"0.00001155","marketCost":"0.00001155","surchargeCost":"0","gatewayCost":"0.00001155","generationId":"gen_..."}}}
```

```sh
# TypeSafe-compatible (docs: AI Gateway › TypeSafe API)
curl https://ai-gateway.vercel.sh/typesafe/v1/systemone \
  -H "Authorization: Bearer $AI_GATEWAY_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"typesafe-ai/jev","state":"I was charged twice for my subscription.",
       "questions":{"refund":{"type":"noul","instructions":"Is the customer asking for money back?"}}}'
```

Notes that matter for implementation:

- **[fact]** In the TypeSafe-compatible route the `model` field is the **Gateway** ID (`typesafe-ai/jev`), not TypeSafe's `jev-latest` — that is what Vercel's own cURL example sends. The doc also says Gateway "implements the TypeSafe request and response shapes" and passes provider errors through unchanged.
- **[fact]** The two surfaces use **different question/answer naming** (`boolean`/`probability` + camelCase usage vs `noul`/`noul` + snake_case usage). A client written against one is not byte-compatible with the other.
- **[fact]** The AI SDK surface is explicitly **experimental**: "This API and the evaluation model specification are experimental and may change in patch releases."
- **[fact]** No streaming, no batching unrelated states, no multilabel classification, one state per call, and "no partial success or automatic model substitution". Unsupported question types fail the whole call.
- **[fact]** AI Gateway does **not** support the OpenAI/Anthropic/Cohere-compatible endpoints for this model; `max_tokens: 0`.

## 4. Input / context / output schema (TypeSafe authoritative shapes)

Request (`POST /v1/systemone`, also mirrored by the pass-through):

| Field | Type | Notes |
| --- | --- | --- |
| `state` | string \| object \| array | Content to evaluate; objects/arrays for structured context. **One state per request.** |
| `model` | string | On TypeSafe: `jev-latest`, `jev-preview`, `jev-1.13.0`. Through Gateway: `typesafe-ai/jev`. |
| `questions` | map<string, Question> | Keys are chosen by the caller, returned under the same ids, "not sent to the underlying model". |

Question types **[fact]** (TypeSafe names; Gateway-native renames `noul` → `boolean`):

| Type | Fields | Answer fields |
| --- | --- | --- |
| `noul` / `boolean` | `instructions` (string \| object \| array); optional `criteria.true` / `criteria.false` | `noul` (0–1) / `probability` (0–1) |
| `choice` | `instructions`; `criteria` = map option→description (max **255 options**) | `choice` (highest-probability option), `probabilities` (sum to 1), `confidence` 0–1 |
| `score` | `instructions`; `criteria` = ordered array of level descriptions (min 2, **max 10**) | `score` (probability-weighted, can land between levels), `legend` (level index→description), `probabilities`, `confidence` 0–1 |

- **[fact]** `instructions` may embed data (`{"potential_duplicate": {...}, "question": "..."}`), referenced by name in backticks.
- **[fact]** Choice/Score confidence is a separate statistic derived from the distribution; AI SDK exposes it at `providerMetadata.typesafe.confidence`. `confidence` ≠ selected option's probability.
- **[fact]** AI SDK `score` answers: fractional score in `[0, levels.length - 1]`, distributions must sum to 1 (tolerance 1e-6), boolean `probability` is the model's P(true) and is "not confidence in either outcome".
- **[fact]** Errors (TypeSafe HTTP): `401` invalid key, `422` validation, `429` rate limit, `529` overloaded — retry with exponential backoff, honor `retry-after`; official SDKs retry by default.
- **[fact]** `usage` reports input/output tokens; answers come back only as complete typed values (no prose).
- **[fact]** Direct TypeSafe `GET /v1/models` lists aliases; versioned IDs are accepted even if not listed.
- **[unknown]** No documented per-request cap on the *number* of questions; the practical ceiling is the token budget. **[unknown]** Whether the Gateway-native `/v1/evaluate` accepts TypeSafe's `noul` spelling (docs show `boolean` only).

## 5. Authentication

| Route | Credential | Notes |
| --- | --- | --- |
| AI Gateway (both surfaces) | `Authorization: Bearer <AI_GATEWAY_API_KEY>` | Created in the Vercel dashboard (team → AI Gateway → API Keys). Keys "work anywhere… never expire unless you revoke them". |
| AI Gateway on Vercel deployments | Vercel OIDC token (`VERCEL_OIDC_TOKEN`) | Not applicable to a local macOS app without a Vercel deployment. |
| BYOK | Optional provider key at team level (paid tier) | To bill TypeSafe directly instead of through Gateway; failed BYOK requests fall back to Gateway system credentials and are billed to credits. **[inference]** Because Gateway serves the model with system credentials by default, **no TypeSafe account is required for the Gateway route** (Vercel's changelog demo calls `typesafe-ai/jev` with only a Gateway credential). |
| Direct TypeSafe API | `TYPESAFE_API_KEY` from `console.typesafe.ai/keys` | Independent of Vercel; Jev announced "in early access"; `typesafe.ai` shows "Join Waitlist". **[unknown]** current signup gating. |

**[fact]** The AI SDK reads `AI_GATEWAY_API_KEY` automatically for string model IDs. The TypeSafe-compatible route requires an AI Gateway credential — the doc is explicit: "This is the credential AI Gateway authenticates you with, not the credential used to call the model."

## 6. Limits and rate limits

| Limit | Value | Source |
| --- | --- | --- |
| Gateway context window (model card) | **32,000 tokens**; `max_tokens: 0` | live `GET /v1/models`; Vercel model page |
| TypeSafe context budget | **64k tokens per request**, of which **32k for `state` + the single longest question** | https://docs.typesafe.ai/models |
| Choice options | max 255 per question | https://docs.typesafe.ai/api |
| Score levels | 2–10 ordered descriptions | https://docs.typesafe.ai/api |
| TypeSafe rate limits | **250,000 tokens/s** and **1,200 requests/min**; "adjusting dynamically… can change without notice" | https://docs.typesafe.ai/models |
| Gateway rate limits | Paid tier: none from Gateway (provider limits still apply). Free tier: lower per-model limits → `429` | https://vercel.com/docs/ai-gateway/rate-limits |
| Gateway budget guard | `402 quota_for_entity_exceeded` when a budget is hit | https://vercel.com/docs/ai-gateway/rate-limits |
| Retry | AI SDK `maxRetries` default 2; honor `retry-after`; retry `429` unchanged | https://vercel.com/docs/ai-gateway/rate-limits, AI SDK evaluation docs |
| Free-tier eligibility of Jev | `availableToFreeTier: true` (`isFree: true`) | embedded model data on https://vercel.com/ai-gateway/models/jev and https://vercel.com/ai-gateway/models/providers/typesafe-ai |
| Data handling | `zdr: "all"`, `no_training: "all"`; per-request `providerOptions.gateway.zeroDataRetention: true` shown in Vercel's example | live catalog; https://vercel.com/changelog/typesafe-ai-jev-now-available-on-ai-gateway |

**[unknown]** The concrete free-tier per-model rate limit for Jev is not published ("To confirm the current limit for a model, contact Vercel from your dashboard's Support entry"). **[unknown]** Whether the free tier ($5/month included credit) is enough for routine personal use — plausible at $0.042/M tokens, but not tested (no paid calls permitted here).

## 7. Pricing

- **[fact]** TypeSafe list price: **$42 per billion / $0.042 per million input tokens; output tokens are free** ("Charged per input token. Output tokens are free."). https://docs.typesafe.ai/models
- **[fact]** Gateway catalog pricing for `typesafe-ai/jev`: input `0.000000042` USD/token (= $0.042/M), output `0`.
- **[fact]** AI Gateway charges **no markup and no platform fee** on tokens; you pay provider list price; free tier includes **$5/month** credit; paid tier is pay-as-you-go credits; BYOK has no Gateway fee. https://vercel.com/docs/ai-gateway/pricing
- **[inference]** At 32k tokens per request (the advertised window) a worst-case call costs ≈ $0.0013; the documented example call (275 input tokens) reports Gateway cost `0.00001155`. Smart-paste requests with a full résumé plus form context (single-digit thousands of tokens) are fractions of a cent each.
- **[unknown]** The semantic difference of the `isFree: true` flag vs `availableToFreeTier: true` (both true for Jev) — no doc defines them; the safe reading is "callable with free-tier credits", not "free of charge".

## 8. Documented latency

| Claim | Class | Source |
| --- | --- | --- |
| "End-to-end response time is 70ms-500ms for TypeSafe… 40x-200x faster for the same levels of frontier intelligence for System One shaped queries" | vendor self-report | https://typesafe.ai/blog/introducing-system-one-models-and-jev |
| "Most queries complete in about 100 ms" | vendor statement | https://docs.typesafe.ai/concepts/system-one |
| Mean round-trip **114 ms** for `typesafe_choice` in the vendor's own run (2026-09-11, `jev-latest`), vs 826 ms–13.0 s for LLM baselines | vendor-measured, published in docs | https://docs.typesafe.ai (Compare stacks cookbook in `llms-full.txt`) |
| "up to 193.6x faster and 444.6x cheaper than LLMs on its workflow evaluations" (attributed to TypeSafe) | vendor self-report relayed by Vercel | https://vercel.com/changelog/typesafe-ai-jev-now-available-on-ai-gateway |
| Batching 13 questions into one call is reported "11.5x cheaper and 9.6x faster than 13 separate calls" | vendor-measured | https://docs.typesafe.ai (Parallel questions cookbook) |
| Vercel-published performance metrics for `typesafe-ai/jev` (throughput, TTFT) are **all `null`** | observed first-party data | https://vercel.com/ai-gateway/models/jev (page data) |

**[inference]** No third-party or Gateway-side latency measurement for Jev is published; all numbers are TypeSafe's own. Treat ~100 ms as a plausible expectation, not a verified end-to-end figure through Vercel's Gateway. **[untested]** Real latency via Gateway (would require a paid call).

## 9. Capability boundaries that bear on this app (all **[fact]** unless noted)

- Jev **never returns generated text**; it is "not trained to generate text". Any pasted string must be assembled by app code.
- It **cannot count reliably**, is weak on numeric/hex/binary representations, does not treat dates as ordered quantities, and is weak at indirection/multi-hop reasoning; docs advise doing arithmetic and comparisons in code.
- Accuracy degrades with large, partly irrelevant `state` ("context rot"); docs advise sending only relevant fields. Directly relevant to pasting whole résumés.
- `state` is **not treated as hostile by default** — prompt-injection-style content in the pasted text can move answers. Relevant because clipboard items are untrusted input.
- Some structural invariants do not hold: `noul` and the equivalent `choice` probability disagree; a question and its negation need not sum to 1. Confidence thresholds must be calibrated per question type/version.
- Alias `jev-latest` moves without notice; docs recommend pinning a version and logging the returned `model` field (responses report e.g. `jev-1.13.0`).
- **[inference]** "Can't hallucinate" (vendor phrasing) means outputs are confined to the declared answer space; it does **not** mean the answer is correct. Docs and Vercel both stress calibrating thresholds with labeled examples.

## 10. Discrepancies and unknowns found

1. **[fact]** AI SDK docs example uses `model: 'typesafe-ai/jev-latest'`, but the live catalog has **only `typesafe-ai/jev`**: probes for `typesafe-ai/jev-latest`, `typesafe-ai/jev-preview`, `typesafe-ai/jev-1.13.0` all returned **404 `model_not_found`**. Use `typesafe-ai/jev`; treat the AI SDK doc string as an error.
2. **[fact]** Context-window phrasing differs: Vercel says 32,000; TypeSafe says 64k per request, with 32k for `state` + longest question. Safe working assumption: the 32k budget binds.
3. **[fact]** The Gateway-native `/v1/evaluate` HTTP page documents only "the same `model`, `state`, and `questions` fields"; the raw response example exists in the rendered page but the *raw* request/response schemas are less complete than TypeSafe's API reference.
4. **[unknown]** Whether `GET /v1/evaluate`-style capability filters or per-model rate limits apply to evaluation models on the free tier.
5. **[unknown]** Whether TypeSafe direct signup is open now (early access/waitlist framing).
6. **[untested]** ZDR/no-training enforcement for Jev through Gateway; BYOK with a TypeSafe key; provider-error passthrough behavior; whether answers' probabilities are rounded (AI SDK `rounding` metadata).
7. **[fact]** Vercel's provider listing page rendered price text as `$0.04/M` in one secondary snapshot; the page's own embedded model data and the model card both say **0.042**. Use the model card value and re-check at implementation time.
8. **[fact]** The demo (`README.md`, `video.mp4`, `frames/`) shows pasted values that are verbatim substrings of the source résumé. It is behavioral evidence only — it proves nothing about which endpoint, model version, or prompt was used, and the README itself labels it as such.

## 11. Decision implications (for the parent; no decision taken here)

1. **"Jev through Vercel" is now a verified capability**, not a hope: `typesafe-ai/jev` exists on AI Gateway with documented pricing, auth, and schemas. The remaining risk is product fit, not availability.
2. **No Vercel deployment is required.** A local macOS app can call Gateway over HTTPS with one long-lived API key (`AI_GATEWAY_API_KEY`). OIDC is only useful for code running on Vercel. Node.js 22.18+ is only required if the AI SDK path is chosen — a Swift client would use HTTP directly and needs neither Node nor the AI SDK.
3. **Choose the TypeSafe-compatible surface for a Swift client if you want the stable contract** (TypeSafe's own field names, documented 401/422/429/529 semantics, official SDKs for reference), or the Gateway-native `/v1/evaluate` if you prefer Gateway naming and Gateway-side validation. Whichever is chosen, write it behind a narrow client seam so the other can be swapped — the two differ in field names.
4. **The transformation gap is the real design risk:** Jev can judge (which field, is it a name/email/url, does this span match, how confident), but it cannot write the "Professional summary" style text. Either the Paste Result is composed locally (span selection + deterministic formatting, matching what the demo shows), or a second generative model is introduced — which would need its own decision, and the map currently names Jev as the intended engine.
5. **Budget is negligible, latency is the UX risk:** ~$0.042/M input tokens means cost is not a constraint for personal use; the open question is typical end-to-end latency through Gateway (unmeasured here) and how that interacts with the map's requirement for a visible indicator on failure/slowness.
6. **Access prerequisites to plan for (no provisioning done):** a Vercel team with AI Gateway enabled; either free-tier eligibility (Jev is flagged eligible) or purchased credits; one API key delivered to the app's secret store (never in source); optional BYOK TypeSafe key only if direct provider billing is wanted.
7. **Privacy posture:** Jev supports ZDR and No Training (catalog flags `all`), and TypeSafe states it does not train on customer data; still, pasted text leaves the machine. The map already accepts that ordinary personal content may reach Jev; per-request `zeroDataRetention: true` is available if the parent wants to request it.

## 12. Validation performed (all read-only; no credentials, no paid calls)

- `gh issue view 1/2 --repo DanielMulec/jevpaste` — ticket + map text, labels, comment (claim note). `gh auth status` shows account `DanielMulec` with `repo` scope.
- Live first-party catalog: `GET https://ai-gateway.vercel.sh/v1/models` → 200, 376 models; `typesafe-ai/jev` present, `"type":"evaluation"`, unique among evaluation-type models.
- Model lookup probes: `GET /v1/models/typesafe-ai/jev` → **200**; `…/jev-latest`, `…/jev-preview`, `…/jev-1.13.0` → **404 `model_not_found`**.
- Unauthenticated surface probes (prove the endpoints exist and require auth, without spending): `POST /v1/evaluate` → **401**; `POST /typesafe/v1/systemone` → **401**; `POST /v1/chat/completions` with Jev → **401**.
- Docs read raw (not via secondary summaries): `https://docs.typesafe.ai/llms-full.txt` (895,642 bytes; API reference, models, limit tables, jaggedness notes), `https://vercel.com/docs/ai-gateway/modalities/evaluation.md`, `…/sdks-and-apis/typesafe.md`, `…/rate-limits.md`, `…/pricing`, `…/authentication-and-byok`, `…/getting-started/evaluation`, `https://ai-sdk.dev/docs/ai-sdk-core/evaluation`, `https://vercel.com/changelog/typesafe-ai-jev-now-available-on-ai-gateway`, `https://typesafe.ai/blog/introducing-system-one-models-and-jev`.
- Package-surface checks: npm registry `ai` → `latest 7.0.107`; published `ai@7.0.107/dist/index.d.ts` declares `EvaluationModel`, `EvaluationQuestion`, `EvaluationAnswer`, `EvaluationResult`, `Experimental_EvaluationModelV4…` and exports `evaluate as experimental_evaluate`; `@typesafe-ai/sdk` → `0.6.0`; PyPI `typesafe-sdk` → `0.7.0`.
- Rendered Vercel model/providers pages inspected for embedded model data (pricing, `availableToFreeTier`, `isFree`, `contextSize`, `releaseDate`, null performance metrics).

### Limitations

- Nothing was executed against a paid endpoint; no API keys were used or read. Every "works in practice" statement is doc- or probe-level, not an end-to-end call.
- Pricing/limits/aliases are explicitly dynamic on both vendors' pages; re-verify before implementation.
- No X/Twitter, Discord, or support-channel access, so community-reported behavior (latency under load, Gateway quirks with evaluation models) is not covered.
- Demo video/README were read but treated as behavioral evidence only; no inference about Jev's internals was drawn from them.

## 13. Primary sources

1. TypeSafe AI docs — full corpus: `https://docs.typesafe.ai/llms-full.txt` (API reference, State, System One, Models, jaggedness, cookbooks).
2. TypeSafe AI docs (human pages): `https://docs.typesafe.ai/introduction/quickstart`, `https://docs.typesafe.ai/concepts/state`, `https://docs.typesafe.ai/models`, `https://docs.typesafe.ai/api`.
3. TypeSafe AI announcement: `https://typesafe.ai/blog/introducing-system-one-models-and-jev` (2026-09-15; early access; 70–500 ms; founder Diogo Almeida).
4. Vercel AI Gateway — TypeSafe API: `https://vercel.com/docs/ai-gateway/sdks-and-apis/typesafe` (base URL, auth, endpoints, model field `typesafe-ai/jev`).
5. Vercel AI Gateway — Evaluation: `https://vercel.com/docs/ai-gateway/modalities/evaluation` (question types, HTTP API, response shape, experimental status).
6. Vercel changelog: `https://vercel.com/changelog/typesafe-ai-jev-now-available-on-ai-gateway` (availability date, AI SDK 7.0.105+, self-reported speed/cost multiples).
7. Vercel model card: `https://vercel.com/ai-gateway/models/jev` and provider listing `https://vercel.com/ai-gateway/models/providers/typesafe-ai` (embedded model data: pricing, free-tier flags, null metrics).
8. Vercel pricing/limits/auth: `https://vercel.com/docs/ai-gateway/pricing`, `https://vercel.com/docs/ai-gateway/rate-limits`, `https://vercel.com/docs/ai-gateway/authentication-and-byok`.
9. Vercel AI SDK: `https://ai-sdk.dev/docs/ai-sdk-core/evaluation`; npm `ai@7.0.107` (`dist/index.d.ts`).
10. Live Gateway API (first-party, unauthenticated): `https://ai-gateway.vercel.sh/v1/models`, `/v1/models/typesafe-ai/jev`.
