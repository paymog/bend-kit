# Migration benchmark in Python with the json module (see README.md).
import json, time

KEYS = {
    1: {"version", "id", "plan", "monthly_cents", "active"},
    2: {"version", "id", "plan", "cents", "period", "status", "note"},
    3: {"version", "id", "plan", "cents", "period", "status"},
}
PERIODS = {"monthly", "yearly"}
STATUSES = {"active", "paused", "cancelled"}


def u32(r, k):
    v = r[k]
    if type(v) is not int or not 0 <= v < 2**32:
        raise ValueError(k)
    return v


def text(r, k, allowed=None):
    v = r[k]
    if type(v) is not str or (allowed is not None and v not in allowed):
        raise ValueError(k)
    return v


def up(r):
    v = r["version"]
    if type(v) is not int or v not in KEYS or not set(r) <= KEYS[v]:
        raise ValueError("version or keys")
    i, plan = u32(r, "id"), text(r, "plan")
    if v == 1:
        if type(r["active"]) is not bool:
            raise ValueError("active")
        cents, period, status = u32(r, "monthly_cents"), "monthly", "active" if r["active"] else "cancelled"
    else:
        cents, status = u32(r, "cents"), text(r, "status", STATUSES)
        period = text(r, "period", PERIODS) if v == 3 or "period" in r else "monthly"
        if v == 2 and "note" in r:
            text(r, "note")
    if not plan or cents == 0:
        raise ValueError("invalid")
    return {"version": 3, "id": i, "plan": plan, "cents": cents, "period": period, "status": status}


def chk(b):
    h = 0
    for c in b:
        h = (h * 31 + c) & 0xFFFFFFFF
    return (h + len(b)) & 0xFFFFFFFF


raw = open("out/doc.json", "rb").read()
t0 = time.perf_counter()
out = json.dumps([up(r) for r in json.loads(raw)], separators=(",", ":"), ensure_ascii=False).encode()
ms = (time.perf_counter() - t0) * 1e3
print(f"migrate\t{ms:.3f}\t{chk(out)}")
