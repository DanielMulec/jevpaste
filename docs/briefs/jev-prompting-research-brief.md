# Research brief: what Typesafe says about asking Jev, and where jevpaste deviates

Daniel heard in a talk that Jev is not a thinker. The question has to do the thinking, and *how* Jev is asked —
the wording, the options, the state, how many questions and in what order — changes the results a lot. Find out
what Typesafe itself says about this, and where jevpaste already deviates from it. This is research for a later
discussion with Daniel about which deviations are fine and why, and for the next Narrowing round
([Improve Narrowing after the beta](https://github.com/DanielMulec/jevpaste/issues/52)). It is not a decision.

## What jevpaste asks Jev today (read these first)

- Wordings, verbatim: `Sources/SmartPasteCore/Narrowing/NarrowingWordings.swift`. Tunables: `NarrowingPolicy.swift`.
- Request shape: `Sources/SmartPasteCore/Values/NarrowingRequest.swift` (state = `source_document`,
  `target_context`, `excerpts`; Choice questions only, ≤ 255 options, `null` descriptions in the id form),
  `Narrowing/RequestAssembly.swift`, `Narrowing/StepPlanner.swift`.
- Question sequence: `Narrowing/Narrowing.swift` (steps), `FollowUp.swift` (follow-up, speculative fan-out, ranking
  of probabilities), `ChooserFill.swift` (asking again for each Candidate Chooser row).
- Target Context: `Sources/MacInterop/TargetContextReader.swift`. Model ids: `Sources/JevGateway/JevEndpoint.swift`.
  Settings Test question: `Sources/JevGateway/JevConnectionTest.swift`.
- Design and recorded reasons: `docs/design/narrowing.md`, `docs/design/jev-gateway.md`, `CONTEXT.md`.
- Our own measurements (why the wordings are what they are):
  `git show spike/narrowing:spikes/narrowing/round2/FINDINGS.md`, `…:spikes/narrowing/round2/results/explore.md`,
  `…:spikes/narrowing/FINDINGS.md` (round 1), and the older `spikes/abstention`, `spikes/context`,
  `spikes/granularity` FINDINGS on the same branch. Issue #52 (`gh issue view 52 --comments`).

## Questions

1. **Choice.** jevpaste uses nothing but Choice. Everything Typesafe says about it: many options (ours are up to 252
   overlapping excerpts of one text), option ids with `null` descriptions and the texts in the state, whether option
   names are read, "none of the above"-style options (`nothing_fits`, `ask_user`), "a Choice always names something",
   probability collapse onto one option, `confidence`, extraction as a Choice over enumerated parts, the nearest
   cookbooks (line-by-line search, structure recovery, skill suggestion), progressive disclosure, speculative fan-out,
   Choice versus Noul for "whether" questions.
2. **Instructions.** Our one long instruction carries several conditional branches (one particular thing → exact
   option, else the least extra text, else everything, ask if ambiguous). It is place-neutral, refers to "the place
   where the text cursor is", uses backticked state references, becomes object-valued at later steps
   (`{current_piece, question}`), and is identical at every step and in every parallel Choice. What does Typesafe say
   about each of these, and about length?
3. **State.** The whole copy, the Target Context object and the excerpts map are sent at every step. Guidance on
   context rot and distractors, minimal state per question, key order, what belongs in the state versus the question.
4. **How many questions, and in what order.** Our Narrowing makes one judgment per step over several steps. Does
   Typesafe recommend decomposing into several narrow questions per request instead or as well? What does it say
   about independence of parallel questions, asking the same question again with options removed (our chooser fill),
   asking one thing several ways, composing answers in code, review bands and confidence routing?
5. **Model and language.** Version pinning: on the Vercel AI Gateway jevpaste sends `typesafe-ai/jev`, which pins no
   version. The jaggedness page for jev-1.13 and anything newer (models, changelog) since 2026-09-17. English is the
   primary language, but our copies, labels and forms are often German.
6. **Probability order.** `FollowUp.swift` breaks ties by the order in which Jev lists `probabilities`. Does Typesafe
   define that order (option order? arbitrary? route-dependent?)? Probabilities are rounded, so ties are common.
7. **Anything else** a Choice-based extraction app should know and may ignore today: adversarial content in the state
   (a copy can contain instructions), Typesafe's agent-skill guidance, how Typesafe says to evaluate and tune
   (labelled data, thresholds per question, refit after rewording).
8. **Talks and posts by Typesafe staff** with guidance on wording and question design, especially from 2026-09-15
   on. Known: the launch post, a Latent Space interview with Diogo Almeida (`cFx9Z3ZXca0`), a CodeRabbit talk with
   Allie Laabs (`j8RO-IOKtvM`). Not yet read by anyone here: LangChain × TypeSafe (`HHUsHkYhkcM`), ThursdAI with
   Allie Laabs (`QkPnAoHBXwo`), Diogo at AI Engineer (`cJ0EOzey--o`). Read what you can (captions are fine; say so).

## Deliverable

One file: `docs/research/jev-prompting.md` in this worktree. Tables over prose, plain English, aim for ≤ 450 lines.

1. TL;DR, at most 10 items.
2. Sources table with short keys (URL, retrieval date).
3. **Deviation register** — the core. One row per aspect of how jevpaste asks Jev. Columns:
   what jevpaste does (file) · what Typesafe says (quote + source key) · verdict (`follows` / `deviates` / `partly` /
   `no guidance`) · our recorded reason, if any (design doc, spike FINDINGS with numbers, issue — or "none recorded") ·
   evidence on each side (`primary-doc` versus `measured` on our cells) · what it may cost us (tie to a known miss
   where plausible: C03, C04, R10, B06, two exact addresses not asked; label `inferred`) · candidate alternative to
   test in #52's next round (not run).
4. Where our own measurements confirm or contradict Typesafe's guidance (for example: wording variant V7 added
   context and got worse; the id form, not the wording, fixed the weak "keep"; the first of two equal addresses took
   all the weight).
5. What stays unknown.

## Rules

- Primary sources only: Typesafe's docs (the `.md` pages and `llms-full.txt` at `docs.typesafe.ai`), cookbooks,
  Typesafe's GitHub repos (SDKs, skills, evals), posts and talks by Typesafe staff. Secondary write-ups only as
  pointers. Label every claim `primary-doc`, `measured` (jevpaste's own recorded data; cite file and branch),
  `inferred` or `unknown`.
- Optional map, not evidence: Daniel's independent sister project collected Typesafe's prompting sources for a
  different use (Noul relevance questions): `../jevsearch/docs/research/jev-prompting.md` (sources in its §2). Use it
  only to find sources faster; read and cite every Typesafe claim at the source itself, and frame nothing in that
  project's terms.
- Jev calls: at most 10 tiny probes, and only to settle a doc claim that is ambiguous (for example the order of
  `probabilities`). Do not evaluate jevpaste's wordings — that is #52's spike. Keys: `~/.config/jevpaste/keys/<provider>`.
  Never print, echo or log a key, its length or prefix. List every probe in the file (shape, result).
- Do not edit code, do not touch `main`, do not commit, no subagents. Write only `docs/research/jev-prompting.md`.
  No absolute home paths and no window titles in the file.
- When done, send an intercom message to session `01a0fe65-71e1-746e-a4bb-93c96000d6bf` with the path and at most
  4 lines. If you are blocked, ask the same session through intercom.
