// Journal
// =======
// JS twins of journal.c. fsyncSync is fsync(2); macOS's F_FULLFSYNC is not reached from here.

function journal_err(e) {
  return io_fail(Math.abs(e?.errno ?? 5));
}

function journal_sync_dir(fs, name) {
  const slash = name.lastIndexOf(47);
  const dir = slash < 0 ? "." : slash === 0 ? "/" : Buffer.from(name.slice(0, slash));
  const fd = fs.openSync(dir, "r");
  try {
    fs.fsyncSync(fd);
  } finally {
    fs.closeSync(fd);
  }
}

function open_words(path, limit) {
  const name = io_bytes(path);
  if (name.length === 0 || name.includes(0)) {
    return io_fail(22);
  }
  const fs = require("fs");
  let fd;
  try {
    fd = fs.openSync(Buffer.from(name), "a+", 0o644);
    journal_sync_dir(fs, name);
    const size = fs.fstatSync(fd).size;
    if (size > Number(limit)) {
      fs.closeSync(fd);
      return io_fail(27);
    }
    const data = Buffer.allocUnsafe(size);
    let at = 0;
    while (at < size) {
      const n = fs.readSync(fd, data, at, size - at, at);
      if (n === 0) {
        fs.closeSync(fd);
        return io_fail(5);
      }
      at += n;
    }
    let slots = 1;
    while (slots < Math.ceil(size / 4)) slots *= 2;
    const words = Array(slots).fill(0);
    for (let i = 0; i < size; i++) {
      words[i >> 2] = (words[i >> 2] | (data[i] << (8 * (i & 3)))) >>> 0;
    }
    return io_done(io_tup(fd, io_tup(size, words)));
  } catch (e) {
    if (fd !== undefined) {
      fs.closeSync(fd);
    }
    return journal_err(e);
  }
}

function append_words(file, len, words) {
  const n = Number(len);
  if (n > words.length * 4) return io_tup(file, io_fail(22));
  const data = Buffer.allocUnsafe(n);
  for (let i = 0; i < n; i++) {
    data[i] = (words[i >> 2] >>> (8 * (i & 3))) & 255;
  }
  try {
    const fs = require("fs");
    let at = 0;
    while (at < n) {
      const wrote = fs.writeSync(file, data, at, n - at);
      if (wrote === 0) return io_tup(file, io_fail(5));
      at += wrote;
    }
    fs.fsyncSync(file);
    return io_tup(file, io_done({ $: CID(Unit) }));
  } catch (e) {
    return io_tup(file, journal_err(e));
  }
}

function truncate(file, len) {
  try {
    const fs = require("fs");
    fs.ftruncateSync(file, Number(len));
    fs.fsyncSync(file);
    return io_tup(file, io_done({ $: CID(Unit) }));
  } catch (e) {
    return io_tup(file, journal_err(e));
  }
}

io_eff(CID(open.words), open_words);
io_eff(CID(append.words), append_words);
io_eff(CID(truncate), truncate);
