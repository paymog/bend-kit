#!/usr/bin/env python3
"""Compare every live route with the final prerendered bytes."""

from pathlib import Path
import sys
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def request(url, method="GET"):
    try:
        response = urlopen(Request(url, method=method), timeout=120)
    except HTTPError as error:
        response = error
    with response:
        return response.status, response.headers, response.read()


def check(out, base):
    count = 0
    for file in sorted(Path(out).rglob("*")):
        if not file.is_file() or file.name == ".nojekyll":
            continue
        relative = file.relative_to(out).as_posix()
        paths = ["/" + relative]
        if file.name == "index.html":
            directory = "/" + relative.removesuffix("index.html")
            paths = [directory]
            if directory != "/":
                paths.append(directory.rstrip("/"))
            if directory.startswith("/playground/"):
                paths.append("/" + relative)
        media = {".html": "text/html", ".css": "text/css", ".js": "text/javascript", ".md": "text/markdown", ".txt": "text/plain"}[file.suffix]
        expected = file.read_bytes()
        for path in paths:
            status, headers, body = request(base.rstrip("/") + path)
            assert status == 200, (path, status)
            assert body == expected, (path, "body differs", len(body), len(expected))
            assert headers.get_content_type() == media, (path, headers)
            assert headers["cache-control"] == "public, max-age=300", (path, headers)
            status, head, body = request(base.rstrip("/") + path, "HEAD")
            assert status == 200 and body == b"", (path, status, "HEAD body")
            assert int(head["content-length"]) == len(expected), (path, head)
            count += 1
    for path in ("/missing", "/packages/missing", "/packages/missing/README.md", "/playground/missing.js", "/playground/../README.md", "/.env", "/site/app.bend"):
        status, _, _ = request(base.rstrip("/") + path)
        assert status == 404, (path, status)
    status, _, _ = request(base.rstrip("/") + "/", "POST")
    assert status == 405, status
    print(f"site: {count} routes match prerendered bytes, media types, caching, and HEAD; missing routes stay private")


if __name__ == "__main__":
    check(*sys.argv[1:])
