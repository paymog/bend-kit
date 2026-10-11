// Journal recovery benchmark: node:zlib crc32 and a straight scan (see README.md).
import zlib from "node:zlib";

const lg = Number(process.argv[2] ?? 20);
const n = 1 << lg;
const chunks: Uint8Array[] = [];
let total = 0;
for (let i = 0; i < n; i++) {
  const plen = 16 + ((i * 7) % 48);
  const frame = new Uint8Array(12 + plen);
  const view = new DataView(frame.buffer);
  for (let j = 0; j < plen; j++) frame[12 + j] = (i * 31 + j) & 255;
  const sum = zlib.crc32(frame.subarray(12)) >>> 0;
  view.setUint32(0, plen, true);
  view.setUint32(4, ~plen >>> 0, true);
  view.setUint32(8, sum, true);
  chunks.push(frame);
  total += frame.length;
}
const buf = new Uint8Array(total);
let w = 0;
for (const chunk of chunks) {
  buf.set(chunk, w);
  w += chunk.length;
}
const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);

const t0 = performance.now();
let acc = 0;
let count = 0;
let off = 0;
while (off + 12 <= buf.length) {
  const plen = view.getUint32(off, true);
  const nlen = view.getUint32(off + 4, true);
  const want = view.getUint32(off + 8, true);
  if (nlen !== (~plen >>> 0) || plen > 64 || off + 12 + plen > buf.length) {
    console.error("bad frame");
    process.exit(1);
  }
  const payload = buf.subarray(off + 12, off + 12 + plen);
  if ((zlib.crc32(payload) >>> 0) !== want) {
    console.error("bad frame");
    process.exit(1);
  }
  acc = (Math.imul(acc, 31) + plen + payload[0]) >>> 0;
  count++;
  off += 12 + plen;
}
if (off !== buf.length || count !== n) {
  console.error("bad frame");
  process.exit(1);
}
const t1 = performance.now();
console.log(`recover\t${(t1 - t0).toFixed(3)}\t${acc}\t${count}`);
