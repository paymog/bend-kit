#!/usr/bin/env python3
"""Count native closure targets; do not use this instrumented binary for timing."""
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"


def main():
    OUT.mkdir(exist_ok=True)
    source = OUT / "dispatch.c"
    binary = OUT / "dispatch"
    subprocess.run(["bend", "profile.bend", "-o", str(source)], cwd=HERE, check=True)
    text = source.read_text()
    names = dict((int(i), name) for name, i in re.findall(r"^#define FID_(\w+) (\d+)$", text, re.M))
    marker = "    u32 f    = term_aux(fun);"
    if text.count(marker) != 1 or not names:
        raise SystemExit("unsupported generated C: expected one closure dispatcher and FID names")
    counters = "\nstatic unsigned long long dispatch_counts[" + str(max(names) + 1) + "];\n"
    counters += "static void dispatch_report(void) {\n"
    for i, name in names.items():
        counters += f'  if (dispatch_counts[{i}]) fprintf(stderr, "dispatch\\t{name}\\t%llu\\n", dispatch_counts[{i}]);\n'
    counters += "}\n__attribute__((constructor)) static void dispatch_init(void) { atexit(dispatch_report); }\n"
    text = text.replace("// Dialect", counters + "\n// Dialect", 1)
    text = text.replace(marker, marker + "\n    ++dispatch_counts[f];")
    source.write_text(text)
    subprocess.run(["cc", "-O2", "-Wno-unused-value", str(source), "-o", str(binary), "-lm", "-lpthread"], check=True)
    for mode in ("range", "overflow", "constant"):
        results = []
        for n in (0, 1000):
            run = subprocess.run([str(binary), mode, str(n)], capture_output=True, text=True, check=True)
            expected = 0
            for _ in range(n):
                expected = (expected * 31 + (18 if mode == "overflow" else 1588457592)) & 0xFFFFFFFF
            if int(run.stdout.strip().split("\t")[-1]) != expected:
                raise SystemExit(f"{mode}: unexpected checksum: {run.stdout}")
            counts = {}
            for line in run.stderr.splitlines():
                if line.startswith("dispatch\t"):
                    _, name, count = line.split("\t")
                    counts[name] = int(count)
            if not counts:
                raise SystemExit("no closure counts")
            results.append(counts)
        print(f"{mode}: closure calls per command (1000 commands minus zero-command setup)")
        delta = {name: results[1].get(name, 0) - results[0].get(name, 0) for name in names.values()}
        for name, count in sorted(delta.items(), key=lambda item: -item[1]):
            if count:
                print(f"{name}\t{count / 1000:g}")
        print(f"total\t{sum(delta.values()) / 1000:g}")


if __name__ == "__main__":
    main()
