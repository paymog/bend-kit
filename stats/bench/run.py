#!/usr/bin/env python3
"""Build and run the statistics benchmark. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
OPS = ["mean", "variance", "median", "histogram", "gcd", "lcm", "isqrt"]
PACKED = ["packed_identity", "packed_gcd", "packed_lcm", "packed_isqrt"]
WARM_PACKED = [f"warm_{op}" for op in PACKED]
BEND_LIST = ["identity_shared", "gcd_shared", "lcm_shared", "isqrt_shared", "identity_release"]
OPS += PACKED
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}

VARIANTS = {
    "C": (["cc", "-O2", "-o", OUT / "c", "bench.c"], [OUT / "c"]),
    "Rust": (["rustc", "-C", "opt-level=3", "-o", OUT / "rs", "bench.rs"], [OUT / "rs"]),
    "Bun": (None, ["bun", "bench.ts"]),
    "Node": (None, ["node", "--no-warnings", "bench.ts"]),
    "Python": (None, ["python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


def parse(text):
    got, chk, ms = {}, {}, {}
    for line in text.splitlines():
        p = line.split("\t")
        if len(p) != 3:
            continue
        if p[0] == "chk":
            chk[p[1]] = p[2]
        elif p[0] == "ms":
            ms[p[1]] = float(p[2])
        else:
            got[p[0]] = (float(p[1]), p[2])
    for op, t in ms.items():
        got[op] = (t, chk.get(op))
    return got


def check_rows(name, result):
    expected = OPS + (BEND_LIST if name == "Bend" else [])
    if name in ("Bun", "Node"):
        expected += WARM_PACKED
    if set(result) != set(expected):
        sys.exit(f"missing or extra rows: {name}: {set(result) ^ set(expected)}")
    aliases = {f"packed_{op}": op for op in ["gcd", "lcm", "isqrt"]}
    if name in ("Bun", "Node"):
        aliases.update({f"warm_{op}": op for op in PACKED})
    if name == "Bend":
        aliases.update({f"{op}_shared": op for op in ["gcd", "lcm", "isqrt"]})
        aliases.update(identity_shared="packed_identity", identity_release="packed_identity")
    for op, reference in aliases.items():
        if result[op][1] != result[reference][1]:
            sys.exit(f"diagnostic checksum mismatch: {name}: {op} != {reference}")


def main():
    OUT.mkdir(exist_ok=True)
    table, checks, estimates, deltas = {}, {}, {}, {}
    small_checks = None
    for name, (build, run) in VARIANTS.items():
        if build:
            r = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"build failed: {name}\n{r.stderr}")
        runs = []
        for _ in range(RUNS):
            # A small first run checks the edge cases before the timed input.
            if not runs:
                probe = subprocess.run([*run, "16"], cwd=HERE, env=ENV, capture_output=True, text=True)
                if probe.returncode != 0:
                    sys.exit(f"{name} small input failed:\n{probe.stdout}\n{probe.stderr}")
                small = parse(probe.stdout)
                check_rows(name, small)
                current = {op: small[op][1] for op in OPS}
                if small_checks is None:
                    small_checks = current
                elif current != small_checks:
                    sys.exit(f"small input checksum mismatch: {name}: {current} != {small_checks}")
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stdout}\n{r.stderr}")
            runs.append(parse(r.stdout))
        measured = OPS + (BEND_LIST if name == "Bend" else [])
        if name in ("Bun", "Node"):
            measured += WARM_PACKED
        for result in runs:
            check_rows(name, result)
        table[name] = {op: statistics.median(x[op][0] for x in runs) for op in measured}
        checks[name] = {op: runs[0][op][1] for op in measured}
        deltas[name] = {
            f"{prefix}{op}": [x[f"{prefix}{op}"][0] - x[f"{prefix}identity"][0] for x in runs]
            for prefix in (["packed_", "warm_packed_"] if name in ("Bun", "Node") else ["packed_"])
            for op in ["gcd", "lcm", "isqrt"]
        }
        estimates[name] = {op: statistics.median(deltas[name][f"packed_{op}"])
                           for op in ["gcd", "lcm", "isqrt"]}
        for result in runs:
            if any(result[op][1] != checks[name][op] for op in measured):
                sys.exit(f"unstable checksums: {name}")
        print(f"ran {name}", file=sys.stderr)

    for op in OPS:
        seen = {n: c[op] for n, c in checks.items()}
        if len(set(seen.values())) > 1:
            sys.exit(f"checksum mismatch in {op}: {seen}")

    names = list(table)
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    for op in OPS:
        print(f"| {op} | " + " | ".join(f"{table[n][op]:,.3f}" for n in names) + " |")
    print()
    print("| op | checksum |")
    print("|---|---:|")
    for op in OPS:
        print(f"| {op} | {checks['Bend'][op]} |")
    print("\nBend list ownership (ms; each kernel pass retains the same shared list):")
    print("| op | Bend | checksum |")
    print("|---|---:|---:|")
    for op in BEND_LIST:
        print(f"| {op} | {table['Bend'][op]:,.3f} | {checks['Bend'][op]} |")
    print("\nKernel estimates (ms; median of each run's packed kernel minus packed identity, not direct timings):")
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    for op in ["gcd", "lcm", "isqrt"]:
        print(f"| {op} | " + " | ".join(f"{estimates[n][op]:,.3f}" for n in names) + " |")
    print("\nWarmed JavaScript packed loops (ms; three untimed full passes per function and dispatch path):")
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    for op in PACKED:
        print(f"| {op} | " + " | ".join(
            f"{table[n]['warm_' + op] if n in ('Bun', 'Node') else table[n][op]:,.3f}"
            for n in names) + " |")
    print("\nNative and Python columns repeat the original packed measurements; only JavaScript is warmed.")
    print("\nPer-run kernel estimates (ms; kernel minus matching identity, not isolated arithmetic):")
    print("| language | pass | " + " | ".join(f"run {i + 1}" for i in range(RUNS)) + " | median |")
    print("|---|---|" + "---:|" * (RUNS + 1))
    for name in names:
        for op, values in deltas[name].items():
            print(f"| {name} | {op} | " + " | ".join(f"{v:,.3f}" for v in values)
                  + f" | {statistics.median(values):,.3f} |")


main()
