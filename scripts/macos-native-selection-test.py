#!/usr/bin/env python3
"""Check the macOS matrix against changed native packages."""
from pathlib import Path
import os
import subprocess
import textwrap

root = Path(__file__).resolve().parents[1]
workflow = (root / ".github/workflows/ci.yml").read_text()
selection = workflow.split("          native=$(\n", 1)[1].split("          )\n", 1)[0]
script = "native=$(\n" + textwrap.dedent(selection) + '\n)\nprintf "%s" "$native"\n'
packages = ["commands", "webhooks", "f32array", "bits"]
cases = [(package, [package]) for package in packages]
cases += [
    (" ".join(packages), packages),
    ("bytes", []),
    ("", []),
    ("bytes commands wire", ["commands", "wire"]),
]
for changed, expected in cases:
    result = subprocess.run(
        ["bash", "-e", "-c", script], cwd=root,
        env=dict(os.environ, pkgs=changed), capture_output=True, text=True, check=True,
    )
    assert result.stdout.splitlines() == expected, (changed, result.stdout, expected)
print("PASS macOS native selection: eight changed-package cases")
