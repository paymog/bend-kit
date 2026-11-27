"""Pystache baseline for the fixed Unicode partial workloads."""
import time
import pystache

src = "{{#items}}\n  {{>p}}\n{{/items}}"
for name, n, p in [
    ("large", 16, "猫😀 {{v}}\n\n{{{v}}}\n" * 128),
    ("nested", 200, "猫\n{{v}}\n\n  {{>q}}\n"),
]:
    ctx = {"v": "é猫😀 & <", "items": [{"x": True} for _ in range(n)]}
    renderer = pystache.Renderer(partials={"p": p, "q": "😀\n\n{{{v}}}\n"})
    parsed = pystache.parse(src)
    def render():
        return renderer.render(parsed, ctx).encode("utf-8")
    h = 2166136261
    for b in render():
        h = ((h ^ b) * 16777619) & 0xffffffff
    start = time.perf_counter()
    total = sum(len(render()) for _ in range(100))
    print(f"chk\t{name}\t{h}\nlen\t{name}\t{total}\nms\t{name}\t{(time.perf_counter() - start) * 1000}")
