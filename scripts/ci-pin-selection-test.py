#!/usr/bin/env python3
"""Check the workflow's sibling-pin argument selection."""
from pathlib import Path
import os
import subprocess
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
