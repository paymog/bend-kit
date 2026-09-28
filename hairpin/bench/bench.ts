// 1000 sequential GETs with fetch (undici in Node), a base URL, and a default header.
const base = "http://127.0.0.1:47840/api/";
const defaults = { "x-bench": "1" };

let sum = 0;
const t0 = performance.now();
for (let i = 0; i < 1000; i++) {
  const res = await fetch(new URL("item", base), { headers: defaults });
  const body = await res.arrayBuffer();
  sum = (sum + res.status + body.byteLength) >>> 0;
}
const ms = performance.now() - t0;
console.log(`get_1000\t${ms.toFixed(3)}\t${sum}`);
