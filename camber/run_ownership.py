#!/usr/bin/env python3
"""Run the ownership experiment in native and JavaScript lanes, without repo artifacts."""
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "camber" / "ownership_check.bend"


def run(command, timeout):
    print("+", " ".join(map(str, command)), flush=True)
    subprocess.run(command, cwd=ROOT, check=True, timeout=timeout)


def main():
    with tempfile.TemporaryDirectory(prefix="camber-ownership-") as directory:
        temp = Path(directory)
        for lane, suffix in (("native", ""), ("javascript", ".js")):
            executable = temp / ("ownership_check" + suffix)
            run(["bend", SOURCE, "-o", executable], 120)
            journal = temp / (lane + "-journal")
            command = [executable, journal] if lane == "native" else ["bun", executable, journal]
            run(command, 15)
            records = [json.loads(line) for line in journal.read_text().splitlines()]
            assert records == [{"id": 9, "name": "Cara"}], records
            assert (temp / (lane + "-journal-left")).read_bytes() == b""
            assert (temp / (lane + "-journal-right")).read_bytes() == b""
            print(f"{lane}: actual journal contains only the accepted creation; PASS", flush=True)


if __name__ == "__main__":
    main()
