// Crypto benchmark in JavaScript (Bun and Node): SHA-256 of 16 MiB of zero bytes with node:crypto.
import { createHash } from "node:crypto";

const data = new Uint8Array(16_777_216);
const t0 = performance.now();
const h = createHash("sha256").update(data).digest("hex");
const t1 = performance.now();
console.log(`sha256\t${(t1 - t0).toFixed(3)}\t${h}`);
