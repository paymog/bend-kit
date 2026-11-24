#!/usr/bin/env python3
"""Write the payload, build and run the bits benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys, zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
PROFILE = "--profile" in sys.argv
BUILD = "--build" in sys.argv or PROFILE
ARGS = [x for x in sys.argv[1:] if x not in ("--build", "--profile")] if __name__ == "__main__" else []
RUNS = int(ARGS[0]) if ARGS else 3
PLAIN = int(ARGS[1]) if len(ARGS) > 1 else 1_048_576
OPS = ("huffman", "fields")
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1",
       "CARGO_TARGET_DIR": str(OUT / "target")}
ZLIB = subprocess.run(["brew", "--prefix", "zlib"], capture_output=True, text=True).stdout.strip()

VARIANTS = {
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
    "C (zlib inflate)": (["cc", "-O2", "bench.c", "-o", OUT / "c", f"-I{ZLIB}/include", f"-L{ZLIB}/lib", "-lz"], [OUT / "c"]),
    "Rust (bitstream-io)": (["cargo", "build", "--release", "-q"], [OUT / "target" / "release" / "bench"]),
    "Python (zlib)": (None, ["python3", "bench.py"]),
    "Bun (node:zlib)": (None, ["bun", "bench.ts"]),
}


def lcg(x):
    return (x * 1664525 + 1013904223) & 0xFFFFFFFF


def plain_bytes(n):
    x, out = 0x5EED, bytearray(n)
    for i in range(n):
        x = lcg(x)
        out[i] = x >> 24
    return bytes(out)


# RFC 1951 §3.2.6: the fixed literal/length code of symbol s.
def fixed(s):
    if s < 144:
        return s + 48, 8
    if s < 256:
        return s + 256, 9
    if s < 280:
        return s - 256, 7
    return s - 88, 8


def deflate_fixed(plain):
    """One final fixed-Huffman block of literals, then end-of-block. Codes go most significant bit first."""
    out, acc, n = bytearray(), 0, 0

    def put(v, k):
        nonlocal acc, n
        acc |= v << n
        n += k
        while n >= 8:
            out.append(acc & 255)
            acc >>= 8
            n -= 8

    put(1, 1)
    put(1, 2)
    for s in list(plain) + [256]:
        c, k = fixed(s)
        put(int(f"{c:0{k}b}"[::-1], 2), k)
    if n:
        out.append(acc)
    return bytes(out)


# define_huffman_tree! also builds a writer, whose macro expansion did not finish in 10 minutes
# for 288 symbols, so the reader is the crate's own compile_read_tree_nodes! alone.
TREE_RS = """struct FixedLit;
impl bitstream_io::huffman::FromBits for FixedLit {
    type Symbol = u16;
    fn from_bits<F, E>(mut next: F) -> Result<u16, E>
    where
        F: FnMut() -> Result<bool, E>,
    {
        bitstream_io::compile_read_tree_nodes!(next, NODES)
    }
}
"""


def tree(code, depth):
    """The fixed code as a bitstream-io node list: [bit 0 subtree, bit 1 subtree] or a symbol."""
    if code in LEAF:
        return str(LEAF[code])
    return f"[{tree(code + '0', depth + 1)}, {tree(code + '1', depth + 1)}]"


LEAF = {f"{fixed(s)[0]:0{fixed(s)[1]}b}": s for s in range(288)}


def checksum(xs):
    h = 0
    for x in xs:
        h = (h * 31 + x) & 0xFFFFFFFF
    return h


def fields13(data):
    v, total = int.from_bytes(data, "little"), len(data) * 8
    return [(v >> (13 * i)) & 8191 for i in range(total // 13)]


def dynamic(plain):
    """A complete max-15 literal tree and one unused distance code."""
    lens = [8] * 255 + [9, 10, 11, 12, 13, 14, 15, 15]
    counts = [lens.count(i) for i in range(16)]
    code, next_code = 0, {}
    for length in range(1, 16):
        code = (code + counts[length - 1]) << 1
        next_code[length] = code
    codes = []
    for length in lens:
        codes.append((next_code[length], length))
        next_code[length] += 1
    bits = []

    def put(v, n):
        bits.extend((v >> i) & 1 for i in range(n))

    put(1, 1)
    put(2, 2)
    put(len(lens) - 257, 5)
    put(0, 5)
    put(15, 4)
    for symbol in [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]:
        put(4 if symbol < 16 else 0, 3)
    for length in lens + [1]:
        put(int(f"{length:04b}"[::-1], 2), 4)
    header = len(bits)
    for symbol in list(plain) + [256]:
        value, length = codes[symbol]
        put(int(f"{value:0{length}b}"[::-1], 2), length)

    def pack(xs):
        return bytes(sum(bit << j for j, bit in enumerate(xs[i:i + 8]))
                     for i in range(0, len(xs), 8))

    return pack(bits), pack([0, 0, 0] + bits[header:])


def build_bench():
    OUT.mkdir(exist_ok=True)
    source = "profile.bend" if PROFILE else "build.bend"
    subprocess.run(["bend", source, "-o", OUT / "build"], cwd=HERE, env=ENV, check=True)
    subprocess.run(VARIANTS["C (zlib inflate)"][0], cwd=HERE, env=ENV, check=True)
    print("| plain bytes | Bend build ms | Bend decode ms | build / decode | zlib inflate ms |")
    print("|---:|---:|---:|---:|---:|")
    stages = ("clock", "codes", "maximum", "count", "next", "reserve", "assign", "batch1000")
    if PROFILE:
        print("Stage times (ms) follow each block row in the same order:", ", ".join(stages))
    for size in (1024, 4096, 8192, 16383):
        plain = plain_bytes(size)
        payload, short = dynamic(plain)
        assert zlib.decompress(payload, -15) == plain
        (OUT / "payload.bin").write_bytes(payload)
        (OUT / "short.bin").write_bytes(short)
        times = {op: [] for op in ("build", "decode", "huffman") + (stages if PROFILE else ())}
        want = str(checksum(plain))
        for _ in range(RUNS):
            for binary in ("build", "c"):
                r = subprocess.run([OUT / binary], cwd=HERE, env=ENV, capture_output=True, text=True, check=True)
                for line in r.stdout.splitlines():
                    if line.count("\t") != 2:
                        continue
                    op, ms, result = line.split("\t")
                    assert result == ("8000" if op == "batch1000" else want), (op, result, want)
                    times[op].append(float(ms))
        build, decode, inflate = (statistics.median(times[op]) for op in ("build", "decode", "huffman"))
        print(f"| {size} | {build:.6f} | {decode:.6f} | {build / decode:.2f} | {inflate:.6f} |", flush=True)
        if PROFILE:
            print("stages", size, *(f"{statistics.median(times[op]):.6f}" for op in stages), flush=True)


def main():
    OUT.mkdir(exist_ok=True)
    plain = plain_bytes(PLAIN)
    payload = deflate_fixed(plain)
    if zlib.decompress(payload, -15) != plain:
        sys.exit("zlib does not inflate the payload back to the plain bytes")
    (OUT / "payload.bin").write_bytes(payload)
    (OUT / "tree.rs").write_text(TREE_RS.replace("NODES", tree("", 0)))
    want = {"huffman": str(checksum(plain)), "fields": str(checksum(fields13(payload)))}
    print(f"plain {PLAIN:,} bytes, payload {len(payload):,} bytes, checksums {want}", file=sys.stderr)

    table = {}
    for name, (build, run) in VARIANTS.items():
        if build:
            b = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            if b.returncode:
                sys.exit(f"build failed: {name}\n{b.stderr}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode:
                sys.exit(f"{name} failed:\n{r.stderr or r.stdout}")
            runs.append({op: (float(ms), c) for op, ms, c in (l.split("\t") for l in r.stdout.splitlines() if l.count("\t") == 2)})
            result = runs[-1]
            missing = [op for op in runs[0] if op not in result or any(value is None for value in result[op])]
            if not result or missing:
                sys.exit(f"{name} repetition {len(runs)}: missing timing or checksum for {missing or 'all operations'}: {result}")
            if {op: value[1:] for op, value in result.items()} != {op: value[1:] for op, value in runs[0].items()}:
                sys.exit(f"{name} repetition {len(runs)}: checksum mismatch: {result} != {runs[0]}")
        for op in runs[0]:
            if runs[0][op][1] != want[op]:
                sys.exit(f"{name} {op}: checksum {runs[0][op][1]} != {want[op]}")
        table[name] = {op: statistics.median(x[op][0] for x in runs) for op in runs[0]}
        print(f"ran {name}", file=sys.stderr)

    print("| variant | huffman ms | huffman MB/s | fields ms |")
    print("|---|---:|---:|---:|")
    for name, t in table.items():
        h, f = t.get("huffman"), t.get("fields")
        print(f"| {name} | {h:,.2f} | {PLAIN / 1e3 / h:,.0f} | {f'{f:,.2f}' if f is not None else '-'} |")


if __name__ == "__main__":
    build_bench() if BUILD else main()
