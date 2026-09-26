# Issue 51 live-proof fixtures and helpers (THROWAWAY branch, never merged)

Copy to /tmp/jevpaste-cursor-51 before use (`mkdir -p /tmp/jevpaste-cursor-51 && cp live51/* /tmp/jevpaste-cursor-51/`);
the helpers and pages use that path. See docs/acceptance/run-2026-09-26-cursor-context*.log on branch cursor-context.
- live.sh <bundle> <fixture>: fixture on the clipboard, gate on the frontmost app, SIGUSR1 to the
  `--accept-signal-trigger` test instance only; clipboard digest equality (needs /tmp/jevpaste-acc/clipboard-vault,
  `swiftc -O -o /tmp/jevpaste-acc/clipboard-vault scripts/acceptance/clipboard-vault.swift`).
- sig.sh <bundle> <USR1|USR2>: the same gate for the `--cursor-probe` instance.
- gate-a.html: <textarea> holding long.txt, caret set to the middle on load. short.html: heading + labelled input.
