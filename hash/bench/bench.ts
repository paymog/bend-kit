// Hash benchmark in JavaScript (see README.md). Bun has every hash here but FNV and SipHash; Node has only CRC-32.
import zlib from "node:zlib";

const N = 16777213;
const buf = new Uint8Array(N);
for (let i = 0; i < N; i++) buf[i] = i % 251;

const hex = (x: number | bigint, w: number) => x.toString(16).padStart(w, "0");
const run = (name: string, w: number, f: () => number | bigint) => {
  const t0 = performance.now();
  const h = f();
  const t1 = performance.now();
  console.log(`${name}\t${(t1 - t0).toFixed(3)}\t${hex(h, w)}`);
};

if (typeof Bun !== "undefined") {
  run("crc32", 8, () => Bun.hash.crc32(buf));
  run("adler32", 8, () => Bun.hash.adler32(buf));
  run("xxh32", 8, () => Bun.hash.xxHash32(buf, 0));
  run("xxh64", 16, () => BigInt.asUintN(64, Bun.hash.xxHash64(buf, 0n)));
} else {
  run("crc32", 8, () => zlib.crc32(buf));
}
