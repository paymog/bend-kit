#!/usr/bin/env python3
"""Compare interleaved fixed and counterbalanced JavaScript blocks."""
import statistics

import run

BLOCKS = ["fixed", "balanced", "balanced", "fixed", "fixed", "balanced"]


def orders(schedule):
    return [run.CONTROLS] * 4 if schedule == "fixed" else run.CONTROL_ORDERS


def delta(result, path, op):
    return result[f"{path}_warm_{op}"][0] - result[f"{path}_cold_{op}"][0]


def main():
    # Keep the six-language small and full checksum gates before the experiment.
    run.RUNS = 1
    run.main()
    reference = run.execute("C", run.VARIANTS["C"][1], 2097152)
    run.check_rows("C", reference)
    blocks = {name: {schedule: [] for schedule in set(BLOCKS)} for name in ("Bun", "Node")}
    print("\nInterleaved blocks: " + " -> ".join(BLOCKS), flush=True)
    for index, schedule in enumerate(BLOCKS, 1):
        names = ("Bun", "Node") if index % 2 else ("Node", "Bun")
        print(f"Block {index}: {schedule}; runtime order: {' -> '.join(names)}", flush=True)
        for name in names:
            results = []
            for number, order in enumerate(orders(schedule), 1):
                print(f"{name} block {index} run {number}: {' -> '.join(order)}", flush=True)
                result = run.execute(name, run.VARIANTS[name][1], 2097152, order)
                run.check_rows(name, result)
                if any(result[op][1] != reference[op][1] for op in run.OPS):
                    raise SystemExit(f"full input checksum mismatch: {name} block {index} run {number}")
                results.append(result)
            blocks[name][schedule].append(results)
            print("| path and op | run 1 | run 2 | run 3 | run 4 | block median | min | max |", flush=True)
            print("|---|---:|---:|---:|---:|---:|---:|---:|", flush=True)
            for path in ("shared", "direct"):
                for op in ("identity", "gcd", "lcm", "isqrt"):
                    values = [delta(result, path, op) for result in results]
                    summary = [*values, statistics.median(values), min(values), max(values)]
                    print(f"| {path} {op} | " + " | ".join(f"{v:+.3f}" for v in summary) + " |", flush=True)
    print("\nSchedule comparison (ms; spread is max minus min of block medians):")
    print("| runtime | path and op | fixed blocks | balanced blocks | balanced-fixed | fixed spread | balanced spread |")
    print("|---|---|---|---|---:|---:|---:|")
    for name, schedules in blocks.items():
        for path in ("shared", "direct"):
            for op in ("identity", "gcd", "lcm", "isqrt"):
                fixed, balanced = [
                    [statistics.median(delta(result, path, op) for result in block) for block in schedules[schedule]]
                    for schedule in ("fixed", "balanced")
                ]
                columns = [", ".join(f"{v:+.3f}" for v in values) for values in (fixed, balanced)]
                difference = statistics.median(balanced) - statistics.median(fixed)
                print(f"| {name} | {path} {op} | {' | '.join(columns)} | {difference:+.3f} | "
                      f"{max(fixed) - min(fixed):.3f} | {max(balanced) - min(balanced):.3f} |")


if __name__ == "__main__":
    main()
