"""Minimal stdlib client for the Vercel AI Gateway evaluation surface.

The API key is read from the AI_GATEWAY_API_KEY environment variable and is
never logged, printed or written to disk.
"""

import json
import os
import ssl
import time
import urllib.error
import urllib.request


def _ssl_context():
    """python.org builds ship no CA bundle; fall back to certifi when present."""
    context = ssl.create_default_context()
    try:
        import certifi

        context.load_verify_locations(certifi.where())
    except Exception:
        pass
    return context


SSL_CONTEXT = _ssl_context()
ENDPOINT = "https://ai-gateway.vercel.sh/v1/evaluate"
MODEL = "typesafe-ai/jev"
TIMEOUT_SECONDS = 30
PACING_SECONDS = 0.7  # the free tier 429s easily; keep a gap between calls

_calls_made = 0
_throttles = 0
_last_call_at = 0.0


def calls_made():
    return _calls_made


def throttles():
    return _throttles


def evaluate(state, questions, max_calls, attempts=6):
    """POST one evaluation. Returns (payload, latency_ms). Raises on failure."""
    global _calls_made
    key = os.environ.get("AI_GATEWAY_API_KEY")
    if not key:
        raise SystemExit(
            "AI_GATEWAY_API_KEY is not set. Run: set -a; . ~/.config/jevpaste/env; set +a"
        )
    if _calls_made >= max_calls:
        raise SystemExit("call budget of %d reached" % max_calls)

    body = json.dumps(
        {"model": MODEL, "state": state, "questions": questions}
    ).encode("utf-8")

    global _throttles, _last_call_at
    last_error = None
    for attempt in range(attempts):
        gap = time.monotonic() - _last_call_at
        if gap < PACING_SECONDS:
            time.sleep(PACING_SECONDS - gap)
        request = urllib.request.Request(
            ENDPOINT,
            data=body,
            headers={
                "Authorization": "Bearer " + key,
                "Content-Type": "application/json",
            },
            method="POST",
        )
        started = time.monotonic()
        _last_call_at = started
        try:
            with urllib.request.urlopen(
                request, timeout=TIMEOUT_SECONDS, context=SSL_CONTEXT
            ) as response:
                payload = json.loads(response.read().decode("utf-8"))
            _calls_made += 1
            return payload, (time.monotonic() - started) * 1000.0
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")[:200]
            last_error = "HTTP %s: %s" % (error.code, detail)
            if error.code in (429, 529, 500, 502, 503) and attempt < attempts - 1:
                _throttles += 1
                retry_after = error.headers.get("retry-after") if error.headers else None
                delay = float(retry_after) if retry_after else min(30.0, 2.0 * 2**attempt)
                time.sleep(delay)
                continue
            raise RuntimeError(last_error)
        except Exception as error:  # network/timeout
            last_error = "%s: %s" % (type(error).__name__, error)
            if attempt < attempts - 1:
                time.sleep(2.0 * (attempt + 1))
                continue
            raise RuntimeError(last_error)
    raise RuntimeError(last_error or "unknown failure")
