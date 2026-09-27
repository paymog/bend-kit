// Time benchmark: JavaScript (Bun and Node, see README.md).
const N = 4096;
const T0 = -2208988800;
const STEP = 3155761;

const start = performance.now();
let chk = 0;
let t = T0;
for (let i = 0; i < N; i++) {
  // toISOString always writes milliseconds; the Bend side leaves out a zero fraction.
  const s = new Date(t * 1000).toISOString().replace(".000Z", "Z");
  const back = Date.parse(s) / 1000;
  let sum = 0;
  for (let j = 0; j < s.length; j++) sum += s.charCodeAt(j);
  chk = (chk + sum + back) >>> 0;
  t += STEP;
}
const ms = performance.now() - start;
console.log(`trip\t${ms.toFixed(3)}\t${chk}`);
