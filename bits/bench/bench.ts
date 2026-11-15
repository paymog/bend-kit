// Bits benchmark in JavaScript: inflateRawSync on the raw DEFLATE payload. Bun and Node ship no bit reader.
import { readFileSync } from "node:fs";
import { inflateRawSync } from "node:zlib";

const data = readFileSync("out/payload.bin");
const t = performance.now();
const out = inflateRawSync(data);
const ms = performance.now() - t;
let h = 0;
for (const b of out) h = (Math.imul(h, 31) + b) >>> 0;
console.log(`huffman\t${ms.toFixed(3)}\t${h}`);
