// Shortest F32 benchmark: the JavaScript side (see README.md). Argument: N.
// JavaScript has no float32 printer; the obvious loop tries 1 to 9 digits
// until Math.fround reads x back.
const n = Number(process.argv[2] ?? 50000);

function shortest(x: number): string {
  if (Number.isNaN(x)) return "nan";
  if (!Number.isFinite(x)) return x < 0 ? "-inf" : "inf";
  if (x === 0) return Object.is(x, -0) ? "-0.0" : "0.0";
  let sci = "";
  for (let p = 0; p < 9; p++) {
    sci = Math.abs(x).toExponential(p);
    if (Math.fround(Number(sci)) === Math.abs(x)) break;
  }
  const [m, es] = sci.split("e");
  const e = Number(es);
  let d = m.replace(".", "");
  // toExponential breaks an exact tie upward; step an odd last digit down to even.
  const p = d.length - 1, wide = Math.abs(x).toExponential(Math.min(p + 40, 100));
  const tail = wide.split("e")[0].replace(".", "").slice(p + 1);
  if (/^50*$/.test(tail) && Number(d[p]) % 2 === 1)
    d = d.slice(0, p) + String(Number(d[p]) - 1);
  while (d.length > 1 && d.endsWith("0")) d = d.slice(0, -1);
  const sign = x < 0 ? "-" : "";
  if (e < -4 || e >= 16)
    return `${sign}${d[0]}${d.length > 1 ? "." + d.slice(1) : ""}e${e < 0 ? "-" : "+"}${String(Math.abs(e)).padStart(2, "0")}`;
  if (e < 0) return `${sign}0.${"0".repeat(-e - 1)}${d}`;
  if (e + 1 >= d.length) return `${sign}${d}${"0".repeat(e + 1 - d.length)}.0`;
  return `${sign}${d.slice(0, e + 1)}.${d.slice(e + 1)}`;
}

const words = new Uint32Array(n);
let s = 1;
for (let i = 0; i < n; i++) words[i] = s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
const fs = new Float32Array(words.buffer);
const t0 = performance.now();
let h = 2166136261;
const enc = new TextEncoder();
for (let i = 0; i < n; i++) {
  for (const c of enc.encode(shortest(fs[i]) + "\n")) h = Math.imul(h ^ c, 16777619) >>> 0;
}
console.log(`short\t${(performance.now() - t0).toFixed(3)}\t${h}`);
