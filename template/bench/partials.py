#!/usr/bin/env python3
"""Run fixed Unicode partial workloads; reject missing or different results."""
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}


def main():
    runs = int(sys.argv[1]) if len(sys.argv) > 1 else 5
    out = HERE / "out"
    out.mkdir(exist_ok=True)
    for cmd in [["bun", "install", "--frozen-lockfile"], ["bend", "partials.bend", "-o", str(out / "partials")]]:
        subprocess.run(cmd, cwd=HERE, env=ENV, check=True, stdout=sys.stderr)
    variants = {
        "Bend": [str(out / "partials")],
        "Bun": ["bun", "partials.ts"],
        "Node": ["node", "--no-warnings", "partials.ts"],
        "Python": ["uv", "run", "-q", "--with", "pystache==0.6.8", "python", "partials_python.py"],
    }
    results = {}
    expected = {"large": ("3491016133", "9830400"), "nested": ("715866821", "1160000")}
    for variant, cmd in variants.items():
        for repetition in range(runs):
            result = subprocess.run(cmd, cwd=HERE, env=ENV, capture_output=True, text=True, check=True)
            fields = {}
            for line in result.stdout.splitlines():
                key, label, value = line.split("\t")
                fields.setdefault(label, {})[key] = value
            labels = {"large-packed", "large-text", "nested-packed", "nested-text"} if variant == "Bend" else {"large", "nested"}
            assert set(fields) == labels, (variant, fields)
            for label, values in fields.items():
                assert set(values) == {"chk", "len", "ms"}, values
                workload = label.split("-")[0]
                check = (values["chk"], values["len"])
                assert expected.setdefault(workload, check) == check, (variant, label, check, expected)
                results.setdefault(f"{variant}/{label}", []).append(float(values["ms"]))
    record = {"runs": results, "medians_ms": {k: statistics.median(v) for k, v in results.items()}, "checksums_and_total_utf8_bytes": expected}
    print(json.dumps(record, indent=2))


if __name__ == "__main__":
    main()
