"""Paired raw/scoped controls; not the final Camber API or release gate."""
import argparse
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile

from run_dispatch import ROOT, guarded
from run_raw import Server, exchange, probes, trial, workloads


def generate(temp):
    source = "import Base\n\n" + "\n\n".join(
        f"def r{n}(id: U32) -> Bool:\n  match id:\n" + "".join(f"    case {i}:\n      True{{}}\n" for i in range(n)) + "    case _:\n      False{}"
        for n in (10, 100, 1000)) + "\n"
    (temp / "routes.bend").write_text(source)
    entry = temp / "paired.bend"
    entry.write_text(f"import Base\nimport {os.path.relpath(ROOT / 'camber/lifecycle_bench.bend', temp)} as Bench\nimport ./routes.bend as Routes\n\ndef main() -> IO(Unit):\n  Bench.run(~Routes.r10, ~Routes.r100, ~Routes.r1000)\n")
    return entry


def evaluate(rows, limits):
    decisions = {}
    median = lambda values, key: statistics.median(x[key] for x in values)
    for name, pair in rows.items():
        raw, scoped = pair["raw"], pair["scoped"]
        allowance = limits[name]["direct_ceiling_us"] - limits[name]["raw_direct_median_us"]
        added = median(scoped["direct"], "microseconds_per_request") - median(raw["direct"], "microseconds_per_request")
        ratio = median(scoped["saturation"], "expected_responses_per_second") / median(raw["saturation"], "expected_responses_per_second")
        verdict = {"direct_added_us": added, "frozen_direct_allowance_us": allowance, "direct_pass": added <= allowance,
                   "closed_loop_throughput_ratio": ratio, "throughput_pass": ratio >= .9, "latency": {}}
        for phase in ("saturation", "fixed_rate"):
            for key in ("p95_ms", "p99_ms"):
                reference = median(raw[phase], key)
                ceiling = reference + max(.25, reference * .2)
                actual = median(scoped[phase], key)
                verdict["latency"][f"{phase}_{key}"] = {"raw": reference, "scoped": actual, "ceiling": ceiling, "pass": actual <= ceiling}
        decisions[name] = verdict
    return decisions


def exercise(lane, command, data, output, results, rows=None):
    rows = workloads() if rows is None else rows
    frozen = json.loads((ROOT / "camber/raw_budget.json").read_text())["lanes"][lane]
    for row in rows:
        name, _, _, _, body, status, expected, _ = row
        count = 50 if len(body) > 65536 else 10000
        pair = {kind: {"direct": []} for kind in ("raw", "scoped")}
        for repeat in range(3):
            for kind in (("raw", "scoped") if repeat % 2 == 0 else ("scoped", "raw")):
                stdout, rss, wall = guarded(command + [kind + "-direct", name, str(count)], 60)
                label, seconds, nanos, checksum = stdout.strip().split("\t")
                assert label == name and int(checksum) == ((status + len(expected)) * count) % 2**32, stdout
                pair[kind]["direct"].append({"microseconds_per_request": (int(seconds) + int(nanos) / 1e9) * 1e6 / count,
                                             "iterations": count, "sampled_peak_rss_kib": rss, "wall_seconds": wall})
        data["workloads"][name] = pair
        print(lane, name, "direct raw/scoped", *(round(statistics.median(x['microseconds_per_request'] for x in pair[k]['direct']), 3) for k in ('raw','scoped')), flush=True)
    output.write_text(json.dumps(results, indent=2) + "\n")
    verified = set()
    for row in rows:
        name, profile = row[:2]
        for kind in ("raw", "scoped"):
            data["workloads"][name][kind].update(saturation=[], fixed_rate=[])
        for repeat in range(3):
            for kind in (("raw", "scoped") if repeat % 2 == 0 else ("scoped", "raw")):
                server = Server(command, profile, row, operation=kind + "-serve")
                try:
                    if (kind, profile) not in verified:
                        probes(server, profile)
                        verified.add((kind, profile))
                    saturated = trial(server, row, 1.0, 2)
                    rate = frozen[name]["fixed_offered_requests_per_second"]
                    fixed = trial(server, row, 1.0, 2, rate)
                    data["workloads"][name][kind]["saturation"].append(saturated)
                    data["workloads"][name][kind]["fixed_rate"].append(fixed)
                    print(lane, kind, name, "paired live trial", repeat + 1, "PASS", flush=True)
                finally:
                    server.close()
                data["servers"][f"{kind}-{profile}-{name}-{repeat}"] = {
                    "post_spawn_ready_seconds": server.startup_seconds, "sampled_peak_rss_kib": server.peak_kib,
                    "cpu_seconds": server.cpu}
                output.write_text(json.dumps(results, indent=2) + "\n")
    data["budget_evaluation"] = evaluate(data["workloads"], frozen)
    output.write_text(json.dumps(results, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--workload", action="append", choices=[row[0] for row in workloads()])
    args = parser.parse_args()
    results = {"platform": platform.platform(), "bend": subprocess.check_output(["bend", "version"], text=True).strip(),
               "bun": subprocess.check_output(["bun", "--version"], text=True).strip(), "warmup_iterations": 100,
               "live_duration_seconds": 1, "trials": 3, "concurrency": 2, "lanes": {}}
    with tempfile.TemporaryDirectory(prefix="camber-lifecycle-") as directory:
        temp = Path(directory).resolve()
        entry = generate(temp)
        for lane in ("native", "js"):
            executable = temp / ("paired" if lane == "native" else "paired.js")
            _, rss, seconds = guarded(["bend", str(entry), "-o", str(executable)], 180)
            command = [str(executable), "--threads", "1", "--gpu", "off"] if lane == "native" else ["bun", str(executable)]
            data = {"build_seconds": seconds, "sampled_build_peak_rss_kib": rss, "artifact_bytes": executable.stat().st_size,
                    "workloads": {}, "servers": {}}
            results["lanes"][lane] = data
            exercise(lane, command, data, args.output, results, [row for row in workloads() if not args.workload or row[0] in args.workload])
    failures = {lane: [name for name, row in data["budget_evaluation"].items() if not row["direct_pass"] or not row["throughput_pass"] or not all(x["pass"] for x in row["latency"].values())] for lane, data in results["lanes"].items()}
    print("Budget failures (not hidden):", failures)


if __name__ == "__main__":
    main()
