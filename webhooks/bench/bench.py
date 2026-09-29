"""Webhook verify benchmark in Python with standardwebhooks: one fixed message, 10,000 verifies (see README.md)."""
import os
import time

from standardwebhooks import Webhook

N = 10_000
BODY = '{"test": 2432232314}'
# run.py signs the message at its start and passes the timestamp and signature in the environment.
HEADERS = {
    "webhook-id": "msg_p5jXN8AQM9LWM0D4loKWxJek",
    "webhook-timestamp": os.environ["WEBHOOK_TS"],
    "webhook-signature": os.environ["WEBHOOK_SIG"],
}

wh = Webhook("whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw")
n = 0
t0 = time.perf_counter()
for _ in range(N):
    wh.verify(BODY, HEADERS, json_parse=False)  # raises on failure
    n += 1
print(f"verify\t{(time.perf_counter() - t0) * 1000:.3f}\t{n} {HEADERS['webhook-id']}")
