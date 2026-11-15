import heapq
import time

start = time.perf_counter_ns()
queue = []
for i in range(1024):
    heapq.heappush(queue, ((i * 37) % 64, i))
checksum = 0
while queue:
    deadline, identifier = heapq.heappop(queue)
    checksum = (checksum * 31 + identifier) & 0xffffffff
print(f"{(time.perf_counter_ns() - start) / 1e6:.6f}\t{checksum}")
