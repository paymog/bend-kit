#!/usr/bin/env python3
"""Check re-pin waves, cycle rejection, self-imports, and exceptions offline."""
import importlib.util
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("repin", Path(__file__).with_name("repin.py"))
repin = importlib.util.module_from_spec(spec)
spec.loader.exec_module(repin)

patch("urllib.request.urlopen", side_effect=AssertionError("unexpected hub request")).start()

with TemporaryDirectory() as tmp:
    root = Path(tmp)
    repin.ROOT = root
    (root / "scripts").mkdir()
    versions = {"zlib": "0.6.0.0", "http": "0.39.2.0", "consumer": "0.1.0.0"}
    for pkg, ver in versions.items():
        (root / pkg).mkdir()
        (root / pkg / "VERSION").write_text(ver + "\n")
    (root / "README.md").write_text("bend-kit-http@0.39.2.0/http.bend\n")
    (root / "http/README.md").write_text("bend-kit-http@0.39.2.0; bend-kit-zlib@0.5.0.0\n")
    (root / "http/http.bend").write_text("import bend-kit-zlib@0.5.0.0/zlib.bend\n")
    consumer = root / "consumer/consumer.bend"
    consumer.write_text("import bend-kit-http@0.39.2.0/http.bend\nimport 0xabc/other.bend\n")
    exceptions = root / "scripts/pins.allow"
    unrelated = "0xabc  # keep this unrelated exception"
    exceptions.write_text("# Temporary pins\n\nbend-kit-zlib@0.5.0.0  # completed\n" + unrelated + "\n")

    repin.apply([("http", "0.40.0.0", {
        "http/http.bend": {("zlib", "0.5.0.0"): "0.6.0.0"},
    })], versions, list(versions))
    expected = ("# Temporary pins\n\n" + unrelated + "\n"
                "bend-kit-http@0.39.2.0  # importers re-pin to bend-kit-http@0.40.0.0 in a later wave\n")
    assert exceptions.read_text() == expected, exceptions.read_text()
    assert versions["http"] == "0.39.2.0", "apply mutated the planning versions"
    assert (root / "http/VERSION").read_text() == "0.40.0.0\n"
    assert (root / "http/http.bend").read_text() == "import bend-kit-zlib@0.6.0.0/zlib.bend\n"
    assert (root / "README.md").read_text() == "bend-kit-http@0.40.0.0/http.bend\n"
    assert (root / "http/README.md").read_text() == "bend-kit-http@0.40.0.0; bend-kit-zlib@0.6.0.0\n"

    versions["http"] = "0.40.0.0"
    repin.apply([("consumer", None, {
        "consumer/consumer.bend": {("http", "0.39.2.0"): "0.40.0.0"},
    })], versions, list(versions))
    assert exceptions.read_text() == "# Temporary pins\n\n" + unrelated + "\n"
    assert "bend-kit-http@0.40.0.0/http.bend" in consumer.read_text()

with TemporaryDirectory() as tmp:
    root = Path(tmp)
    repin.ROOT = root
    (root / "scripts").mkdir()
    packages = root / "scripts/packages.sh"
    packages.write_text("#!/bin/sh\nprintf 'bytes\\nprotobuf\\n'\n")
    packages.chmod(0o755)
    for pkg in ("bytes", "protobuf"):
        (root / pkg).mkdir()
        (root / pkg / "VERSION").write_text("0.2.0.0\n")
    (root / "protobuf/bench").mkdir()
    (root / "protobuf/evidence").mkdir()
    (root / "README.md").write_text("")
    old = "bend-kit-bytes@0.1.0.0/bytes.bend"
    templates = {
        "protobuf/generator.py": f'imports = ["import {old} as B"]\n',
        "protobuf/bench/run.py": f"'import Base\\nimport {old} as B\\n'\n",
        "protobuf/check.bend": f"import {old} as B\n",
    }
    for file, text in templates.items():
        (root / file).write_text(text)
    evidence = root / "protobuf/evidence/old.bend"
    evidence.write_text(f"import {old}\n")
    unrelated = root / "protobuf/history.py"
    unrelated.write_text(f'"{old}"\n')
    exceptions = root / "scripts/pins.allow"
    exceptions.write_text(f"{old.split('/')[0]}  # old templates\n")
    pkgs, versions, files, pins = repin.load()
    assert set(files["protobuf"]) == set(templates), files
    repin.hub_hash = lambda p, v: "published"
    repin.hub_files = lambda p, v: {f"{p}/{p}.bend"}
    moves, waiting = next(repin.waves(pkgs, versions, files, pins))
    assert not waiting
    assert len(moves) == 1 and moves[0][:2] == ("protobuf", None), moves
    assert set(moves[0][2]) == set(templates), moves
    repin.apply(moves, versions, pkgs)
    for file in templates:
        assert old not in (root / file).read_text(), file
        assert "bend-kit-bytes@0.2.0.0/" in (root / file).read_text(), file
    assert evidence.read_text() == f"import {old}\n"
    assert unrelated.read_text() == f'"{old}"\n'
    assert old.split("/")[0] not in exceptions.read_text()
    generator = root / "protobuf/generator.py"
    generator.write_text(f'RUNTIME = "bend-kit-protobuf@0.1.0.0/protobuf.bend"\n')
    repin.allow(versions, pkgs)
    assert "bend-kit-protobuf@0.1.0.0" in exceptions.read_text()
    pkgs, versions, files, pins = repin.load()
    moves, waiting = next(repin.waves(pkgs, versions, files, pins))
    assert set(moves[0][2]) == {"protobuf/generator.py"}
    repin.apply(moves, versions, pkgs)
    assert "bend-kit-protobuf@0.2.0.0/" in generator.read_text()
    assert "bend-kit-protobuf@0.1.0.0" not in exceptions.read_text()

