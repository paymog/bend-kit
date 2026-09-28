// Crypto benchmark in JavaScript (Bun and Node): SHA-256 of 16 MiB of zero bytes, and PBKDF2-HMAC-SHA-256, with node:crypto.
import { createHash, pbkdf2Sync } from "node:crypto";

const data = new Uint8Array(16_777_216);
let t0 = performance.now();
const h = createHash("sha256").update(data).digest("hex");
let t1 = performance.now();
console.log(`sha256\t${(t1 - t0).toFixed(3)}\t${h}`);
t0 = performance.now();
const k = pbkdf2Sync("password", "salt", 100_000, 32, "sha256").toString("hex");
t1 = performance.now();
console.log(`pbkdf2\t${(t1 - t0).toFixed(3)}\t${k}`);
