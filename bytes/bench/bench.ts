const L = Number(process.argv[2] ?? 28);
const N = 1 << L;
const reads = Number(process.argv[3] ?? 1 << 24);
const b1 = Number(process.argv[4] ?? 1000000);
const b2 = Number(process.argv[5] ?? 4000000);
const count = Math.max(1, Number(process.env.BYTES_BENCH_COUNT ?? 1));
const warmup = Number(process.env.BYTES_BENCH_WARMUP ?? 0);

function measure(name: string, operation: () => number) {
  for (let i = 0; i < warmup; i++) operation();
  let last = 0, total = 0;
  const t0 = performance.now();
  for (let i = 0; i < count; i++) {
    last = operation();
    total = (total + last) >>> 0;
  }
  const ms = performance.now() - t0;
  console.log(`${name}\t${ms}\t${last}\t${count}\t${total}`);
}

function fillBuf(n: number): Uint8Array {
  const b = new Uint8Array(n);
  for (let i = 0; i < n; i++) b[i] = (i * 31 + 7) & 255;
  b.set([13, 10, 13, 10], n - 4);
  return b;
}

measure("fill", () => {
  const b = fillBuf(N);
  return b[12345 % N] + b[N - 1];
});
const b = fillBuf(N);
measure("sum", () => {
  let sum = 0;
  for (let i = 0; i < N; i++) sum = (sum + b[i]) >>> 0;
  return sum;
});
const needle = Buffer.from([13, 10, 13, 10]);
const buf = Buffer.from(b.buffer, b.byteOffset, b.byteLength);
measure("find", () => buf.indexOf(needle));
measure("slice", () => {
  const out = Buffer.from(buf.subarray(N / 4 + 1, N / 4 + 1 + N / 2));
  return out[0] + out[out.length - 1];
});
measure("concat", () => {
  const chunks: Buffer[] = [];
  const chunkSize = Math.min(N, 65536);
  for (let k = 0; k < N / chunkSize; k++) chunks.push(Buffer.alloc(chunkSize, k & 255));
  const out = Buffer.concat(chunks);
  if (out.length !== N) throw new Error("concat length");
  return out[0] + out[out.length - 1];
});
measure("random", () => {
  let x = 1, acc = 0;
  for (let i = 0; i < reads; i++) {
    x = (Math.imul(x, 1664525) + 1013904223) >>> 0;
    acc = (acc + b[x >>> (32 - L)]) >>> 0;
  }
  return acc;
});
const c = Buffer.from(buf);
measure("equal", () => buf.equals(c) ? 1 : 0);
for (const size of [b1, b2]) {
  measure(`build_${size}`, () => {
    let out = new Uint8Array(1);
    for (let i = 0; i < size; i++) {
      if (i === out.length) {
        const grown = new Uint8Array(out.length * 2);
        grown.set(out);
        out = grown;
      }
      out[i] = i & 255;
    }
    return size + out[size - 1];
  });
}
