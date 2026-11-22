#!/usr/bin/env python3
"""Check that only the known macOS public DNS failure is allowed."""
import os
from pathlib import Path
import subprocess
import tempfile
import textwrap

workflow = Path(__file__).resolve().parents[1] / ".github/workflows/ci.yml"
block = workflow.read_text().split("      - name: Check native DNS effects\n", 1)[1]
block = block.split("        run: |\n", 1)[1].split("      - name:", 1)[0]
script = textwrap.dedent(block)
known = "== native dns\nok zero-length RDATA then A\nresolve.all AAAA gave []\n"
cases = [
    (0, "all checks passed\n", 0),
    (1, known, 0),
    (2, known, 2),
    (1, known.replace("ok zero-length RDATA then A", "wrong packet answer"), 1),
    (1, "compiler error\n" + known, 1),
    (1, known + "another assertion failed\n", 1),
    (1, "unrelated failure\n", 1),
]
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    (root / "scripts").mkdir()
    native = root / "scripts/native-check.sh"
    native.write_text('#!/bin/bash\nprintf "%s" "$TEST_OUTPUT"\nexit "$TEST_STATUS"\n')
    native.chmod(0o755)
    for status, output, expected in cases:
        env = dict(os.environ, RUNNER_TEMP=directory, TEST_OUTPUT=output, TEST_STATUS=str(status))
        result = subprocess.run(["bash", "-e", "-c", script], cwd=root, env=env, capture_output=True, text=True)
        assert result.returncode == expected, (status, output, result)
        assert ("::warning::" in result.stdout) == (status == 1 and output == known)
print("PASS macOS DNS allowance: seven success and failure cases")
