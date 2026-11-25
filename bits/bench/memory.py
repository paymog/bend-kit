#!/usr/bin/env python3
"""Measure whole-process caller RSS and inspect every DEFLATE block on macOS."""
import collections
import gzip
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import statistics
import subprocess
import sys
import zlib

HERE = Path(__file__).resolve().parent
OUT = HERE / "out" / "memory"
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    # The existing benchmark reads its defaults at import time.
    args, sys.argv = sys.argv, [str(path)]
    try:
        spec.loader.exec_module(module)
    finally:
        sys.argv = args
    return module


def canonical(lens):
    codes, next_code, code = {}, {}, 0
    for width in range(1, 17):
        code = (code + (lens.count(width - 1) if width > 1 else 0)) << 1
        next_code[width] = code
        for symbol, length in enumerate(lens):
            if length == width:
                codes[width, next_code[width]] = symbol
                next_code[width] += 1
        assert next_code[width] <= 1 << width
    return codes


def sizes(lens):
    codes = canonical(lens)
    maximum = max(lens, default=0)
    prefixes = {}
    for (width, code), symbol in codes.items():
        if width > 9:
            prefix = code >> (width - 9)
            prefixes[prefix] = max(prefixes.get(prefix, 0), width - 9)
    round_up = lambda n: 1 << (max(1, n) - 1).bit_length()
    uniform = len(prefixes) * (1 << max(0, maximum - 9))
    compact = sum(1 << width for width in prefixes.values())
    return {"depths": dict(sorted(collections.Counter(lens).items())),
            "root": 1 << min(maximum, 9), "secondary": round_up(uniform),
            "reserved": uniform, "compact_reserved": compact,
            "compact_secondary": round_up(compact)}


