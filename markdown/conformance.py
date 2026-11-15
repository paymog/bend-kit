#!/usr/bin/env python3
"""Run the CommonMark 0.31.2 spec examples against markdown.bend in a native build.

python3 conformance.py            # pass count per section
python3 conformance.py Links      # also print the failures in one section
"""
import json
import os
import subprocess
import sys
import urllib.request
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
SPEC = "https://spec.commonmark.org/0.31.2/spec.json"
END = "\x01END\x01"


def lit(s):
    return '"' + "".join(f"\\u{{{ord(c):X}}}" for c in s) + '"'


HEAD = """import Base
import ../markdown.bend as M

"""


def main():
    show = sys.argv[1] if len(sys.argv) > 1 else None
    OUT.mkdir(exist_ok=True)
    cases = json.load(urllib.request.urlopen(SPEC))
    body = "".join(f"def c{i}() -> String:\n  M.to_html({lit(t['markdown'])})\n\n" for i, t in enumerate(cases))
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
        elif show and t["section"] == show:
            print(f"FAIL {t['example']}\n  md   {t['markdown']!r}\n  want {t['html']!r}\n  got  {g!r}")
    for s in total:
        print(f"{ok[s]:4}/{total[s]:<4} {s}")
    print(f"{sum(ok.values())}/{len(cases)} pass")


if __name__ == "__main__":
    main()
