# Worker brief — app icon (ticket #39)

Ticket: [Give JevPaste an app icon and keep the staging bundle out of Launchpad](https://github.com/DanielMulec/jevpaste/issues/39).
Branch `app-icon` from `main`. Report to the supervisor by `intercom` (id given in your prompt); Daniel is reached only
through the supervisor. Read `CONTEXT.md` and `docs/design/ui.md` (if present) for the app's vocabulary first.

## What the app is
JevPaste: a macOS menu-bar smart-paste app. ⌘⇧V pastes the *right excerpt* of the clipboard into the focused field —
an email into the Email box, a phone into the Phone box — chosen by Jev (an LLM), never rewritten. The status item is
SF Symbol `doc.on.clipboard`. Tone: quiet, precise, personal tool; not a startup logo.

## Task 1 — generate candidates (AFK)
1. Use pi's `generate_image` tool (Antigravity, default model `gemini-3-pro-image`, aspect `1:1`). Produce **4 distinct
   candidates** into `docs/icon-candidates/` (set `path`), each a macOS-app-icon composition: a single rounded-square
   tile filling ~80 % of the canvas, flat/soft-gradient background, one bold centred glyph, no text, no drop shadow
   outside the tile, no photorealism. Motif ideas (one per candidate, vary colour): a clipboard with a highlighted
   single line being lifted out; a clipboard + cursor/caret; a paste arrow into a field; a clipboard with a small
   spark (Jev). Keep the whole thing legible at 16 px.
2. Write `docs/icon-candidates/README.md`: one line per candidate (file, motif, colour). Commit.
3. `intercom ask` the supervisor with the four file paths and a one-line description each; **stop and wait** for
   Daniel's pick (he may ask for a variation — iterate, max 2 rounds).

## Task 2 — install the chosen icon
1. Copy the pick to `Resources/AppIcon.png` as a **1024×1024 PNG with transparent corners outside the tile** (macOS
   applies no mask to `.icns`; if the generated image has a solid background, cut the tile out: `sips`/Python-PIL are
   fine, keep it reproducible in a small script under `scripts/` or document the exact command in the commit).
2. `make app` — verify `build/JevPaste.app/Contents/Resources/AppIcon.icns` exists and `iconutil` produced all sizes;
   `qlmanage -p` or `sips -g` to sanity check. Do not `make install` (supervisor does that).

## Task 3 — keep the staging bundle out of Launchpad
`build/JevPaste.app` gets registered with Launch Services and shows as a second app. In the `install` target
(`Makefile` / `scripts/make-app.sh`, whichever owns it), after copying to `~/Applications`, unregister the staging bundle:
`/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u build/JevPaste.app`
(and/or delete `build/JevPaste.app` after the copy — your call, say why). Keep `make check` green; the line-count hook applies.

## Gates
- A: candidates → Daniel's pick (via supervisor).
- B: `make check` green, icon visible in `build/JevPaste.app` (attach a screenshot path of the Finder/Get Info icon if
  you can take one with `screencapture`; otherwise describe), Makefile change explained.
- C: report comment on #39: commits, files, the command used for the corner cut, what the install target now does.
Then idle for review.
