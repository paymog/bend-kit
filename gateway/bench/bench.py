"""Gateway benchmark: the Python side (see README.md)."""
import sys, time

CAPACITY = 4
TTL = 1_000_000


def allowed(method, roles):
    return "suspended" not in roles and method == "GET" and "reader" in roles


def main():
    rounds = 2 ** (int(sys.argv[1]) if len(sys.argv) > 1 else 10)
    keys = [f"k{i}" for i in range(64)]
    roles = ["reader"]
    t0 = time.perf_counter()
    cache = {}
    in_use = 0
    for k in keys:
        if allowed("GET", roles) and in_use < CAPACITY:
            in_use += 1
            cache[k] = (k, 0 + TTL)
            in_use -= 1
    acc = 0
    for _ in range(rounds):
        for k in keys:
            for _ in range(8):
                if not allowed("GET", roles) or in_use >= CAPACITY:
                    continue
                in_use += 1
                e = cache.get(k)
                if e is not None and 0 < e[1]:
                    acc = (acc + len(e[0])) & 0xFFFFFFFF
                in_use -= 1
    ms = (time.perf_counter() - t0) * 1000
    print(f"gateway\t{ms:.3f}\t{acc}")


main()
