#!/usr/bin/env python3
"""Check workflow selection, archive integrity, ShellCheck, and gate results."""
from pathlib import Path
import hashlib
import os
import re
import shutil
import subprocess
import tempfile
import textwrap

root = Path(__file__).resolve().parents[1]
workflow = (root / ".github/workflows/ci.yml").read_text()
selection = workflow.split("      - id: workflows\n", 1)[1].split("      - id:", 1)[0]
selection = textwrap.dedent(selection.split("        run: |\n", 1)[1])
gate = workflow.split("  gate:\n", 1)[1]
assert "workflow-lint" in gate.split("    if:", 1)[0]
assert "    if: always() && (github.event_name == 'push' || github.event_name == 'pull_request')" in gate
assert "if: needs.changes.outputs.workflows == 'true'" in workflow
assert "workflows: ${{ steps.workflows.outputs.changed }}" in workflow
acceptance = workflow.split("  launchd-acceptance:\n", 1)[1].split("  changes:\n", 1)[0]
assert "if: github.event_name == 'workflow_dispatch' || github.event_name == 'schedule'" in acceptance
assert "runs-on: macos-15" in acceptance
assert "--lane all --case all" in acceptance
assert "if: always()" in acceptance
assert "actions/upload-artifact@" in acceptance
assert 'if-no-files-found: error' in acceptance
assert "    if: github.event_name == 'push' || github.event_name == 'pull_request'" in workflow.split("  changes:\n", 1)[1]
shellcheck = shutil.which("shellcheck")
assert shellcheck, "ShellCheck must be installed"
install = workflow.split("      - name: Install actionlint and ShellCheck\n", 1)[1].split("      - name:", 1)[0]
install = textwrap.dedent(install.split("        run: |\n", 1)[1])
pins = re.findall(r"([0-9a-f]{64})  (actionlint\.tar\.gz|shellcheck\.tar\.xz)", install)
assert len(pins) == 2 and len({name for _, name in pins}) == 2, pins
with tempfile.TemporaryDirectory() as tmp:
    fixture = Path(tmp)
    source = fixture / "source"
    source.mkdir()
    script = install
    for digest, name in pins:
        data = name.encode()
        (source / name).write_bytes(data)
        script = script.replace(digest, hashlib.sha256(data).hexdigest())
    for name, body in [
        ("curl", 'cp "$SOURCE/$3" "$3"'),
        ("tar", 'echo extracted >> "$EXTRACTED"'),
    ]:
        command = fixture / name
        command.write_text(f"#!/bin/sh\n{body}\n")
        command.chmod(0o755)
    extracted = fixture / "extracted"
    for corrupt in [None, *[name for _, name in pins]]:
        for _, name in pins:
            (source / name).write_bytes(name.encode() + (b"changed" if name == corrupt else b""))
        extracted.unlink(missing_ok=True)
        result = subprocess.run(["bash", "-e", "-o", "pipefail", "-c", script],
                                capture_output=True, text=True,
                                env=dict(os.environ, PATH=f"{fixture}:{os.environ['PATH']}",
                                         SOURCE=str(source), EXTRACTED=str(extracted),
                                         RUNNER_TEMP=tmp, GITHUB_PATH=str(fixture / "path")))
        assert (result.returncode == 0) == (corrupt is None), result.stdout + result.stderr
        assert extracted.exists() == (corrupt is None), corrupt
with tempfile.TemporaryDirectory() as tmp:
    fixture = Path(tmp)
    git = fixture / "git"
    git.write_text('#!/bin/sh\nprintf "%s" "$CHANGED_PATHS"\n')
    git.chmod(0o755)
    output = fixture / "output"
    cases = [
        ("pull_request", "", False),
        ("pull_request", "README.md\nhttp/http.bend\n", False),
        ("pull_request", ".github/workflows/ci.yml\n", True),
        ("pull_request", ".github/workflows/publish.yaml\n", True),
        ("pull_request", "scripts/workflow-lint-test.py\n", True),
        ("pull_request", ".github/workflows/notes.txt\n", False),
        ("push", "", True),
    ]
    for event, paths, expected in cases:
        output.write_text("")
        subprocess.run(["bash", "-e", "-o", "pipefail", "-c", selection], check=True,
                       env=dict(os.environ, PATH=f"{fixture}:{os.environ['PATH']}",
                                EVENT_NAME=event, BASE_REF="main", CHANGED_PATHS=paths,
                                GITHUB_OUTPUT=str(output)))
        assert output.read_text() == f"changed={str(expected).lower()}\n", (event, paths)
    for expansion, valid in [('"$arg"', True), ("$arg", False)]:
        source = f'''name: fixture
on: push
jobs:
  fixture:
    runs-on: ubuntu-latest
    steps:
      - run: |
          arg="two words"
          printf '%s\\n' {expansion}
'''
        result = subprocess.run(["actionlint", "-shellcheck", shellcheck, "-"],
                                input=source, text=True, capture_output=True)
        assert (result.returncode == 0) == valid, result.stdout + result.stderr
        if not valid:
            assert "SC2086" in result.stdout + result.stderr, result
    script = textwrap.dedent(gate.split("        run: |\n", 1)[1])
    for status in ["success", "skipped", "failure", "cancelled"]:
        substituted = re.sub(r"\$\{\{ needs\.([\w-]+)\.result }}",
                             lambda m: status if m[1] == "workflow-lint" else "success", script)
        result = subprocess.run(["bash", "-e", "-c", substituted], capture_output=True, text=True)
        assert (result.returncode == 0) == (status in ["success", "skipped"]), status
print("PASS workflow lint: selection, archive integrity, SC2086 detection, and gate failure handling")
