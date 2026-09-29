#!/usr/bin/env python3
"""Build and run the scrypt benchmark one process at a time; print a markdown table. See README.md."""
import os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
# RFC 7914 §12 vector 3 (pleaseletmein, SodiumChloride, N=16384, r=8, p=1), first 32 octets.
WANT = "7023bdcb3afd7348461c06cd81fd38ebfda8fbba904f8e3ea9b543f6545da1f2"
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1"}
SSL = os.environ.get("OPENSSL_PREFIX", "/opt/homebrew/opt/openssl@3")

VARIANTS = {
    "C": (
        ["clang", "-O2", f"-I{SSL}/include", f"-L{SSL}/lib", "-o", OUT / "c", "bench.c", "-lcrypto"],
        [OUT / "c"],
    ),
    "Python": (None, [sys.executable, "bench.py"]),
    "Node": (None, ["node", "--no-warnings", "bench.js"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


def main():
    OUT.mkdir(exist_ok=True)
    table = {}
    for name, (build, run) in VARIANTS.items():
        if build:
            b = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            if b.returncode != 0:
                sys.exit(f"build failed: {name}\n{b.stderr or b.stdout}")
        times = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr or r.stdout}")
            rows = [l.split("\t") for l in r.stdout.splitlines() if l.startswith("scrypt\t")]
            if len(rows) != 1 or len(rows[0]) != 3:
                sys.exit(f"{name} printed unexpected output:\n{r.stdout}")
            _, ms, got = rows[0]
            if got != WANT:
                sys.exit(f"{name} checksum {got}, want {WANT}")
            times.append(float(ms))
        table[name] = statistics.median(times)
        print(f"ran {name}", file=sys.stderr)

    print(f"checksum {WANT}", file=sys.stderr)
    best = min(table.values()) or 0.001
    print("| variant | scrypt ms | vs fastest |")
    print("|---:|---:|---:|")
    for n, ms in table.items():
        print(f"| {n} | {ms:,.1f} | {ms / best:.1f}x |")


if __name__ == "__main__":
    main()
