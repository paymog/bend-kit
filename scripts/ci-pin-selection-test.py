#!/usr/bin/env python3
"""Check package selection and the workflow's sibling-pin arguments."""
from pathlib import Path
import os
import subprocess
import shutil
import tempfile
import textwrap

root = Path(__file__).resolve().parents[1]
workflow = (root / ".github/workflows/ci.yml").read_text()
step = workflow.split("      - name: Check sibling pins\n", 1)[1].split("      - name:", 1)[0]
script = textwrap.dedent(step.split("        run: |\n", 1)[1])
script = script.replace("${{ github.base_ref }}", "main")
cases = [
    ("", []),
    ("scripts/unrelated.sh\n", []),
    ("http/http.bend\n", ["origin/main", "http"]),
    ("wire/wire.bend\nhttp/check.bend\nhttp/http.bend\nother/file\n", ["origin/main", "http", "wire"]),
    ("README.md\n", ["origin/main"]),
    ("http/README.md\n", ["origin/main"]),
    ("scripts/pins.sh\n", ["origin/main"]),
    ("scripts/packages.sh\n", ["origin/main"]),
    ("scripts/pins.allow\n", ["origin/main"]),
    ("dns/dns.bend\nscripts/pins.allow\n", ["origin/main"]),
]
with tempfile.TemporaryDirectory() as tmp:
    fixture = Path(tmp)
    (fixture / "scripts").mkdir()
    commands = {
        "git": 'printf "%s" "$CHANGED_PATHS"\n',
        "scripts/packages.sh": 'printf "http\\nwire\\n"\n',
        "scripts/pins.sh": 'printf "%s\\n" "$@" > "$PIN_ARGS"\n',
        "scripts/pins-check.sh": "exit 0\n",
        "scripts/repin-check.py": "",
    }
    for name, body in commands.items():
        path = fixture / name
        path.write_text("#!/usr/bin/env bash\n" + body if not name.endswith(".py") else body)
        path.chmod(0o755)
    output = fixture / "args"
    for changed, expected in cases:
        output.unlink(missing_ok=True)
        subprocess.run(
            ["bash", "-euo", "pipefail", "-c", script], cwd=fixture, check=True,
            env=dict(os.environ, PATH=f"{fixture}:{os.environ['PATH']}",
                     CHANGED_PATHS=changed, PIN_ARGS=str(output)),
        )
        actual = output.read_text().splitlines() if output.exists() else []
        assert actual == expected, (changed, actual, expected)
print("PASS CI pin selection: zero, one, multiple, and full-repo cases")

with tempfile.TemporaryDirectory() as tmp:
    fixture = Path(tmp)
    (fixture / "scripts").mkdir()
    shutil.copyfile(root / "scripts/packages.sh", fixture / "scripts/packages.sh")
    for package in ("dns", "http", "wire"):
        (fixture / package).mkdir()
        (fixture / package / f"{package}.bend").touch()
    git = fixture / "git"
    git.write_text('#!/usr/bin/env bash\nprintf "%s" "$CHANGED_PATHS"\n')
    git.chmod(0o755)
    packages = ["dns", "http", "wire"]
    for changed, expected in [
        ("", []),
        ("README.md\n", []),
        ("dns/dns.bend\n", ["dns"]),
        ("dns/dns.bend\nscripts/pins.allow\n", ["dns"]),
        ("scripts/pins.allow\n", []),
        ("scripts/pins.sh\n", packages),
        ("scripts/packages.sh\n", packages),
        ("scripts/pins.allow.bak\n", packages),
        (".github/workflows/ci.yml\n", packages),
        ("scripts/pins.allow\nscripts/check.sh\n", packages),
        ("scripts/pins.allow\n.github/workflows/ci.yml\n", packages),
    ]:
        result = subprocess.run(
            ["bash", "scripts/packages.sh", "origin/main"], cwd=fixture,
            check=True, capture_output=True, text=True,
            env=dict(os.environ, PATH=f"{fixture}:{os.environ['PATH']}",
                     CHANGED_PATHS=changed),
        )
        assert result.stdout.splitlines() == expected, (changed, result.stdout, expected)
    result = subprocess.run(
        ["bash", "scripts/packages.sh"], cwd=fixture,
        check=True, capture_output=True, text=True,
    )
    assert result.stdout.splitlines() == packages, result.stdout
print("PASS package selection: pin allowances stay narrow; scripts and CI select all")
