#!/usr/bin/env python3
"""Check re-pin wave exceptions without contacting the hub."""
import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory

spec = importlib.util.spec_from_file_location("repin", Path(__file__).with_name("repin.py"))
repin = importlib.util.module_from_spec(spec)
spec.loader.exec_module(repin)

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

print("Re-pin wave checks pass")
