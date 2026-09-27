// Integer benchmark: the JavaScript side (see README.md). Argument: N.
// JavaScript has no u64, so this uses BigInt with BigInt.asUintN(64).
const n = Number(process.argv[2] ?? 16384);
const a = 6364136223846793005n, c = 1442695040888963407n, m = 1000003n;

let t0 = performance.now();
let x = 1n;
for (let i = 0; i < n; i++) x = BigInt.asUintN(64, x * a + c);
console.log(`lcg\t${(performance.now() - t0).toFixed(3)}\t${x}`);

const xs: bigint[] = [];
let s = 1;
for (let i = 0; i < n; i++) {
  const hi = (Math.imul(s, 1664525) + 1013904223) >>> 0;
  const lo = (Math.imul(hi, 1664525) + 1013904223) >>> 0;
  s = lo;
  xs.push((BigInt(hi) << 32n) | BigInt(lo));
}
t0 = performance.now();
let acc = 0n;
for (const v of xs) acc = BigInt.asUintN(64, acc + (v % m));
console.log(`rem\t${(performance.now() - t0).toFixed(3)}\t${acc}`);
