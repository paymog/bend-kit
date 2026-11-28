#!/usr/bin/env python3
"""Check download recovery and archive integrity without network access."""
from pathlib import Path
import hashlib
import io
import json
import os
import re
import subprocess
import tarfile
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "scripts/install-bend.sh").read_text()
with tempfile.TemporaryDirectory() as tmp:
    fixture = Path(tmp)
    archive = fixture / "release.tar.gz"
    with tarfile.open(archive, "w:gz") as tar:
        for name, data in {
            "bend/bin/bend": b"#!/bin/sh\necho 'bend 2.0.40'\n",
            "bend/bend2": b"compiler",
            "bend/guide": b"guide",
        }.items():
            info = tarfile.TarInfo(name)
            info.size = len(data)
            info.mode = 0o755
            tar.addfile(info, io.BytesIO(data))
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    installer = fixture / "install-bend.sh"
    installer.write_text(re.sub(r"SHA=[0-9a-f]{64}", f"SHA={digest}", source))
    commands = fixture / "commands"
    commands.mkdir()
    for name, body in {
        "uname": '#!/bin/sh\nprintf "%s\\n" "$PLATFORM"\n',
        "sleep": '#!/bin/sh\nprintf "%s\\n" "$1" >> "$SLEEPS"\n',
        "curl": '''#!/usr/bin/env python3
from pathlib import Path
import json, os, shutil, sys
args = sys.argv[1:]
for flag, value in [("--proto", "=https"), ("--proto-redir", "=https"),
                    ("--tlsv1.2", None), ("--connect-timeout", "15"),
                    ("--max-time", "120")]:
    assert flag in args
    if value:
        assert args[args.index(flag) + 1] == value
calls = Path(os.environ["CALLS"])
previous = calls.read_text().splitlines() if calls.exists() else []
url = args[-1]
assert url.startswith("https://github.com/bendlang/bend/releases/download/v2.0.40/bend-2.0.40-")
with calls.open("a") as out:
    out.write(url + "\\n")
failures = json.loads(os.environ["FAILURES"])
status = failures[min(len(previous), len(failures) - 1)]
if "--dump-header" in args:
    Path(args[args.index("--dump-header") + 1]).write_text(
        f"HTTP/2 {status}\\r\\nX-GitHub-Request-Id: fixture-id\\r\\n"
        "Location: https://example.invalid/?secret=DO_NOT_LOG\\r\\n"
        "Set-Cookie: DO_NOT_LOG\\r\\n")
if status != 200:
    print(f"curl: fixture HTTP {status}", file=sys.stderr)
    sys.exit(28 if status == 0 else 22)
output_flag = "--output" if "--output" in args else "-o"
shutil.copyfile(os.environ["ARCHIVE"], args[args.index(output_flag) + 1])
''',
    }.items():
        command = commands / name
        command.write_text(body)
        command.chmod(0o755)
    for platform in ("Linux x86_64", "Darwin arm64"):
        for failures, corrupt in [([200], False), ([403, 200], False),
                                  ([504, 200], False), ([0, 200], False),
                                  ([403], False), ([504], False), ([0], False),
                                  ([200], True), ([403, 200], True)]:
            calls = fixture / "calls"
            sleeps = fixture / "sleeps"
            calls.unlink(missing_ok=True)
            sleeps.unlink(missing_ok=True)
            dest = fixture / "installed"
            dest.mkdir(exist_ok=True)
            (dest / "bend2").write_text("old compiler")
            bad_archive = fixture / "bad.tar.gz"
            bad_archive.write_bytes(b"not the pinned release")
            env = dict(os.environ, PATH=f"{commands}:{os.environ['PATH']}",
                       PLATFORM=platform, CALLS=str(calls), SLEEPS=str(sleeps),
                       ARCHIVE=str(bad_archive if corrupt else archive),
                       FAILURES=json.dumps(failures))
            result = subprocess.run(["bash", str(installer), str(dest)], env=env,
                                    capture_output=True, text=True, timeout=10)
            success = failures[-1] == 200 and not corrupt
            assert (result.returncode == 0) == success, (platform, failures, result)
            urls = calls.read_text().splitlines()
            count = len(failures) if failures[-1] == 200 else 3
            assert len(urls) == count, (failures, urls)
            assert len(set(urls)) == count, urls
            if count > 1:
                assert "bend-ci=" in urls[1], urls
                assert "fixture-id" in result.stderr, result.stderr
                assert f"HTTP/2 {failures[0]}" in result.stderr, result.stderr
            assert "DO_NOT_LOG" not in result.stdout + result.stderr
            delays = sleeps.read_text().splitlines() if sleeps.exists() else []
            assert delays == ["2", "4"][:count - 1], delays
            if success:
                assert "bend 2.0.40" in result.stdout
                assert (dest / "bend2").read_bytes() == b"compiler"
            else:
                assert (dest / "bend2").read_text() == "old compiler"
                if not corrupt:
                    assert "failed after 3 attempts" in result.stderr, result.stderr
print("PASS Bend installer: both platforms, transient and persistent failures, diagnostics, checksums")
