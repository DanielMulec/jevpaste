# Official ChatGPT sign-in for a third-party macOS app: primary-source research

- Ticket: [Establish how official ChatGPT sign-in works for a third-party macOS app](https://github.com/DanielMulec/jevpaste/issues/48) (map: [#1](https://github.com/DanielMulec/jevpaste/issues/1); raised by the resolution of [#31](https://github.com/DanielMulec/jevpaste/issues/31))
- Branch: `research/chatgpt-signin` (base `bd95978`, kept, never merged); report at `docs/research/chatgpt-signin.md`
- Predecessors: `docs/research/jev-vercel.md` (branch `research/jev-vercel`) and `docs/research/typesafe-direct.md` (branch `research/typesafe-direct`). This report uses the same structure.
- Research date: 2026-09-26. All sources were retrieved live in this session. OpenAI's help-centre pages are dated relatively ("updated yesterday", "3 days ago"), and plans, limits, model rollouts and prices are explicitly dynamic.
- Scope: the question in #48, bullet by bullet, plus a supervisor addition from Daniel: whether the **Codex SDK / `codex exec` / Codex app-server** lets a third-party app use a user's ChatGPT login (§5). No account was created, no OAuth client was registered, no login was run, no API was called with a key or token, and no auth file was read. What pi and Codex CLI store is described from their documentation and source code only.
- Evidence classes: **[fact]** means a first-party source (OpenAI docs, help centre, terms, OpenAI source code, or a live unauthenticated probe) states or shows it. **[statement]** means an OpenAI employee said it publicly (X, the official forum). It is first-party but not contractual. **[inference]** means it is reasoned from facts. **[unknown]** means no authoritative source was found. **[secondary]** means only third parties say it, so no conclusion rests on it.
- Three kinds of answer are kept apart throughout: **(a)** what OpenAI officially offers third-party developers, **(b)** what Codex CLI (and pi, which copies it) does for itself, and **(c)** what is undocumented or unverifiable.

## 1. Verdict (short)

1. **[fact] (a) "Sign in with ChatGPT" for third parties is identity-only, partner-gated, and in beta.** It started rolling out on 2026-07-29 "across select plugins and partner sites, starting with Airtable, GitLab, HubSpot, Notion, Supabase, and Vercel", plus OpenAI Academy and ChatGPT Sites. The partner receives "only your name, email address, and profile picture", and explicitly not "your files or tokens" or billing. There is **no public developer programme**: OpenAI publishes no client-registration page, no scopes, no redirect rules for native apps, and no SDK. The 2025 developer interest form (`openai.com/form/sign-in-with-chatgpt/`) now returns **404**. On 2026-09-08 OpenAI Support wrote on the official forum that letting users fund AI usage from their own ChatGPT account is a feature request: "We don't have a timeline to share." **So the official programme cannot give JevPaste GPT-6 Luna on the user's subscription.**
2. **[fact] (b) Codex CLI's "Sign in with ChatGPT" is a different thing.** It is OAuth 2.0 authorization code + PKCE against `https://auth.openai.com`. It uses Codex's own public `client_id`, a loopback redirect `http://127.0.0.1:1455/auth/callback`, and scopes `openid profile email offline_access api.connectors.read api.connectors.invoke`. With the resulting ChatGPT access token it calls the **undocumented** backend `https://chatgpt.com/backend-api/codex` rather than `api.openai.com`, and the usage counts against the user's ChatGPT plan allowance. Pi copies that flow: it uses the same `client_id` with `originator=pi`. No OpenAI document describes `chatgpt.com/backend-api/codex` as a public endpoint.
3. **[fact] (a/b) OpenAI does document embedding Codex *itself* in your own product with the user's ChatGPT login.** The app-server docs say: "Use it when you want a deep integration inside your own product: authentication, conversation history, approvals, and streamed agent events". The app-server has a managed `chatgpt` login mode, and `model/list` and `account/rateLimits/read` methods. The Codex SDK docs list "Integrate Codex within your own application". What you get is **the Codex agent harness** (threads, turns, tools, sandbox) running on the user's Codex allowance. It is not a plain model endpoint.
4. **[statement] OpenAI's stance on third-party clients using the subscription is permissive for personal and open-source use, and restrictive otherwise.** Tibo Sottiaux (X bio: "Codex & ChatGPT @OpenAI"), 2026-08-21: "You are completely fine if you use your subscription through Sign in With ChatGPT, either through the official clients or through one of the many OSS clients (Pi, OpenCode, ...)". Same person, 2026-09-08, replying to a closed iMessage product ("bring your ChatGPT account"): "Sorry, but this is not an approved use of Sign in With ChatGPT. We support pure OSS clients and others we have partnerships with, but you need to reach out and talk to us for that." Sam Altman, 2026-05-02: "you can sign in to openclaw with your chatgpt account now and use your subscription there!"
5. **[fact] No written term grants this permission.** The consumer Terms of Use are silent on third-party clients. They do prohibit sharing credentials, "automatically or programmatically extracting data or Output", and "circumventing any rate limits". OpenAI's Pro-plan help article reads them as prohibiting "Reselling access or using ChatGPT to power third-party services."
6. **[fact] GPT-6 Luna is reachable on all three routes.** Through ChatGPT/Codex sign-in it is available on Plus/Pro/Business (CLI, IDE, desktop, web). On Free/Go it is "in the desktop app, subject to rollout", and Enterprise/Edu need an admin to enable it. Through the OpenAI API it is `gpt-6-luna` at **$0.10 / $0.50 per 1M** input/output tokens. Through the Vercel AI Gateway it is `openai/gpt-6-luna` at the same price (live catalog). Within ChatGPT plans, Luna is "available in Work and Codex. They aren't available in Chat."
7. **[inference] Answer to Daniel's Codex-SDK hypothesis: partly right.** For **Daniel's own use** (his own account, a local client, the Codex harness), OpenAI's Codex lead has publicly called this "completely fine", and OpenAI documents the app-server for product embedding. For **"any and all JevPaste users"**, the only on-record OpenAI line is "pure OSS clients" or a partnership. JevPaste's repo is public but has **no licence**, so it isn't OSS today. A closed or commercial distribution would need OpenAI's approval. Every permissive statement is a post, not a contract, and the ToU clause "using ChatGPT to power third-party services" remains.

## 2. (a) What OpenAI officially offers: "Sign in with ChatGPT"

| Fact | Class | Source |
| --- | --- | --- |
| "an identity-provider sign-in option that lets you use identity information from your ChatGPT account to create, link, or access an account with a supported external application" | fact | https://help.openai.com/en/articles/20001410-sign-in-with-chatgpt |
| Availability: "available on OpenAI Academy and ChatGPT Sites and is rolling out across select plugins and partner sites. Initial participating partners include Airtable, GitLab, HubSpot, Notion, Supabase, and Vercel." | fact | same |
| "For identity sign-in, the external application receives only your name, email address, and profile picture". It "does not independently share … Your files or tokens … Your billing information or other ChatGPT account data." | fact | same |
| Delegated access is a separate permission flow. The documented examples are a ChatGPT Site requesting your connected apps, and HubSpot requesting your ChatGPT Ads account. **No example grants model inference.** | fact | same |
| Org admins control it under "External access" in the OpenAI Admin Console. It is enabled by default for orgs without an explicit identity policy. | fact | same |
| Release note (2026-07-29): "We're beginning to roll out Sign in with ChatGPT across select plugins and partner sites … only your name, email, and profile picture … are shared". | fact | https://help.openai.com/en/articles/6825453-chatgpt-release-notes |
| Beta status as seen by partners: Vercel says "Sign in with ChatGPT is in beta". Supabase calls itself "a launch partner for OpenAI's Sign in with ChatGPT beta". | fact (partner first-party) | https://vercel.com/changelog/sign-in-with-chatgpt-is-now-available-on-vercel, https://supabase.com/blog/sign-in-with-chatgpt-beta |
| ChatGPT Sites uses platform paths `/signin-with-chatgpt` and `/signout-with-chatgpt`. Identity arrives as request headers `oai-authenticated-user-email` and `oai-authenticated-user-full-name`. Only Sites hosted by OpenAI can use this. | fact | https://learn.chatgpt.com/docs/sites.md |
| The developer interest form from May 2025 (`https://openai.com/form/sign-in-with-chatgpt/`) now serves OpenAI's 404 page. | fact (probe, 2026-09-26) | that URL |
| OpenAI Support on the official forum (2026-09-08), answering "Allow ChatGPT Sites to use the visitor's ChatGPT subscription": "Sites already supports optional ChatGPT sign-in for identity … We'll share the separate request to let visitors choose to fund AI usage from their own accounts. We don't have a timeline to share." | statement (account `OpenAI_Support`, flagged staff) | https://community.openai.com/t/feature-request-allow-chatgpt-sites-to-use-the-visitors-chatgpt-subscription-or-credits/1391237 |

Answering the #48 bullets for the official programme:

- **OAuth flow, client registration, scopes, native redirect:** **[unknown]** None are published for third parties. Partner integrations (GitLab MR `!247672` calls it "SIWC") exist, but OpenAI's documentation offers no self-serve registration. **[secondary]** Third-party blogs describe an OIDC code+PKCE flow at `auth.openai.com` with `openid email profile`. No OpenAI page confirms this for non-partners.
- **Models/endpoints granted:** **none**. It is identity only (§2 table, row 3).
- **Rate limits / pricing on the user's plan:** not applicable. Nothing is metered against the user's plan.
- **Terms for third-party apps:** no developer terms for SIWC were found. The *App Developer Terms* cover apps and plugins *inside* ChatGPT, not external sign-in.
- **What a user sees:** a "Sign in with ChatGPT" or "Continue with ChatGPT" button on the partner's page, then an OpenAI screen showing the identity info to be shared. Any extra permissions are approved separately.

**[inference]** Even if JevPaste became a partner, SIWC as documented would give it the user's name and email only. It is irrelevant to running GPT-6 Luna on the user's subscription.

## 3. (b) What Codex CLI does for itself (and what pi copies)

Source: `github.com/openai/codex` at commit `e72da2b` (2026-09-26). Docs: https://learn.chatgpt.com/docs/auth.md.

| Item | Value | Class | Where |
| --- | --- | --- | --- |
| Issuer | `https://auth.openai.com` | fact | `codex-rs/login/src/server.rs` (`DEFAULT_ISSUER`) |
| Client | public client `CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"` (overridable via `CODEX_APP_SERVER_LOGIN_CLIENT_ID`) | fact | `codex-rs/login/src/auth/manager.rs` |
| Flow | authorization code + PKCE; `GET {issuer}/oauth/authorize`, code exchange at `{issuer}/oauth/token`; refresh at `/oauth/token`; revoke at `/oauth/revoke` | fact | `server.rs`, `manager.rs` |
| Scopes | `openid profile email offline_access api.connectors.read api.connectors.invoke` | fact | `server.rs` `build_authorize_url` |
| Extra authorize params | `id_token_add_organizations=true`, `codex_cli_simplified_flow=true`, `originator=<client>`, optional `allowed_workspace_id` | fact | same |
| Redirect | loopback `http://127.0.0.1:<port>/auth/callback`, default port **1455** (with a fallback port) | fact | `server.rs`; docs: "Codex's local callback server (default `localhost:1455`)" |
| Headless alternative | device code (`codex login --device-auth`, beta); the user must enable it in ChatGPT security settings; verification at `https://auth.openai.com/codex/device` | fact | https://learn.chatgpt.com/docs/auth.md, https://learn.chatgpt.com/docs/app-server.md |
| API-key side effect | after login, Codex tries an RFC 8693 token exchange (`requested_token=openai-api-key`) to obtain an "API-key style access token" and persists it too | fact | `server.rs` `obtain_api_key` |
| Model traffic with ChatGPT auth | default base URL switches to `CHATGPT_CODEX_BASE_URL = "https://chatgpt.com/backend-api/codex"` (Responses wire API); with an API key, `https://api.openai.com/v1` | fact | `codex-rs/model-provider-info/src/lib.rs` `to_api_provider` |
| Header `originator` | identifies the client; code treats `codex_cli_rs`, `codex-tui`, `codex_vscode`, `Codex …` as "first-party" | fact | `codex-rs/login/src/auth/default_client.rs` |
| Storage | "Codex caches login details locally in a plaintext file at `~/.codex/auth.json` or in your OS-specific credential store". Selectable with `cli_auth_credentials_store = file \| keyring \| auto \| ephemeral`. "treat `~/.codex/auth.json` like a password: it contains access tokens" | fact | https://learn.chatgpt.com/docs/auth.md |
| Refresh | "Codex refreshes tokens automatically during use before they expire" | fact | same |
| Billing | "Sign in with ChatGPT for subscription access. Sign in with an API key for usage-based access". "When you sign in with an API key, Codex uses standard API pricing instead of included ChatGPT plan credits." | fact | same |

**Pi (the harness this session runs in)** **[fact, from its installed package]**: `@earendil-works/pi-ai` `dist/auth/oauth/openai-codex.js` uses the **same `client_id`**, `https://auth.openai.com`, redirect `http://localhost:1455/auth/callback`, scope `openid profile email offline_access`, `codex_cli_simplified_flow=true` and `originator=pi`. It calls `https://chatgpt.com/backend-api`. Pi stores the resulting OAuth credentials in `~/.pi/agent/auth.json` (pi `docs/models.md`, `docs/custom-provider.md`). The file was not opened.

**(c) Undocumented:** `chatgpt.com/backend-api/codex` appears in no OpenAI API reference. The public issue [openai/codex#36886](https://github.com/openai/codex/issues/36886) (2026-08-04) asks for "a documented auth contract for third-party clients using a ChatGPT subscription with the Responses API". As of today it has **no answer** and still carries the `documentation` label. The help article that used to describe Codex CLI's sign-in (`help.openai.com/en/articles/11381614-api-codex-cli-and-sign-in-with-chatgpt`) now redirects to the generic Codex CLI page. Its earlier wording (secondary search snippets: the refresh token can "generate API keys, consume credits") could not be verified live.

## 4. GPT-6 Luna: availability and price per route

| Route | Luna available? | Price to the user | Source |
| --- | --- | --- | --- |
| ChatGPT/Codex sign-in, Plus / Pro / Business | yes: "GPT-6 Sol and GPT-6 Luna" (CLI, IDE, desktop, web) | included in the plan's Codex allowance; after that, credits at **2.5 / 0.25 / 12.5 credits per 1M** input / cached / output tokens | https://learn.chatgpt.com/docs/pricing.md, https://learn.chatgpt.com/docs/models.md |
| ChatGPT/Codex sign-in, Free / Go | "GPT-6 Luna at Standard speed **in the desktop app**, subject to rollout" | included | https://learn.chatgpt.com/docs/pricing.md |
| ChatGPT Enterprise / Edu | "an administrator must enable Luna first" | per workspace | https://learn.chatgpt.com/docs/models.md |
| ChatGPT *Chat* (not Work/Codex) | **no**: "They aren't available in Chat." | — | https://learn.chatgpt.com/docs/models.md |
| OpenAI API (`gpt-6-luna`) | yes; Responses, Chat Completions, Batch; structured outputs; 1,050,000 context; reasoning effort `none`…`max` | **$0.10** input, **$0.01** cached, **$0.125** cache write, **$0.50** output per 1M (Standard); Batch/Flex 50 % | https://developers.openai.com/api/docs/models/gpt-6-luna.md, https://developers.openai.com/api/docs/pricing.md |
| Vercel AI Gateway (`openai/gpt-6-luna`) | yes (live catalog; released 2026-09-22) | input `0.0000001`/token, output `0.0000005`/token (same as OpenAI list), no Gateway markup | live `GET https://ai-gateway.vercel.sh/v1/models`; markup and free tier per `jev-vercel.md` §7 |

- **[fact]** Plus usage estimate for Luna: **350–3,000 local messages per 5 hours** (Pro 5x 1,750–14,000; Pro 20x 7,000–56,000). "Weekly limits may also apply." Codex, ChatGPT Work, ChatGPT for Excel and Workspace Agents share one allowance. https://learn.chatgpt.com/docs/pricing.md, https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan
- **[fact]** API rate limits for `gpt-6-luna`: Tier 1 is 500 RPM and 500,000 TPM, up to Tier 5 at 30,000 RPM. Tier 1 requires "$5 paid". A "Free" usage tier exists in allowed geographies, but the Luna model page lists only Tiers 1–5. **[unknown]** whether Free-tier API keys can call Luna. https://developers.openai.com/api/docs/guides/rate-limits.md
- **[inference]** A typical Smart Paste extraction (≈3k input + ≈100 output tokens, reasoning `none`/`low`) costs roughly **$0.0003–0.0004** at API list price. Per call, it is negligible on any route.

## 5. The Codex SDK / `codex exec` / app-server path (supervisor addition)

### 5.1 What it is and how it authenticates

| Component | What it is | Auth | Source |
| --- | --- | --- | --- |
| **TypeScript SDK** `@openai/codex-sdk` (Apache-2.0) | "wraps the `codex` CLI from `@openai/codex`. It spawns the CLI and exchanges JSONL events over stdin/stdout". "Use the library server-side; it requires Node.js 18 or later." | Without `apiKey`, the spawned `codex exec` "reuses saved CLI authentication by default" (i.e. a prior `codex login`, including ChatGPT). With `apiKey`, the SDK injects `CODEX_API_KEY`. | https://learn.chatgpt.com/docs/codex-sdk.md; `sdk/typescript/README.md`, `src/exec.ts` (resolves platform packages `@openai/codex-darwin-arm64` etc.); https://learn.chatgpt.com/docs/non-interactive-mode.md |
| **Python SDK** `openai-codex` | "controls the local Codex app-server over JSON-RPC … Published SDK builds include a pinned Codex CLI runtime dependency." Stable release. | same as app-server | https://learn.chatgpt.com/docs/codex-sdk.md |
| **`codex exec`** | non-interactive CLI for scripts/CI | "reuses saved CLI authentication by default"; `CODEX_API_KEY` overrides. The ChatGPT-managed auth-in-CI path is "advanced", and the docs say "Do not use this workflow for public or open-source repositories." | https://learn.chatgpt.com/docs/non-interactive-mode.md |
| **Codex app-server** (`codex app-server`, open source) | "the interface Codex uses to power rich clients (for example, the Codex VS Code extension). Use it when you want a deep integration inside your own product: authentication, conversation history, approvals, and streamed agent events." JSON-RPC 2.0 over **stdio JSONL** (default), a Unix socket, or WebSocket ("experimental and unsupported"). | `account/login/start` with `apiKey`, **`chatgpt`** ("Codex owns the ChatGPT OAuth flow, persists tokens, and refreshes them automatically"; returns an `authUrl` and hosts the local callback), `chatgptDeviceCode`, or experimental `chatgptAuthTokens` (the host supplies the tokens). `account/read` reports `planType`. | https://learn.chatgpt.com/docs/app-server.md |

- **[fact]** The protocol source marks the external-token mode differently from the docs page. The docs call `chatgptAuthTokens` "experimental and intended for host apps that already own the user's ChatGPT auth lifecycle". The protocol type in `codex-rs/app-server-protocol/src/protocol/v2/account.rs`, and the generated JSON schemas (`schema/json/v2/LoginAccountParams.json`, `AccountUpdatedNotification.json`), say: "[UNSTABLE] FOR OPENAI INTERNAL USE ONLY - DO NOT USE. The access token must contain the same scopes that Codex-managed ChatGPT auth tokens have." The managed `chatgpt` mode carries no such marker.
- **[fact]** The app-server exposes `model/list` ("Available models … depend on the client and account"), per-turn `outputSchema` (structured output for one turn), `account/rateLimits/read` and `account/rateLimits/updated` ("fetch ChatGPT rate limits"), and `account/usage/read`. https://learn.chatgpt.com/docs/app-server.md
- **[fact]** "Use `clientInfo.name` to identify your client for the OpenAI Compliance Logs Platform. If you are developing a new Codex integration intended for enterprise use, please contact OpenAI to get it added to a known clients list." The doc's own example uses `name: "my_product"`. https://learn.chatgpt.com/docs/app-server.md
- **[fact]** Stability wording in the same doc, in the Code Mode host subsection: "The app-server command and WebSocket transport are experimental and aren't supported for production workloads." **[unknown]** whether "app-server command" there means the whole app-server or only the `--code-mode-host` option. The page elsewhere presents app-server as the product-embedding interface, and the Python SDK built on it is "stable".
- **[fact]** Under ChatGPT auth, the model requests go to `https://chatgpt.com/backend-api/codex` (§3), and usage counts against the plan's Codex allowance. The app-server's rate-limit notifications report that allowance (`limitId: "codex"`).

### 5.2 Which models (is GPT-6 Luna reachable?)

**[fact]** Yes, within plan rules (§4). `gpt-6-luna` is selectable in the CLI and SDK on Plus, Pro and Business; `model/list` returns what the account may use. Free/Go have Luna "in the desktop app" only. **[unknown]** whether it's also available to Free/Go through CLI, SDK or app-server.

### 5.3 Is it rate-limited by the user's ChatGPT plan?

**[fact]** Yes. Codex usage with ChatGPT sign-in draws on the plan's shared agentic allowance (5-hour and weekly windows, plus credits), which is visible via `/status`, the usage dashboard, or `account/rateLimits/read`. With an API key, standard API pricing and tiers apply instead. https://learn.chatgpt.com/docs/pricing.md, https://learn.chatgpt.com/docs/auth.md

### 5.4 Is it usable from a native Swift macOS app?

- **[fact]** There is no Swift SDK. The official SDKs are TypeScript (Node ≥ 18) and Python (≥ 3.10).
- **[inference]** A Swift app can skip both SDKs and launch `codex app-server` as a subprocess (`Process` + pipes) speaking newline-delimited JSON-RPC over stdio. That is the protocol the docs document, and it needs **no Node.js**. The TypeScript SDK path would need a bundled Node runtime.
- **[fact, observed locally]** The Codex CLI binary on this Mac (Homebrew cask `codex` 0.147.0) is a single native executable of **~220 MB** (`/opt/homebrew/Caskroom/codex/0.147.0/bin/codex`). The app would have to bundle it or require the user to install Codex.
- **[inference]** Every call is an **agent turn**: Codex's own base instructions, tool definitions and sandbox wrap the prompt. Extraction then carries extra tokens and latency that a plain Responses call wouldn't, and the output is the agent's final message (`outputSchema` can constrain it). This was not measured here, because running it requires a signed-in call.
- **[unknown]** Behaviour of the Codex Seatbelt sandbox when launched from a signed or notarized host app. Whether an App-Sandboxed JevPaste could spawn it wasn't investigated (JevPaste's entitlements are out of scope).

### 5.5 Does OpenAI permit embedding Codex auth in a third-party end-user app? (exact wording)

(See §5.6 for the item-by-item check of a separate ChatGPT-generated analysis, and §13 for the verdict per distribution variant.)

For (documentation, first-party):

- App-server: "Use it when you want a deep integration inside your own product: authentication, conversation history, approvals, and streamed agent events." https://learn.chatgpt.com/docs/app-server.md
- Codex SDK: "Use the SDK when you need to: … Build Codex into your own internal tools and workflows. Integrate Codex within your own application". https://learn.chatgpt.com/docs/codex-sdk.md
- Codex for Open Source programme page (grants ChatGPT Pro with Codex to maintainers): "Developers should code in the tools they prefer, whether that's Codex, OpenCode, Cline, pi, OpenClaw, or something else, and this program supports that work." **[fact]** https://developers.openai.com/community/codex-for-oss

For (statements by OpenAI people, non-contractual):

- Tibo Sottiaux, 2026-05-23: "About 5% of our production traffic is on the Pi harness, about another 5% is on OpenCode. Reminder you can use your ChatGPT account in a flourishing set of other tools." https://x.com/thsottiaux/status/2058071172361998482
- Tibo Sottiaux, 2026-08-21: "Converting a subscription into api traffic to then re-serve or share across many users is not something we support and this type of usage gets flagged by our fraud-prevention systems. You are completely fine if you use your subscription through Sign in With ChatGPT, either through the official clients or through one of the many OSS clients (Pi, OpenCode, ...) that support signing in with your account and using your included usage." https://x.com/thsottiaux/status/2090675027670978569
- Sam Altman, 2026-05-02: "you can sign in to openclaw with your chatgpt account now and use your subscription there!" https://x.com/sama/status/2050357911915028689

Against, or limiting:

- Tibo Sottiaux, 2026-09-08, replying to "Companion", an iMessage agent product ("bring your ChatGPT account"): "Sorry, but this is not an approved use of Sign in With ChatGPT. We support pure OSS clients and others we have partnerships with, but you need to reach out and talk to us for that." An X community note on the product post repeats this and links the SIWC help article. https://x.com/thsottiaux/status/2097131394199896166
- Tibo Sottiaux, 2026-08-23: "We don't support sub2api". https://x.com/thsottiaux/status/2091406082497552557
- Terms of Use (updated 2026-01-16; the EU and RoW versions have the same wording): "You may not share your account credentials or make your account available to anyone else". Prohibited: "Automatically or programmatically extracting data or Output" and "Interfering with or disrupting our Services, including circumventing any rate limits or restrictions". https://openai.com/policies/terms-of-use/, https://openai.com/policies/eu-terms-of-use/, https://openai.com/policies/row-terms-of-use/
- OpenAI's own reading of those Terms for Pro (help centre, shown as "updated 4 days ago", i.e. about 2026-09-22): "Usage must also adhere to our Terms of Use, which prohibits, among other things: Abusive usage, such as automatically or programmatically extracting data. Sharing your account credentials or making your account available to anyone else. Reselling access or using ChatGPT to power third-party services." https://help.openai.com/en/articles/9793128-about-chatgpt-pro-tiers
- Terms that govern Codex use with a ChatGPT account: "When you sign in to Codex using an existing ChatGPT account, the ChatGPT Terms of Use and Privacy Policy … apply". No separate Codex terms were found, and Service Terms §4 only covers the licensing of Codex *output*. https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan, https://openai.com/policies/service-terms/
- The usage-policy page adds nothing specific to third-party clients. https://openai.com/policies/usage-policies/
- "Do not use this workflow [ChatGPT-managed auth in CI] for public or open-source repositories." https://learn.chatgpt.com/docs/non-interactive-mode.md

**Plain answer.**

- **Daniel is right** that OpenAI is permissive here and that the Codex SDK / app-server path is officially documented for embedding Codex, with a ChatGPT login, in your own product. He is also right that OpenAI's Codex lead has said personal use of your own subscription through OSS clients like Pi and OpenCode is "completely fine".
- **He is not right that this makes it open to any third-party app for any users.** The same person drew the line on 2026-09-08: pure OSS clients, or partners who "reach out and talk to us". Beyond that, "not an approved use".
- **No clause in the Terms grants the permission**, and OpenAI's help centre still lists "using ChatGPT to power third-party services" as prohibited.

For JevPaste:

- **Daniel on his own Mac, his own account:** within what OpenAI publicly calls fine. **[statement]**
- **Shipped to other users as open source (with an actual OSS licence):** within the "pure OSS clients" line. **[statement]**
- **Shipped closed or commercially:** requires contacting OpenAI for a partnership. **[statement]**

### 5.6 Claims from a ChatGPT-generated analysis (supplied by Daniel), checked

| # | Claim | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | App-server officially offers a `chatgpt` login via `account/login/start { type: "chatgpt" }`, so a local third-party app never handles the OAuth token and needs no client registration | **Mostly true.** Official: "Codex owns the ChatGPT OAuth flow, persists tokens, and refreshes them automatically". The host app receives only an `authUrl` and completion notifications. "No registration" holds only because the app-server authenticates as **Codex**, with Codex's built-in public `client_id` (`CLIENT_ID`, overridable via `CODEX_APP_SERVER_LOGIN_CLIENT_ID`). That's a technical fact, not a grant of permission. | https://learn.chatgpt.com/docs/app-server.md (Auth endpoints); `codex-rs/login/src/auth/manager.rs`, `server.rs` |
| 2 | `chatgptAuthTokens` is marked "FOR OPENAI INTERNAL USE ONLY – DO NOT USE" | **True in the protocol source and schemas** (exact text: "[UNSTABLE] FOR OPENAI INTERNAL USE ONLY - DO NOT USE."). The public docs page instead calls it "experimental and intended for host apps that already own the user's ChatGPT auth lifecycle". The two first-party sources disagree; the stricter one is the code. | `codex-rs/app-server-protocol/src/protocol/v2/account.rs`; https://learn.chatgpt.com/docs/app-server.md |
| 3 | `account/read` and `model/list` expose whether GPT-6 Luna is available on the user's plan | **Partly true.** `account/read` and `account/updated` report `planType` (e.g. `"plus"`). `model/list`'s "Available models, reasoning efforts, and defaults depend on the client and account", so Luna's presence in `model/list` is the availability signal. `account/read` itself says nothing about models. Not observed live (no sign-in). | https://learn.chatgpt.com/docs/app-server.md (Models; Auth endpoints) |
| 4 | ToU: accounts are personal, credentials not shareable, rate limits must not be circumvented | **True.** "You may not share your account credentials or make your account available to anyone else and are responsible for all activities that occur under your account." Prohibited: "Interfering with or disrupting our Services, including circumventing any rate limits or restrictions or bypassing any protective measures". | https://openai.com/policies/terms-of-use/, https://openai.com/policies/eu-terms-of-use/ (both updated 2026-01-16) |
| 5 | EU terms forbid "automatically or programmatically extracting" output, which sits in tension with the programmatic SDK/app-server | **Quote true** (EU wording: "Automatically or programmatically extracting data or Output"; the US and RoW wording is equivalent). **Tension: real, and not reconciled in writing.** OpenAI's own docs promote programmatic Codex use with ChatGPT auth: `codex exec` "reuses saved CLI authentication by default", and ChatGPT-managed auth in CI/CD is documented. **[inference]** OpenAI evidently doesn't apply that clause to use through its Codex harness. But no document says so, and a smart-paste extractor isn't coding work. | EU ToU; https://learn.chatgpt.com/docs/non-interactive-mode.md; https://learn.chatgpt.com/docs/auth/ci-cd-auth.md |
| 6 | Conclusion: personal local use is clear; other users each running a local app-server with their own login looks like intended use but has no explicit doc; cloud-relaying ChatGPT usage: don't | **Personal:** consistent with the 2026-08-21 statement ("completely fine … official clients or … OSS clients"), but "clear" overstates it: it is a post, not a term. **Other users:** needs refining. The 2026-09-08 statement makes approval depend on the *client*, not on where it runs: "We support pure OSS clients and others we have partnerships with, but you need to reach out and talk to us for that." A closed or unlicensed app used by others is "not an approved use" even if every user runs it locally with their own login. **Cloud relay:** correct, and it is the one case with an explicit first-party "not something we support … flagged by our fraud-prevention systems" (2026-08-21) and "We don't support sub2api" (2026-08-23). | X posts in §5.5 |

**Does "pure OSS client" settle it for JevPaste?**

- **[fact]** A public repo is not an open-source licence. GitHub: "without a license, the default copyright laws apply, meaning that you retain all rights to your source code and no one may reproduce, distribute, or create derivative works from your work." (https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository). JevPaste became public on 2026-09-26 and has no licence, so by that definition it is not OSS today.
- **[fact]** The two clients OpenAI names both carry OSI licences: pi (MIT, `badlogic/pi-mono`) and OpenCode (MIT). They are coding harnesses.
- **[unknown]** OpenAI hasn't defined "pure OSS client". Open questions: does it mean an OSI licence alone, no hosted or commercial component, or a coding use-case? A developer asked in the same thread on 2026-09-08 ("is there public information what is supported use? I have couple of OSS projects where I want to enable Codex login use, but it's unclear if I can."), and no public answer was found.
- **[inference]** The rejected "Companion" product differed from Pi and OpenCode on several axes at once: closed, hosted ("isolated computer"), commercial, and not a coding tool. The statement therefore doesn't isolate which one decided it. Adding an OSI licence would move JevPaste onto the literal wording ("OSS clients … that support signing in with your account"), but only OpenAI can confirm that a non-coding smart-paste utility counts. The wording the sources support is "pure OSS clients" or "partnerships" ("reach out and talk to us"), no more.

## 6. Terms: what is permitted where

| Question | ChatGPT sign-in (SIWC, official) | ChatGPT sign-in via Codex harness / Codex OAuth | OpenAI API key | Vercel AI Gateway |
| --- | --- | --- | --- | --- |
| Governing terms | Partner agreements (not public) | ChatGPT Terms of Use | Services Agreement (business/developer) | Vercel terms + provider pass-through (see `jev-vercel.md`) |
| Personal-use native app (Daniel only) | n/a: identity only | **[statement]** "completely fine" through official or OSS clients | **[fact]** permitted: "the right to use OpenAI's API to integrate the Services into Customer Applications" (§2.2) | **[fact]** permitted (Gateway keys "work anywhere"; `jev-vercel.md` §5) |
| Other users | only as an OpenAI partner | **[statement]** pure OSS clients, or a partnership; otherwise "not an approved use". **[fact]** the help centre lists "using ChatGPT to power third-party services" as prohibited | **[fact]** "to make Customer Applications available to End Users" (§2.2); "Customer will not share Account access credentials … between multiple users" (§3.1); "Customer is responsible for all activities … of End Users" (§3.2) | **[inference]** permitted if each user brings their own Gateway key, or if Daniel funds a shared key and accepts the cost |

Services Agreement quotes (updated 2025-12-01, effective 2026-01-01): https://openai.com/policies/services-agreement/

## 7. What a user sees

- **Official SIWC (partner site):** a "Sign in with ChatGPT" or "Continue with ChatGPT" button, then OpenAI's sign-in and a screen listing the identity info shared (name, email, picture). Any extra permissions follow separately. **[fact]** help article, §2.
- **Codex-style ChatGPT login (app-server `chatgpt` mode, or pi/Codex CLI):** the app opens the browser at an `auth.openai.com/oauth/authorize…` URL. The user signs in to ChatGPT, approves, and the browser returns to `localhost:<port>/auth/callback` with a success page. Afterwards `account/updated` reports e.g. `planType: "plus"`. **[fact]** app-server doc and Codex source. **[inference]** Because the request carries Codex's `client_id`, OpenAI's consent page presents the client as Codex, not as JevPaste; this was not observed (no login was run). Headless alternative: a one-time device code entered at `https://auth.openai.com/codex/device`, which must first be enabled in ChatGPT security settings.
- **OpenAI API key:** the user creates an OpenAI Platform account, adds billing ($5 prepaid for Tier 1), creates a key at `platform.openai.com/api-keys`, and pastes it into JevPaste.
- **Vercel AI Gateway:** the user creates a Vercel team, enables AI Gateway, creates a key, and pastes it into JevPaste. There's a $5/month free credit (`jev-vercel.md` §7).

## 8. What would block JevPaste

1. **[fact]** The official SIWC programme grants no inference, has no public registration, and has "no timeline" for user-funded usage. It cannot deliver the #31 goal.
2. **[fact]** No documented, stable contract exists for using a ChatGPT credential outside the Codex harness. `chatgpt.com/backend-api/codex` is undocumented ([openai/codex#36886](https://github.com/openai/codex/issues/36886) is unanswered), and the credential "isn't valid against `api.openai.com`" (issue author's observation, **[secondary]**). Calling that backend directly with a JevPaste-owned client is therefore both unsupported and outside the one documented embedding surface.
3. **[statement]** Distribution to other users is approved only for "pure OSS clients" or partners. **[fact]** JevPaste's GitHub repo was made **public on 2026-09-26 and has no licence** (`gh repo view`: `visibility: PUBLIC`, `licenseInfo: null`), so it isn't an OSS client in any licence sense today (§5.6).
4. **[inference]** Via the documented route (app-server), JevPaste would ship or require a ~220 MB Codex binary, pay agent-harness overhead on every paste, and depend on an interface whose stability wording is mixed (§5.1).
5. **[inference]** Reusing Codex's `client_id` (as pi does) or the user's `~/.codex/auth.json` makes JevPaste impersonate or piggy-back on Codex's client identity. OpenAI's statements cover "clients that support signing in with your account". None of them addresses a non-coding utility app, and none addresses the `client_id` question. **[unknown]** whether OpenAI would treat a smart-paste extractor as a "client" in the sense Tibo meant.
6. **[fact]** Plan limits apply: Free/Go get Luna only "in the desktop app", Enterprise/Edu need admin enablement, and every Smart Paste draws on the same allowance as the user's Codex/Work usage.

## 9. Discrepancies and unknowns

1. **[fact]** The help article that once explained Codex CLI's sign-in (`11381614`) now redirects to the CLI landing page, so the old consent wording can't be checked.
2. **[fact]** "Sign in with ChatGPT" names two different things: the partner identity product (§2), and Codex's subscription login (§3), which OpenAI people also call "Sign in With ChatGPT" (§5.5). Both use `auth.openai.com`.
3. **[unknown]** The scope of "pure OSS clients". Does it need an OSI licence? Must the client be a coding agent? Does it cover a separately built extractor using the Codex harness? No first-party definition was found; a forum user asked the same on 2026-09-08 ("is there public information what is supported use?") without a published answer.
4. **[unknown]** Whether the app-server as a whole is "experimental" (see §5.1 wording).
5. **[unknown]** Whether Free/Go users can reach Luna through the CLI, SDK or app-server rather than the desktop app.
6. **[unknown]** Whether Free-tier API keys can call `gpt-6-luna`.
7. **[unknown]** Latency and token overhead of a Codex agent turn vs a direct Responses call for an extraction prompt (unmeasured; would need signed-in calls).
8. **[secondary]** Various third-party blogs claim OpenAI "officially supports" third-party harnesses. The first-party statements above are narrower than those claims.

## 10. Decision implications (for Daniel; no decision is taken here)

1. **For the #31 spike (Daniel only),** Luna via Daniel's own ChatGPT sign-in is consistent with OpenAI's public "completely fine" line, as long as it runs through a client that signs in with his account. The documented surface is the Codex app-server or `codex exec`. The pi-style direct call to `backend-api/codex` works in practice but has no contract.
2. **For "any and all JevPaste users",** the only terms-clean paths today are:
   - **BYO OpenAI API key:** Luna at $0.10/$0.50 per M. Explicitly allowed for Customer Applications with End Users.
   - **BYO Vercel Gateway key:** same price, and $5/month free credit per Vercel team.
   - **Daniel-funded key:** he pays for everyone.
3. **The subscription route for other users** requires one of two things: making JevPaste a genuine OSS client (add an OSS licence) and accepting that "pure OSS" is undefined, or contacting OpenAI for a partnership. Either way, the documented integration is the Codex harness (bundled binary, agent turn), not a model endpoint.
4. **Widening the map beyond Daniel's Mac** is therefore feasible today only with BYO-key (API or Gateway). A subscription-backed version for other users is a partnership or licensing question for OpenAI, not a technical one.

## 11. Validation performed (read-only; no credentials; no sign-in; no billable calls)

- `gh issue view 48`, `gh issue view 31 --comments`; read `docs/research/jev-vercel.md` and `docs/research/typesafe-direct.md` from their branches; `gh repo view` (visibility and licence).
- OpenAI docs as raw Markdown: `learn.chatgpt.com/docs/{auth,models,pricing,sites,plugins,codex-sdk,app-server,non-interactive-mode,open-source}.md`, `developers.openai.com/api/docs/{models/gpt-6-luna,pricing,guides/rate-limits}.md`, `developers.openai.com/plugins/build/auth.md`, and the `llms.txt` indexes.
- OpenAI help centre (Cloudflare blocks curl, so pages were rendered in Chrome and read as text): articles `20001410` (SIWC), `6825453` (release notes, 2026-07-29 entry), `11369540` (Codex with your ChatGPT plan), `9793128` (Pro tiers), `11381614` (now redirects).
- OpenAI policies rendered in Chrome: Terms of Use (US/EU/RoW), Usage Policies, Service Terms, Services Agreement. `openai.com/form/sign-in-with-chatgpt/` returns 404.
- Codex source: sparse clone of `github.com/openai/codex` at `e72da2b` (2026-09-26); read `codex-rs/login/src/{server.rs,auth/manager.rs,auth/default_client.rs}`, `codex-rs/model-provider-info/src/lib.rs`, `sdk/typescript/{README.md,package.json,src/exec.ts}`, `codex-rs/app-server/README.md`.
- Pi package: `@earendil-works/pi-ai` `dist/auth/oauth/openai-codex.js` and pi docs, for constants and storage location only. No auth file was opened.
- Codex for Open Source page HTML: `https://developers.openai.com/community/codex-for-oss`.
- `codex-rs/app-server-protocol` (`src/protocol/v2/account.rs`, `schema/json/**`) at the same commit, grepped for the `chatgptAuthTokens` markers. GitHub Docs' "Licensing a repository" page. The `LICENSE` files of `badlogic/pi-mono` and `anomalyco/opencode`, both MIT.
- X posts (rendered in Chrome): `thsottiaux/status/2058071172361998482`, `2090675027670978569`, `2091406082497552557`, `2097131394199896166` (and the parent post and community note), `sama/status/2050357911915028689`; profile bio `@thsottiaux`.
- Official forum JSON: `community.openai.com/t/1391237.json` (staff flags), `…/1389585.json`, `…/1371778.json`.
- Live Gateway catalog: `GET https://ai-gateway.vercel.sh/v1/models` (unauthenticated), entries `openai/gpt-6-luna` and `openai/gpt-6-luna-fast`.
- Local: `codex --version` → `codex-cli 0.147.0`; binary size via `ls -la`.
- `web_search` was used only to discover leads. Third-party blogs (manifest.build, explainx.ai, dreaming.press, EvanZhouDev/openai-oauth) were used to find primary URLs, never as evidence.

### Limitations

- No sign-in was performed, so the consent screen, `model/list` output, per-plan Luna availability through the CLI, and agent-turn overhead are documented or inferred, not observed.
- The permission picture rests on X posts by OpenAI staff, which can change or be superseded without notice. They are not terms.
- The help centre and learn.chatgpt.com change frequently (pages updated within the last few days). Re-check before any implementation.

## 12. Primary sources

1. Sign in with ChatGPT (help centre): https://help.openai.com/en/articles/20001410-sign-in-with-chatgpt
2. ChatGPT release notes (2026-07-29 SIWC entry): https://help.openai.com/en/articles/6825453-chatgpt-release-notes
3. ChatGPT Sites (SIWC for Sites): https://learn.chatgpt.com/docs/sites.md; Plugins: https://learn.chatgpt.com/docs/plugins.md
4. OpenAI Support forum reply (no timeline for user-funded usage): https://community.openai.com/t/feature-request-allow-chatgpt-sites-to-use-the-visitors-chatgpt-subscription-or-credits/1391237
5. Codex authentication: https://learn.chatgpt.com/docs/auth.md
6. Codex models: https://learn.chatgpt.com/docs/models.md; Codex pricing and limits: https://learn.chatgpt.com/docs/pricing.md
7. Codex SDK: https://learn.chatgpt.com/docs/codex-sdk.md; App Server: https://learn.chatgpt.com/docs/app-server.md; Non-interactive mode: https://learn.chatgpt.com/docs/non-interactive-mode.md; Open Source: https://learn.chatgpt.com/docs/open-source.md
8. Codex source: https://github.com/openai/codex (`codex-rs/login`, `codex-rs/model-provider-info`, `sdk/typescript`, `codex-rs/app-server`); open issue https://github.com/openai/codex/issues/36886
9. Using Codex with your ChatGPT plan: https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan; About ChatGPT Pro tiers: https://help.openai.com/en/articles/9793128-about-chatgpt-pro-tiers
10. Terms: https://openai.com/policies/terms-of-use/, https://openai.com/policies/eu-terms-of-use/, https://openai.com/policies/row-terms-of-use/, https://openai.com/policies/usage-policies/, https://openai.com/policies/service-terms/, https://openai.com/policies/services-agreement/
11. OpenAI API: https://developers.openai.com/api/docs/models/gpt-6-luna.md, https://developers.openai.com/api/docs/pricing.md, https://developers.openai.com/api/docs/guides/rate-limits.md
12. OpenAI staff statements: https://x.com/thsottiaux/status/2058071172361998482, https://x.com/thsottiaux/status/2090675027670978569, https://x.com/thsottiaux/status/2091406082497552557, https://x.com/thsottiaux/status/2097131394199896166, https://x.com/sama/status/2050357911915028689
13. Partner first-party: https://vercel.com/changelog/sign-in-with-chatgpt-is-now-available-on-vercel, https://supabase.com/blog/sign-in-with-chatgpt-beta
14. GitHub Docs, licensing a repository: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository
15. Vercel AI Gateway catalog: `GET https://ai-gateway.vercel.sh/v1/models`; pricing, free tier and auth per `docs/research/jev-vercel.md` (branch `research/jev-vercel`)

## 13. Decision table

| | **ChatGPT sign-in: official SIWC** | **ChatGPT sign-in via Codex SDK / app-server** (Codex OAuth) | **OpenAI API key** | **Vercel AI Gateway** |
| --- | --- | --- | --- | --- |
| Auth flow | OpenAI identity sign-in for partners; no public registration, scopes or native redirect | OAuth code+PKCE at `auth.openai.com` with **Codex's** public `client_id`, loopback `:1455` (or device code); app-server `account/login/start {type:"chatgpt"}` owns the flow and refresh | user-pasted `sk-…` key; `Authorization: Bearer` to `api.openai.com/v1` | user-pasted Gateway key; `Authorization: Bearer` to `ai-gateway.vercel.sh` |
| Models / GPT-6 Luna | **none**: identity only | **yes** on Plus/Pro/Business; Free/Go "in the desktop app" only; Enterprise/Edu need admin enablement; runs as a Codex **agent turn** via undocumented `chatgpt.com/backend-api/codex` | **yes**, `gpt-6-luna` (Responses/Chat/Batch, structured outputs) | **yes**, `openai/gpt-6-luna` |
| Rate limits / cost to user | n/a | plan allowance shared with Codex/Work (Plus ≈ 350–3,000 Luna messages/5 h, weekly limits); then credits (2.5 / 12.5 credits per 1M in/out) | $0.10 / $0.50 per 1M; Tier 1 ($5 paid) 500 RPM / 500k TPM | $0.10 / $0.50 per 1M, no markup; $5/month free credit; free-tier limits unpublished |
| Terms: personal-use native app | n/a | **[statement]** "completely fine" through official or OSS clients; no contractual clause | permitted (Services Agreement §2.2) | permitted |
| Terms: other users | partners only | **[statement]** "pure OSS clients and others we have partnerships with"; closed products "not an approved use"; **[fact]** help centre: no "using ChatGPT to power third-party services" | permitted: Customer Applications "available to End Users"; no shared credentials (§3.1) | permitted with per-user keys (or Daniel-funded) |
| What the user sees | "Continue with ChatGPT" + identity consent | browser login to ChatGPT, consent presented under Codex's client identity **[inference]**, localhost success page; plan shown as `planType` | create a Platform account, add billing, paste key | create a Vercel team, enable Gateway, paste key |
| What would block JevPaste | grants no inference; no timeline for user-funded usage | not OSS today (public repo, **no licence**) → partnership needed for other users; ~220 MB Codex binary or install; agent-turn overhead (unmeasured); no documented contract for direct backend use; mixed stability wording | user friction (billing setup); Free-tier Luna access **[unknown]** | user friction (Vercel account); free-tier per-model limits unpublished |

### Verdict per variant (ChatGPT subscription routes)

"Supported wording" quotes the strongest first-party text for each case. None of these statements is contractual. The ToU clauses in §5.5 and §5.6 (credentials, "programmatically extracting", "using ChatGPT to power third-party services") apply throughout.

| Variant | Verdict | Supported wording (source) |
| --- | --- | --- |
| **V1** Daniel alone: local JevPaste → local `codex app-server` (or `codex exec`), his own `chatgpt` login, Luna on his plan (the #31 spike) | **Publicly endorsed; no written term** | "You are completely fine if you use your subscription through Sign in With ChatGPT, either through the official clients or through one of the many OSS clients" (Sottiaux, 2026-08-21); app-server "inside your own product" (docs) |
| **V1b** Same, but calling `chatgpt.com/backend-api/codex` directly with Codex's `client_id` (pi-style, no app-server) | **Works in practice; no contract** | Pi does exactly this and is named as fine (2026-05-23, 2026-08-21), but the endpoint is undocumented ([openai/codex#36886](https://github.com/openai/codex/issues/36886) unanswered) |
| **V2** JevPaste published under an OSI licence; each user runs it locally with their own ChatGPT login via app-server | **Plausibly within the stated line; unconfirmed** | "We support pure OSS clients" (2026-09-08). "Pure" is undefined, and whether a non-coding utility counts is **[unknown]**. Confirm with OpenAI before relying on it |
| **V3** JevPaste distributed as it is today (public repo, **no licence**), or closed or commercial, to other users with their own logins | **Not approved without a partnership** | "Sorry, but this is not an approved use of Sign in With ChatGPT. We support pure OSS clients and others we have partnerships with, but you need to reach out and talk to us for that." (2026-09-08); help centre: no "using ChatGPT to power third-party services" |
| **V4** Cloud relay: a JevPaste server holding users' ChatGPT tokens, or one subscription serving many users | **Not supported; flagged as fraud** | "Converting a subscription into api traffic to then re-serve or share across many users is not something we support and this type of usage gets flagged by our fraud-prevention systems." (2026-08-21); ToU credential-sharing clause |
| **V5** Use `chatgptAuthTokens` (JevPaste owns the ChatGPT tokens and feeds them to app-server) | **Don't** | Protocol source: "[UNSTABLE] FOR OPENAI INTERNAL USE ONLY - DO NOT USE." |
| **V6** Official "Sign in with ChatGPT" (identity) as JevPaste's login | **Unavailable and useless for Luna** | Identity only; partners only; no timeline for user-funded usage (help centre; OpenAI Support 2026-09-08) |
