#!/usr/bin/env python3
"""Build and run the websocket benchmark; print a markdown table. See README.md."""
import json, os, shutil, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
OPS = {"frame": 256 * 65536 / 1e6, "stream": 16384 * 1000 / 1e6}
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1", "PYTHONPATH": str(OUT / "py")}


def setup():
    OUT.mkdir(exist_ok=True)
    js = OUT / "js"
    js.mkdir(exist_ok=True)
    (js / "package.json").write_text(json.dumps({"private": True, "type": "module", "dependencies": {"ws": "8.22.0"}}))
    shutil.copy(HERE / "bench.ts", js / "bench.ts")
    steps = [
        (["bun", "install", "--silent"], js),
        ([sys.executable, "-m", "pip", "install", "-q", "--target", str(OUT / "py"), "websockets==17.1"], HERE),
        (["cargo", "build", "-q", "--release", "--manifest-path", "rs/Cargo.toml", "--target-dir", str(OUT / "rs")], HERE),
        (["bend", "bench.bend", "-o", str(OUT / "bend")], HERE),
    ]
    for cmd, cwd in steps:
        if subprocess.run(cmd, cwd=cwd, env=ENV, capture_output=True).returncode != 0:
            sys.exit(f"build failed: {' '.join(cmd)}")


VARIANTS = {
    "Rust": ([OUT / "rs" / "release" / "bench"], HERE),
    "Node": (["node", "--no-warnings", "bench.ts"], OUT / "js"),
    "Python": ([sys.executable, "bench.py"], HERE),
    "Bend": ([OUT / "bend"], HERE),
}


def main():
    setup()
    table, checks = {}, {}
    for name, (cmd, cwd) in VARIANTS.items():
        runs = {op: [] for op in OPS}
        for _ in range(RUNS):
            r = subprocess.run(cmd, cwd=cwd, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr or r.stdout}")
            for line in r.stdout.splitlines():
                op, *rest = line.split("\t")
                if op in OPS:
                    ms, c = rest
                    runs[op].append(float(ms))
                    checks.setdefault(op, {})[name] = c
        table[name] = {op: statistics.median(ms) for op, ms in runs.items()}
        print(f"ran {name}", file=sys.stderr)

    for op in OPS:
        if len(set(checks[op].values())) != 1:
            sys.exit(f"{op} checksum mismatch: {checks[op]}")
        print(f"{op} checksum {next(iter(checks[op].values()))}", file=sys.stderr)

    for op, mb in OPS.items():
        best = min(t[op] for t in table.values()) or 0.001
        print(f"\n| {op} | ms | MB/s | vs fastest |")
        print("|---:|---:|---:|---:|")
        for n, t in table.items():
            print(f"| {n} | {t[op]:,.1f} | {mb / (t[op] / 1000):,.0f} | {t[op] / best:.1f}x |")


if __name__ == "__main__":
    main()
