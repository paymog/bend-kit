#!/usr/bin/env python3
"""Run the Mustache spec (interpolation, sections, inverted, comments, delimiters, partials) against template.bend in a native build."""
import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
SPEC = "https://raw.githubusercontent.com/mustache/spec/v1.4.2/specs/{}.json"
FILES = ["interpolation", "sections", "inverted", "comments", "delimiters", "partials"]
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
    return not isinstance(t["data"], dict)


def parts(ps):
    m = "Map.new(&2, List<&2, T.Node>)"
    for k, v in ps.items():
        m = f"Map.set(&2, List<&2, T.Node>, {m}, {lit(k)}, nodes(T.parse({lit(v)})))"
    return m


HEAD = """import Base
import ../template.bend as T
import bend-kit-encoding@0.5.0.3/encoding.bend as E

def same(+text: String, +packed: String) -> String:
  T.when(String, String.eq(text, packed), u => text, u => "PACKED MISMATCH " ++ packed)

def nodes(r: Result<&2, &2, String, List<&2, T.Node>>) -> List<&2, T.Node>:
  match r:
    case Fail{m}:
      [T.NText{"PARTIAL FAIL " ++ m}]
    case Done{n}:
      n

def out(r: Result<&2, &2, String, List<&2, T.Node>>, +ctx: Map<&2, T.Value>, +ps: Map<&2, List<&2, T.Node>>) -> String:
  match r:
    case Fail{m}:
      "FAIL " ++ m
    case Done{+n}:
      same(T.render_with(n, ctx, ps), E.utf8.decode(T.render_bytes_with(n, ctx, ps)))

"""


def load_cases():
    cases = []
    for f in FILES:
        for t in json.load(urllib.request.urlopen(SPEC.format(f)))["tests"]:
            if not skip(t):
                cases.append((f, t))
    cases.append(("unicode", {
        "name": "UTF-8 variables and indented partials",
        "template": "{{v}}\n  {{>p}}\n{{{v}}}",
        "data": {"v": "é猫😀 & <"},
        "partials": {"p": "猫\n{{v}}\n😀\n"},
        "expected": "é猫😀 &amp; &lt;\n  猫\n  é猫😀 &amp; &lt;\n  😀\né猫😀 & <",
    }))
    cases.append(("unicode", {
        "name": "UTF-8 empty partial and trailing whitespace",
        "template": "é\n  {{>empty}}\n😀{{>p}}猫",
        "data": {},
        "partials": {"empty": "", "p": "é\n"},
        "expected": "é\n😀é\n猫",
    }))
    for name, outer, inner, value in [
        ("Unicode", "  ", "  ", "é猫😀 & <"),
        ("tabs", "\t", "\t ", "é猫😀 & <"),
        ("variable newlines", "  ", "\t", "é\n猫😀 & <"),
    ]:
        cases.append(("nested-partials", {
            "name": name,
            "template": "{{v}}\n" + outer + "{{>p}}\n{{{v}}}",
            "data": {"v": value},
            "partials": {"p": "猫\n{{v}}\n" + inner + "{{>q}}\n", "q": "😀\n{{{v}}}\n"},
            "expected": value.replace("&", "&amp;").replace("<", "&lt;") + "\n"
                + outer + "猫\n" + outer + value.replace("&", "&amp;").replace("<", "&lt;") + "\n"
                + outer + inner + "😀\n" + outer + inner + value + "\n" + value,
        }))
    for name, partial, expected in [
        ("empty blank line", "😀\n\n{{{v}}}\n", "  猫\n    😀\n\n    é\n猫\n"),
        ("leading blank line", "\n😀\n", "  猫\n\n    😀\n"),
        ("whitespace-only line", "😀\n  \n猫\n", "  猫\n    😀\n      \n    猫\n"),
        ("empty nested partial", "", "  猫\n"),
        ("third nesting level", "{{>r}}\n", "  猫\n    😀\n"),
    ]:
        cases.append(("nested-partials", {
            "name": name,
            "template": "  {{>p}}\n",
            "data": {"v": "é\n猫"},
            "partials": {"p": "猫\n  {{>q}}\n", "q": partial, "r": "😀\n"},
            "expected": expected,
        }))
    cases.append(("nested-partials", {
        "name": "resume parent after nested partial",
        "template": "  {{>p}}\n",
        "data": {},
        "partials": {"p": "猫\n  {{>q}}\n後\n", "q": "😀\n"},
        "expected": "  猫\n    😀\n  後\n",
    }))
    cases.append(("nested-partials", {
        "name": "recursive partial depth limit",
        "template": "  {{>p}}\n",
        "data": {},
        "partials": {"p": "猫\n{{>p}}\n"},
        "expected": "  猫\n" * 64,
    }))
    return cases


def main():
    OUT.mkdir(exist_ok=True)
    cases = load_cases()
    body = "".join(f"def c{i}() -> String:\n  out(T.parse({lit(t['template'])}), {obj(t['data'])}, {parts(t.get('partials', {}))})\n\n" for i, (_, t) in enumerate(cases))
    main = "def main() -> IO(Unit):\n  do IO<Unit>:\n" + "".join(f"    IO.print(c{i}() ++ {lit(END)})\n" for i in range(len(cases)))
    (OUT / "conformance.bend").write_text(HEAD + body + main)
    env = {**os.environ, "BEND_NO_TELEMETRY": "1"}
    subprocess.run(["bend", "conformance.bend", "-o", "conformance"], cwd=OUT, env=env, check=True)
    got = subprocess.run([OUT / "conformance"], capture_output=True, check=True).stdout.decode().split(END + "\n")
    if len(got) != len(cases) + 1:
        sys.exit(f"incomplete output: {len(got) - 1}/{len(cases)} cases")
    fails = 0
    for (f, t), g in zip(cases, got):
        if g != t["expected"]:
            fails += 1
            print(f"FAIL {f}: {t['name']}\n  want {t['expected']!r}\n  got  {g!r}")
    print(f"{len(cases) - fails}/{len(cases)} pass")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
