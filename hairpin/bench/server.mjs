// Keep-alive server for the benchmark: GET /api/item answers 1024 bytes, or 400 without x-bench: 1.
import http from "node:http";

const body = Buffer.alloc(1024, "a");
http
  .createServer((req, res) => {
    const ok = req.url === "/api/item" && req.headers["x-bench"] === "1";
    res.writeHead(ok ? 200 : 400, { "content-type": "text/plain", "content-length": ok ? body.length : 0 });
    res.end(ok ? body : undefined);
  })
  .listen(47840, "127.0.0.1", () => console.log("ready"));
