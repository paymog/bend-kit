const buf = new ArrayBuffer(8);
const u32 = new Uint32Array(buf);
const f64 = new Float64Array(buf);

function f(hi, lo) {
  u32[0] = lo;
  u32[1] = hi;
  return f64[0];
}

function hi(x) {
  f64[0] = x;
  return u32[1] >>> 0;
}

const xs = [
  f(1072693248, 0),
  f(1073217536, 0),
  f(1074266112, 0),
  f(1017118720, 0),
  f(0, 1),
  f(3220176896, 0),
];

const t0 = performance.now();
let h = 0;
for (const a of xs) {
  for (const b of xs) {
    h = (h ^ hi(a + b) ^ hi(a * b) ^ hi(a / b)) >>> 0;
  }
}
const ms = performance.now() - t0;
console.log(`fold\t${ms.toFixed(3)}\t${h}`);
