# 1000 sequential GETs on one httpx.Client with base_url and a default header.
# Then 1000 GETs of a flaky URL on a requests.Session with urllib3's Retry: httpx retries only connects.
import time

import httpx
import requests
from requests.adapters import HTTPAdapter
from urllib3.util import Retry

with httpx.Client(base_url="http://127.0.0.1:47840/api/", headers={"x-bench": "1"}) as c:
    total = 0
    t0 = time.perf_counter_ns()
    for _ in range(1000):
        r = c.get("item")
        total = (total + r.status_code + len(r.content)) & 0xFFFFFFFF
    ms = (time.perf_counter_ns() - t0) / 1e6
print(f"get_1000\t{ms:.3f}\t{total}")

with requests.Session() as s:
    retry = Retry(total=2, status_forcelist=[503], backoff_factor=0, respect_retry_after_header=True)
    s.mount("http://", HTTPAdapter(max_retries=retry))
    total = 0
    t0 = time.perf_counter_ns()
    for _ in range(1000):
        r = s.get("http://127.0.0.1:47840/api/flaky")
        total = (total + r.status_code + len(r.content)) & 0xFFFFFFFF
    ms = (time.perf_counter_ns() - t0) / 1e6
print(f"retry_1000\t{ms:.3f}\t{total}")
