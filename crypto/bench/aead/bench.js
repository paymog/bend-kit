// AEAD benchmark in Node: 4,096 chained seals of 4 KiB with AES-256-GCM and ChaCha20-Poly1305, with node:crypto.
import { createCipheriv, createHash } from "node:crypto";

const N = 4096;
const M = 4096;
const key = Buffer.alloc(32, 0x42);

// Seal i encrypts the first M octets of seal i-1's output under nonce i (little-endian, then 8 zeros). No AAD.
function run(op, alg) {
  const nonce = Buffer.alloc(12);
  let out = Buffer.alloc(M + 16);
  const t0 = performance.now();
  for (let i = 0; i < N; i += 1) {
    nonce.writeUInt32LE(i, 0);
    const c = createCipheriv(alg, key, nonce, { authTagLength: 16 });
    out = Buffer.concat([c.update(out.subarray(0, M)), c.final(), c.getAuthTag()]);
  }
  const t1 = performance.now();
  console.log(`${op}\t${(t1 - t0).toFixed(3)}\t${createHash("sha256").update(out).digest("hex")}`);
}

run("aes-256-gcm", "aes-256-gcm");
run("chacha20-poly1305", "chacha20-poly1305");
