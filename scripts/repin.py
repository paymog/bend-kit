#!/usr/bin/env python3
"""Print the re-pin waves that move every sibling import to the sibling's VERSION.

A package moves in a wave when every sibling version that its stale imports
need is on the hub. A package that moves raises its VERSION when a re-pinned
file is one of its newest published files, as scripts/publish.sh --check
requires. The raise is at the place of the highest number that its re-pinned
siblings raised. A VERSION that already holds an unpublished raise keeps it
unless the wave needs a raise at a higher place. Files that import their own
package from the hub wait until the package's other files are re-pinned and
published.
Files under an evidence/ folder keep their pins.

Usage: scripts/repin.py [--apply]. --apply re-pins the first wave: imports,
package READMEs, root README import rows, VERSION, and scripts/pins.allow.
BEND_HUB overrides the hub, as in scripts/publish.sh.
"""
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HUB = os.environ.get("BEND_HUB", "https://hub.bend-lang.com")
IMPORT = re.compile(r"^\s*import\s+bend-kit-([a-z0-9-]+)@([0-9.]+)/", re.M)
TARGET = re.compile(r"^\s*import\s+(bend-kit-[a-z0-9-]+@[0-9.]+|0x[0-9a-f]+)/", re.M)

_hashes = {}


def hub_hash(pkg, ver):
    key = f"bend-kit-{pkg}@{ver}"
    if key not in _hashes:
        try:
            with urllib.request.urlopen(f"{HUB}/name/{key}") as r:
                _hashes[key] = r.read().decode().strip()
        except urllib.error.HTTPError as e:
            if e.code != 404:
                raise
            _hashes[key] = None
    return _hashes[key]


def newest(pkg):
    try:
        with urllib.request.urlopen(f"{HUB}/name/bend-kit-{pkg}") as r:
            vers = [v["version"] for v in json.load(r)["versions"]]
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
        return None
    return max(vers, key=lambda v: [int(x) for x in v.split(".")], default=None)


def hub_files(pkg, ver):
    with urllib.request.urlopen(f"{HUB}/package/{hub_hash(pkg, ver)}.json") as r:
        keys = json.load(r)["files"]
    # A package published from the repo root stores archive/archive.bend, as in publish.sh.
    return {k if k.startswith(f"{pkg}/") else f"{pkg}/{k}" for k in keys}


def raise_at(old, new):
    return next(i for i, (a, b) in enumerate(zip(old.split("."), new.split("."))) if a != b)


def bump(ver, place):
    n = [int(x) for x in ver.split(".")]
    return ".".join(str(x) for x in n[:place] + [n[place] + 1] + [0] * (len(n) - place - 1))


def load():
    pkgs = subprocess.run([ROOT / "scripts/packages.sh"], capture_output=True, text=True, check=True).stdout.split()
    ver = {p: (ROOT / p / "VERSION").read_text().strip() for p in pkgs}
    files = {p: sorted(str(f.relative_to(ROOT)) for f in (ROOT / p).rglob("*.bend") if "evidence" not in f.parts) for p in pkgs}
    pins = {f: {(q, v) for q, v in IMPORT.findall((ROOT / f).read_text()) if q in ver} for fs in files.values() for f in fs}
    return pkgs, ver, files, pins


