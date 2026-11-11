"""Verify a Maigz webhook delivery. Standard library only.

    ok = verify(headers, raw_body, signing_secret)

Call it with the exact raw request body bytes, before parsing any JSON.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import time

TOLERANCE_SECONDS = 300


def verify(headers: dict, raw_body: bytes, signing_secret: str, now: float | None = None) -> bool:
    lower = {k.lower(): v for k, v in headers.items()}
    timestamp = lower.get("x-maigz-timestamp", "")
    signature = lower.get("x-maigz-signature", "")
    if not timestamp.isdigit() or not signature.startswith("v1=") or not signing_secret.startswith("whsec_"):
        return False
    if abs((now if now is not None else time.time()) - int(timestamp)) > TOLERANCE_SECONDS:
        return False
    encoded = signing_secret[len("whsec_"):]
    key = base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4))
    expected = hmac.new(key, timestamp.encode("ascii") + b"." + raw_body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature[len("v1="):])


if __name__ == "__main__":
    # Self-check with a made-up secret and body.
    secret = "whsec_" + base64.urlsafe_b64encode(b"example-key-example-key-example!").decode().rstrip("=")
    body = b'{"id":"d1","type":"zine.published","created_at":"2026-10-05T18:42:00Z","data":{}}'
    stamp = str(int(time.time()))
    raw_key = base64.urlsafe_b64decode(secret[6:] + "==")
    sig = "v1=" + hmac.new(raw_key, stamp.encode() + b"." + body, hashlib.sha256).hexdigest()
    headers = {"X-Maigz-Timestamp": stamp, "X-Maigz-Signature": sig}
    assert verify(headers, body, secret)
    assert not verify(headers, body + b" ", secret)
    assert not verify({**headers, "X-Maigz-Timestamp": str(int(stamp) - 301)}, body, secret)
    print("verify_webhook: ok")
