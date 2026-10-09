// Resources benchmark: async-sema (see README.md).
import { Sema } from "async-sema";

const rounds = 1 << Number(process.argv[2] ?? 14);
const pool = new Sema(64);
let admitted = 0;
let refused = 0;
const t0 = performance.now();
for (let i = 0; i < rounds; i++) {
  for (let k = 0; k < 65; k++) {
    if (pool.tryAcquire() !== undefined) admitted++;
    else refused++;
  }
  for (let k = 0; k < 64; k++) pool.release();
}
const chk = (Math.imul(admitted, 31) + refused) >>> 0;
const t1 = performance.now();
console.log(`lease\t${(t1 - t0).toFixed(3)}\t${chk}`);
