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

print("Re-pin wave checks pass")
