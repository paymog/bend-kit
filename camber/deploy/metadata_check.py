#!/usr/bin/env python3
"""Check fresh receipt versions without compiling or starting platform jobs."""
import json
import tempfile
from pathlib import Path
from unittest.mock import patch

import run


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
        current = receipt(root / "current.json")
        assert current == run.published_versions()
        assert current.keys() == {"camber", "http", "json", "router", "bytes"}, current

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
