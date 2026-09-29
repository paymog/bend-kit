# BigInt benchmark: the Python side, with int (see README.md).
import time

M, X, A, N = "170141183460469231731687303715884105727", "123456789012345678901234567890123456789", "98765432109876543210987654321098765432", 64

t0 = time.perf_counter()
m, x, a = int(M), int(X), int(A)
acc = x
for _ in range(N):
    _, x = divmod(x * x + a, m)
    acc += x
chk = str(acc)
print(f"modsq\t{(time.perf_counter() - t0) * 1e3:.3f}\t{chk}")
