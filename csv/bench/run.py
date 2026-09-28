#!/usr/bin/env python3
"""Write the input, build and run the CSV benchmark; print a markdown table. See README.md."""
import csv, io, os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
ROWS = int(sys.argv[2]) if len(sys.argv) > 2 else 20000
OPS = ["parse", "encode"]
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

# name -> (build argv or None, run argv). Every program reads out/doc.csv and prints `op<TAB>ms<TAB>checksum` per op.
VARIANTS = {
    "Rust": (["cargo", "build", "--release", "-q", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"], [OUT / "rs" / "release" / "rs"]),
    "Python": (None, ["python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


# Every row has five fields, so no writer quotes a lone empty field.
def row(i):
    note = ["plain", "has, comma", 'say "hi"', "two\r\nlines", ""][i % 5]
    return [str(i), f"user {i}", note, str(i * 7 % 1000), f"t{i % 13}"]


def main():
    OUT.mkdir(exist_ok=True)
    buf = io.StringIO(newline="")
    csv.writer(buf, lineterminator="\r\n").writerows(row(i) for i in range(ROWS))
    doc = buf.getvalue().encode()
    (OUT / "doc.csv").write_bytes(doc)
    print(f"input {len(doc):,} bytes, {ROWS} rows", file=sys.stderr)

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
        best = max(min(t[op] for t in table.values()), 1e-9)
        cells = [f"{table[n][op]:,.1f} ({table[n][op] / best:.1f}x)" for n in names]
        print(f"| {op} | " + " | ".join(cells) + " |")


main()
