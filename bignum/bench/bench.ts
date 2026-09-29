// BigInt benchmark: the JavaScript side, with BigInt (see README.md).
const M = "170141183460469231731687303715884105727";
const X = "123456789012345678901234567890123456789";
const A = "98765432109876543210987654321098765432";
const N = 64;

const t0 = performance.now();
const m = BigInt(M), a = BigInt(A);
let x = BigInt(X), acc = x, q = 0n;
for (let i = 0; i < N; i++) {
  const y = x * x + a;
  q = y / m;
  x = y % m;
  acc += x;
}
const chk = acc.toString();
console.log(`modsq\t${(performance.now() - t0).toFixed(3)}\t${chk}`);
if (q < 0n) console.log(q); // keeps the quotient live
