// Postgres result decode benchmark in JavaScript with pg-protocol, the codec under `pg` (see README.md). run.py copies this next to out/js/node_modules.
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";

const { Parser } = createRequire(import.meta.url)("pg-protocol/dist/parser");
const data = readFileSync("out/result.pgwire");

const t0 = performance.now();
const parser = new Parser();
const msgs = [];
// 64 KiB at a time, as a socket delivers it.
for (let i = 0; i < data.length; i += 65536) parser.parse(data.subarray(i, i + 65536), (m) => msgs.push(m));
const t1 = performance.now();

const m = (h, x) => (Math.imul(h, 31) + x) >>> 0;
// pg-protocol decodes names, values, and the tag as UTF-8 strings; these give back their bytes.
const s = (h, str) => {
  const b = Buffer.from(str);
  h = m(h, b.length);
  for (const x of b) h = m(h, x);
  return h;
};
// The checksum in run.py.
let h = 0;
for (const msg of msgs) {
  if (msg.name === "rowDescription") {
    h = m(h, 1);
    for (const f of msg.fields) h = m(s(h, f.name), f.dataTypeID);
    h = m(h, 2);
  } else if (msg.name === "dataRow") {
    h = m(h, 3);
    for (const v of msg.fields) h = v === null ? m(h, 4) : s(m(h, 5), v);
    h = m(h, 6);
  } else if (msg.name === "commandComplete") {
    h = s(m(h, 7), msg.text);
  } else if (msg.name !== "readyForQuery") {
    throw new Error(`unexpected ${msg.name}`);
  }
}
console.log(`decode\t${(t1 - t0).toFixed(3)}\t${h}`);