def inspect(gz):
    # Inputs are emitted here with a ten-byte gzip header and no optional fields.
    assert gz[:3] == b"\x1f\x8b\x08" and gz[3] == 0
    data, pos, produced, blocks = gz[10:-8], 0, 0, []

    def read(n):
        nonlocal pos
        assert pos + n <= len(data) * 8
        value = sum(((data[(pos + i) // 8] >> ((pos + i) % 8)) & 1) << i
                    for i in range(n))
        pos += n
        return value

    def symbol(codes):
        code = 0
        for width in range(1, 17):
            code = (code << 1) | read(1)
            if (width, code) in codes:
                return codes[width, code]
        raise ValueError("invalid Huffman code")

    length_base = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27,
                   31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
    length_extra = [0] * 8 + [1] * 4 + [2] * 4 + [3] * 4 + [4] * 4 + [5] * 4 + [0]
    distance_extra = [0] * 4 + [i for i in range(1, 14) for _ in range(2)]
    final = 0
    while not final:
        start, plain_start = pos, produced
        final, kind = read(1), read(2)
        record = {"kind": kind, "start_bit": start, "plain_start": plain_start}
        if kind == 0:
            read(-pos % 8)
            n = read(16)
            assert read(16) == (n ^ 65535)
            assert pos + n * 8 <= len(data) * 8
            pos += n * 8
            produced += n
            record["live_tables"] = 0
        else:
            if kind == 1:
                ll, dl = [8] * 144 + [9] * 112 + [7] * 24 + [8] * 8, [5] * 30
            elif kind == 2:
                nl, nd, nc = read(5) + 257, read(5) + 1, read(4) + 4
                cl = [0] * 19
                for s in (16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15)[:nc]:
                    cl[s] = read(3)
                codes, lens = canonical(cl), []
                while len(lens) < nl + nd:
                    s = symbol(codes)
                    if s < 16:
                        lens.append(s)
                    elif s == 16:
                        lens.extend([lens[-1]] * (read(2) + 3))
                    else:
                        lens.extend([0] * (read(3 if s == 17 else 7) + (3 if s == 17 else 11)))
                assert len(lens) == nl + nd
                ll, dl = lens[:nl], lens[nl:]
                record["header_tree"] = sizes(cl)
            else:
                raise ValueError("reserved block type")
            record.update(literal=sizes(ll), distance=sizes(dl),
                          payload_start_bit=pos, live_tables=2)
            literals, distances = canonical(ll), canonical(dl)
            while True:
                s = symbol(literals)
                if s == 256:
                    break
                if s < 256:
                    produced += 1
                else:
                    assert 257 <= s <= 285
                    produced += length_base[s - 257] + read(length_extra[s - 257])
                    d = symbol(distances)
                    assert d < 30
                    read(distance_extra[d])
        record.update(end_bit=pos, plain_end=produced)
        blocks.append(record)
    assert produced == len(zlib.decompress(gz, 31))
    return blocks


def measured(binary, cwd, want, runs):
    rss, times = [], []
    for _ in range(runs):
        p = subprocess.run(["/usr/bin/time", "-l", str(binary)], cwd=cwd,
                           env=ENV, capture_output=True, text=True, check=True)
        rows = [line.split("\t") for line in p.stdout.splitlines() if "\t" in line]
        assert len(rows) == 1 and rows[0][0] == "inflate", p.stdout
        assert int(rows[0][2]) == want, p.stdout
        rss.append(int(re.search(r"(\d+)\s+maximum resident set size", p.stderr)[1]))
        times.append(float(rows[0][1]))
    return {"rss_bytes": rss, "inflate_ms": times}


def main():
    assert sys.platform == "darwin", "RSS units and /usr/bin/time flags are macOS-specific"
    runs = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    sizes_plain = [int(x) for x in sys.argv[2:]] or [1024, 32768, 131072]
    assert runs > 0 and all(0 < n <= 4194304 for n in sizes_plain)
    for level in (0, 1, 9):
        plain = b"abc123" * 1024
        assert inspect(gzip.compress(plain, compresslevel=level, mtime=0))[-1]["plain_end"] == len(plain)
    assert sizes([16, 16])["secondary"] == 128
    assert sizes([10] * 32 + [12] * 16 + [16, 16])["compact_reserved"] == 176
    OUT.mkdir(parents=True, exist_ok=True)
    caller = load("caller", HERE / "../../zlib/bench/run.py")
    bits = load("bits_bench", HERE / "run.py")
    sparse = load("sparse", HERE / "sparse.py")
    for source, binary in [(HERE / "memory.bend", OUT / "decode"),
                           (HERE / "../../zlib/bench/bench.bend", OUT / "encode"),
                           (HERE / "sparse.bend", OUT / "sparse")]:
        subprocess.run(["bend", str(source), "-o", str(binary)], env=ENV, check=True)
    report = {}
    for n in sizes_plain:
        plain = caller.plain_bytes(n)
        work = OUT / str(n)
        (work / "out").mkdir(parents=True, exist_ok=True)
        (work / "out/plain.bin").write_bytes(plain)
        (work / "out/payload.gz").write_bytes(gzip.compress(plain, mtime=0))
        encoded = subprocess.run([OUT / "encode"], cwd=work, env=ENV,
                                 text=True, capture_output=True, check=True)
        assert f"\t{bits.checksum(plain)}" in encoded.stdout, encoded.stdout
        kit = (work / "out/bend.gz").read_bytes()
        assert zlib.decompress(kit, 31) == plain
        for name, gz in [("kit", kit), ("python", gzip.compress(plain, mtime=0))]:
            (work / "out/payload.gz").write_bytes(gz)
            blocks = inspect(gz)
            result = measured(OUT / "decode", work, bits.checksum(plain), runs)
            result.update(blocks=blocks, plain_bytes=n, gzip_bytes=len(gz),
                          sha256=hashlib.sha256(gz).hexdigest(), checksum=bits.checksum(plain))
            report[f"{name}-{n}"] = result
            print(name, n, "blocks", len(blocks), "peak RSS bytes", result["rss_bytes"],
                  "median inflate ms", statistics.median(result["inflate_ms"]))
    control = OUT / "controls"
    (control / "out").mkdir(parents=True, exist_ok=True)
    for name, lens in sparse.FIXTURES.items():
        print(name, json.dumps(sizes(lens), sort_keys=True))
        for msb in (False, True):
            tag = name + ("-msb" if msb else "-lsb")
            (control / "out" / (tag + ".bin")).write_bytes(sparse.fixture(lens, msb)[0])
    control_rss = []
    for _ in range(runs):
        p = subprocess.run(["/usr/bin/time", "-l", str(OUT / "sparse")], cwd=control,
                           env=ENV, text=True, capture_output=True, check=True)
        tag = None
        checked = 0
        for line in p.stdout.splitlines():
            if line in {n + order for n in sparse.FIXTURES for order in ("-lsb", "-msb")}:
                tag = line
            elif "\t" in line:
                op, value, checksum = line.split("\t")
                checked += 1
                mixed = tag.startswith("mixed")
                if op == "entries":
                    assert (int(value), int(checksum)) == (512, 4096 if mixed else 128)
                else:
                    assert op in ("build1000", "decode4096"), line
                    assert int(checksum) == (31000 if op == "build1000" else
                                            3343667776 if mixed else 628164608)
        assert checked == 84, p.stdout
        control_rss.append(int(re.search(r"(\d+)\s+maximum resident set size", p.stderr)[1]))
    report["controls"] = {"rss_bytes": control_rss, "live_tables": 1}
    (OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print("synthetic combined RSS bytes", control_rss)
    print("raw samples and all block distributions:", OUT / "report.json")


if __name__ == "__main__":
    main()
