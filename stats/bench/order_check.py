#!/usr/bin/env python3
"""Check controlled process positions and immediate predecessors."""
from collections import Counter
from unittest.mock import patch

import run

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
print("controlled process order checks pass")
