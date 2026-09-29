"""tty width/pad_right benchmark: the Python side (see README.md)."""
import sys, time, unicodedata

N = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
COLS = 20
M = 0xFFFFFFFF
# class -> (first code point, span); classes 0..2 are ASCII so it is a third of the draws.
CLASSES = [(0x21, 94)] * 3 + [(0x3B1, 25), (0x4E00, 512), (0xAC00, 512), (0x3041, 86), (0x300, 52), (0xFF01, 94)]


def gen(n):
    s, out = 1, []
    for _ in range(n):
        s = (s * 1664525 + 1013904223) & M
        k = 1 + (s >> 16) % 16
        cs = []
        for _ in range(k):
            s = (s * 1664525 + 1013904223) & M
            v = s >> 8
            base, span = CLASSES[v % 9]
            cs.append(chr(base + (v // 9) % span))
        out.append("".join(cs))
    return out


def width(s):
    w = 0
    for c in s:
        if unicodedata.combining(c):
            continue
        w += 2 if unicodedata.east_asian_width(c) in "WF" else 1
    return w


def pad_right(s, cols):
    return s + " " * (cols - width(s))


def main():
    xs = gen(N)
    t0 = time.perf_counter_ns()
    total = sum(width(s) for s in xs)
    t1 = time.perf_counter_ns()
    print(f"chk\twidth\t{total}")
    print(f"ms\twidth\t{(t1 - t0) / 1e6:.3f}")
    t0 = time.perf_counter_ns()
    h, n = 2166136261, 0
    for s in xs:
        for c in pad_right(s, COLS) + "\n":
            h = ((h ^ ord(c)) * 16777619) & M
            n += 1
    t1 = time.perf_counter_ns()
    print(f"chk\tpad\t{h}")
    print(f"chk\tpadlen\t{n}")
    print(f"ms\tpad\t{(t1 - t0) / 1e6:.3f}")


main()
