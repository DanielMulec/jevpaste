"""Minimal Jev client for the granularity spike (stdlib only).

Reads AI_GATEWAY_API_KEY from the environment. The key is never logged or
written to any artifact: only status, latency, usage and answers are kept.
"""

import json
import os
import pathlib
import ssl
import time
import urllib.error
import urllib.request

ENDPOINT = "https://ai-gateway.vercel.sh/v1/evaluate"
MODEL = "typesafe-ai/jev"


def _tls_context():
    """This python.org build ships no CA bundle; fall back to the system one."""
    for bundle in (os.environ.get("SSL_CERT_FILE"), "/etc/ssl/cert.pem"):
        if bundle and pathlib.Path(bundle).exists():
            return ssl.create_default_context(cafile=bundle)
    return ssl.create_default_context()


TLS = _tls_context()

call_count = 0  # successful evaluations (billed)
attempt_count = 0  # HTTP requests including 429 retries
RETRY_BACKOFF_SECONDS = (5, 10, 20, 40, 60)


class CallBudgetExceeded(RuntimeError):
    pass


def evaluate(state, questions, budget=150, timeout=30.0):
    """POST one evaluation. Returns (response_dict, latency_ms, input_tokens)."""
    global call_count, attempt_count
    if call_count >= budget:
        raise CallBudgetExceeded(f"call budget of {budget} reached")
    api_key = os.environ.get("AI_GATEWAY_API_KEY")
    if not api_key:
        raise RuntimeError("AI_GATEWAY_API_KEY is not set")

    payload = json.dumps({"model": MODEL, "state": state, "questions": questions}).encode()
    request = urllib.request.Request(
        ENDPOINT,
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    last_attempt = len(RETRY_BACKOFF_SECONDS)
    for attempt in range(last_attempt + 1):
        started = time.monotonic()
        try:
            attempt_count += 1
            with urllib.request.urlopen(request, timeout=timeout, context=TLS) as response:
                body = json.loads(response.read().decode())
            latency_ms = (time.monotonic() - started) * 1000.0
            call_count += 1
            usage = body.get("usage") or {}
            return body, latency_ms, usage.get("inputTokens")
        except urllib.error.HTTPError as error:
            detail = error.read().decode()[:400]
            if error.code in (429, 529) and attempt < last_attempt:
                print(f"  [{error.code} retry {attempt + 1}]", flush=True)
                time.sleep(RETRY_BACKOFF_SECONDS[attempt])
                continue
            raise RuntimeError(f"HTTP {error.code}: {detail}") from None
        except urllib.error.URLError as error:
            if attempt < last_attempt:
                time.sleep(RETRY_BACKOFF_SECONDS[attempt])
                continue
            raise RuntimeError(f"network error: {error.reason}") from None
    raise RuntimeError("unreachable")


def choice_answer(body, question_id):
    """Extract (chosen_option, probabilities, confidence) from a choice answer."""
    answer = body["answers"][question_id]
    probabilities = answer.get("probabilities") or {}
    return answer.get("choice"), probabilities, answer.get("confidence")
