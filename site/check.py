"""Check documentation output after Camber renders the site."""

from html import unescape
from pathlib import Path
import re
import sys


out, base = sys.argv[1:]
base = base.rstrip("/")
pages = {
    "getting-started": ("Getting started", "bend hello.bend --check-only", "2 hi"),
    "changelog": ("Changelog", "Unreleased", "Older changes are in the git history."),
    "roadmap": ("bend-kit roadmap", "Current baseline", "This is a ranked backlog, not a promise."),
}
for route, (title, *content) in pages.items():
    page = Path(out, route, "index.html").read_text()
    assert re.search(r'<h1\b[^>]*>' + re.escape(title) + r'</h1>', page), route
    text = unescape(re.sub(r"<[^>]+>", "", page))
    for value in content:
        assert value in text, (route, value)

for path in Path(out).rglob("index.html"):
    playground = "playground" in path.relative_to(out).parts
    page = path.read_text()
    nav = page.split("<nav>", 1)[1].split("</nav>", 1)[0]
    for route in pages:
        href = "../" + route + "/" if playground else base + "/" + route + "/"
        assert 'href="' + href + '"' in nav, (path, route)

print("site: documentation pages and header links pass")
