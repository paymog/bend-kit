// Zlib
// ====
// JS twins of zlib.c, through bun:ffi on the same C libraries.

// Copies of wire_words and wire_words_octets in wire/effs/wire.js; keep them in step.
function zlib_words(b, n) {
  const w = Math.ceil(n / 4);
  let size = 1;
  while (size < w) {
    size *= 2;
  }
  const a = Array(size).fill(0);
  for (let i = 0; i < n; i += 1) {
    a[i >> 2] = (a[i >> 2] | (b[i] << (8 * (i & 3)))) >>> 0;
  }
  return { $: CID(Tuple), fst: n, snd: a };
}

function zlib_words_octets(n, a) {
  n = Number(n);
  if (n > 4 * a.length) {
    return null;
  }
  const b = new Uint8Array(n);
  for (let i = 0; i < n; i += 1) {
    b[i] = (a[i >> 2] >>> (8 * (i & 3))) & 255;
  }
  return b;
}

// The library named by the env variable, else the first path that loads; null if none does.
function zlib_lib(key, env, paths, syms) {
  const cache = (globalThis.BEND_ZLIB ??= {});
  if (cache[key] !== undefined) {
    return cache[key];
  }
  cache[key] = null;
  const ffi = require("bun:ffi");
  for (const p of [process.env[env], ...paths]) {
    if (!p) {
      continue;
    }
    try {
      cache[key] = { s: ffi.dlopen(p, syms).symbols, ffi };
      return cache[key];
    } catch {
      continue;
    }
  }
  return null;
}

function zlib_fail(code, why) {
  return { $: CID(Fail), error: io_tup(code, why) };
}

// Output that doubles from about 4x the input up to max bytes. grow() moves the bytes, so re-read ptr().
function zlib_buf(ffi, n, max) {
  const b = { max, cap: Math.min(Math.max(n * 4, 65536), max), have: 0 };
  b.out = new Uint8Array(b.cap + 1);
  b.ptr = () => ffi.ptr(b.out) + b.have;
  b.grow = () => {
    if (b.cap >= b.max) {
      return false;
    }
    b.cap = Math.min(b.cap * 2, b.max);
    const grown = new Uint8Array(b.cap + 1);
    grown.set(b.out.subarray(0, b.have));
    b.out = grown;
    return true;
  };
  return b;
}

// A pointer to the input; ffi.ptr refuses an empty array.
function zlib_in(ffi, b) {
  return ffi.ptr(b.length ? b : new Uint8Array(1));
}

// Bun's node:zlib zstd stops after the first frame and passes truncated input, so call libzstd.
function zstd_words(max, n, words) {
  const b = zlib_words_octets(n, words);
  if (b === null) {
    return io_fail(22);
  }
  const z = zlib_lib("zstd", "BEND_LIBZSTD", ["/opt/homebrew/lib/libzstd.1.dylib",
    "/usr/local/lib/libzstd.1.dylib", "libzstd.1.dylib", "libzstd.so.1"], {
    ZSTD_createDCtx: { args: [], returns: "ptr" },
    ZSTD_freeDCtx: { args: ["ptr"], returns: "u64" },
    ZSTD_decompressStream: { args: ["ptr", "ptr", "ptr"], returns: "u64" },
    ZSTD_isError: { args: ["u64"], returns: "u32" },
    ZSTD_getErrorName: { args: ["u64"], returns: "cstring" },
  });
  if (z === null) {
    return zlib_fail(2, "zstd needs libzstd.1; set BEND_LIBZSTD to its path");
  }
  const { s, ffi } = z;
  const o = zlib_buf(ffi, b.length, Number(max));
  // ZSTD_inBuffer and ZSTD_outBuffer: pointer, size, pos.
  const src = new BigUint64Array([BigInt(zlib_in(ffi, b)), BigInt(b.length), 0n]);
  const dst = new BigUint64Array(3);
  const dctx = s.ZSTD_createDCtx();
  let fail = null;
  for (;;) {
    dst[0] = BigInt(o.ptr());
    dst[1] = BigInt(o.cap - o.have);
    dst[2] = 0n;
    const r = s.ZSTD_decompressStream(dctx, ffi.ptr(dst), ffi.ptr(src));
    o.have += Number(dst[2]);
    if (s.ZSTD_isError(r)) {
      fail = zlib_fail(22, s.ZSTD_getErrorName(r).toString());
      break;
    }
    if (Number(r) === 0 && src[2] === src[1]) {
      break;
    }
    if (o.have === o.cap) {
      if (!o.grow()) {
        fail = zlib_fail(27, "zstd output is larger than max");
        break;
      }
    } else if (src[2] === src[1]) {
      fail = zlib_fail(22, "zstd input ends inside a frame");
      break;
    }
  }
  s.ZSTD_freeDCtx(dctx);
  return fail ?? io_done(zlib_words(o.out, o.have));
}

