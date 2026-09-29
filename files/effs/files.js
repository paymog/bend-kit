// Files
// =====
// JS twins of files.c: POSIX paths as UTF-8, errno via io_fail.

function files_err(e) {
  return io_fail(Math.abs(e?.errno ?? 5));
}

function files_path(path) {
  const name = io_bytes(path);
  if (name.includes(0)) {
    return { ok: false, code: 22 };
  }
  return { ok: true, p: name.length > 0 ? Buffer.from(name) : "" };
}

function list_dir_raw(path) {
  const got = files_path(path);
  if (!got.ok) {
    return io_fail(got.code);
  }
  try {
    const names = require("fs").readdirSync(got.p);
    return io_done(names.join(String.fromCharCode(0)));
  } catch (e) {
    return files_err(e);
  }
}

function stat_raw(path) {
  const got = files_path(path);
  if (!got.ok) {
    return io_fail(got.code);
  }
  try {
    const st = require("fs").statSync(got.p);
    const kind = st.isFile() ? 0 : st.isDirectory() ? 1 : 2;
    return io_done(io_tup(kind, st.size >>> 0, (Math.floor(st.mtimeMs / 1000) >>> 0)));
  } catch (e) {
    return files_err(e);
  }
}

function mkdir(path) {
  const got = files_path(path);
  if (!got.ok) {
    return io_fail(got.code);
  }
  try {
    require("fs").mkdirSync(got.p);
    return io_done({ $: CID(Unit) });
  } catch (e) {
    return files_err(e);
  }
}
function remove(path) {
  const got = files_path(path);
  if (!got.ok) {
    return io_fail(got.code);
  }
  try {
    const fs = require("fs");
    if (fs.lstatSync(got.p).isDirectory()) {
      fs.rmdirSync(got.p);
    } else {
      fs.unlinkSync(got.p);
    }
    return io_done({ $: CID(Unit) });
  } catch (e) {
    return files_err(e);
  }
}

function rename(from, to) {
  const a = files_path(from);
  if (!a.ok) {
    return io_fail(a.code);
  }
  const b = files_path(to);
  if (!b.ok) {
    return io_fail(b.code);
  }
  try {
    require("fs").renameSync(a.p, b.p);
    return io_done({ $: CID(Unit) });
  } catch (e) {
    return files_err(e);
  }
}

function temp_dir() {
  try {
    const pathMod = require("path");
    const dir = require("fs").mkdtempSync(pathMod.join(require("os").tmpdir(), "bend-"));
    return io_done(dir);
  } catch (e) {
    return files_err(e);
  }
}

io_eff(CID(list_dir.raw), list_dir_raw);
io_eff(CID(stat.raw), stat_raw);
io_eff(CID(mkdir), mkdir);
io_eff(CID(remove), remove);
io_eff(CID(rename), rename);
io_eff(CID(temp_dir), temp_dir);

function read_words(file, max) {
  const n = Math.min(Number(max), 1048576);
  const data = Buffer.allocUnsafe(n);
  try {
    const count = require("fs").readSync(file, data, 0, n, null);
    let size = 1;
    while (size < Math.ceil(count / 4)) size *= 2;
    const words = Array(size).fill(0);
    for (let i = 0; i < count; i++) {
      words[i >> 2] = (words[i >> 2] | (data[i] << (8 * (i & 3)))) >>> 0;
    }
    return io_tup(file, io_done(io_tup(count, words)));
  } catch (e) {
    return io_tup(file, files_err(e));
  }
}

function write_words(file, len, words) {
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
    return io_tup(file, io_done({ $: CID(Unit) }));
  } catch (e) {
    return io_tup(file, files_err(e));
  }
}

io_eff(CID(read.words), read_words);
io_eff(CID(write.words), write_words);
