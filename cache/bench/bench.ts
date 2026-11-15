// Cache benchmark: lru-cache with a ttl (see README.md).
import { LRUCache } from "lru-cache";

const rounds = 1 << Number(process.argv[2] ?? 12);
const keys = Array.from({ length: 64 }, (_, i) => `k${i}`);
const cache = new LRUCache<string, [number, number]>({ max: 64, ttl: 1e9 });
let chk = 0;
const t0 = performance.now();
for (let i = 0; i < rounds; i++) {
  const v = i + 1;
  for (const k of keys) cache.set(k, [v, v]);
  for (const k of keys) {
    for (let r = 0; r < 8; r++) {
      const e = cache.get(k);
      if (e !== undefined) chk = (chk + e[1]) >>> 0;
    }
  }
}
const t1 = performance.now();
console.log(`cache\t${(t1 - t0).toFixed(3)}\t${chk}`);
