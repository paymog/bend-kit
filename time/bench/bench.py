"""Time benchmark: Python (see README.md)."""
import time
from datetime import datetime, timedelta, timezone

N = 4096
T0 = -2208988800
STEP = 3155761
EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)

start = time.perf_counter()
chk = 0
t = T0
for _ in range(N):
    s = (EPOCH + timedelta(seconds=t)).strftime("%Y-%m-%dT%H:%M:%SZ")
    back = int((datetime.fromisoformat(s) - EPOCH).total_seconds())
    chk = (chk + sum(s.encode()) + back) & 0xFFFFFFFF
    t += STEP
ms = (time.perf_counter() - start) * 1000
print(f"trip\t{ms:.3f}\t{chk}")
