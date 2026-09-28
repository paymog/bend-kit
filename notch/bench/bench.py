# Log line benchmark: the Python side (see README.md). Argument: N.
import json, sys, time

n = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
xs, s = [], 1
for _ in range(n):
    s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
    xs.append(s)

t0 = time.perf_counter()
h = 2166136261
for x in xs:
    rec = {"time": "2026-09-27T12:00:00Z", "level": "INFO", "msg": "request done", "svc": "api",
           "user": f'u"{x % 1000}', "id": x, "ok": x & 1 == 1}
    for c in (json.dumps(rec, separators=(",", ":")) + "\n").encode():
        h = ((h ^ c) * 16777619) & 0xFFFFFFFF
print(f"json\t{(time.perf_counter() - t0) * 1000:.3f}\t{h}")
