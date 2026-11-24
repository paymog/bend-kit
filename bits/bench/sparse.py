#!/usr/bin/env python3
"""Measure the current max-16 tables in both stream orders."""
import os
from pathlib import Path
import statistics
import subprocess
import sys

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
FIXTURES = {"sparse": [16, 16], "mixed": [10] * 32 + [12] * 16 + [16, 16]}


def fixture(lens, msb):
    counts = [lens.count(i) for i in range(17)]
    starts, code = [0] * 17, 0
    for width in range(1, 17):
        code = (code + counts[width - 1]) << 1
        starts[width] = code
    codes, prefixes = [], {}
    for width in lens:
        code = starts[width]
        starts[width] += 1
        assert code < 1 << width
        codes.append(f"{code:0{width}b}")
        prefix = code >> (width - 9)
        prefixes[prefix] = max(prefixes.get(prefix, 0), width - 9)
    bits, checksum = "", 0
    for i in range(4096):
        symbol = i % len(lens)
        bits += codes[symbol]
        checksum = (checksum * 31 + symbol) & 0xFFFFFFFF
    bits += "0" * (-len(bits) % 8)
    data = bytes(int(bits[i:i + 8] if msb else bits[i:i + 8][::-1], 2)
                 for i in range(0, len(bits), 8))
    used = len(prefixes) * 128
    compact = sum(1 << width for width in prefixes.values())
    allocated = lambda n: 1 << (n - 1).bit_length()
    return data, checksum, (512, allocated(used)), (len(prefixes), used, compact, allocated(compact))


def main():
    OUT.mkdir(exist_ok=True)
    wants, sizes = {}, {}
    for name, lens in FIXTURES.items():
        for msb in (False, True):
            tag = name + ("-msb" if msb else "-lsb")
            data, checksum, size, counts = fixture(lens, msb)
            (OUT / (tag + ".bin")).write_bytes(data)
            wants[tag] = checksum
            sizes[tag] = size
        print(name, "prefixes / uniform used / compact used / compact allocated:", counts)
    env = {**os.environ, "BEND_NO_TELEMETRY": "1"}
    subprocess.run(["bend", "sparse.bend", "-o", OUT / "sparse"], cwd=HERE, env=env, check=True)
    times = {tag: {"build1000": [], "decode4096": []} for tag in wants}
    for _ in range(int(sys.argv[1]) if len(sys.argv) > 1 else 3):
        result = subprocess.run([OUT / "sparse"], cwd=HERE, env=env,
                                text=True, capture_output=True, check=True)
        tag = None
        for line in result.stdout.splitlines():
            if line in wants:
                tag = line
            elif "\t" in line:
                op, value, checksum = line.split("\t")
                assert tag is not None, line
                if op == "entries":
                    assert (int(value), int(checksum)) == sizes[tag], line
                else:
                    assert int(checksum) == (31000 if op == "build1000" else wants[tag]), (tag, line)
                    times[tag][op].append(float(value))
    print("| fixture | root entries | secondary entries | build ms | decode 4096 ms | checksum |")
    print("|---|---:|---:|---:|---:|---:|")
    for tag, ops in times.items():
        assert all(ops.values()), tag
        build = statistics.median(ops["build1000"]) / 1000
        decode = statistics.median(ops["decode4096"])
        print(f"| {tag} | {sizes[tag][0]} | {sizes[tag][1]} | {build:.6f} | {decode:.6f} | {wants[tag]} |")


if __name__ == "__main__":
    main()
