// scrypt benchmark in Node: one 32-octet key from N = 16384, r = 8, p = 1, with node:crypto scryptSync.
import { scryptSync } from "node:crypto";

const t0 = performance.now();
const key = scryptSync("pleaseletmein", "SodiumChloride", 32, { N: 16384, r: 8, p: 1, maxmem: 64 << 20 });
const t1 = performance.now();
console.log(`scrypt\t${(t1 - t0).toFixed(3)}\t${key.toString("hex")}`);
