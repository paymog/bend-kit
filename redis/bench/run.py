#!/usr/bin/env python3
"""Write the recording, build and run the RESP decode benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
REPLIES = int(sys.argv[2]) if len(sys.argv) > 2 else 100000
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}
BREW = "/opt/homebrew"
IOREDIS, REDIS_PY = "6.0.0", "8.1.0"

# name -> (build argv or None, run argv). Every program reads out/replies.resp and prints `decode<TAB>ms<TAB>checksum`.
VARIANTS = {
    "C": (["cc", "-O2", f"-I{BREW}/include", "bench.c", f"-L{BREW}/lib", "-lhiredis", "-o", OUT / "c"], [OUT / "c"]),
    "Rust": (["cargo", "build", "--release", "-q", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"], [OUT / "rs" / "release" / "rs"]),
    "Bun": (["sh", "-c", f"npm i -s --prefix out/js ioredis@{IOREDIS} && cp bench.mjs out/js/"], ["bun", OUT / "js" / "bench.mjs"]),
    "Node": (None, ["node", OUT / "js" / "bench.mjs"]),
    "Python": (None, ["uv", "run", "-q", "--no-project", "--with", f"redis=={REDIS_PY}", "python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


class Simple(bytes):
    pass


# The replies a GET/SET/INCR/LRANGE/HGETALL/SCAN/SISMEMBER workload sees, in RESP3.
def reply(i):
    k = i % 8
    if k == 0:
        return Simple(b"OK")
    if k == 1:
        return bytes((i * 7 + j) & 255 for j in range(i % 100))
    if k == 2:
        return None
    if k == 3:
        return i * 1000003 - (1 << 40)
    if k == 4:
        return [f"item-{j}".encode() for j in range(i % 10)]
    if k == 5:
        return {f"field-{j}".encode(): f"value-{i}-{j}".encode() for j in range(i % 5)}
    if k == 6:
        return [str(i).encode(), [f"key:{i + j}".encode() for j in range(i % 7)]]
    return i % 2 == 0


def enc(v):
    if isinstance(v, Simple):
        return b"+" + v + b"\r\n"
    if v is None:
        return b"_\r\n"
    if isinstance(v, bool):
        return b"#t\r\n" if v else b"#f\r\n"
    if isinstance(v, int):
        return b":%d\r\n" % v
    if isinstance(v, bytes):
        return b"$%d\r\n" % len(v) + v + b"\r\n"
    if isinstance(v, list):
        return b"*%d\r\n" % len(v) + b"".join(map(enc, v))
    return b"%%%d\r\n" % len(v) + b"".join(enc(a) + enc(b) for a, b in v.items())


# Pre-order walk, h = h*31 + x (u32): 1 string (length, then bytes), 2 integer (low 32 bits),
# 3 null, 4..5 around array items, 6..7 around map keys and values, 8 boolean. Then add the reply count.
def walk(v, h):
    m = lambda h, x: (h * 31 + x) & 0xFFFFFFFF
    if v is None:
        return m(h, 3)
    if isinstance(v, bool):
        return m(m(h, 8), int(v))
    if isinstance(v, int):
        return m(m(h, 2), v & 0xFFFFFFFF)
    if isinstance(v, bytes):
        h = m(m(h, 1), len(v))
        for b in v:
            h = m(h, b)
        return h
    if isinstance(v, list):
        h = m(h, 4)
        for x in v:
            h = walk(x, h)
        return m(h, 5)
    h = m(h, 6)
    for a, b in v.items():
        h = walk(b, walk(a, h))
    return m(h, 7)


def main():
    OUT.mkdir(exist_ok=True)
    replies = [reply(i) for i in range(REPLIES)]
    data = b"".join(map(enc, replies))
    (OUT / "replies.resp").write_bytes(data)
    h = 0
    for v in replies:
        h = walk(v, h)
    want = str((h + len(replies)) & 0xFFFFFFFF)
    print(f"input {len(data):,} bytes, {REPLIES} replies, checksum {want}", file=sys.stderr)

    table, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build:
            b = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            if b.returncode != 0:
                sys.exit(f"build failed: {name}\n{b.stderr}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed ({r.returncode}):\n{r.stdout}{r.stderr}")
            op, ms, c = r.stdout.strip().split("\t")
            runs.append((float(ms), c))
        table[name] = statistics.median(t for t, _ in runs)
        checks[name] = runs[0][1]
        print(f"ran {name}", file=sys.stderr)

    bad = [(n, c) for n, c in checks.items() if c != want]
    if bad:
        sys.exit(f"checksum mismatch: want {want}, got {bad}")
    print(f"checksum {want}", file=sys.stderr)

    names = list(table)
    best = min(table.values())
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    cells = [f"{table[n]:,.1f}" + (f" ({table[n] / best:.1f}x)" if best > 0 else "") for n in names]
    print("| decode | " + " | ".join(cells) + " |")


main()
