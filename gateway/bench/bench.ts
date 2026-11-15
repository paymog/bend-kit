// Gateway benchmark: the JavaScript side (see README.md).
const CAPACITY = 4;
const TTL = 1_000_000;

function allowed(method: string, roles: string[]): boolean {
  return !roles.includes("suspended") && method === "GET" && roles.includes("reader");
}

const rounds = 2 ** Number(process.argv[2] ?? 10);
const keys = Array.from({ length: 64 }, (_, i) => `k${i}`);
const roles = ["reader"];
const t0 = performance.now();
const cache = new Map<string, [string, number]>();
let inUse = 0;
for (const k of keys) {
  if (allowed("GET", roles) && inUse < CAPACITY) {
    inUse++;
    cache.set(k, [k, 0 + TTL]);
    inUse--;
  }
}
let acc = 0;
for (let r = 0; r < rounds; r++) {
  for (const k of keys) {
    for (let j = 0; j < 8; j++) {
      if (!allowed("GET", roles) || inUse >= CAPACITY) continue;
      inUse++;
      const e = cache.get(k);
      if (e !== undefined && 0 < e[1]) acc = (acc + e[0].length) >>> 0;
      inUse--;
    }
  }
}
const ms = performance.now() - t0;
console.log(`gateway\t${ms.toFixed(3)}\t${acc}`);
