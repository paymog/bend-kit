const fs = require("fs");
const fd = fs.openSync("bench/fixture.bin", "r");
const bytes = Buffer.allocUnsafe(16384);
let hash = 2166136261;
try {
  let n;
  while ((n = fs.readSync(fd, bytes, 0, bytes.length, null)) !== 0) {
    for (let i = 0; i < n; i++) hash = Math.imul(hash ^ bytes[i], 16777619) >>> 0;
  }
} finally {
  fs.closeSync(fd);
}
console.log(hash);
