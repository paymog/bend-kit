// CBOR benchmark in JavaScript with cbor-x (see README.md). run.py copies this next to out/js/node_modules.
import { readFileSync } from "node:fs";
import { Decoder, Encoder } from "cbor-x";

// Plain objects for text-keyed maps; minimal map headers and no record extension, so output is preferred CBOR.
const dec = new Decoder({ mapsAsObjects: true });
const enc = new Encoder({ mapsAsObjects: true, useRecords: false, variableMapSize: true });
const data = readFileSync("out/doc.cbor");

const t0 = performance.now();
const value = dec.decode(data);
const t1 = performance.now();
const out = enc.encode(value);
const t2 = performance.now();

// Checksum: h = h*31 + b, u32, then add the length.
let h = 0;
for (const b of out) h = (Math.imul(h, 31) + b) >>> 0;
h = (h + out.length) >>> 0;
console.log(`decode\t${(t1 - t0).toFixed(3)}\t${h}`);
console.log(`encode\t${(t2 - t1).toFixed(3)}\t${h}`);
