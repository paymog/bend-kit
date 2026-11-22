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
