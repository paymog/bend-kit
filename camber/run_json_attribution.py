#!/usr/bin/env python3
"""Observe explicit marker flushing and unchanged internal JSON stage clocks."""
import argparse
import hashlib
import json
import tempfile
import platform
import time
from pathlib import Path

from run_dispatch import ROOT, guarded
from run_json_progress import workloads


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = ROOT / "camber/json_attribution_probe.bend"
    results = {"scope": "JSON attribution without HTTP; explicit synchronous marker flush",
               "platform": platform.platform(),
               "bend": guarded(["bend", "version"], 20)[0].strip(),
               "bun": guarded(["bun", "--version"], 20)[0].strip(),
               "source_sha256": {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                                 for path in [source, *sorted(source.parent.glob("probe_stdout.*"))]},
               "cases": []}
    with args.output.open("x") as receipt:
        receipt.write(json.dumps(results, indent=2) + "\n")
    with tempfile.TemporaryDirectory(prefix="camber-json-attribution-") as directory:
        temp = Path(directory)
        fixtures = {name: body for name, mode, body, status in workloads()
                    if name in ("json_array_65536", "json_array_1048576", "json_string_1048576")}
        for name, body in fixtures.items():
            (temp / name).write_bytes(body)
        for lane, suffix in (("native", ""), ("javascript", ".js")):
            binary = temp / ("attribution" + suffix)
            guarded(["bend", source, "-o", binary], 180)
            command = ([str(binary), "+RTS", "--threads", "1", "--gpu", "off", "-RTS"]
                       if lane == "native" else ["bun", str(binary)])
            cases = [("json_array_65536", 1), ("json_array_1048576", 1),
                     ("json_array_1048576", 16), ("json_array_1048576", 126),
                     ("json_string_1048576", 16), ("packed", 1), ("packed", 16), ("packed", 126)]
            for name, count in cases:
                events = []
                started = time.monotonic()
                text, rss, elapsed = guarded(command + ["packed" if name == "packed" else str(temp / name), str(count)],
                                             180, lambda line: events.append({"text": line, "seconds": time.monotonic() - started}))
                stages = {stage: [int(parts[1]) + int(parts[2]) / 1e9 for line in text.splitlines()
                                  if (parts := line.split("\t"))[0] == stage]
                          for stage in ("PARSE", "DISPOSE")}
                row = {"lane": lane, "fixture": name, "count": count, "events": events,
                       "stdout": text, "sampled_peak_rss_kib": rss, "wall_seconds": elapsed, "stages": stages}
                results["cases"].append(row)
                args.output.write_text(json.dumps(results, indent=2) + "\n")
                assert text.startswith("BATCH_BEGIN\n") and text.endswith("BATCH_DONE\n"), row
                assert all(len(values) == count for values in stages.values()), row
                print(f"{lane}/{name}/{count}: stage clocks and completion passed", flush=True)


if __name__ == "__main__":
    main()
