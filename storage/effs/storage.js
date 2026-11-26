let storageCrypto;
function storage_crypto_load() {
  if (storageCrypto !== undefined) return storageCrypto;
  storageCrypto = null;
  const ffi = require("bun:ffi");
  for (const path of [process.env.BEND_LIBCRYPTO,
    "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib",
    "/usr/local/opt/openssl@3/lib/libcrypto.3.dylib", "libcrypto.3.dylib", "libcrypto.so.3"]) {
    if (!path) continue;
    try {
      const lib = ffi.dlopen(path, {
        EVP_Q_digest: {args: ["ptr", "ptr", "ptr", "ptr", "u64", "ptr", "ptr"], returns: "i32"},
      });
      storageCrypto = {ffi, lib};
      break;
    } catch {}
  }
  return storageCrypto;
}

function blob_hash_words(n, raw) {
  if (n > raw.length * 4) return io_fail(22);
  const crypto = storage_crypto_load();
  if (!crypto) return {$: CID(Fail), error: io_tup(2, "storage needs OpenSSL 3; set BEND_LIBCRYPTO to its path")};
  const header = new TextEncoder().encode(`file ${n}\n`);
  const bytes = new Uint8Array(header.length + n);
  bytes.set(header);
  for (let i = 0; i < n; ++i) {
    bytes[header.length + i] = (raw[i >>> 2] >>> (8 * (i & 3))) & 255;
  }
  const digest = new Uint8Array(64);
  const size = new BigUint64Array(1);
  const {ffi, lib} = crypto;
  const algorithm = new TextEncoder().encode("SHA256\0");
  if (!lib.symbols.EVP_Q_digest(null, ffi.ptr(algorithm), null, ffi.ptr(bytes), bytes.length, ffi.ptr(digest), ffi.ptr(size)) || size[0] !== 32n) {
    return {$: CID(Fail), error: io_tup(22, "storage: SHA-256 failed")};
  }
  const words = Array(8);
  for (let i = 0; i < 8; ++i) {
    words[i] = (digest[4 * i] | digest[4 * i + 1] << 8 | digest[4 * i + 2] << 16 | digest[4 * i + 3] << 24) >>> 0;
  }
  return io_done(io_tup(raw, io_tup(32, words)));
}

io_eff(CID(Blob.hash.words), blob_hash_words);

function write_temp(prefix) {
  const bytes = io_bytes(prefix);
  if (bytes.includes(0)) return io_fail(22);
  const suffix = "." + require("crypto").randomUUID();
  const path = Buffer.concat([Buffer.from(bytes), Buffer.from(suffix)]);
  try {
    const fd = require("fs").openSync(path, "wx", 0o600);
    return io_done(io_tup(prefix + suffix, fd));
  } catch (e) {
    return io_fail(Math.abs(e?.errno ?? 5));
  }
}

io_eff(CID(write.temp), write_temp);

let storageSync;
function storage_sync(path, directory, failFullsync = false) {
  const fs = require("fs");
  const fd = fs.openSync(path, fs.constants.O_RDONLY | (directory ? fs.constants.O_DIRECTORY : 0));
  let error;
  try {
    fs.fsyncSync(fd);
    if (failFullsync) throw {errno: 5};
    if (process.platform === "darwin") {
      if (!storageSync) {
        storageSync = require("bun:ffi").dlopen("libSystem.B.dylib", {
          fcntl: {args: ["i32", "i32", "i32"], returns: "i32"},
        });
      }
      let rc, code;
      do {
        rc = storageSync.symbols.fcntl(fd, 51, 0); // F_FULLFSYNC
        code = rc < 0 ? io_sys().errno() : 0;
      } while (code === 4);
      if (code) throw {errno: code};
    }
  } catch (e) {
    error = e;
  }
  try { fs.closeSync(fd); } catch (e) { error ??= e; }
  if (error) throw error;
}

function write_durable(tmp, path, fault) {
  const fs = require("fs");
  const parent = require("path").posix.dirname;
  const tb = Buffer.from(io_bytes(tmp));
  let pb = Buffer.from(io_bytes(path));
  if (tb.includes(0) || pb.includes(0) || !pb.length) return io_fail(22);
  // Paths carry octets, not UTF-8 text.
  const up = p => Buffer.from(parent(p.toString("latin1")), "latin1");
  try {
    if (!tb.length) {
      for (;;) {
        storage_sync(pb, true);
        const next = up(pb);
        if (next.equals(pb)) break;
        pb = next;
      }
    } else {
      if (fault === 1) return io_fail(5);
      storage_sync(tb, false, fault === 7);
      if (fault === 2 || fault === 3) return io_fail(5);
      fs.renameSync(tb, pb);
      if (fault === 4 || fault === 5) return io_fail(5);
      storage_sync(up(pb), true);
      storage_sync(up(tb), true);
      if (fault === 6) return io_fail(5);
    }
    return io_done({$: CID(Unit)});
  } catch (e) {
    return io_fail(Math.abs(e?.errno ?? 5));
  }
}

io_eff(CID(write.durable), write_durable);

function write_sync(path) {
  const bytes = Buffer.from(io_bytes(path));
  if (bytes.includes(0)) return io_fail(22);
  try {
    storage_sync(bytes, false);
    return io_done({$: CID(Unit)});
  } catch (e) {
    return io_fail(Math.abs(e?.errno ?? 5));
  }
}

io_eff(CID(write.sync), write_sync);

function copy_into(path, file) {
  const fs = require("fs");
  let src, code = 0;
  try {
    const name = io_bytes(path);
    if (name.includes(0)) throw {errno: 22};
    src = fs.openSync(Buffer.from(name), fs.constants.O_RDONLY | fs.constants.O_CLOEXEC);
    const buffer = Buffer.alloc(65536);
    let total = 0;
    for (;;) {
      const n = fs.readSync(src, buffer, 0, buffer.length, null);
      if (!n) break;
      total += n;
      if (total > 0xffffffff) throw {errno: 27};
      for (let at = 0; at < n;) {
        const wrote = fs.writeSync(file, buffer, at, n - at);
        if (!wrote) throw {errno: 5};
        at += wrote;
      }
    }
  } catch (e) {
    code = Math.abs(e?.errno ?? 5);
  } finally {
    if (src !== undefined) {
      try { fs.closeSync(src); } catch (e) { code ||= Math.abs(e?.errno ?? 5); }
    }
  }
  return io_tup(file, code ? io_fail(code) : io_done({$: CID(Unit)}));
}

io_eff(CID(copy.into), copy_into);
