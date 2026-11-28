#!/usr/bin/env python3
"""Check package selection and conformance failure handling without Bend or network IO."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
from unittest.mock import patch

import conformance as harness

root = Path(__file__).resolve().parents[1]
workflow = (root / ".github/workflows/ci.yml").read_text()
job = workflow.split("  check:\n", 1)[1].split("  stream-live:\n", 1)[0]
step = job.split("      - name: Check template Mustache conformance\n", 1)[1].split("      - name:", 1)[0]
assert "if: matrix.package == 'template'" in step
assert 'export PATH="$HOME/.bend/bin:$PATH"' in step
assert "python3 -B template/conformance-test.py" in step
assert "python3 -B scripts/rss-check.py python3 -B template/conformance.py" in step
assert "run: scripts/install-bend.sh" in job
assert "T.render_with(n, ctx, ps)" in harness.HEAD
assert "E.utf8.decode(T.render_bytes_with(n, ctx, ps))" in harness.HEAD
assert '"PACKED MISMATCH "' in harness.HEAD
encoding_version = (root / "encoding/VERSION").read_text().strip()
assert f"bend-kit-encoding@{encoding_version}/encoding.bend" in harness.HEAD

spec = json.dumps({"tests": [
    {"name": "variable", "template": "{{v}}", "data": {"v": "ok"}, "expected": "ok"},
    {"name": "non-map", "template": "", "data": None, "expected": ""},
]}).encode()
with patch.object(harness.urllib.request, "urlopen", side_effect=lambda url: io.BytesIO(spec)):
    cases = harness.load_cases()
assert [group for group, _ in cases[:6]] == harness.FILES
assert sum(group == "unicode" for group, _ in cases) == 2
assert sum(group == "nested-partials" for group, _ in cases) == 10
expected = [case["expected"] for _, case in cases]
nested = next(i for i, (group, _) in enumerate(cases) if group == "nested-partials")

with tempfile.TemporaryDirectory() as tmp:
    out = Path(tmp)
    git = out / "git"
    git.write_text('#!/bin/sh\nprintf "%s\\n" "$CHANGED_PATH"\n')
    git.chmod(0o755)
    for changed, selected in [("template/template.bend", True), ("template/conformance.py", True),
                              ("http/http.bend", False), ("README.md", False)]:
        result = subprocess.run(["bash", "scripts/packages.sh", "base"], cwd=root,
                                env=dict(os.environ, PATH=f"{out}:{os.environ['PATH']}", CHANGED_PATH=changed),
                                capture_output=True, text=True, check=True)
        assert ("template" in result.stdout.splitlines()) == selected, changed
    for mode in ["pass", "packed", "nested", "incomplete", "compile"]:
        actual = expected.copy()
        if mode == "packed":
            actual[0] = "PACKED MISMATCH wrong"
        elif mode == "nested":
            actual[nested] = actual[nested].replace("    😀", "  😀")
            assert actual[nested] != expected[nested]
        elif mode == "incomplete":
            actual.pop()
        output = (harness.END + "\n").join([*actual, ""]).encode()
        with patch.object(harness, "OUT", out), patch.object(harness, "load_cases", return_value=cases), \
             patch.object(harness.subprocess, "run") as run, contextlib.redirect_stdout(io.StringIO()):
            if mode == "compile":
                run.side_effect = subprocess.CalledProcessError(1, "bend")
            else:
                run.side_effect = [subprocess.CompletedProcess([], 0), subprocess.CompletedProcess([], 0, output)]
            try:
                harness.main()
            except SystemExit as exc:
                assert (exc.code == 0) == (mode == "pass"), (mode, exc.code)
            except subprocess.CalledProcessError:
                assert mode == "compile"
            else:
                raise AssertionError(f"missing conformance verdict: {mode}")
            assert run.call_args_list[0].kwargs["check"] is True
            if mode != "compile":
                assert run.call_args_list[1].kwargs["check"] is True
print("PASS template conformance: package selection, corpus, mismatches, incomplete output, and compile failure")
