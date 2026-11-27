#!/usr/bin/env python3
"""Check fresh receipt versions without compiling or starting platform jobs."""
import hashlib
import json
import os
import tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import run
from system_host import SystemHost


def system_permissions(root):
    evidence = SimpleNamespace(invocation={}, save=lambda: None)
    guard = SimpleNamespace(evidence=evidence)
    with patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}):
        try:
            SystemHost(guard)
        except RuntimeError as error:
            assert "disposable GitHub-hosted" in str(error)
        else:
            raise AssertionError("system deployment must reject an ordinary host")
    host = SystemHost.__new__(SystemHost)
    host.guard = guard
    host.uid = os.getuid()
    host.name = "fixture"
    host.record = {"paths": []}
    guard.command = lambda argv, **kwargs: {"status": 0 if os.access(argv[-1], os.W_OK) else 1}
    file = root / "protected"
    file.write_text("original")
    file.chmod(0o600)
    host.inspect(file, uid=host.uid, mode=0o600)
    host.verify_paths()
    file.write_text("changed")
    try:
        host.verify_paths()
    except AssertionError:
        pass
    else:
        raise AssertionError("runtime input mutation must fail")
    for candidate in (file, root / "linked"):
        if candidate == file:
            file.chmod(0o666)
        else:
            candidate.symlink_to(file)
        try:
            host.inspect(candidate, uid=host.uid)
        except AssertionError:
            pass
        else:
            raise AssertionError("writable or symlinked input must fail")


def receipt(output):
    with patch.object(run.sys, "argv", ["run.py", "--output", str(output)]), \
            patch.object(run, "disk_floor", side_effect=RuntimeError("metadata-only check")):
        try:
            run.main()
        except RuntimeError as error:
            assert str(error) == "RuntimeError('metadata-only check')", error
        else:
            raise AssertionError("deployment should stop before building")
    invocation = json.loads(output.read_text())["invocations"][-1]
    assert invocation["status"] == "failed"
    assert invocation["commands"] == []
    return invocation["published"]


def main():
    with tempfile.TemporaryDirectory(prefix="camber-metadata-") as temporary:
        root = Path(temporary)
        system_permissions(root)
        current = receipt(root / "current.json")
        assert current == run.published_versions()
        assert current.keys() == {"camber", "http", "json", "router", "bytes"}, current
        hashes = run.source_hashes()
        for suffix in ("bend", "c", "js"):
            path = run.HERE.parent / f"probe_stdout.{suffix}"
            assert hashes[str(path.relative_to(run.ROOT))] == hashlib.sha256(path.read_bytes()).hexdigest()

        source = root / "users.bend"
        sibling = root / "sibling.bend"
        source.write_text("import Base\nimport ./sibling.bend as S\n"
                          "import bend-kit-camber@1.2.3.4/camber.bend as C\n")
        sibling.write_text("import ./users.bend as U\n"
                           "import bend-kit-http@2.3.4.5/http.bend as H\n"
                           "import bend-kit-http@2.3.4.5/completion.bend as T\n")
        with patch.object(run, "HERE", root), patch.object(run, "ROOT", root):
            before = receipt(root / "fixture.json")
            assert before == {"camber": "1.2.3.4", "http": "2.3.4.5"}, before
            sibling.write_text(sibling.read_text().replace("2.3.4.5", "2.3.4.6"))
            after = receipt(root / "fixture.json")
            assert after == {**before, "http": "2.3.4.6"}, after
            assert after != before
            sibling.write_text(sibling.read_text() + "import bend-kit-camber@9.0.0.0/camber.bend as C\n")
            try:
                run.published_versions()
            except ValueError as error:
                assert "conflicting consumer imports for camber" in str(error), error
            else:
                raise AssertionError("conflicting imports must fail")
    print("deployment receipt metadata checks passed")


if __name__ == "__main__":
    main()
