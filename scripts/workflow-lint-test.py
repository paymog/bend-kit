#!/usr/bin/env python3
"""Check workflow selection, ShellCheck integration, and required-gate results."""
from pathlib import Path
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
assert "    if: always()" in gate
assert "if: needs.changes.outputs.workflows == 'true'" in workflow
assert "workflows: ${{ steps.workflows.outputs.changed }}" in workflow
shellcheck = shutil.which("shellcheck")
assert shellcheck, "ShellCheck must be installed"
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
print("PASS workflow lint: selection, SC2086 detection, and gate failure handling")
