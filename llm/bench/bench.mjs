// SSE parse benchmark in JavaScript with eventsource-parser (see README.md). run.py copies this next to out/js/node_modules.
import { readFileSync } from "node:fs";
import { createParser } from "eventsource-parser";

const data = readFileSync("out/stream.sse");
const events = [];

const t0 = performance.now();
const parser = createParser({ onEvent: (e) => events.push(e) });
const dec = new TextDecoder();
for (let i = 0; i < data.length; i += 65536) parser.feed(dec.decode(data.subarray(i, i + 65536), { stream: true }));
const t1 = performance.now();

const m = (h, x) => (Math.imul(h, 31) + x) >>> 0;
const enc = new TextEncoder();
let h = 0;
for (const e of events) {
  h = m(h, 1);
  for (const b of enc.encode(e.event ?? "message")) h = m(h, b);
  h = m(h, 2);
  for (const b of enc.encode(e.data)) h = m(h, b);
}
h = (h + events.length) >>> 0;
console.log(`parse\t${(t1 - t0).toFixed(3)}\t${h}`);
