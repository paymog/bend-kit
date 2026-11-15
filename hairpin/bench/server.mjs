// Keep-alive server for the benchmark: GET /api/item answers 1024 bytes, or 400 without x-bench: 1.
// GET /api/flaky answers 503 with Retry-After: 0, then 1024 bytes, in turn.
import http from "node:http";

const body = Buffer.alloc(1024, "a");
let flaky = 0;
http
  .createServer((req, res) => {
    if (req.url === "/api/flaky") {
      const busy = flaky++ % 2 === 0;
      res.writeHead(busy ? 503 : 200, { "content-type": "text/plain", "content-length": busy ? 0 : body.length, ...(busy ? { "retry-after": "0" } : {}) });
      res.end(busy ? undefined : body);
      return;
    }
    const ok = req.url === "/api/item" && req.headers["x-bench"] === "1";
    res.writeHead(ok ? 200 : 400, { "content-type": "text/plain", "content-length": ok ? body.length : 0 });
    res.end(ok ? body : undefined);
  })
  .listen(47840, "127.0.0.1", () => console.log("ready"));
