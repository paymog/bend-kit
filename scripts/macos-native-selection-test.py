#!/usr/bin/env python3
"""Check the macOS matrix against changed native packages."""
from pathlib import Path
import os
import subprocess
import tempfile
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

hairpin = next(line.strip() for line in workflow.splitlines() if 'echo "hairpin=' in line)
with tempfile.TemporaryDirectory() as tmp:
    output = Path(tmp) / "output"
    for changed, expected in [("hairpin", True), ("bytes\nhairpin\nhttp", True), ("http", False), ("", False)]:
        output.write_text("")
        subprocess.run(
            ["bash", "-e", "-c", hairpin + ' >> "$GITHUB_OUTPUT"'], cwd=root,
            env=dict(os.environ, pkgs=changed, GITHUB_OUTPUT=str(output)), check=True,
        )
        assert output.read_text() == f"hairpin={str(expected).lower()}\n"
job = workflow.split("\n  hairpin-ca-macos:\n", 1)[1].split("\n  smoke:\n", 1)[0]
for required in [
    "if: needs.changes.outputs.hairpin == 'true'",
    "runs-on: macos-15",
    """test "$(uname -sm)" = 'Darwin arm64'""",
    "scripts/install-bend.sh",
    "sh hairpin/ca-check.sh\n",
    "sh hairpin/ca-check.sh js\n",
]:
    assert required in job, required
gate = workflow.split("\n  gate:\n", 1)[1]
assert "hairpin-ca-macos," in gate
assert "needs.hairpin-ca-macos.result" in gate
print("PASS macOS Hairpin CA: selection, both lanes, and required gate")

for required in [
    "ref: ${{ github.event.pull_request.head.sha || github.sha }}",
    "persist-credentials: false",
    'test "$actual" = "$EXPECTED_HEAD_SHA"',
    "bun-version: ${{ env.BUN_VERSION }}",
    'python3 -B scripts/rss-check.py bend hairpin/check.bend -o "$RUNNER_TEMP/hairpin-check"',
    '"$RUNNER_TEMP/hairpin-check"\n',
    'bend hairpin/check.bend -o "$RUNNER_TEMP/hairpin-check.js"',
    'bun "$RUNNER_TEMP/hairpin-check.js"',
]:
    assert required in job, required
assert job.index('bend hairpin/check.bend -o "$RUNNER_TEMP/hairpin-check"') < job.index('bend hairpin/check.bend -o "$RUNNER_TEMP/hairpin-check.js"')
hairpin_gate = gate.split('case "${{ needs.hairpin-ca-macos.result }}" in', 1)[1].split("esac", 1)[0]
for result, expected in [("success", 0), ("skipped", 0), ("failure", 1), ("cancelled", 1)]:
    script = 'case "$result" in' + hairpin_gate.replace("${{ needs.hairpin-ca-macos.result }}", "$result") + "esac"
    status = subprocess.run(["bash", "-c", script], env=dict(os.environ, result=result), capture_output=True)
    assert status.returncode == expected, (result, status.returncode)
print("PASS macOS Hairpin package: both lanes, runner/head, memory ceiling, and required gate")

http = next(line.strip() for line in workflow.splitlines() if 'echo "http=' in line)
with tempfile.TemporaryDirectory() as tmp:
    output = Path(tmp) / "output"
    for changed, expected in [("http", True), ("bytes\nhttp\nhairpin", True), ("hairpin", False), ("", False)]:
        output.write_text("")
        subprocess.run(
            ["bash", "-e", "-c", http + ' >> "$GITHUB_OUTPUT"'], cwd=root,
            env=dict(os.environ, pkgs=changed, GITHUB_OUTPUT=str(output)), check=True,
        )
        assert output.read_text() == f"http={str(expected).lower()}\n"
