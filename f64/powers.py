#!/usr/bin/env python3
"""Generate powers.bend with exact rational arithmetic, or check it with --check."""
from fractions import Fraction
from pathlib import Path
import sys


def generate():
    rows = []
    for k in range(-350, 351):
        x = Fraction(10**k) if k >= 0 else Fraction(1, 10**-k)
        b = x.numerator.bit_length() - x.denominator.bit_length()
        two_b = Fraction(2**b) if b >= 0 else Fraction(1, 2**-b)
        if x < two_b:
            b -= 1
        shift = 127 - b
        y = x * (Fraction(2**shift) if shift >= 0 else Fraction(1, 2**-shift))
        c = y.numerator // y.denominator
        assert 2**127 <= c < 2**128
        assert c <= y < c + 1
        limbs = [(c >> s) & 0xFFFFFFFF for s in (96, 64, 32, 0)]
        rows.append((limbs, b - 127 + 2048, y.denominator == 1))
    text = """# Normalized lower bounds for 10^(index - 350), with exactness flags.
import Base

type Power is Data:
  Power{a: U32, b: U32, c: U32, d: U32, exp: U32, exact: Bool}

"""
    chunks = (len(rows) + 15) // 16
    for chunk in range(chunks):
        entries = rows[chunk * 16:(chunk + 1) * 16]
        text += f"def chunk{chunk}(n: U32) -> Power:\n  match n:\n"
        for j, (limbs, exp, exact) in enumerate(entries):
            pattern = str(j) if j < len(entries) - 1 else "_"
            fields = ", ".join(map(str, limbs))
            flag = "True{}" if exact else "False{}"
            text += f"    case {pattern}:\n      Power{{{fields}, {exp}, {flag}}}\n"
        text += "\n"
    text += "def select(chunk: U32, index: U32) -> Power:\n  match chunk:\n"
    for chunk in range(chunks):
        pattern = str(chunk) if chunk < chunks - 1 else "_"
        text += f"    case {pattern}:\n      chunk{chunk}((index .&. 15 : U32))\n"
    text += "\ndef get(+index: U32) -> Power:\n  select((index >> 4n : U32), index)\n"
    return text


if __name__ == "__main__":
    text = generate()
    if sys.argv[1:] == ["--check"]:
        assert Path(__file__).with_suffix(".bend").read_text() == text
        print("701 cached powers match exact rational bounds")
    elif sys.argv[1:]:
        sys.exit("usage: powers.py [--check]")
    else:
        print(text, end="")