function zlib_z() {
  return zlib_lib("z", "BEND_LIBZ", ["/usr/lib/libz.1.dylib", "libz.1.dylib", "libz.so.1"], {
    zlibVersion: { args: [], returns: "ptr" },
    inflateInit2_: { args: ["ptr", "i32", "ptr", "i32"], returns: "i32" },
    inflate: { args: ["ptr", "i32"], returns: "i32" },
    inflateReset: { args: ["ptr"], returns: "i32" },
    inflateEnd: { args: ["ptr"], returns: "i32" },
    deflateInit2_: { args: ["ptr", "i32", "i32", "i32", "i32", "i32", "ptr", "i32"], returns: "i32" },
    deflate: { args: ["ptr", "i32"], returns: "i32" },
    deflateBound: { args: ["ptr", "u64"], returns: "u64" },
    deflateEnd: { args: ["ptr"], returns: "i32" },
  });
}

// z_stream on LP64 (64-bit macOS and Linux): 112 bytes, fields at these offsets.
const ZLIB_Z = { size: 112, next_in: 0, avail_in: 8, next_out: 24, avail_out: 32, msg: 48 };

function zlib_z_stream() {
  const b = new Uint8Array(ZLIB_Z.size);
  return { b, v: new DataView(b.buffer) };
}

function inflate_words(max, n, words) {
  const b = zlib_words_octets(n, words);
  if (b === null) {
    return io_fail(22);
  }
  const z = zlib_z();
  if (z === null) {
    return zlib_fail(2, "inflate needs libz.1; set BEND_LIBZ to its path");
  }
  const { s, ffi } = z;
  const st = zlib_z_stream();
  const zp = ffi.ptr(st.b);
  // Window bits 15 + 32: a gzip or a zlib header, found from the first bytes.
  if (s.inflateInit2_(zp, 15 + 32, s.zlibVersion(), ZLIB_Z.size) !== 0) {
    return io_fail(12);
  }
  const o = zlib_buf(ffi, b.length, Number(max));
  st.v.setBigUint64(ZLIB_Z.next_in, BigInt(zlib_in(ffi, b)), true);
  st.v.setUint32(ZLIB_Z.avail_in, b.length, true);
  let fail = null;
  for (;;) {
    st.v.setBigUint64(ZLIB_Z.next_out, BigInt(o.ptr()), true);
    st.v.setUint32(ZLIB_Z.avail_out, o.cap - o.have, true);
    const r = s.inflate(zp, 0);
    const room = st.v.getUint32(ZLIB_Z.avail_out, true);
    const left = st.v.getUint32(ZLIB_Z.avail_in, true);
    o.have = o.cap - room;
    if (r === 1) {
      // Z_STREAM_END: gzip -d reads the next member, if any.
      if (left === 0) {
        break;
      }
      s.inflateReset(zp);
      continue;
    }
    if (r !== 0 && r !== -5) {
      const msg = Number(st.v.getBigUint64(ZLIB_Z.msg, true));
      fail = zlib_fail(22, msg ? new ffi.CString(msg).toString() : "inflate failed");
      break;
    }
    if (room === 0) {
      if (!o.grow()) {
        fail = zlib_fail(27, "inflate output is larger than max");
        break;
      }
    } else if (left === 0) {
      fail = zlib_fail(22, "inflate input ends inside a stream");
      break;
    }
  }
  s.inflateEnd(zp);
  return fail ?? io_done(zlib_words(o.out, o.have));
}

