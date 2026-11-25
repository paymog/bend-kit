#!/usr/bin/env python3
"""Build and run the statistics benchmark. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 4
OPS = ["mean", "variance", "median", "histogram", "gcd", "lcm", "isqrt"]
PACKED = ["packed_identity", "packed_gcd", "packed_lcm", "packed_isqrt"]
WARM_PACKED = [f"warm_{op}" for op in PACKED]
CONTROLS = ["shared_cold", "shared_warm", "direct_cold", "direct_warm"]
CONTROL_ORDERS = [
    [CONTROLS[i] for i in order]
    for order in [(0, 1, 3, 2), (1, 2, 0, 3), (2, 3, 1, 0), (3, 0, 2, 1)]
]
CONTROL_OPS = [f"{mode}_{op}" for mode in CONTROLS for op in ["identity", "gcd", "lcm", "isqrt"]]
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
        expected += WARM_PACKED + CONTROL_OPS
    if set(result) != set(expected):
        sys.exit(f"missing or extra rows: {name}: {set(result) ^ set(expected)}")
    aliases = {f"packed_{op}": op for op in ["gcd", "lcm", "isqrt"]}
    if name in ("Bun", "Node"):
        aliases.update({f"warm_{op}": op for op in PACKED})
        aliases.update({f"{mode}_{op}": f"packed_{op}"
                        for mode in CONTROLS for op in ["identity", "gcd", "lcm", "isqrt"]})
    if name == "Bend":
        aliases.update({f"{op}_shared": op for op in ["gcd", "lcm", "isqrt"]})
        aliases.update(identity_shared="packed_identity", identity_release="packed_identity")
    for op, reference in aliases.items():
        if result[op][1] != result[reference][1]:
            sys.exit(f"diagnostic checksum mismatch: {name}: {op} != {reference}")


def execute(name, run, count, order=CONTROLS):
    r = subprocess.run([*run, str(count)], cwd=HERE, env=ENV, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"{name} failed:\n{r.stdout}\n{r.stderr}")
    result = parse(r.stdout)
    if name in ("Bun", "Node"):
        for mode in order:
            r = subprocess.run([*run, str(count), mode], cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} {mode} failed:\n{r.stdout}\n{r.stderr}")
            control = parse(r.stdout)
            expected = {f"{mode}_{op}" for op in ["identity", "gcd", "lcm", "isqrt"]}
            if set(control) != expected:
                sys.exit(f"missing or extra control rows: {name}: {mode}")
            result.update(control)
    return result


def main():
    OUT.mkdir(exist_ok=True)
    table, checks, estimates, deltas, all_runs = {}, {}, {}, {}, {}
    small_checks = None
    for name, (build, run) in VARIANTS.items():
        if build:
            r = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"build failed: {name}\n{r.stderr}")
        runs = []
        for index in range(RUNS):
            # A small first run checks the edge cases before the timed input.
            if not runs:
                small = execute(name, run, 16)
                check_rows(name, small)
                current = {op: small[op][1] for op in OPS}
                if small_checks is None:
                    small_checks = current
                elif current != small_checks:
                    sys.exit(f"small input checksum mismatch: {name}: {current} != {small_checks}")
            order = CONTROL_ORDERS[index % len(CONTROL_ORDERS)]
            if name in ("Bun", "Node"):
                print(f"{name} run {index + 1} mode order: {' -> '.join(order)}", file=sys.stderr)
            runs.append(execute(name, run, 2097152, order))
        measured = OPS + (BEND_LIST if name == "Bend" else [])
        if name in ("Bun", "Node"):
            measured += WARM_PACKED + CONTROL_OPS
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
        all_runs[name] = runs

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
    print("\nControlled fresh-process JavaScript loops (ms):")
    print("| language | mode | op | median |")
    print("|---|---|---|---:|")
    for name in ("Bun", "Node"):
        for mode in CONTROLS:
            for op in ["identity", "gcd", "lcm", "isqrt"]:
                print(f"| {name} | {mode} | {op} | {table[name][f'{mode}_{op}']:.3f} |")
    print("\nControlled signed deltas (ms; warm minus cold, or kernel minus matching identity):")
    print("| language | comparison | " + " | ".join(f"run {i + 1}" for i in range(RUNS)) + " | median |")
    print("|---|---|" + "---:|" * (RUNS + 1))
    for name in ("Bun", "Node"):
        comparisons = [
            (f"{path} warm-cold {op}", f"{path}_warm_{op}", f"{path}_cold_{op}")
            for path in ("shared", "direct") for op in ["identity", "gcd", "lcm", "isqrt"]
        ] + [
            (f"{mode} {op}-identity", f"{mode}_{op}", f"{mode}_identity")
            for mode in CONTROLS for op in ["gcd", "lcm", "isqrt"]
        ]
        for label, left, right in comparisons:
            values = [result[left][0] - result[right][0] for result in all_runs[name]]
            print(f"| {name} | {label} | " + " | ".join(f"{v:+.3f}" for v in values)
                  + f" | {statistics.median(values):+.3f} |")


if __name__ == "__main__":
    main()
