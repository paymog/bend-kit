import sys
import time
import bench_pb2

loops = int(sys.argv[1]) if len(sys.argv) > 1 else 100
input_bytes = open("fixture.bin", "rb").read()
checksum = 0
start = time.perf_counter()
for _ in range(loops):
    message = bench_pb2.Sample.FromString(input_bytes)
    checksum += sum(message.SerializeToString())
print(f"{checksum}\t{(time.perf_counter() - start) * 1000:.6f}")
