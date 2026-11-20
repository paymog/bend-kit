"""Mustache render benchmark: chevron (see README.md)."""
import time

import chevron

N, R = 200, 100
SRC = '<ul>\n{{#items}}\n  <li><a href="{{url}}">{{name}}</a>{{#tags}} [{{.}}]{{/tags}}</li>\n{{/items}}\n</ul>\n'


def fnv(s, h=2166136261):
    for b in s.encode():
        h = ((h ^ b) * 16777619) & 0xFFFFFFFF
    return h


items = [{"name": f"Item {i} & co", "url": f'/items/{i}?a=1&b="2"', "tags": ["new", "<hot>"] if i % 2 == 0 else []} for i in range(N)]
ctx = {"items": items}
chk = fnv(chevron.render(SRC, ctx))
t0 = time.perf_counter()
total = sum(len(chevron.render(SRC, ctx)) for _ in range(R))
ms = (time.perf_counter() - t0) * 1000
print(f"render\t{ms:.3f}\t{chk}")
print(f"len\trender\t{total}")