with TemporaryDirectory() as tmp:
    root = Path(tmp)
    repin.ROOT = root
    (root / "scripts").mkdir()
    packages = root / "scripts/packages.sh"
    packages.write_text("#!/bin/sh\nprintf 'consumer\\nmiddle\\ndep\\n'\n")
    packages.chmod(0o755)
    for pkg, version, source in (
        ("dep", "0.2.0.0", ""),
        ("middle", "0.1.0.0", "import bend-kit-dep@0.1.0.0/dep.bend\n"),
        ("consumer", "0.1.0.0", "import bend-kit-middle@0.1.0.0/middle.bend\n"),
    ):
        (root / pkg).mkdir()
        (root / pkg / "VERSION").write_text(version + "\n")
        (root / pkg / f"{pkg}.bend").write_text(source)
    pkgs, versions, files, pins = repin.load()
    published = {("dep", "0.2.0.0"), ("middle", "0.1.0.0"), ("consumer", "0.1.0.0")}
    repin.hub_hash = lambda p, v: "published" if (p, v) in published else None
    repin.newest = lambda p: "0.1.0.0" if p in ("middle", "consumer") else None
    repin.hub_files = lambda p, v: {f"{p}/{p}.bend"}
    plan = list(repin.waves(pkgs, versions, files, pins))
    assert plan == [
        ([("middle", "0.2.0.0", {
            "middle/middle.bend": {("dep", "0.1.0.0"): "0.2.0.0"},
        })], set()),
        ([("consumer", "0.2.0.0", {
            "consumer/consumer.bend": {("middle", "0.1.0.0"): "0.2.0.0"},
        })], set()),
    ], plan
    assert versions["middle"] == "0.1.0.0", "waves mutated the input versions"
    assert pins["middle/middle.bend"] == {("dep", "0.1.0.0")}, "waves mutated the input pins"

    published.remove(("dep", "0.2.0.0"))
    first = next(repin.waves(pkgs, versions, files, pins))
    assert first == ([], {("dep", "0.2.0.0")}), first
    published.add(("dep", "0.2.0.0"))

    for pending, expected in (("0.1.1.0", "0.2.0.0"), ("0.2.0.0", None)):
        (root / "middle/VERSION").write_text(pending + "\n")
        pkgs, versions, files, pins = repin.load()
        first = next(repin.waves(pkgs, versions, files, pins))
        assert first == ([("middle", expected, {
            "middle/middle.bend": {("dep", "0.1.0.0"): "0.2.0.0"},
        })], set()), (pending, first)

