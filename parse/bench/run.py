#!/usr/bin/env python3
"""Write the input, build and run the parser combinator benchmark; print a markdown table. See README.md."""
import json, os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
RECORDS = int(sys.argv[2]) if len(sys.argv) > 2 else 4000
OPS = ["parse"]
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

# name -> (build argv or None, run argv). Every program reads out/doc.json and prints `parse<TAB>ms<TAB>checksum`.
VARIANTS = {
    "Rust": (["cargo", "build", "-q", "--release", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "cargo"],
             [OUT / "cargo" / "release" / "rs"]),
    "Bun": (None, ["bun", "bench.ts"]),
    "Python": (None, ["uv", "run", "-q", "--with", "pyparsing==3.3.2", "python", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


# ASCII only, keys in sorted order, integers and exact halves: every encoder then prints the same text.
def record(i):
    return {
        "active": i % 3 == 0,
        "id": i,
        "meta": None,
        "name": f"user {i}",
        "nested": {"x": i * 7 % 1000, "y": [i % 10, i % 100, -i]},
        "note": 'line one\nline "two"\ttab \\ slash',
        "score": i + 0.5,
        "tags": [f"t{i % 5}", f"t{i % 7}"],
    }


def main():
    OUT.mkdir(exist_ok=True)
    doc = json.dumps({"count": RECORDS, "items": [record(i) for i in range(RECORDS)]}, indent=2)
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
        table[name] = {op: statistics.median(x[op][0] for x in runs) for op in runs[0]}
        checks[name] = {op: c for op, (_, c) in runs[0].items()}
        print(f"ran {name}", file=sys.stderr)

    for op in OPS:
        seen = {checks[n].get(op) for n in checks}
        if len(seen) != 1:
            sys.exit(f"checksum mismatch in {op}: {[(n, checks[n].get(op)) for n in checks]}")
        print(f"{op} checksum {seen.pop()}", file=sys.stderr)

    names = list(table)
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    for op in OPS:
        best = min(t[op] for t in table.values())
        cells = [f"{table[n][op]:,.1f} ({table[n][op] / best:.1f}x)" for n in names]
        print(f"| {op} | " + " | ".join(cells) + " |")


main()
