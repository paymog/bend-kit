#!/usr/bin/env python3
"""Check strict proofs and scoped runtime verdicts without running Bend."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as tmp:
    fixture = Path(tmp)
    (fixture / "scripts").mkdir()
    for name in ("check.sh", "verdict.sh"):
        shutil.copyfile(root / "scripts" / name, fixture / "scripts" / name)
    bend = fixture / "bend"
    bend.write_text('''#!/usr/bin/env bash
if [ "$1" = pure.bend ] || [ "${2:-}" = -o ]; then
  echo 'ALL PROOFS CHECK'
  exit 0
fi
if [ "$1" = PROOF.bend ]; then
  if [ "$PROOF_DEF" = pure ]; then
    echo 'ALL PROOFS CHECK'
    exit 0
  fi
  name=$PROOF_DEF
else
  name=runtime.effect
fi
printf 'SOME PROOFS FAIL\nError: 1 def relies on unsafe or foreign code:\ndefs that depend on foreign: %s\n' "$name"
exit 1
''')
    bend.chmod(0o755)
    for package in ("storage", "http", "hairpin", "wire"):
        folder = fixture / package
        folder.mkdir()
        (folder / "PROOF.bend").touch()
        if package == "http":
            (folder / "mtls-check-test.py").touch()
            (folder / "ca-check-test.py").touch()
        if package == "storage":
            # Keep the JS harnesses empty; this check covers verdict routing only.
            for name in ("http_origin_check.py", "local_check.py"):
                (folder / name).touch()
        for proof_def in ("pure", "unrelated.effect", "LAWS.claim"):
            result = subprocess.run(
                ["bash", "scripts/check.sh", package], cwd=fixture,
                env=dict(os.environ, PATH=f"{fixture}:{os.environ['PATH']}",
                         PROOF_DEF=proof_def),
                capture_output=True, text=True,
            )
            expected = proof_def == "pure" or (
                package == "wire" and proof_def == "unrelated.effect"
            )
            assert (result.returncode == 0) == expected, (
                package, proof_def, result.stdout, result.stderr
            )
print("PASS package proof gates: pure proofs, foreign definitions, laws, and runtime policy")
