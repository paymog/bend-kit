#!/usr/bin/env python3
"""Check decimal kernel selection, proof order, and failure handling."""
from pathlib import Path
import os
import re
import subprocess
import tempfile
import textwrap

root = Path(__file__).resolve().parents[1]
workflow = (root / ".github/workflows/ci.yml").read_text()
selection = workflow.split("      - id: decimal\n", 1)[1].split("      - id:", 1)[0]
selection = textwrap.dedent(selection.split("        run: |\n", 1)[1])
job = workflow.split("  bytes-kernel:\n", 1)[1].split("  check:\n", 1)[0]
proofs = textwrap.dedent(job.split("      - name: Check independent decimal proofs\n", 1)[1].split("        run: |\n", 1)[1])
expected = ["bytes/array-proof.bend", "bytes/roundtrip-proof.bend", "lemmas/lemmas.bend"]
assert "if: needs.changes.outputs.decimal == 'true'" in job
assert "decimal: ${{ steps.decimal.outputs.changed }}" in workflow
assert "timeout-minutes: 30" in job
assert "scripts/rss-check.py bend" in proofs
assert "lean-4.34.0-linux.tar.zst" in job
assert "caaa98356098c85dc0fcbbd28e1ec66f39eb6551829972b752ff20e1286b646b" in job
with tempfile.TemporaryDirectory() as tmp:
    fixture = Path(tmp)
    git = fixture / "git"
    git.write_text('#!/bin/sh\nprintf "%s" "$CHANGED_PATHS"\n')
    git.chmod(0o755)
    output = fixture / "output"
    env = dict(os.environ, PATH=f"{fixture}:{os.environ['PATH']}",
               GITHUB_OUTPUT=str(output), BASE_REF="main", BEFORE="a" * 40)
    for event in ["pull_request", "push"]:
        for path, selected in [
            *[(path, True) for path in expected],
            ("bytes/bytes.bend", True), ("bytes/decimal-proof.bend", True),
            ("bytes/word-proof.bend", True), ("lemmas/PROOF.bend", True),
            ("scripts/install-bend.sh", True), ("scripts/rss-check.py", True),
            ("scripts/bytes-kernel-test.py", True), (".github/workflows/ci.yml", True),
            ("bytes/README.md", False), ("http/http.bend", False), ("", False),
        ]:
            output.write_text("")
            subprocess.run(["bash", "-euo", "pipefail", "-c", selection], check=True,
                           env=dict(env, EVENT_NAME=event, CHANGED_PATHS=path))
            assert output.read_text().strip() == f"changed={str(selected).lower()}", (event, path)
    output.write_text("")
    subprocess.run(["bash", "-euo", "pipefail", "-c", selection], check=True,
                   env=dict(env, EVENT_NAME="push", BEFORE="0" * 40, CHANGED_PATHS=""))
    assert output.read_text().strip() == "changed=true"
    bend = fixture / "bend"
    bend.write_text('''#!/bin/sh
printf '%s\\n' "$1" >> "$PROOF_ORDER"
[ "$2" = --verdict ] || exit 2
if [ "$1" = "$FAIL_PROOF" ]; then
  case "$FAIL_MODE" in
    exit) echo 'ALL PROOFS CHECK'; exit 1 ;;
    signal) kill -KILL $$ ;;
    missing) exit 0 ;;
  esac
fi
echo 'ALL PROOFS CHECK'
''')
    bend.chmod(0o755)
    order = fixture / "order"
    for fail, mode in [("", ""), *[(proof, mode) for proof in expected for mode in ["exit", "signal", "missing"]]]:
        order.write_text("")
        result = subprocess.run(["bash", "-euo", "pipefail", "-c", proofs], cwd=root,
                                env=dict(env, RUNNER_TEMP=tmp, PROOF_ORDER=str(order),
                                         FAIL_PROOF=fail, FAIL_MODE=mode), capture_output=True, text=True)
        assert (result.returncode == 0) == (not fail), (fail, mode, result.stdout, result.stderr)
        wanted = expected[:expected.index(fail) + 1] if fail else expected
        assert order.read_text().splitlines() == wanted

gate = workflow.split("  gate:\n", 1)[1]
assert "bytes-kernel" in gate.split("    if:", 1)[0]
script = textwrap.dedent(gate.split("        run: |\n", 1)[1])
for status in ["success", "skipped", "failure", "cancelled"]:
    replaced = re.sub(r"\$\{\{ needs\.[\w-]+\.result \}\}", "success", script.replace("${{ needs.bytes-kernel.result }}", status))
    result = subprocess.run(["bash", "-euo", "pipefail", "-c", replaced], capture_output=True)
    assert (result.returncode == 0) == (status in ["success", "skipped"]), status
print("PASS bytes kernel: scoped selection, sequential verdicts, failure propagation, and merge gate")
