"""Engine L rescue check: an LLM returns the excerpt for the cells Engine J missed or got ambiguous (1 run each).

Usage (key exported, never printed):
    set -a; . ~/.config/jevpaste/env; set +a
    python3 l_rescue.py cells              # list the rescue cells picked from the J matrix
    python3 l_rescue.py run [model...]     # default: both models

Gateway: OpenAI-compatible chat completions on the Vercel AI Gateway (same key as Jev). On 402/403/429 that persists
after 3 paced retries the model is stopped and recorded. Luna falls back to `codex exec` (Daniel's own ChatGPT login,
approved for the spike) when the Gateway refuses it. Every request/response is appended to results/raw.jsonl
(kind `l_call` / `l_result`; never counted as a billed Jev call).
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "abstention"))

import jev  # noqa: E402  (SSL context only)

import analyze  # noqa: E402
import fixtures  # noqa: E402

ENDPOINT = "https://ai-gateway.vercel.sh/v1/chat/completions"
MODELS = ["deepseek/deepseek-v4.1-flash", "openai/gpt-6-luna"]
CODEX_MODEL = os.environ.get("CODEX_MODEL", "gpt-6-luna")
# Codex with a ChatGPT account rejects `gpt-6-luna` (HTTP 400 "not supported when using Codex with a ChatGPT
# account"); its model catalog offers `gpt-5.6-luna`, run as a labelled substitute via `codex-substitute`.
MAX_CALLS_PER_MODEL = 40
RETRIES = 3
PACING_SECONDS = 2.0
STOP_CODES = (402, 403, 429)

INSTRUCTION = (
    "You fill one form field from text the user copied. `item` is the copied text; `target_context` describes the "
    "focused field and its page. Return exactly one contiguous substring of `item` that belongs in this field, "
    "verbatim (same characters, spacing and line breaks; nothing added, removed or reformatted), or NONE if the "
    "item holds nothing for this field. Answer with JSON only: {\"excerpt\": \"<substring>\"} or "
    "{\"excerpt\": \"NONE\"}."
)


def prompt(item_id, cell):
    payload = {"item": fixtures.ITEMS[item_id], "target_context": fixtures.target_context(cell)}
    return INSTRUCTION + "\n\n" + json.dumps(payload, ensure_ascii=False, indent=1)


def rescue_cells():
    """Cells where J missed in any matrix run, or the two runs pasted different texts."""
    results = {}
    for r in analyze.rows():
        if r.get("kind") == "j_result" and r.get("run") in analyze.MATRIX_RUNS \
                and r.get("variant") == analyze.MATRIX_VARIANT:
            results.setdefault(r["cell"], {})[r["run"]] = r
    picked = []
    for item_id, cell in fixtures.all_cells():
        runs = results.get(cell["id"], {})
        if not runs:
            continue
        missed = any(not r["hit"] or not r["j_hit"] for r in runs.values())
        split = len({r["final"] for r in runs.values()}) > 1
        if missed or split:
            picked.append((item_id, cell, "miss" if missed else "runs disagree"))
    return picked


def parse_excerpt(text):
    if text is None:
        return None, "no content"
    body = text.strip()
    if body.startswith("```"):
        body = body.strip("`")
        body = body[body.find("{"):]
    try:
        start, end = body.index("{"), body.rindex("}") + 1
        value = json.loads(body[start:end]).get("excerpt")
    except (ValueError, AttributeError) as error:
        return None, "unparseable: %s" % error
    return value, None


def verdict(item_id, cell, excerpt):
    if excerpt is None:
        return None, None
    item = fixtures.ITEMS[item_id]
    if excerpt == "NONE":
        return True, cell["expected"] is None
    verbatim = excerpt in item
    return verbatim, verbatim and excerpt in analyze.acceptable(cell)


def gateway_call(model, text):
    key = os.environ.get("AI_GATEWAY_API_KEY")
    if not key:
        raise SystemExit("AI_GATEWAY_API_KEY is not set")
    body = json.dumps({"model": model, "messages": [{"role": "user", "content": text}],
                       "response_format": {"type": "json_object"}}).encode("utf-8")
    request = urllib.request.Request(ENDPOINT, data=body, method="POST", headers={
        "Authorization": "Bearer " + key, "Content-Type": "application/json"})
    started = time.monotonic()
    try:
        with urllib.request.urlopen(request, timeout=120, context=jev.SSL_CONTEXT) as response:
            payload = json.loads(response.read().decode("utf-8"))
        return 200, payload, (time.monotonic() - started) * 1000.0
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")[:600]
        return error.code, {"error": detail}, (time.monotonic() - started) * 1000.0


def codex_call(text, codex_model=None):
    """Full `codex exec` agent turn on Daniel's own login; returns (status, final message, events, latency)."""
    workdir = tempfile.mkdtemp(prefix="anyfield-codex-")
    started = time.monotonic()
    try:
        proc = subprocess.run(
            ["codex", "exec", "-m", codex_model or CODEX_MODEL, "--json", "--ephemeral", "--skip-git-repo-check",
             "-s", "read-only", "-C", workdir, "-"],
            input=text, capture_output=True, text=True, timeout=300)
    finally:
        latency = (time.monotonic() - started) * 1000.0
        shutil.rmtree(workdir, ignore_errors=True)
    events, message = [], None
    for line in proc.stdout.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        events.append(event)
        item = event.get("item") or {}
        if item.get("type") in ("agent_message", "assistant_message") and item.get("text"):
            message = item["text"]
    return proc.returncode, message, events, proc.stderr[-600:], latency


