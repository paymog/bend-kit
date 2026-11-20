"""Text benchmark: difflib, rapidfuzz, and textwrap (see README.md)."""
import difflib, sys, textwrap, time
from rapidfuzz.distance import Levenshtein


def lcg(x):
    return (x * 1103515245 + 12345) & 0xFFFFFFFF & 0x7FFFFFFF


def word(x, base=97):
    x = lcg(x)
    n = 4 + (x >> 16) % 9
    out = []
    for _ in range(n):
        x = lcg(x)
        out.append(chr(base + (x >> 16) % 26))
    return "".join(out), x


def lines(n):
    a = [f"line {i}" for i in range(n)]
    b = []
    for i in range(n):
        if i % 50 == 7:
            b.append(f"changed {i}")
        elif i % 70 != 11:
            b.append(f"line {i}")
        if i % 90 == 13:
            b.append(f"added {i}")
    return a, b


def report(op, t0, chk):
    print(f"{op}\t{(time.perf_counter() - t0) * 1000:.3f}\t{chk}")


def main():
    s = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    a, b = lines(s * 10000)
    t0 = time.perf_counter()
    ops = difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes()
    report("diff", t0, sum((i2 - i1) + (j2 - j1) for tag, i1, i2, j1, j2 in ops if tag != "equal"))

    t0 = time.perf_counter()
    acc, x = 0, 1
    for _ in range(s * 20000):
        w1, x = word(x)
        w2, x = word(x)
        acc += Levenshtein.distance(w1, w2)
    report("distance", t0, acc & 0xFFFFFFFF)

    ws, x = [], 1
    for _ in range(s * 20000):
        w, x = word(x)
        ws.append(w)
    text = " ".join(ws)
    t0 = time.perf_counter()
    ls = textwrap.wrap(text, 72)
    report("wrap", t0, f"{len(ls)}:{sum(map(len, ls))}")

    ws, x = [], 1
    for _ in range(s * 20000):
        w, x = word(x, 1072)
        ws.append(w)
    text = " ".join(ws)
    t0 = time.perf_counter()
    ls = textwrap.wrap(text, 72)
    report("wrap_utf", t0, f"{len(ls)}:{sum(map(len, ls))}")


main()
