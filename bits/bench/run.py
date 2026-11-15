#!/usr/bin/env python3
"""Write the payload, build and run the bits benchmark; print a markdown table. See README.md."""
import os, statistics, subprocess, sys, zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
PLAIN = int(sys.argv[2]) if len(sys.argv) > 2 else 1_048_576
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
    main()
