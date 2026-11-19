// Text benchmark: jsdiff and fastest-levenshtein (see README.md). No popular wrap library.
import { diffArrays } from "diff";
import { distance } from "fastest-levenshtein";

function lcg(x: number): number {
  return (Math.imul(x, 1103515245) + 12345) & 0x7fffffff;
}

function word(x: number): [string, number] {
  x = lcg(x);
  const n = 4 + ((x >>> 16) % 9);
  let w = "";
  for (let i = 0; i < n; i++) {
    x = lcg(x);
    w += String.fromCharCode(97 + ((x >>> 16) % 26));
  }
  return [w, x];
}

function report(op: string, t0: number, chk: string) {
  console.log(`${op}\t${(performance.now() - t0).toFixed(3)}\t${chk}`);
}

const s = Number(process.argv[2] ?? 1);
const n = s * 10000;
const a: string[] = [];
const b: string[] = [];
for (let i = 0; i < n; i++) {
  a.push(`line ${i}`);
  if (i % 50 === 7) b.push(`changed ${i}`);
  else if (i % 70 !== 11) b.push(`line ${i}`);
  if (i % 90 === 13) b.push(`added ${i}`);
}

let t0 = performance.now();
let changes = 0;
for (const c of diffArrays(a, b)) if (c.added || c.removed) changes += c.count ?? c.value.length;
report("diff", t0, String(changes));

t0 = performance.now();
let acc = 0;
let x = 1;
for (let i = 0; i < s * 20000; i++) {
  const [w1, x1] = word(x);
  const [w2, x2] = word(x1);
  x = x2;
  acc = (acc + distance(w1, w2)) >>> 0;
}
report("distance", t0, String(acc));
