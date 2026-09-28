// RESP decode benchmark in JavaScript with ioredis's RESP3 decoder (see README.md). run.py copies this next to out/js/node_modules.
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";

const { Decoder, RESP_TYPES } = createRequire(import.meta.url)("ioredis/built/resp/decoder.js");
// Strings as Buffers and maps as Map (keys keep their order). Integers are numbers, exact below 2^53.
const types = {
  [RESP_TYPES.SIMPLE_STRING]: Buffer,
  [RESP_TYPES.BLOB_STRING]: Buffer,
  [RESP_TYPES.MAP]: Map,
};
const replies = [];
const decoder = new Decoder({
  onReply: (r) => replies.push(r),
  onErrorReply: (e) => { throw e; },
  onPush: (p) => replies.push(p),
  getTypeMapping: () => types,
});
const data = readFileSync("out/replies.resp");

const t0 = performance.now();
for (let i = 0; i < data.length; i += 65536) decoder.write(data.subarray(i, i + 65536));
const t1 = performance.now();

const m = (h, x) => (Math.imul(h, 31) + x) >>> 0;
// The pre-order checksum in run.py.
function walk(v, h) {
  if (v === null) return m(h, 3);
  if (typeof v === "boolean") return m(m(h, 8), v ? 1 : 0);
  if (typeof v === "number") return m(m(h, 2), Number(BigInt.asUintN(32, BigInt(v))));
  if (Buffer.isBuffer(v)) {
    h = m(m(h, 1), v.length);
    for (const b of v) h = m(h, b);
    return h;
  }
  if (Array.isArray(v)) {
    h = m(h, 4);
    for (const x of v) h = walk(x, h);
    return m(h, 5);
  }
  // The decoder turns map keys into UTF-8 strings; these keys are ASCII, so their bytes survive.
  h = m(h, 6);
  for (const [k, x] of v) h = walk(x, walk(Buffer.from(k), h));
  return m(h, 7);
}
let h = 0;
for (const v of replies) h = walk(v, h);
h = (h + replies.length) >>> 0;
console.log(`decode\t${(t1 - t0).toFixed(3)}\t${h}`);
