function inspect(path, want) {
  const fs = require("fs");
  let fd;
  try {
    const name = io_bytes(path);
    if (name.includes(0)) return io_fail(22);
    fd = fs.openSync(Buffer.from(name), "r");
    const hash = require("crypto").createHash("sha256");
    const buffer = Buffer.alloc(65536);
    const head = [];
    let total = 0, newline = false, longHead = false;
    for (;;) {
      const n = fs.readSync(fd, buffer, 0, buffer.length, null);
      if (!n) break;
      total += n;
      if (total > 0xffffffff) return io_fail(27);
      hash.update(buffer.subarray(0, n));
      for (let i = 0; i < n && !newline && !longHead; ++i) {
        if (buffer[i] === 10) newline = true;
        else if (head.length === 400) longHead = true;
        else head.push(buffer[i]);
      }
    }
    if (hash.digest("hex") !== want) {
      return {$: CID(Fail), error: io_tup(22, `storage: object ${want} does not match its digest`)};
    }
    const text = String.fromCharCode(...head);
    if (!newline || longHead || (!text.startsWith("file ") && total !== head.length + 1)) {
      return {$: CID(Fail), error: io_tup(22, "storage: object does not decode")};
    }
    fs.closeSync(fd);
    fd = undefined;
    return io_done(io_tup(total, text));
  } catch (e) {
    return io_fail(Math.abs(e?.errno ?? 5));
  } finally {
    if (fd !== undefined) fs.closeSync(fd);
  }
}

io_eff(CID(inspect), inspect);
