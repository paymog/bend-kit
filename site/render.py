#!/usr/bin/env python3
"""Keep package README navigation on the static site."""

import html
from html.parser import HTMLParser
from pathlib import Path
import re
import sys
import unicodedata
from urllib.parse import urljoin, urlsplit, urlunsplit


REPO = "https://github.com/paymog/bend-kit/blob/main/"


def slug(text):
    return "".join(
        "-" if c.isspace() else c
        for c in text.lower()
        if c.isspace() or c in "-_" or unicodedata.category(c)[0] in "LNM"
    )


class PackagePage(HTMLParser):
    def __init__(self, name, base, packages):
        super().__init__(convert_charrefs=False)
        self.name = name
        self.base = base.rstrip("/")
        self.packages = packages
        self.section = None
        self.heading = None
        self.used = set()
        self.out = []

    def link(self, value, image=False):
        parts = urlsplit(value)
        if parts.scheme or parts.netloc or value.startswith("/"):
            return value
        prefix = "bench-" if self.section == "bench" else ""
        if value.startswith("#"):
            return "#" + prefix + value[1:]
        source = REPO + self.name + ("/bench/" if prefix else "/")
        resolved = urlsplit(urljoin(source, value))
        path = resolved.path.removeprefix("/paymog/bend-kit/blob/main/")
        bits = path.rstrip("/").split("/")
        if not image and bits[0] in self.packages and not resolved.query:
            fragment = "#" + resolved.fragment if resolved.fragment else ""
            if len(bits) == 1 or bits[1:] == ["README.md"]:
                return self.base + "/packages/" + bits[0] + "/" + fragment
            if bits[0] == self.name and bits[1:] == ["bench", "README.md"]:
                return "#bench-" + resolved.fragment if resolved.fragment else "#benchmarks"
        if image:
            return urlunsplit(resolved).replace(
                "https://github.com/paymog/bend-kit/blob/main/",
                "https://raw.githubusercontent.com/paymog/bend-kit/main/", 1
            )
        return urlunsplit(resolved)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "section" and attrs.get("class") in ("readme", "bench"):
            self.section = attrs["class"]
        if self.section:
            for key in ("href", "src"):
                if key in attrs:
                    attrs[key] = self.link(attrs[key], key == "src")
        if re.fullmatch("h[1-6]", tag) and self.section:
            self.heading = (len(self.out), tag, attrs, [])
        if tag == "section" and attrs.get("class") == "bench":
            attrs["id"] = "benchmarks"
            self.used.add("benchmarks")
        self.out.append(self.start(tag, attrs))

    @staticmethod
    def start(tag, attrs):
        return "<" + tag + "".join(
            " " + key + ("" if value is None else '="' + html.escape(value, quote=True) + '"')
            for key, value in attrs.items()
        ) + ">"

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        self.out[-1] = self.out[-1][:-1] + " />"

    def handle_endtag(self, tag):
        if self.heading and tag == self.heading[1]:
            index, heading_tag, attrs, text = self.heading
            root = ("bench-" if self.section == "bench" else "") + slug("".join(text))
            candidate = root
            suffix = 0
            while candidate in self.used:
                suffix += 1
                candidate = root + "-" + str(suffix)
            self.used.add(candidate)
            attrs["id"] = candidate
            self.out[index] = self.start(heading_tag, attrs)
            self.heading = None
        self.out.append("</" + tag + ">")
        if tag == "section":
            self.section = None

    def handle_data(self, data):
        self.out.append(data)
        if self.heading:
            self.heading[3].append(data)

    def handle_entityref(self, name):
        self.reference("&" + name + ";")

    def handle_charref(self, name):
        self.reference("&#" + name + ";")

    def reference(self, value):
        self.out.append(value)
        if self.heading:
            self.heading[3].append(html.unescape(value))

    def handle_comment(self, data):
        self.out.append("<!--" + data + "-->")

    def handle_decl(self, decl):
        self.out.append("<!" + decl + ">")


if __name__ == "__main__":
    out, base = sys.argv[1:]
    pages = list((Path(out) / "packages").glob("*/index.html"))
    packages = {page.parent.name for page in pages}
    for page in pages:
        parser = PackagePage(page.parent.name, base, packages)
        parser.feed(page.read_text())
        parser.close()
        page.write_text("".join(parser.out))
