# 1000 sequential GETs on one httpx.Client with base_url and a default header.
import time

import httpx

with httpx.Client(base_url="http://127.0.0.1:47840/api/", headers={"x-bench": "1"}) as c:
    total = 0
    t0 = time.perf_counter_ns()
    for _ in range(1000):
        r = c.get("item")
        total = (total + r.status_code + len(r.content)) & 0xFFFFFFFF
    ms = (time.perf_counter_ns() - t0) / 1e6
print(f"get_1000\t{ms:.3f}\t{total}")
