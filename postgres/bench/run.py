#!/usr/bin/env python3
"""Check the recording, build and run the Postgres result decode benchmark; print a markdown table. See README.md."""
import os, shutil, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
FIXTURE = HERE / "result.pgwire"
ROWS = 20000
PG = "/opt/homebrew/opt/libpq"
PG_PROTOCOL, PSYCOPG = "1.16.0", "3.3.6"
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

# name -> (build argv or None, run argv). Every program reads out/result.pgwire and prints `decode<TAB>ms<TAB>checksum`.
VARIANTS = {
    "C": (["cc", "-O2", f"-I{PG}/include", "bench.c", f"-L{PG}/lib", "-lpq", "-o", OUT / "c"], [OUT / "c"]),
    "Rust": (["cargo", "build", "--release", "-q", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"], [OUT / "rs" / "release" / "rs"]),
    "Bun": (["sh", "-c", f"npm i -s --prefix out/js pg-protocol@{PG_PROTOCOL} && cp bench.mjs out/js/"], ["bun", OUT / "js" / "bench.mjs"]),
    "Node": (None, ["node", OUT / "js" / "bench.mjs"]),
    "Python": (None, ["uv", "run", "-q", "--no-project", "--with", f"psycopg[binary]=={PSYCOPG}", "python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}

# (name, type oid, type size, type modifier): int4, text, int8, text, bool, all from table 16384.
COLUMNS = [(b"id", 23, 4, -1), (b"name", 25, -1, -1), (b"balance", 20, 8, -1), (b"note", 25, -1, -1), (b"active", 16, 1, -1)]
NOTE = b"abcdefghij ,.'\"\\-_0123456789"


# Row i of `SELECT id, name, balance, note, active FROM accounts`, in text format; None is NULL.
def row(i):
    name = f"zoë-{i}" if i % 7 == 0 else f"user-{i}"
    note = None if i % 5 == 0 else bytes(NOTE[(i + j) % len(NOTE)] for j in range(i % 40))
    return [str(i + 1).encode(), name.encode(), str(i * 1000003 - (1 << 40)).encode(), note, b"t" if i % 3 else b"f"]


def msg(tag, body):
    return tag + (len(body) + 4).to_bytes(4, "big") + body


def i16(n):
    return (n & 0xFFFF).to_bytes(2, "big")


def i32(n):
    return (n & 0xFFFFFFFF).to_bytes(4, "big")


# The backend's reply to that query: RowDescription, one DataRow per row, CommandComplete, ReadyForQuery.
def recording(rows):
    desc = i16(len(COLUMNS)) + b"".join(
        name + b"\0" + i32(16384) + i16(k + 1) + i32(oid) + i16(size) + i32(mod) + i16(0)
        for k, (name, oid, size, mod) in enumerate(COLUMNS)
    )
    out = [msg(b"T", desc)]
    for r in rows:
        out.append(msg(b"D", i16(len(r)) + b"".join(i32(-1) if v is None else i32(len(v)) + v for v in r)))
    out.append(msg(b"C", b"SELECT %d\0" % len(rows)))
    out.append(msg(b"Z", b"I"))
    return b"".join(out)


# h = h*31 + x (u32): 1, then each column's name (length, bytes) and type oid, then 2; for each row 3,
# then per column 4 for NULL or 5, length, bytes, then 6; then 7 and the command tag (length, bytes).
def checksum(rows):
    h = 0

    def m(*xs):
        nonlocal h
        for x in xs:
            h = (h * 31 + x) & 0xFFFFFFFF

    def s(b):
        m(len(b), *b)

    m(1)
    for name, oid, _, _ in COLUMNS:
        s(name)
        m(oid)
    m(2)
    for r in rows:
        m(3)
        for v in r:
            if v is None:
                m(4)
            else:
                m(5)
                s(v)
        m(6)
    m(7)
    s(b"SELECT %d" % len(rows))
    return str(h)


def main():
    if sys.argv[1:] == ["fixture"]:
        FIXTURE.write_bytes(recording([row(i) for i in range(ROWS)]))
        return
    runs_n = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    n = int(sys.argv[2]) if len(sys.argv) > 2 else ROWS
    rows = [row(i) for i in range(n)]
    data = recording(rows)
    if n == ROWS and FIXTURE.read_bytes() != data:
        sys.exit(f"{FIXTURE.name} differs from the generator; `python3 run.py fixture` rewrites it")
    OUT.mkdir(exist_ok=True)
    (OUT / "result.pgwire").write_bytes(data)
    want = checksum(rows)
    print(f"input {len(data):,} bytes, {n} rows, checksum {want}", file=sys.stderr)

    table, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build:
            b = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            if b.returncode != 0:
                sys.exit(f"build failed: {name}\n{b.stdout}{b.stderr}")
        runs = []
        for _ in range(runs_n):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed ({r.returncode}):\n{r.stdout}{r.stderr}")
            op, ms, c = r.stdout.strip().split("\t")
            runs.append((float(ms), c))
        table[name] = statistics.median(t for t, _ in runs)
        checks[name] = runs[0][1]
        print(f"ran {name}", file=sys.stderr)

    bad = [(k, c) for k, c in checks.items() if c != want]
    if bad:
        sys.exit(f"checksum mismatch: want {want}, got {bad}")
    print(f"checksum {want}", file=sys.stderr)

    names = list(table)
    best = min(table.values())
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    cells = [f"{table[k]:,.1f}" + (f" ({table[k] / best:.1f}x)" if best > 0 else "") for k in names]
    print("| decode | " + " | ".join(cells) + " |")


if __name__ == "__main__":
    main()
