#!/usr/bin/env python3
"""Run the Mustache spec (interpolation, sections, inverted, comments) against template.bend in a native build."""
import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
SPEC = "https://raw.githubusercontent.com/mustache/spec/v1.4.2/specs/{}.json"
FILES = ["interpolation", "sections", "inverted", "comments"]
END = "\x01END\x01"


def lit(s):
    return '"' + "".join(f"\\u{{{ord(c):X}}}" for c in s) + '"'


def num(x):
    return str(x) if isinstance(x, int) else repr(x)


def val(v):
    if isinstance(v, bool):
        return f"T.VBool{{{'True' if v else 'False'}{{}}}}"
    if isinstance(v, (int, float)):
        return f"T.VStr{{{lit(num(v))}}}"
    if isinstance(v, str):
        return f"T.VStr{{{lit(v)}}}"
    if isinstance(v, list):
        return "T.VList{[" + ", ".join(val(x) for x in v if x is not None) + "]}"
    return f"T.VMap{{{obj(v)}}}"


def obj(d):
    m = "Map.new(&2, T.Value)"
    for k, v in d.items():
        if v is not None:
            m = f"Map.set(&2, T.Value, {m}, {lit(k)}, {val(v)})"
    return m


def skip(t):
    return "partials" in t or "{{=" in t["template"] or not isinstance(t["data"], dict)


HEAD = """import Base
import ../template.bend as T

def out(r: Result<&2, &2, String, String>) -> String:
  match r:
    case Fail{m}:
      "FAIL " ++ m
    case Done{s}:
      s

"""


def main():
    OUT.mkdir(exist_ok=True)
    cases = []
    for f in FILES:
        for t in json.load(urllib.request.urlopen(SPEC.format(f)))["tests"]:
            if not skip(t):
                cases.append((f, t))
    body = "".join(f"def c{i}() -> String:\n  out(T.render_text({lit(t['template'])}, {obj(t['data'])}))\n\n" for i, (_, t) in enumerate(cases))
    main = "def main() -> IO(Unit):\n  do IO<Unit>:\n" + "".join(f"    IO.print(c{i}() ++ {lit(END)})\n" for i in range(len(cases)))
    (OUT / "conformance.bend").write_text(HEAD + body + main)
    env = {**os.environ, "BEND_NO_TELEMETRY": "1"}
    subprocess.run(["bend", "conformance.bend", "-o", "conformance"], cwd=OUT, env=env, check=True)
    got = subprocess.run([OUT / "conformance"], capture_output=True, check=True).stdout.decode().split(END + "\n")
    fails = 0
    for (f, t), g in zip(cases, got):
        if g != t["expected"]:
            fails += 1
            print(f"FAIL {f}: {t['name']}\n  want {t['expected']!r}\n  got  {g!r}")
    print(f"{len(cases) - fails}/{len(cases)} pass")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
