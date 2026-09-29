#!/usr/bin/env python3
"""Build and run the DNS benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
OPS = ["build", "parse"]
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}
DNSPYTHON = "2.8.0"
# name -> (build argv or None, run argv).
VARIANTS = {
    "C": (["clang", "-O2", "-o", OUT / "c", "bench.c", "-lresolv"], [OUT / "c", "100000"]),
    "Rust": (["cargo", "build", "--release", "-q", "--locked", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"], [OUT / "rs" / "release" / "rs", "100000"]),
    "Bun": (["sh", "-c", "mkdir -p out/js && cp js/package*.json out/js/ && npm ci -s --prefix out/js && cp bench.mjs out/js/"], ["bun", OUT / "js" / "bench.mjs"]),
    "Node": (None, ["node", OUT / "js" / "bench.mjs"]),
    "Python": (None, ["uv", "run", "-q", "--no-project", "--with", f"dnspython=={DNSPYTHON}", "python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


def parse(text):
    """-> {op: (ms, checksum)}. Most variants print `op ms chk`; Bend prints `chk op v` then `ms op v`."""
    got, chk = {}, {}
    for p in (line.split("\t") for line in text.splitlines()):
        if len(p) != 3:
            continue
        if p[0] == "chk":
            chk[p[1]] = p[2]
        elif p[0] == "ms":
            got[p[1]] = (float(p[2]), chk[p[1]])
        else:
            got[p[0]] = (float(p[1]), p[2])
    return got


OUT.mkdir(exist_ok=True)
table, checks = {}, {}
for name, (build, run) in VARIANTS.items():
    if build and subprocess.run(build, cwd=HERE, env=ENV).returncode != 0:
        sys.exit(f"build failed: {name}")
    runs = [parse(subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True, check=True).stdout) for _ in range(RUNS)]
    table[name] = {op: statistics.median(r[op][0] for r in runs) for op in OPS}
    checks[name] = {op: runs[0][op][1] for op in OPS}
if len({tuple(c.values()) for c in checks.values()}) != 1:
    sys.exit(f"checksum mismatch: {checks}")
print("| op | " + " | ".join(table) + " |")
print("|---|" + "---:|" * len(table))
for op in OPS:
    best = min(t[op] for t in table.values())
    print(f"| {op} | " + " | ".join(f"{t[op]:,.1f} ({t[op] / best:.1f}x)" for t in table.values()) + " |")
print("checksums: " + ", ".join(f"{op} {checks['C'][op]}" for op in OPS))
