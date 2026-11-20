"""Planner benchmark: graphlib.TopologicalSorter (see README.md)."""
import sys
import time
from graphlib import TopologicalSorter

rounds = int(sys.argv[1]) if len(sys.argv) > 1 else 4
n = 1000
tasks = [(f"n{i}", [f"n{j}" for j in range(i + 1, min(i + 4, n))]) for i in range(n)]
chk = 0
t0 = time.perf_counter()
for _ in range(rounds):
    ts = TopologicalSorter()
    for node, deps in tasks:
        ts.add(node, *deps)
    for node in ts.static_order():
        chk += 1 + int(node[1:])
chk &= 0xFFFFFFFF
t1 = time.perf_counter()
print(f"plan\t{(t1 - t0) * 1e3:.3f}\t{chk}")
