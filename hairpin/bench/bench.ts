// 1000 sequential GETs with fetch (undici in Node), a base URL, and a default header.
// Then 1000 GETs of a flaky URL through ky's retry: each answers 503 with Retry-After: 0, then 200.
import ky from "ky";

const base = "http://127.0.0.1:47840/api/";
const defaults = { "x-bench": "1" };

let sum = 0;
let t0 = performance.now();
for (let i = 0; i < 1000; i++) {
  const res = await fetch(new URL("item", base), { headers: defaults });
  const body = await res.arrayBuffer();
  sum = (sum + res.status + body.byteLength) >>> 0;
}
console.log(`get_1000\t${(performance.now() - t0).toFixed(3)}\t${sum}`);

// ky retries only when it throws an HTTPError, so a final failure lands in the catch and scores its status.
const api = ky.create({ baseUrl: base, retry: { limit: 2, statusCodes: [503] } });
sum = 0;
t0 = performance.now();
for (let i = 0; i < 1000; i++) {
  try {
    const res = await api.get("flaky");
    const body = await res.arrayBuffer();
    sum = (sum + res.status + body.byteLength) >>> 0;
  } catch (e) {
    sum = (sum + (e.response?.status ?? 0)) >>> 0;
  }
}
console.log(`retry_1000\t${(performance.now() - t0).toFixed(3)}\t${sum}`);
