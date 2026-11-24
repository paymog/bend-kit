#!/usr/bin/env python3
"""Write the inputs, build and run the zlib benchmark; print a markdown table. See README.md."""
import gzip, os, statistics, subprocess, sys, zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
PLAIN = int(sys.argv[2]) if len(sys.argv) > 2 else 4_194_304
OPS = ("inflate", "deflate")
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1"}

VARIANTS = {
    "Bun": (None, ["bun", "bench.ts"]),
    "Node": (None, ["node", "--no-warnings", "bench.ts"]),
    "Python": (None, ["python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
    "Bend (libz)": (["bend", "native.bend", "-o", OUT / "native"], [OUT / "native"]),
}

# ~247 ASCII words; 1024 LCG-built sentences give gzip level-6 ratio near 4:1.
_VOCAB = tuple(
    sorted(
        set(
            (
                "the be to of and a in that have I it for not on with he as you do at this but his by from "
                "they we say her she or an will my one all would there their what so up out if about who get "
                "which go me when make can like time no just him know take people into year your good some "
                "could them see other than then now look only come its over think also back after use two how "
                "our work first well way even new want because any these give day most us is was are been has "
                "had were said each which she do how their if will up other about out many then them these so "
                "some her would make like into him time has two more go no way could my than first been call "
                "who oil sit now find long down day did get come made may part over new sound take only little "
                "work know place year live me back give most very after thing our just name good sentence man "
                "think say great where help through much before line right too mean old any same tell boy follow "
                "came want show also around form three small set put end does another well large must big even "
                "such because turn here why ask went men read need land different home us move try kind hand "
                "picture again change off play spell air away animal house point page letter mother answer found "
                "study still learn should America world high every near add food between own below country plant "
                "last school father keep tree never start city earth eye light thought head under story saw left "
                "dont few while along might close something seem next hard open example begin life always those "
                "both paper together got group often run"
            ).split()
        )
    )
)


def _lcg(x: int) -> int:
    return (x * 1664525 + 1013904223) & 0xFFFFFFFF


def _sentences(count: int, seed0: int) -> tuple[bytes, ...]:
    seed = seed0
    out = []
    for _ in range(count):
        parts = []
        nwords = 6 + (seed & 11)
        seed = _lcg(seed)
        for _ in range(nwords):
            seed = _lcg(seed)
            parts.append(_VOCAB[seed % len(_VOCAB)])
        out.append((" ".join(parts) + ".").encode("ascii"))
    return tuple(out)


_SENTS = _sentences(1024, 0xDEADBEEF)


def plain_bytes(n: int) -> bytes:
    """Text-like ASCII: LCG sentences, newlines, and ~3% raw LCG bytes."""
    seed = 0xC0FFEE01
    buf = bytearray()
    while len(buf) < n:
        seed = _lcg(seed)
        r = seed
        low = r & 0xFF
        if low < 8:
            buf.append(low)
            continue
        if low < 12:
            buf.extend(b"\n")
            continue
        sent = _SENTS[(r >> 8) % len(_SENTS)]
        if buf and buf[-1] not in (10,):
            buf.append(32)
        for b in sent:
            if len(buf) >= n:
                break
            buf.append(b)
    return bytes(buf)


def mbps(n: int, ms: float) -> float:
    return (n / 1_000_000) / (ms / 1000.0) if ms else float("inf")


def first_header_bits(gz: bytes) -> int:
    """Count the first block header, including its code-length runs."""
    data, pos = gz[10:-8], 0

    def read(n):
        nonlocal pos
        value = sum(((data[(pos + i) // 8] >> ((pos + i) % 8)) & 1) << i for i in range(n))
        pos += n
        return value

    read(1)
    kind = read(2)
    if kind == 1:
        return pos
    if kind != 2:
        raise ValueError(f"expected a Huffman block, got {kind}")
    nl, nd, nc = read(5) + 257, read(5) + 1, read(4) + 4
    order = (16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15)
    lens = [0] * 19
    for s in order[:nc]:
        lens[s] = read(3)
    codes, code = {}, 0
    for width in range(1, 8):
        for s, length in enumerate(lens):
            if length == width:
                codes[width, code] = s
                code += 1
        code <<= 1
    lengths = []
    while len(lengths) < nl + nd:
        code = 0
        for width in range(1, 8):
            code = (code << 1) | read(1)
            s = codes.get((width, code))
            if s is not None:
                break
        else:
            raise ValueError("invalid code-length symbol")
        if s < 16:
            lengths.append(s)
        elif s == 16:
            lengths.extend([lengths[-1]] * (read(2) + 3))
        else:
            lengths.extend([0] * (read(3 if s == 17 else 7) + (3 if s == 17 else 11)))
    if len(lengths) != nl + nd:
        raise ValueError("code-length run exceeds the header")
    return pos


def main():
    OUT.mkdir(exist_ok=True)
    plain = plain_bytes(PLAIN)
    (OUT / "plain.bin").write_bytes(plain)
    gz = gzip.compress(plain, compresslevel=6, mtime=0)
    (OUT / "payload.gz").write_bytes(gz)
    ratio = len(plain) / len(gz)
    print(
        f"plain {PLAIN:,} bytes, gzip {len(gz):,} bytes, ratio {ratio:.2f}x",
        file=sys.stderr,
    )

    table, checks, sizes = {}, {}, {}
    for name, (build, run) in VARIANTS.items():
        if build and subprocess.run(build, cwd=HERE, env=ENV, capture_output=True).returncode != 0:
            err = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            sys.exit(f"build failed: {name}\n{err.stderr}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed:\n{r.stderr or r.stdout}")
            lines = [l for l in r.stdout.splitlines() if len(l.split("\t")) == 3]
            runs.append({op: (float(ms), c) for op, ms, c in (l.split("\t") for l in lines)})
            result = runs[-1]
            missing = [op for op in OPS if op not in result or any(value is None for value in result[op])]
            if not result or missing:
                sys.exit(f"{name} repetition {len(runs)}: missing timing or checksum for {missing or 'all operations'}: {result}")
            if {op: value[1:] for op, value in result.items()} != {op: value[1:] for op, value in runs[0].items()}:
                sys.exit(f"{name} repetition {len(runs)}: checksum mismatch: {result} != {runs[0]}")
        table[name] = {op: statistics.median(x[op][0] for x in runs) for op in OPS}
        checks[name] = {op: runs[0][op][1] for op in OPS}
        sizes[name] = int(runs[0]["size"][1])
        print(f"ran {name}", file=sys.stderr)

    for op in OPS:
        seen = {checks[n][op] for n in checks}
        if len(seen) != 1:
            sys.exit(f"checksum mismatch in {op}: {[(n, checks[n][op]) for n in checks]}")
        print(f"{op} checksum {seen.pop()}", file=sys.stderr)

    # Bend's gzip output must decode with the system gzip, byte for byte.
    for f in ("bend.gz", "native.gz"):
        ungz = subprocess.run(["gzip", "-dc", OUT / f], capture_output=True, check=True).stdout
        if ungz != plain:
            sys.exit(f"gzip -d of out/{f} does not match the plain text")
        print(f"gzip -d out/{f} ok, crc32 {zlib.crc32(ungz)}", file=sys.stderr)
        if f == "bend.gz":
            print(f"first Bend block header: {first_header_bits((OUT / f).read_bytes())} bits", file=sys.stderr)

    names = list(table)
    print("| variant | inflate ms | inflate MB/s | deflate ms | deflate MB/s | gzip bytes | ratio |")
    print("|---:|---:|---:|---:|---:|---:|---:|")
    for n in names:
        i, d = table[n]["inflate"], table[n]["deflate"]
        print(
            f"| {n} | {i:,.1f} | {mbps(PLAIN, i):,.0f} | {d:,.1f} | {mbps(PLAIN, d):,.0f} | "
            f"{sizes[n]:,} | {PLAIN / sizes[n]:.2f}x |"
        )


if __name__ == "__main__":
    main()
