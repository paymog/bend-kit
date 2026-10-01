#!/usr/bin/env python3
"""Run the ownership experiment in native and JavaScript lanes, without repo artifacts."""
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ("ownership_check", "interface_check")


def run(command, timeout):
    print("+", " ".join(map(str, command)), flush=True)
    subprocess.run(command, cwd=ROOT, check=True, timeout=timeout)


def main():
    with tempfile.TemporaryDirectory(prefix="camber-ownership-") as directory:
        temp = Path(directory)
        for source in SOURCES:
            for lane, suffix in (("native", ""), ("javascript", ".js")):
                executable = temp / (source + suffix)
                run(["bend", ROOT / "camber" / (source + ".bend"), "-o", executable], 120)
                journal = temp / (source + "-" + lane + "-journal")
                command = [executable, journal] if lane == "native" else ["bun", executable, journal]
                run(command, 15)
                records = [json.loads(line) for line in journal.read_text().splitlines()]
                assert records == [{"id": 9, "name": "Cara"}], records
                if source == "ownership_check":
                    assert Path(str(journal) + "-left").read_bytes() == b""
                    assert Path(str(journal) + "-right").read_bytes() == b""
                print(f"{source}/{lane}: actual journal contains only the accepted creation; PASS", flush=True)


if __name__ == "__main__":
    main()