with TemporaryDirectory() as tmp:
    root = Path(tmp)
    repin.ROOT = root
    repin.hub_hash = lambda *args: (_ for _ in ()).throw(AssertionError("hub access"))
    (root / "scripts").mkdir()
    (root / "scripts/pins.allow").write_text("")
    versions = {"http": "0.40.0.0", "hairpin": "0.15.0.0",
                "camber": "0.16.0.0", "jwt": "0.13.0.0", "time": "0.3.0.0"}
    for p, v in versions.items():
        (root / p).mkdir()
        (root / p / "VERSION").write_text(v + "\n")
        (root / p / f"{p}.bend").write_text("" if p in ("http", "time") else
            "import bend-kit-http@0.39.2.0/http.bend\n")
    (root / "http/http.bend").write_text("import bend-kit-time@0.2.0.0/time.bend\n")
    for p in ("camber", "jwt"):
        with (root / p / f"{p}.bend").open("a") as entry:
            entry.write("import bend-kit-hairpin@0.15.0.0/hairpin.bend\n")
    prose = ("## Same type\n\n"
             "`hairpin@0.15.0.0`, `camber@0.16.0.0`, and `jwt@0.13.0.0` "
             "use `bend-kit-http@0.39.2.0`.\n")
    tail = "## Packages\n\nbend-kit-hairpin@0.15.0.0/hairpin.bend\n"
    (root / "README.md").write_text(prose + tail)
    (root / "time/README.md").write_text("Used by `http@0.39.2.0`.\n")
    output = StringIO()
    with redirect_stdout(output):
        repin.apply([(p, v, {f"{p}/{p}.bend": {("http", "0.39.2.0"): "0.40.0.0"}})
                     for p, v in (("hairpin", "0.16.0.0"), ("camber", "0.17.0.0"))],
                    versions, list(versions))
    report = output.getvalue()
    generated = (root / "README.md").read_text()
    assert "| `bend-kit-http@0.39.2.0` | `jwt@0.13.0.0` |" in generated, generated
    assert "| `bend-kit-http@0.40.0.0` | `camber@0.17.0.0`, `hairpin@0.16.0.0` |" in generated, generated
    assert "| `bend-kit-hairpin@0.15.0.0` | `camber@0.17.0.0`, `jwt@0.13.0.0` |" in generated, generated
    assert "`http@0.40.0.0` imports: `time@0.2.0.0`." in generated, generated
    assert "README.md:" not in report.replace("time/README.md:", ""), report
    assert "time/README.md:1: review dependency guidance manually:" in report, report
    assert generated.endswith(tail.replace("0.15.0.0", "0.16.0.0")), generated
    after = dict(versions, hairpin="0.16.0.0", camber="0.17.0.0")
    repin.same_type(after, list(reversed(versions)))
    assert (root / "README.md").read_text() == generated, "generation is not stable"
    assert "bend-kit-http@0.39.2.0" in (root / "scripts/pins.allow").read_text()

versions = {"alpha": "0.2.0.0", "beta": "0.2.0.0"}
files = {p: [f"{p}/{p}.bend"] for p in versions}
pins = {"alpha/alpha.bend": {("beta", "0.1.0.0")},
        "beta/beta.bend": {("alpha", "0.1.0.0")}}
output = StringIO()
with patch.object(repin, "load", return_value=(list(versions), versions, files, pins)), \
        patch.object(repin, "hub_hash", return_value="published"), \
        patch.object(repin, "newest", return_value="0.2.0.0"), \
        patch.object(repin, "hub_files", side_effect=lambda p, v: set(files[p])), \
        patch("sys.argv", ["repin.py"]), redirect_stdout(output):
    try:
        repin.main()
    except SystemExit as error:
        assert error.code == "repin: stale imports form a cycle: alpha beta", error.code
    else:
        raise AssertionError("stale dependency cycle was accepted")
assert output.getvalue() == "", output.getvalue()

versions = {"dep": "0.2.0.0", "consumer": "0.1.0.0"}
files = {"dep": ["dep/dep.bend"],
         "consumer": ["consumer/consumer.bend", "consumer/check.bend"]}
pins = {"dep/dep.bend": set(),
        "consumer/consumer.bend": {("dep", "0.1.0.0")},
        "consumer/check.bend": {("consumer", "0.0.0.0")}}
published = {("dep", "0.2.0.0"), ("consumer", "0.1.0.0")}
with patch.object(repin, "hub_hash", side_effect=lambda p, v: "published" if (p, v) in published else None), \
        patch.object(repin, "newest", return_value="0.1.0.0"), \
        patch.object(repin, "hub_files", side_effect=lambda p, v: {f"{p}/{p}.bend"}):
    plan = list(repin.waves(list(versions), versions, files, pins))
    assert plan == [
        ([("consumer", "0.2.0.0", {
            "consumer/consumer.bend": {("dep", "0.1.0.0"): "0.2.0.0"},
        })], set()),
        ([("consumer", None, {
            "consumer/check.bend": {("consumer", "0.0.0.0"): "0.2.0.0"},
        })], set()),
    ], plan

    published.remove(("dep", "0.2.0.0"))
    first = next(repin.waves(list(versions), versions, files, pins))
    assert first == ([], {("dep", "0.2.0.0")}), first

    versions["consumer"] = "0.2.0.0"
    pins["consumer/consumer.bend"] = {("dep", "0.2.0.0")}
    first = next(repin.waves(list(versions), versions, files, pins))
    assert first == ([], {("consumer", "0.2.0.0")}), first
    published.add(("consumer", "0.2.0.0"))
    plan = list(repin.waves(list(versions), versions, files, pins))
    assert plan == [([("consumer", None, {
        "consumer/check.bend": {("consumer", "0.0.0.0"): "0.2.0.0"},
    })], set())], plan

print("Re-pin wave checks pass")
