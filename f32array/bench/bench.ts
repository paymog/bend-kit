const N = 1 << 22;

const ms = (t: number) => performance.now() - t;
const ends = (x: Float32Array) => Math.trunc(x[N - 1] + x[12345]);

const src = new Float32Array(N);
const b = new Float32Array(N);
for (let i = 0; i < N; i++) {
  src[i] = (i + 3) & 3;
  b[i] = (i * 5 + 3) & 3;
}
const bytes = new Uint8Array(N * 4);
const view = new DataView(bytes.buffer);
for (let i = 0; i < N; i++) view.setFloat32(i * 4, src[i], true);

let t = performance.now();
const a = new Float32Array(bytes.slice().buffer); // little-endian host
console.log(`from_bytes\t${ms(t).toFixed(6)}\t${ends(a)}`);

t = performance.now();
let s = Math.fround(0);
for (let i = 0; i < N; i++) s = Math.fround(s + a[i]);
console.log(`sum\t${ms(t).toFixed(6)}\t${Math.trunc(s)}`);

t = performance.now();
let m = a[0];
for (let i = 1; i < N; i++) m = a[i] > m ? a[i] : m;
console.log(`max\t${ms(t).toFixed(6)}\t${Math.trunc(m)}`);

t = performance.now();
let d = Math.fround(0);
for (let i = 0; i < N; i++) d = Math.fround(d + Math.fround(a[i] * b[i]));
console.log(`dot\t${ms(t).toFixed(6)}\t${Math.trunc(d)}`);

t = performance.now();
for (let i = 0; i < N; i++) a[i] *= 2;
console.log(`map\t${ms(t).toFixed(6)}\t${ends(a)}`);

t = performance.now();
for (let i = 0; i < N; i++) a[i] += b[i];
console.log(`add\t${ms(t).toFixed(6)}\t${ends(a)}`);

t = performance.now();
const out = new Uint8Array(a.buffer.slice(0));
console.log(`to_bytes\t${ms(t).toFixed(6)}\t${out.length + out[out.length - 1]}`);
