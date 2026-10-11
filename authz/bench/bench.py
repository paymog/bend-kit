"""Casbin policy evaluation; setup is outside the timed loop."""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "out" / "py"))
import casbin

MODEL = """
[request_definition]
r = sub, owner, act, role, resource
[policy_definition]
p = kind, val, act, eft
[policy_effect]
e = some(where (p.eft == allow)) && !some(where (p.eft == deny))
[matchers]
m = ((p.kind == "owner" && r.sub == r.owner) || (p.kind == "role" && r.role == p.val)) && (p.act == "*" || p.act == r.act)
"""


def main():
    lg = int(sys.argv[1]) if len(sys.argv) > 1 else 8
    model = casbin.Model()
    model.load_model_from_text(MODEL)
    enforcer = casbin.Enforcer(model)
    for row in [("owner", "-", "DELETE", "allow"), ("role", "admin", "*", "allow"), ("role", "suspended", "*", "deny")]:
        enforcer.add_policy(*row)
    requests = [(f"u{i % 7}", f"u{i % 5}", ["GET", "DELETE", "PUT"][i % 3], "admin" if i % 11 == 0 else "suspended" if i % 13 == 0 else "editor", "doc") for i in range(64)]
    rounds = 1 << lg
    chk = 0
    t0 = time.perf_counter_ns()
    for _ in range(rounds):
        for request in requests:
            chk += enforcer.enforce(*request)
    elapsed = (time.perf_counter_ns() - t0) / 1e6
    print(f"authz\t{elapsed:.6f}\t{chk & 0xffffffff}")


if __name__ == "__main__":
    main()
