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

function mix(x) {
  f64[0] = x;
  return (u32[0] ^ u32[1]) >>> 0;
}

function xs(x) {
  x = (x ^ (x << 13)) >>> 0;
  x = (x ^ (x >>> 17)) >>> 0;
  return (x ^ (x << 5)) >>> 0;
}

const v = [
  f(1072693248, 0),
  f(1073217536, 0),
  f(1074266112, 0),
  f(1017118720, 0),
  f(0, 1),
  f(3220176896, 0),
];

let t0 = performance.now();
let h = 0;
for (const a of v) {
  for (const b of v) {
    h = (h ^ hi(a + b) ^ hi(a * b) ^ hi(a / b)) >>> 0;
  }
}
console.log(`fold\t${(performance.now() - t0).toFixed(3)}\t${h}`);

const nums = [];
let x = 611;
for (let i = 0; i < 1000; i++) {
  const a = xs(x);
  const b = xs(a);
  x = b;
  if (((a >>> 20) & 2047) !== 2047) nums.push(f(a, b));
}

function checksum(text) {
  let h = 0;
  for (const s of text) h = (h ^ mix(Number(s))) >>> 0;
  return h;
}

t0 = performance.now();
const text = nums.map((x) => String(x));
console.log(`show\t${(performance.now() - t0).toFixed(3)}\t${checksum(text)}`);

t0 = performance.now();
h = checksum(text);
console.log(`read\t${(performance.now() - t0).toFixed(3)}\t${h}`);

t0 = performance.now();
h = 0;
for (const x of nums) h = (h ^ mix(Math.sqrt(Math.abs(x)))) >>> 0;
console.log(`sqrt\t${(performance.now() - t0).toFixed(3)}\t${h}`);
