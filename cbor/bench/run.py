#!/usr/bin/env python3
"""Write the input, build and run the CBOR benchmark; print a markdown table. See README.md."""
import os, statistics, struct, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
RECORDS = int(sys.argv[2]) if len(sys.argv) > 2 else 20000
OPS = ["decode", "encode"]
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}
BREW = "/opt/homebrew"
CBOR_X, CBOR2 = "1.6.6", "6.1.4"

# name -> (build argv or None, run argv). Every program reads out/doc.cbor and prints `op<TAB>ms<TAB>checksum` per op.
VARIANTS = {
    "C": (["cc", "-O2", f"-I{BREW}/include", "bench.c", f"-L{BREW}/lib", "-lcbor", "-o", OUT / "c"], [OUT / "c"]),
    "Rust": (["cargo", "build", "--release", "-q", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"], [OUT / "rs" / "release" / "rs"]),
    "Bun": (["sh", "-c", f"npm i -s --prefix out/js cbor-x@{CBOR_X} && cp bench.mjs out/js/"], ["bun", OUT / "js" / "bench.mjs"]),
    "Node": (None, ["node", OUT / "js" / "bench.mjs"]),
    "Python": (None, ["uv", "run", "-q", "--no-project", "--with", f"cbor2=={CBOR2}", "python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


class Tag:
    def __init__(self, n, v):
        self.n, self.v = n, v


# Preferred serialization (RFC 8949 §4.1): shortest heads, definite lengths. Floats are doubles that no
# narrower float holds exactly, so every encoder keeps them 8 bytes wide.
def head(major, n):
    if n < 24:
        return bytes([major << 5 | n])
    for ai, fmt in ((24, ">B"), (25, ">H"), (26, ">I"), (27, ">Q")):
        if n < 1 << (8 * struct.calcsize(fmt)):
            return bytes([major << 5 | ai]) + struct.pack(fmt, n)


def enc(v):
    if v is False or v is True or v is None:
        return bytes([{False: 0xF4, True: 0xF5, None: 0xF6}[v]])
    if isinstance(v, int):
        return head(0, v) if v >= 0 else head(1, -1 - v)
    if isinstance(v, float):
        assert struct.unpack(">f", struct.pack(">f", v))[0] != v
        return b"\xfb" + struct.pack(">d", v)
    if isinstance(v, str):
        return head(3, len(v.encode())) + v.encode()
    if isinstance(v, bytes):
        return head(2, len(v)) + v
    if isinstance(v, list):
        return head(4, len(v)) + b"".join(map(enc, v))
    if isinstance(v, dict):
        return head(5, len(v)) + b"".join(enc(k) + enc(x) for k, x in v.items())
    return head(6, v.n) + enc(v.v)


# Text keys that are not integer-like, so JavaScript objects keep insertion order.
def record(i):
    return {
        "id": i,
        "neg": -1 - i * 37,
        "wide": [i % 24, 24 + i % 200, 256 + i, 65536 + i * 3, 4294967296 + i * 1000003],
        "big_neg": -4294967297 - i,
        "name": f"user {i}",
        "text": f"héllo wörld ✓ 😀 {i % 10}",
        "blob": bytes((i * 7 + k) & 255 for k in range(i % 40)),
        "score": i + 0.1,
        "flags": [i % 2 == 0, i % 3 == 0, None],
        "tagged": Tag(1234, i),
        "nested": {"empty_list": [], "empty_map": {}, "deep": [[i, [i + 1, [i + 2]]]]},
    }


def checksum(b):
    h = 0
    for x in b:
        h = (h * 31 + x) & 0xFFFFFFFF
    return str((h + len(b)) & 0xFFFFFFFF)


def main():
    OUT.mkdir(exist_ok=True)
    doc = enc({"count": RECORDS, "items": [record(i) for i in range(RECORDS)]})
    (OUT / "doc.cbor").write_bytes(doc)
    want = checksum(doc)
    print(f"input {len(doc):,} bytes, {RECORDS} records, checksum {want}", file=sys.stderr)

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
            runs.append({op: (float(ms), c) for op, ms, c in (l.split("\t") for l in r.stdout.splitlines())})
        table[name] = {op: statistics.median(x[op][0] for x in runs) for op in OPS}
        checks[name] = {op: c for op, (_, c) in runs[0].items()}
        print(f"ran {name}", file=sys.stderr)

    # Each output re-encodes the input, so every checksum must also match the input's.
    for op in OPS:
        bad = [(n, checks[n].get(op)) for n in checks if checks[n].get(op) != want]
        if bad:
            sys.exit(f"checksum mismatch in {op}: want {want}, got {bad}")
        print(f"{op} checksum {want}", file=sys.stderr)

    names = list(table)
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    for op in OPS:
        # Bend's clock ticks in whole ms; with a 0 ms best, ratios mean nothing (use a bigger input).
        best = min(t[op] for t in table.values())
        cells = [f"{table[n][op]:,.1f}" + (f" ({table[n][op] / best:.1f}x)" if best > 0 else "") for n in names]
        print(f"| {op} | " + " | ".join(cells) + " |")


main()
