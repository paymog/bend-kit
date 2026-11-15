const buf = new ArrayBuffer(8);
const u32 = new Uint32Array(buf);
const f64 = new Float64Array(buf);

function mix(x: number): number {
  f64[0] = x;
  return (u32[0] ^ u32[1]) >>> 0;
}

function xs(x: number): number {
  x = (x ^ (x << 13)) >>> 0;
  x = (x ^ (x >>> 17)) >>> 0;
  return (x ^ (x << 5)) >>> 0;
}

function mean(v: Float64Array): number {
  let s = 0;
  for (const x of v) s += x;
  return s / v.length;
}

function variance(v: Float64Array): number {
  const m = mean(v);
  let s = 0;
  for (const x of v) s += (x - m) * (x - m);
  return s / (v.length - 1);
}

function median(v: Float64Array): number {
  const s = v.slice().sort();
  const i = (s.length - 1) >> 1;
  return (s.length - 1) % 2 ? s[i] + 0.5 * (s[i + 1] - s[i]) : s[i];
}

function histogram(v: Float64Array): number {
  const edges = Array.from({length: 101}, (_, i) => i * 10486);
  const counts = new Uint32Array(100);
  for (const x of v) {
    if (!(edges[0] <= x && x <= edges[100])) continue;
    let lo = 1, hi = 100;
    while (lo < hi) {
      const mid = lo + ((hi - lo) >> 1);
      if (x < edges[mid]) hi = mid;
      else lo = mid + 1;
    }
    counts[lo - 1]++;
  }
  return counts.reduce((sum, n, i) => sum + (i + 1) * n, 0);
}

const v = new Float64Array(10000);
let x = 44;
for (let i = 0; i < v.length; i++) {
  x = xs(x);
  v[i] = x >>> 12;
}

for (const [op, f] of [["mean", mean], ["variance", variance], ["median", median], ["histogram", histogram]] as const) {
  const t0 = performance.now();
  const r = f(v);
  console.log(`${op}\t${(performance.now() - t0).toFixed(3)}\t${mix(r)}`);
}
