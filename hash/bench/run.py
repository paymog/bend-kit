#!/usr/bin/env python3
"""Build and run the hash benchmark; print a markdown table. See README.md."""
import os, shlex, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
OPS = ["crc32", "crc32_short", "adler32", "fnv1a32", "fnv1a64", "xxh32", "xxh64", "siphash13", "siphash24"]
LENGTHS = (0, 1, 3, 4, 7, 8, 15, 16, 17, 31, 32, 33)
PATTERNS = ("zero", "incrementing", "mixed")
MATRIX = [f"crc32_{pattern}_{length}" for pattern in PATTERNS for length in LENGTHS]
CALLS = 100000
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "PYTHONHASHSEED": "0"}
SODIUM = shlex.split(subprocess.check_output(["pkg-config", "--cflags", "--libs", "libsodium"], text=True))

# name -> (build argv or None, run argv). Every program prints `op<TAB>ms<TAB>checksum` per op.
VARIANTS = {
    "C": (["clang", "-O2", "-o", OUT / "c", "bench.c", "-lz", *SODIUM], [OUT / "c"]),
    "Rust": (["rustc", "-C", "opt-level=3", "-C", "target-cpu=native", "-o", OUT / "rs", "bench.rs"], [OUT / "rs"]),
    "Bun": (None, ["bun", "bench.ts"]),
    "Node": (None, ["node", "bench.ts"]),
    "Python": (None, ["python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


def main():
    OUT.mkdir(exist_ok=True)
    if RUNS < 1:
        sys.exit("run count must be positive")
    for command in (["bend", "version"], ["clang", "--version"], ["rustc", "--version"],
                    ["bun", "--version"], ["node", "--version"], ["python3", "--version"]):
        version = subprocess.check_output(command, text=True).splitlines()[0]
        print(f"{command[0]}: {version}", file=sys.stderr)
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
            result = runs[-1]
            required = MATRIX if name in ("Bend", "Python") else []
            if any(op not in result for op in required):
                sys.exit(f"{name}: missing CRC-32 matrix rows")
            missing = [op for op in runs[0] if op not in result or any(value is None for value in result[op])]
            if not result or missing:
                sys.exit(f"{name} repetition {len(runs)}: missing timing or checksum for {missing or 'all operations'}: {result}")
            if {op: value[1:] for op, value in result.items()} != {op: value[1:] for op, value in runs[0].items()}:
                sys.exit(f"{name} repetition {len(runs)}: checksum mismatch: {result} != {runs[0]}")
        table[name] = {op: statistics.median(x[op][0] for x in runs) for op in runs[0]}
        checks[name] = {op: c for op, (_, c) in runs[0].items()}
        print(f"ran {name}", file=sys.stderr)

    for op in OPS:
        seen = {checks[n][op] for n in checks if op in checks[n]}
        if len(seen) != 1 or op not in checks["Bend"]:
            sys.exit(f"checksum mismatch in {op}: {[(n, checks[n].get(op)) for n in checks]}")
        print(f"{op} checksum {seen.pop()}", file=sys.stderr)

    names = list(table)
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    for op in OPS:
        best = min(t[op] for t in table.values() if op in t)
        cells = [f"{table[n][op]:,.1f} ({table[n][op] / best:.1f}x)" if op in table[n] else "n/a" for n in names]
        print(f"| {op} | " + " | ".join(cells) + " |")

    print(f"\nCRC-32 short matrix: {CALLS:,} calls per sample; median of {RUNS} runs.")
    print("| pattern | bytes | checksum | Bend ms | Python zlib ms | Bend ns/call |")
    print("|---|---:|---|---:|---:|---:|")
    for pattern in PATTERNS:
        for length in LENGTHS:
            op = f"crc32_{pattern}_{length}"
            if checks["Bend"][op] != checks["Python"][op]:
                sys.exit(f"checksum mismatch in {op}")
            ms = table["Bend"][op]
            print(f"| {pattern} | {length} | `{checks['Bend'][op]}` | "
                  f"{ms:.6f} | {table['Python'][op]:.6f} | {ms * 1000000 / CALLS:.3f} |")


main()
