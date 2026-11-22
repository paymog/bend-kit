#!/usr/bin/env python3
"""Run the CommonMark 0.31.2 spec examples against markdown.bend in a native build.

python3 conformance.py            # pass count per section
python3 conformance.py Links      # also print the failures in one section
python3 conformance.py --safe     # to_html_safe against cmark without --unsafe (needs cmark on PATH)
python3 conformance.py --gfm      # GFM 0.29 extension examples: tables, task lists, strikethrough, autolinks, tag filter
python3 conformance.py --gfm-diff # CommonMark and GFM corpus against cmark-gfm (needs cmark-gfm on PATH)
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
VERSION_DIFFERENCES = {
    28: '<p>&amp;nbsp &amp;x; &amp;#; &amp;#x;\n�\n&amp;#abcdef0;\n&amp;ThisIsNotDefined; &amp;hi?;</p>\n',
    354: '<p>*$*alpha.</p>\n<p><em>£</em>bravo.</p>\n<p><em>€</em>charlie.</p>\n',
}
END = "\x01END\x01"


def gfm_cases():
    src = urllib.request.urlopen(GFM).read().decode()
    pat = re.compile(r"^`{32} example (\w+)\n(.*?)^\.\n(.*?)^`{32}$", re.M | re.S)
    return [{"section": m.group(1), "example": i, "markdown": m.group(2).replace("\u2192", "\t"), "html": m.group(3).replace("\u2192", "\t")}
            for i, m in enumerate(pat.finditer(src), 1)]


def differential_cases():
    commonmark, gfm = json.load(urllib.request.urlopen(SPEC)), gfm_cases()
    cases = commonmark + gfm
    corpus = []
    for prefix in ("", "x:", "!", "/", "(", "*", "_", "~", "[", "é", "a", "X", "1"):
        for text in ("a@b.co", "www.x.org", "http://x.org", "https://x.org/a_(b)", "ftp://x.org", "HTTP://x.org", "Https://x.org", "FTP://x.org"):
            corpus.append(prefix + text + "\n")
    for text in ("www.x.org", "a@b.co", "http://x.org", "~x~", "~~x~~"):
        corpus.extend((f"[{text}](/y)\n", f"![{text}](/y)\n", f"`{text}`\n"))
    for row in ("- | -", "* | x", "1. | x", "> x | y", "# x | y", "---", "--", "=", "===", "-", "    x | y", "[x]: /url", "```", "<div>", "", "x", "x | y | z"):
        corpus.extend((f"a | b\n--- | ---\n{row}\nlast | row\n", f"> a | b\n> --- | ---\n> {row}\n"))
    for marker in ("-", "*", "1."):
        for box in ("[ ]", "[x]", "[X]", "[a]"):
            for tail in (" text", "", "\ttext", "\n\n  paragraph"):
                corpus.append(f"{marker} {box}{tail}\n")
    for text in ("~x~", "~~x~~", "~~~x~~~", "~a **b** c~", "~~a\nb~~", "~~a\n\nb~~", "a~b~c"):
        corpus.extend((text + "\n", f"[{text}](/x)\n"))
    corpus.extend(s + "\n" for s in (
        "mailto:a@b.co", "xmpp:a@b.co", "xmpp:a@b.co/resource",
        "&#97;b@c.co", r"a\.b_c@d.co", "*a@b.co*", "_a@b.co_",
        "[&#97;b@c.co](/y)", "a@b@c.co"))
    print(f"Corpus: {len(commonmark)} CommonMark 0.31.2; {len(gfm)} GFM 0.29.0.gfm.13; {len(corpus)} generated", flush=True)
    return cases + [{"section": "GFM corpus", "example": f"corpus-{i}", "markdown": s}
                    for i, s in enumerate(corpus, 1)]


def lit(s):
    return '"' + "".join(f"\\u{{{ord(c):X}}}" for c in s) + '"'


HEAD = """import Base
import ../markdown.bend as M

"""


def main():
    args = sys.argv[1:]
    safe = "--safe" in args
    diff = "--gfm-diff" in args
    gfm = "--gfm" in args or diff
    args = [a for a in args if a not in ("--safe", "--gfm", "--gfm-diff")]
    show = args[0] if args else None
    OUT.mkdir(exist_ok=True)
    cases = differential_cases() if diff else gfm_cases() if gfm else json.load(urllib.request.urlopen(SPEC))
    if diff or safe:
        command = ["cmark-gfm", "--unsafe", "-e", "table", "-e", "strikethrough", "-e", "autolink", "-e", "tasklist", "-e", "tagfilter"] if diff else ["cmark"]
        print(subprocess.run([command[0], "--version"], capture_output=True, text=True, check=True).stdout.strip(), flush=True)
        for t in cases:
            t["spec_html"] = t.get("html")
            t["html"] = subprocess.run(command, input=t["markdown"].encode(), capture_output=True, check=True).stdout.decode()
            if diff:
                t["html"] = t["html"].replace('<input type="checkbox" disabled="" />', '<input disabled="" type="checkbox">').replace('<input type="checkbox" checked="" disabled="" />', '<input checked="" disabled="" type="checkbox">')
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
    if len(got) != len(cases) + 1 or got[-1]:
        raise RuntimeError(f"Expected {len(cases)} renderer results, got {len(got) - 1}")
    total, ok, explained = Counter(), Counter(), 0
    for t, g in zip(cases, got):
        total[t["section"]] += 1
        if g == t["html"]:
            ok[t["section"]] += 1
        elif diff and t["section"] in ("Entity and numeric character references", "Emphasis and strong emphasis") and t["html"] == VERSION_DIFFERENCES.get(t["example"]) and g == t["spec_html"]:
            explained += 1
            print(f"VERSION {t['example']}: CommonMark 0.31.2 differs from cmark-gfm's 0.29 base")
        elif show and (show == "all" or t["section"] == show):
            print(f"FAIL {t['example']}\n  md   {t['markdown']!r}\n  want {t['html']!r}\n  got  {g!r}")
    for s in total:
        print(f"{ok[s]:4}/{total[s]:<4} {s}")
    print(f"{sum(ok.values())}/{len(cases)} pass; {explained} explained version differences")
    return int(sum(ok.values()) + explained != len(cases))


if __name__ == "__main__":
    sys.exit(main())