def waves(pkgs, ver, files, pins):
    """Yield (moves, waiting) per wave; a move is (pkg, new VERSION or None, {file: {(q, old): new}})."""
    ver, pins = dict(ver), {f: set(s) for f, s in pins.items()}
    published = set()
    real = {}
    on_hub = lambda p, v: (p, v) in published or hub_hash(p, v) is not None
    for _ in range(64):
        moves, waiting, groups = [], set(), {}
        for p in pkgs:
            stale = {f: {(q, v) for q, v in pins[f] if v != ver[q]} for f in files[p]}
            stale = {f: s for f, s in stale.items() if s}
            own = {f for f in stale if any(q == p for q, _ in pins[f])}
            groups[p] = ({f: s for f, s in stale.items() if f not in own}, {f: stale[f] for f in own})
        unsettled = {p for p, (rest, _) in groups.items() if rest}
        for p in pkgs:
            rest, own = groups[p]
            group = rest or own
            if not group:
                continue
            # A sibling that still re-pins would hand this package values of the old types.
            if any(q != p and q in unsettled for f in files[p] for q, _ in pins[f]):
                continue
            need = {(q, ver[q]) for s in group.values() for q, _ in s}
            if not rest:
                need.add((p, ver[p]))
            missing = {n for n in need if not on_hub(*n)}
            if missing:
                waiting |= missing
                continue
            edits = {f: {(q, v): ver[q] for q, v in s} for f, s in group.items()}
            new = None
            base = ver[p] if on_hub(p, ver[p]) else newest(p)
            if base:
                if p not in real:
                    real[p] = hub_files(p, base) if hub_hash(p, base) else {f"{p}/{p}.bend"}
                if edits.keys() & real[p]:
                    place = min(raise_at(old, n) for e in edits.values() for (_, old), n in e.items())
                    if base == ver[p] or place < raise_at(base, ver[p]):
                        new = bump(ver[p], place)
            moves.append((p, new, edits))
        if not moves and not waiting:
            if any(r or o for r, o in groups.values()):
                sys.exit("repin: stale imports form a cycle: " + " ".join(sorted(p for p, g in groups.items() if any(g))))
            return
        yield moves, waiting
        for p, new, edits in moves:
            for f, e in edits.items():
                pins[f] = {(q, v) for q, v in pins[f] if (q, v) not in e} | {(q, n) for (q, _), n in e.items()}
            if new:
                ver[p] = new
        published |= set(ver.items())
    sys.exit("repin: no fixed point after 64 waves")


def show(n, moves, waiting):
    if not moves:
        print(f"wave {n}: waits for the hub: " + ", ".join(f"bend-kit-{q}@{v}" for q, v in sorted(waiting)))
        return
    print(f"wave {n}:")
    for p, new, edits in moves:
        pairs = sorted({(q, old, v) for e in edits.values() for (q, old), v in e.items()})
        head = f"{p} -> {new}" if new else p
        print(f"  {head}: " + ", ".join(f"{q} {old} -> {v}" for q, old, v in pairs) + f" ({len(edits)} files)")


def sub(path, old, new):
    text = path.read_text()
    out = re.sub(old, new, text)
    if out != text:
        path.write_text(out)


def apply(moves, ver, pkgs):
    before = dict(ver)
    for p, new, edits in moves:
        readme = ROOT / p / "README.md"
        for f, e in edits.items():
            for (q, old), v in e.items():
                sub(ROOT / f, rf"(?m)^(\s*import\s+bend-kit-{q}@){re.escape(old)}/", rf"\g<1>{v}/")
                if readme.exists():
                    sub(readme, rf"bend-kit-{q}@{re.escape(old)}(?![0-9])", f"bend-kit-{q}@{v}")
        if new:
            (ROOT / p / "VERSION").write_text(new + "\n")
            sub(ROOT / "README.md", rf"bend-kit-{p}@{re.escape(ver[p])}/", f"bend-kit-{p}@{new}/")
            if readme.exists():
                sub(readme, rf"bend-kit-{p}@{re.escape(ver[p])}(?![0-9])", f"bend-kit-{p}@{new}")
    allow(before, pkgs)


def allow(before, pkgs):
    """Keep pins.allow lines that an import uses; add one for each import of a version that is not the sibling's VERSION."""
    users = {}
    for f in (f for p in pkgs for f in (ROOT / p).rglob("*.bend") if "evidence" not in f.parts):
        for t in TARGET.findall(f.read_text()):
            users.setdefault(t, []).append(f.relative_to(ROOT))
    path = ROOT / "scripts/pins.allow"
    lines = path.read_text().splitlines()
    kept = [l for l in lines if l.startswith("#") or not l.strip() or l.split()[0] in users]
    have = {l.split()[0] for l in kept if l.strip() and not l.startswith("#")}
    for t in sorted(users):
        q, _, v = t.removeprefix("bend-kit-").partition("@")
        if t in have or q not in before or v == before[q]:
            continue
        kept.append(f"{t}  # importers re-pin to bend-kit-{q}@{before[q]} in a later wave")
    path.write_text("\n".join(kept) + "\n")


def main():
    pkgs, ver, files, pins = load()
    plan = waves(pkgs, ver, files, pins)
    if "--apply" in sys.argv[1:]:
        first = next(plan, None)
        if first is None:
            print("every import names its sibling's VERSION")
            return
        show(1, *first)
        if first[0]:
            apply(first[0], ver, pkgs)
        return
    shown = False
    for n, (moves, waiting) in enumerate(plan, 1):
        show(n, moves, waiting)
        shown = True
    if not shown:
        print("every import names its sibling's VERSION")


if __name__ == "__main__":
    main()
