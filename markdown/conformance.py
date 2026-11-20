#!/usr/bin/env python3
"""Run the CommonMark 0.31.2 spec examples against markdown.bend in a native build.

python3 conformance.py            # pass count per section
python3 conformance.py Links      # also print the failures in one section
python3 conformance.py --safe     # to_html_safe against cmark without --unsafe (needs cmark on PATH)
python3 conformance.py --gfm      # GFM 0.29 extension examples: tables, task lists, strikethrough, autolinks, tag filter
"""
import json
import re
import os
import subprocess
import sys
import urllib.request
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
SPEC = "https://spec.commonmark.org/0.31.2/spec.json"
GFM = "https://raw.githubusercontent.com/github/cmark-gfm/0.29.0.gfm.13/test/spec.txt"
END = "\x01END\x01"


def gfm_cases():
    src = urllib.request.urlopen(GFM).read().decode()
    pat = re.compile(r"^`{32} example (\w+)\n(.*?)^\.\n(.*?)^`{32}$", re.M | re.S)
    return [{"section": m.group(1), "example": i, "markdown": m.group(2).replace("\u2192", "\t"), "html": m.group(3).replace("\u2192", "\t")}
            for i, m in enumerate(pat.finditer(src), 1)]


def lit(s):
    return '"' + "".join(f"\\u{{{ord(c):X}}}" for c in s) + '"'


HEAD = """import Base
import ../markdown.bend as M

"""


def main():
    args = sys.argv[1:]
    safe = "--safe" in args
    gfm = "--gfm" in args
    args = [a for a in args if a not in ("--safe", "--gfm")]
    show = args[0] if args else None
    OUT.mkdir(exist_ok=True)
    cases = gfm_cases() if gfm else json.load(urllib.request.urlopen(SPEC))
    if safe:
        for t in cases:
            t["html"] = subprocess.run(["cmark"], input=t["markdown"].encode(), capture_output=True, check=True).stdout.decode()
    fn = "M.to_html_safe(" if safe else "M.to_html("
    if gfm:
        fn = "M.to_html_with(M.Opts{False{}, True{}}, "
        show = show or "all"
    body = "".join(f"def c{i}() -> String:\n  {fn}{lit(t['markdown'])})\n\n" for i, t in enumerate(cases))
    main = "def main() -> IO(Unit):\n  do IO<Unit>:\n" + "".join(f"    IO.print(c{i}() ++ {lit(END)})\n" for i in range(len(cases)))
    (OUT / "conformance.bend").write_text(HEAD + body + main)
    env = {**os.environ, "BEND_NO_TELEMETRY": "1"}
    subprocess.run(["bend", "conformance.bend", "-o", "conformance"], cwd=OUT, env=env, check=True)
    got = subprocess.run([OUT / "conformance"], capture_output=True, check=True).stdout.decode().split(END + "\n")
    total, ok = Counter(), Counter()
    for t, g in zip(cases, got):
        total[t["section"]] += 1
        if g == t["html"]:
            ok[t["section"]] += 1
        elif show and (show == "all" or t["section"] == show):
            print(f"FAIL {t['example']}\n  md   {t['markdown']!r}\n  want {t['html']!r}\n  got  {g!r}")
    for s in total:
        print(f"{ok[s]:4}/{total[s]:<4} {s}")
    print(f"{sum(ok.values())}/{len(cases)} pass")


if __name__ == "__main__":
    main()
