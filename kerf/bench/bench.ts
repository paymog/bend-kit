// Log line benchmark: the JavaScript side (see README.md). Argument: N.
const n = Number(process.argv[2] ?? 20000);
const xs = new Uint32Array(n);
let s = 1;
for (let i = 0; i < n; i++) xs[i] = s = (Math.imul(s, 1664525) + 1013904223) >>> 0;

const t0 = performance.now();
let h = 2166136261;
const enc = new TextEncoder();
for (const x of xs) {
  const rec = { time: "2026-09-27T12:00:00Z", level: "INFO", msg: "request done", svc: "api",
    user: `u"${x % 1000}`, id: x, ok: (x & 1) === 1 };
  for (const c of enc.encode(JSON.stringify(rec) + "\n")) h = Math.imul(h ^ c, 16777619) >>> 0;
}
console.log(`json\t${(performance.now() - t0).toFixed(3)}\t${h}`);