job = workflow.split("\n  http-macos:\n", 1)[1].split("\n  http-tls-macos:\n", 1)[0]
for required in [
    "if: needs.changes.outputs.http == 'true'",
    "runs-on: macos-15",
    """test "$(uname -sm)" = 'Darwin arm64'""",
    "test \"$actual\" = \"$EXPECTED_HEAD_SHA\"",
    "bun-version: ${{ env.BUN_VERSION }}",
    "scripts/install-bend.sh",
    "python3 -B scripts/rss-check.py scripts/native-check.sh http",
    "python3 -B http/startup_check.py",
]:
    assert required in job, required
assert job.index("scripts/native-check.sh http") < job.index("python3 -B http/startup_check.py")
assert "http-macos," in gate
assert "needs.http-macos.result" in gate
print("PASS macOS HTTP: selection, package acceptance, startup lanes, memory ceiling, and required gate")

wire = next(line.strip() for line in workflow.splitlines() if 'echo "wire=' in line)
with tempfile.TemporaryDirectory() as tmp:
    output = Path(tmp) / "output"
    for changed, expected in [("wire", True), ("bytes\nwire\nhttp", True), ("http", False), ("wireframe", False), ("", False)]:
        output.write_text("")
        subprocess.run(
            ["bash", "-e", "-c", wire + ' >> "$GITHUB_OUTPUT"'], cwd=root,
            env=dict(os.environ, pkgs=changed, GITHUB_OUTPUT=str(output)), check=True,
        )
        assert output.read_text() == f"wire={str(expected).lower()}\n"
assert "wire: ${{ steps.list.outputs.wire }}" in workflow
job = workflow.split("\n  wire-tls-macos:\n", 1)[1].split("\n  hairpin-ca-macos:\n", 1)[0]
for required in [
    "if: needs.changes.outputs.wire == 'true'",
    "runs-on: macos-15",
    "ref: ${{ github.event.pull_request.head.sha || github.sha }}",
    """test "$(uname -sm)" = 'Darwin arm64'""",
    'test "$actual" = "$EXPECTED_HEAD_SHA"',
    "bun-version: ${{ env.BUN_VERSION }}",
    "scripts/install-bend.sh",
    'echo "$(brew --prefix openssl@3)/bin" >> "$GITHUB_PATH"',
    "for s in wire/ca-check.sh wire/mtls-check.sh; do",
    'echo "== $s native"; sh "$s"',
    'echo "== $s js"; sh "$s" js',
]:
    assert required in job, required
assert "wire-tls-macos," in gate
wire_gate = gate.split('case "${{ needs.wire-tls-macos.result }}" in', 1)[1].split("esac", 1)[0]
for result, expected in [("success", 0), ("skipped", 0), ("failure", 1), ("cancelled", 1)]:
    script = 'case "$result" in' + wire_gate.replace("${{ needs.wire-tls-macos.result }}", "$result") + "esac"
    status = subprocess.run(["bash", "-c", script], env=dict(os.environ, result=result), capture_output=True)
    assert status.returncode == expected, (result, status.returncode)
print("PASS macOS Wire TLS: selection, runner/head, pinned tools, four lanes, and required gate")

for name in ["check", "native-macos"]:
    job = workflow.split(f"\n  {name}:\n", 1)[1].split("\n\n", 1)[0]
    bun = next(step for step in job.split("      - ") if "uses: oven-sh/setup-bun@v2" in step)
    assert "matrix.package == 'dns'" in bun
    assert "bun-version: ${{ env.BUN_VERSION }}" in job
    dns = job.split("      - name: Check DNS JavaScript backend\n", 1)[1].split("      - ", 1)[0]
    assert "if: matrix.package == 'dns'" in dns
    assert 'bend dns/check.bend -o "$RUNNER_TEMP/dns-check.js"' in dns
    assert 'bun "$RUNNER_TEMP/dns-check.js"' in dns
    assert "continue-on-error" not in dns
    assert "||" not in dns
print("PASS DNS JavaScript: both package matrices, pinned Bun, compile and run without failure allowance")
