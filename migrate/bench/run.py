#!/usr/bin/env python3
"""Write the input, build and run the migration benchmark; print a markdown table. See README.md."""
import json, os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
RECORDS = int(sys.argv[2]) if len(sys.argv) > 2 else 20000
OP = "migrate"
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}
CJSON = subprocess.check_output(["pkg-config", "--cflags", "--libs", "libcjson"], text=True).split()

# name -> (build argv or None, run argv). Every program reads out/doc.json and prints `op<TAB>ms<TAB>checksum`.
VARIANTS = {
    "C": (["cc", "-O2", "bench.c", *CJSON, "-o", OUT / "c"], [OUT / "c"]),
    "Rust": (["cargo", "build", "--release", "-q", "--locked", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"], [OUT / "rs" / "release" / "rs"]),
    "Bun": (None, ["bun", "bench.ts"]),
    "Node": (None, ["node", "bench.ts"]),
    "Python": (None, ["python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}

PLANS = ["basic", "pro", "team"]


# A third of each version. v2 rotates through every period, status, and note case.
def record(i):
    plan = PLANS[i % 3]
    cents = 100 + i % 1000
    if i % 3 == 0:
        return {"version": 1, "id": i, "plan": plan, "monthly_cents": cents, "active": i % 2 == 0}
    if i % 3 == 1:
        r = {"version": 2, "id": i, "plan": plan, "cents": cents, "status": ["active", "paused", "cancelled"][i % 4 % 3]}
        if i % 5:
            r["period"] = "yearly" if i % 2 else "monthly"
        if i % 7 == 1:
            r["note"] = f"call before renewal {i}"
        return r
    return {"version": 3, "id": i, "plan": plan, "cents": cents, "period": "monthly", "status": "active"}


def main():
    OUT.mkdir(exist_ok=True)
    doc = json.dumps([record(i) for i in range(RECORDS)], separators=(",", ":"))
    (OUT / "doc.json").write_text(doc)
    print(f"input {len(doc):,} bytes, {RECORDS} records", file=sys.stderr)

    table, checks = {}, {}
    for name, (build, run) in VARIANTS.items():
        if build and subprocess.run(build, cwd=HERE, env=ENV, capture_output=True).returncode != 0:
            sys.exit(f"build failed: {name}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr}")
            runs.append({op: (float(ms), c) for op, ms, c in (l.split("\t") for l in r.stdout.splitlines())})
        table[name] = statistics.median(x[OP][0] for x in runs)
        checks[name] = runs[0][OP][1]
        print(f"ran {name}", file=sys.stderr)

    if len(set(checks.values())) != 1:
        sys.exit(f"checksum mismatch: {checks}")
    print(f"{OP} checksum {checks['Bend']}", file=sys.stderr)

    names = list(table)
    best = max(min(table.values()), 1e-9)
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    print(f"| {OP} | " + " | ".join(f"{table[n]:,.1f} ({table[n] / best:.1f}x)" for n in names) + " |")


main()