def log(record):
    with open(analyze.RAW_PATH, "a") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")


def run_codex(model, item_id, cell, reason, text, codex_model=None):
    code, message, events, stderr, latency = codex_call(text, codex_model)
    log({"kind": "l_call", "cell": cell["id"], "model": model, "route": "codex exec", "prompt": text,
         "returncode": code, "events": events, "stderr_tail": stderr, "latency_ms": round(latency, 1),
         "timestamp": time.time()})
    excerpt, problem = parse_excerpt(message)
    verbatim, hit = verdict(item_id, cell, excerpt)
    log({"kind": "l_result", "cell": cell["id"], "model": model, "route": "codex exec", "reason": reason,
         "status": "ok" if code == 0 and problem is None else "exit %s %s" % (code, problem or ""),
         "answer": excerpt, "verbatim": verbatim, "hit": hit, "latency_ms": round(latency, 1)})
    print("%-22s %s codex %s -> %r verbatim=%s hit=%s %.0fms" % (cell["id"], model, code, excerpt, verbatim, hit,
                                                                 latency))


def run(models):
    cells = rescue_cells()
    print("rescue cells: %d" % len(cells))
    for model in models:
        stopped, calls, use_codex = None, 0, False
        for item_id, cell, reason in cells:
            if calls >= MAX_CALLS_PER_MODEL:
                break
            text = prompt(item_id, cell)
            if stopped and not use_codex:
                log({"kind": "l_result", "cell": cell["id"], "model": model, "route": "gateway", "reason": reason,
                     "status": "skipped: %s" % stopped})
                continue
            if use_codex:
                run_codex(model, item_id, cell, reason, text)
                calls += 1
                continue
            status, payload, latency = None, None, None
            for attempt in range(RETRIES + 1):
                time.sleep(PACING_SECONDS * (2 ** attempt if attempt else 1))
                status, payload, latency = gateway_call(model, text)
                calls += 1
                log({"kind": "l_call", "cell": cell["id"], "model": model, "route": "gateway", "attempt": attempt,
                     "request": {"model": model, "prompt": text}, "status": status, "response": payload,
                     "latency_ms": round(latency, 1), "timestamp": time.time()})
                if status not in STOP_CODES:
                    break
            if status in STOP_CODES or status == 401:
                stopped = "HTTP %s after %d retries: %s" % (status, RETRIES, str(payload)[:160])
                print("%s stopped: %s" % (model, stopped))
                log({"kind": "l_result", "cell": cell["id"], "model": model, "route": "gateway", "reason": reason,
                     "status": "stopped: %s" % stopped})
                if model.endswith("gpt-6-luna") and shutil.which("codex"):
                    use_codex = True
                    print("switching Luna to codex exec")
                    run_codex(model, item_id, cell, reason, text)
                    calls += 1
                continue
            content = None
            if status == 200:
                content = ((payload.get("choices") or [{}])[0].get("message") or {}).get("content")
            excerpt, problem = parse_excerpt(content)
            verbatim, hit = verdict(item_id, cell, excerpt)
            log({"kind": "l_result", "cell": cell["id"], "model": model, "route": "gateway", "reason": reason,
                 "status": "ok" if status == 200 and problem is None else "HTTP %s %s" % (status, problem or ""),
                 "answer": excerpt, "verbatim": verbatim, "hit": hit, "latency_ms": round(latency, 1),
                 "cost": ((payload.get("providerMetadata") or {}).get("gateway") or {}).get("cost")
                 if isinstance(payload, dict) else None,
                 "usage": payload.get("usage") if isinstance(payload, dict) else None})
            print("%-22s %s HTTP %s -> %r verbatim=%s hit=%s %.0fms"
                  % (cell["id"], model, status, excerpt, verbatim, hit, latency))


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "cells"
    if command == "cells":
        for item_id, cell, reason in rescue_cells():
            print(cell["id"], reason)
    elif command == "codex-substitute":
        substitute = sys.argv[2] if len(sys.argv) > 2 else "gpt-5.6-luna"
        for item_id, cell, reason in rescue_cells()[:MAX_CALLS_PER_MODEL]:
            run_codex("codex/" + substitute + " (substitute)", item_id, cell, reason, prompt(item_id, cell),
                      codex_model=substitute)
    elif command == "run":
        run(sys.argv[2:] or MODELS)
    else:
        raise SystemExit("unknown command %r" % command)
