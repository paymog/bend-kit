const L = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 28;
const N = 1 << L;
const reads = Number(process.argv[3] ?? 1 << 24);
const b1 = Number(process.argv[4] ?? 1000000);
const b2 = Number(process.argv[5] ?? 4000000);

function fillBuf(n: number): { b: Uint8Array; cs: number } {
  const b = new Uint8Array(n);
  for (let i = 0; i < n; i++) {
    b[i] = (i * 31 + 7) & 255;
  }
  b[n - 4] = 13;
  b[n - 3] = 10;
  b[n - 2] = 13;
  b[n - 1] = 10;
  const cs = b[12345 % n] + b[n - 1];
  return { b, cs };
}

let t0 = performance.now();
const { b, cs: fillCs } = fillBuf(N);
console.log(`fill\t${performance.now() - t0}\t${fillCs}`);

t0 = performance.now();
let sum = 0 >>> 0;
for (let i = 0; i < N; i++) {
  sum = (sum + b[i]) >>> 0;
}
console.log(`sum\t${performance.now() - t0}\t${sum}`);

const needle = Buffer.from([13, 10, 13, 10]);
const buf = Buffer.from(b.buffer, b.byteOffset, b.byteLength);
t0 = performance.now();
const findIdx = buf.indexOf(needle);
console.log(`find\t${performance.now() - t0}\t${findIdx}`);

const sliceStart = (N / 4 + 1) | 0;
const sliceLen = (N / 2) | 0;
t0 = performance.now();
const s = Buffer.from(buf.subarray(sliceStart, sliceStart + sliceLen));
const sliceCs = s[0] + s[s.length - 1];
console.log(`slice\t${performance.now() - t0}\t${sliceCs}`);

t0 = performance.now();
const chunks: Buffer[] = [];
const chunkSize = Math.min(N, 65536);
const numChunks = (N / chunkSize) | 0;
for (let k = 0; k < numChunks; k++) {
  chunks.push(Buffer.alloc(chunkSize, k & 255));
}
const out = Buffer.concat(chunks);
if (out.length !== N) {
  process.exit(1);
}
const concatCs = out[0] + out[out.length - 1];
console.log(`concat\t${performance.now() - t0}\t${concatCs}`);

let x = 1 >>> 0;
let acc = 0 >>> 0;
const shift = 32 - L;
t0 = performance.now();
for (let i = 0; i < reads; i++) {
  x = (Math.imul(x, 1664525) + 1013904223) >>> 0;
  const idx = x >>> shift;
  acc = (acc + b[idx]) >>> 0;
}
console.log(`random\t${performance.now() - t0}\t${acc}`);

const c = Buffer.from(buf);
t0 = performance.now();
const eq = buf.equals(c);
console.log(`equal\t${performance.now() - t0}\t${eq ? 1 : 0}`);

for (const size of [b1, b2]) {
  t0 = performance.now();
  let built = new Uint8Array(1);
  for (let i = 0; i < size; i++) {
    if (i === built.length) {
      const grown = new Uint8Array(built.length * 2);
      grown.set(built);
      built = grown;
    }
    built[i] = i & 255;
  }
  const buildCs = size + built[size - 1];
  console.log(`build_${size}\t${performance.now() - t0}\t${buildCs}`);
}
