#!/usr/bin/env python3
"""Check controlled process positions and immediate predecessors."""
from collections import Counter
from unittest.mock import patch
from contextlib import redirect_stdout
from io import StringIO

import run
import blocks

orders = run.CONTROL_ORDERS
assert len(orders) == 4
assert all(sorted(order) == sorted(run.CONTROLS) for order in orders)
assert all(len(set(column)) == 4 for column in zip(*orders))
assert Counter((a, b) for order in orders for a, b in zip(order, order[1:])) == Counter(
    (a, b) for a in run.CONTROLS for b in run.CONTROLS if a != b
)
for order in orders:
    def execute(command, **kwargs):
        mode = command[-1]
        text = "" if mode == "16" else "\n".join(
            f"{mode}_{op}\t1.000\t42" for op in ["identity", "gcd", "lcm", "isqrt"]
        )
        return type("Result", (), {"returncode": 0, "stdout": text})()

    with patch.object(run.subprocess, "run", side_effect=execute) as process:
        result = run.execute("Bun", ["bun", "bench.ts"], 16, order)
        assert [call.args[0][-1] for call in process.call_args_list[1:]] == order
        assert set(result) == set(run.CONTROL_OPS)
assert Counter(blocks.BLOCKS) == {"fixed": 3, "balanced": 3}
assert blocks.orders("fixed") == [run.CONTROLS] * 4
assert blocks.orders("balanced") == orders
assert blocks.delta({"shared_warm_gcd": (1, "42"), "shared_cold_gcd": (3, "42")}, "shared", "gcd") == -2
rows = {op: (3.0, "42") for op in run.OPS + run.WARM_PACKED + run.CONTROL_OPS}
for path in ("shared", "direct"):
    for op in ("identity", "gcd", "lcm", "isqrt"):
        rows[f"{path}_warm_{op}"] = (1.0, "42")
output = StringIO()
def measure(name, *args):
    return {op: rows[op] for op in run.OPS} if name == "C" else rows


with patch.object(run, "main"), patch.object(run, "execute", side_effect=measure) as process, redirect_stdout(output):
    blocks.main()
assert process.call_count == 49
expected = [
    (name, order)
    for index, schedule in enumerate(blocks.BLOCKS, 1)
    for name in (("Bun", "Node") if index % 2 else ("Node", "Bun"))
    for order in blocks.orders(schedule)
]
assert [(call.args[0], call.args[3]) for call in process.call_args_list[1:]] == expected
assert "| shared gcd | -2.000 | -2.000 | -2.000 | -2.000 | -2.000 | -2.000 | -2.000 |" in output.getvalue()
print("controlled process order checks pass")
