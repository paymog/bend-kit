"""CommonMark render benchmark: markdown-it-py (see README.md)."""
import time

from markdown_it import MarkdownIt

N, R = 100, 10


def section(i):
    return (
        f"## Section {i}\n\nSome *emphasis*, **strong**, `code <tag>`, and a [link](https://example.com/{i}?a=1&b=2 \"title {i}\").\n"
        "Text with &amp; entities &lt; and <span class=\"x\">inline html</span>.\n\n"
        f"- item one\n- item two with `code`\n  - nested *item* {i}\n\n1. first\n2. second\n\n"
        f"> A quote with **bold** text\n> across lines.\n\n```python\ndef f(x):\n    return x < {i}\n```\n\n---\n\n"
    )


def fnv(s, h=2166136261):
    for b in s.encode():
        h = ((h ^ b) * 16777619) & 0xFFFFFFFF
    return h


doc = "".join(section(i) for i in range(N))
md = MarkdownIt("commonmark")
chk = fnv(md.render(doc))
t0 = time.perf_counter()
total = sum(len(md.render(doc)) for _ in range(R))
ms = (time.perf_counter() - t0) * 1000
print(f"render\t{ms:.3f}\t{chk}")
print(f"len\trender\t{total}")