function gzip_words(n, words) {
  const b = zlib_words_octets(n, words);
  if (b === null) {
    return io_fail(22);
  }
  const z = zlib_z();
  if (z === null) {
    return zlib_fail(2, "gzip needs libz.1; set BEND_LIBZ to its path");
  }
  const { s, ffi } = z;
  const st = zlib_z_stream();
  const zp = ffi.ptr(st.b);
  // Level 6, window bits 15 + 16 (a gzip wrapper), memLevel 8, the default strategy.
  if (s.deflateInit2_(zp, 6, 8, 15 + 16, 8, 0, s.zlibVersion(), ZLIB_Z.size) !== 0) {
    return io_fail(12);
  }
  const cap = Number(s.deflateBound(zp, b.length));
  const out = new Uint8Array(cap + 1);
  st.v.setBigUint64(ZLIB_Z.next_in, BigInt(zlib_in(ffi, b)), true);
  st.v.setUint32(ZLIB_Z.avail_in, b.length, true);
  st.v.setBigUint64(ZLIB_Z.next_out, BigInt(ffi.ptr(out)), true);
  st.v.setUint32(ZLIB_Z.avail_out, cap, true);
  const r = s.deflate(zp, 4);
  const have = cap - st.v.getUint32(ZLIB_Z.avail_out, true);
  s.deflateEnd(zp);
  return r === 1 ? io_done(zlib_words(out, have)) : zlib_fail(22, "deflate did not finish");
}

function brotli_words(max, n, words) {
  const b = zlib_words_octets(n, words);
  if (b === null) {
    return io_fail(22);
  }
  const z = zlib_lib("brotli", "BEND_LIBBROTLIDEC", ["/opt/homebrew/lib/libbrotlidec.1.dylib",
    "/usr/local/lib/libbrotlidec.1.dylib", "libbrotlidec.1.dylib", "libbrotlidec.so.1"], {
    BrotliDecoderCreateInstance: { args: ["ptr", "ptr", "ptr"], returns: "ptr" },
    BrotliDecoderDestroyInstance: { args: ["ptr"], returns: "void" },
    BrotliDecoderDecompressStream: { args: ["ptr", "ptr", "ptr", "ptr", "ptr", "ptr"], returns: "i32" },
    BrotliDecoderGetErrorCode: { args: ["ptr"], returns: "i32" },
    BrotliDecoderErrorString: { args: ["i32"], returns: "cstring" },
  });
  if (z === null) {
    return zlib_fail(2, "brotli needs libbrotlidec.1; set BEND_LIBBROTLIDEC to its path");
  }
  const { s, ffi } = z;
  const st = s.BrotliDecoderCreateInstance(null, null, null);
  if (!st) {
    return io_fail(12);
  }
  const o = zlib_buf(ffi, b.length, Number(max));
  // available_in, next_in, available_out, next_out: each a size_t or a pointer the call moves.
  const io = new BigUint64Array([BigInt(b.length), BigInt(zlib_in(ffi, b)), 0n, 0n]);
  const at = (i) => ffi.ptr(io) + 8 * i;
  let fail = null;
  for (;;) {
    io[2] = BigInt(o.cap - o.have);
    io[3] = BigInt(o.ptr());
    const r = s.BrotliDecoderDecompressStream(st, at(0), at(1), at(2), at(3), null);
    o.have = o.cap - Number(io[2]);
    if (r === 1) {
      if (io[0] !== 0n) {
        fail = zlib_fail(22, "brotli input has bytes after the stream");
      }
      break;
    }
    if (r === 0) {
      fail = zlib_fail(22, s.BrotliDecoderErrorString(s.BrotliDecoderGetErrorCode(st)).toString());
      break;
    }
    if (r === 3) {
      if (!o.grow()) {
        fail = zlib_fail(27, "brotli output is larger than max");
        break;
      }
    } else {
      fail = zlib_fail(22, "brotli input ends inside the stream");
      break;
    }
  }
  s.BrotliDecoderDestroyInstance(st);
  return fail ?? io_done(zlib_words(o.out, o.have));
}

io_eff(CID(zstd.words), zstd_words);
io_eff(CID(inflate.words), inflate_words);
io_eff(CID(gzip.words), gzip_words);
io_eff(CID(brotli.words), brotli_words);
