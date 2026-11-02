"""Storage benchmark: hashlib SHA-256 and a dict (see README.md)."""
import hashlib, sys, time

K = int(sys.argv[1]) if len(sys.argv) > 1 else 16


def content(d, f):
    seed = d * 31 + f * 7
    return bytes((seed + j) & 255 for j in range(4096))


def put(store, raw, obj):
    d = hashlib.sha256(raw).hexdigest()
    store.setdefault(d, obj)
    return d


def listing(store, entries):
    rest = put(store, b"end\n", ("end",))
    for name, child in reversed(entries):
        rest = put(store, f"item {child} {rest} {name}\n".encode(), ("item", child, rest))
    return rest


def load(store, d):
    o = store[d]
    if o[0] == "file":
        return len(o[1])
    if o[0] == "end":
        return 0
    return load(store, o[1]) + load(store, o[2])


tree = [(f"d{d:02}", [(f"f{f:02}", content(d, f)) for f in range(K)]) for d in range(K)]
t0 = time.perf_counter()
store = {}
top = []
for dname, fs in tree:
    files = [(fname, put(store, b"file %d\n" % len(data) + data, ("file", data))) for fname, data in fs]
    top.append((dname, listing(store, files)))
root = listing(store, top)
n = load(store, root)
ms = (time.perf_counter() - t0) * 1000
print(f"commit\t{ms:.3f}\t{root}\t{n}")
