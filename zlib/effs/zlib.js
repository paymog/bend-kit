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

function zlib_br() {
  return zlib_lib("brotli", "BEND_LIBBROTLIDEC", ["/opt/homebrew/lib/libbrotlidec.1.dylib",
    "/usr/local/lib/libbrotlidec.1.dylib", "libbrotlidec.1.dylib", "libbrotlidec.so.1"], {
    BrotliDecoderCreateInstance: { args: ["ptr", "ptr", "ptr"], returns: "ptr" },
    BrotliDecoderDestroyInstance: { args: ["ptr"], returns: "void" },
    BrotliDecoderDecompressStream: { args: ["ptr", "ptr", "ptr", "ptr", "ptr", "ptr"], returns: "i32" },
    BrotliDecoderGetErrorCode: { args: ["ptr"], returns: "i32" },
    BrotliDecoderErrorString: { args: ["i32"], returns: "cstring" },
  });
}

// Bun's node:zlib zstd stops after the first frame and passes truncated input, so call libzstd.
function zlib_zstd() {
  return zlib_lib("zstd", "BEND_LIBZSTD", ["/opt/homebrew/lib/libzstd.1.dylib",
    "/usr/local/lib/libzstd.1.dylib", "libzstd.1.dylib", "libzstd.so.1"], {
    ZSTD_createDCtx: { args: [], returns: "ptr" },
    ZSTD_freeDCtx: { args: ["ptr"], returns: "u64" },
    ZSTD_decompressStream: { args: ["ptr", "ptr", "ptr"], returns: "u64" },
    ZSTD_isError: { args: ["u64"], returns: "u32" },
    ZSTD_getErrorName: { args: ["u64"], returns: "cstring" },
  });
}

// z_stream on LP64 (64-bit macOS and Linux): 112 bytes, fields at these offsets.
const ZLIB_Z = { size: 112, next_in: 0, avail_in: 8, next_out: 24, avail_out: 32, msg: 48 };

// Kind 0 accepts gzip, zlib, or raw DEFLATE; 1 is brotli, 2 is zstd.
const ZLIB_DEC = [
  { lib: zlib_z, need: "inflate needs libz.1; set BEND_LIBZ to its path", short: "inflate input ends inside a stream" },
  { lib: zlib_br, need: "brotli needs libbrotlidec.1; set BEND_LIBBROTLIDEC to its path", short: "brotli input ends inside the stream" },
  { lib: zlib_zstd, need: "zstd needs libzstd.1; set BEND_LIBZSTD to its path", short: "zstd input ends inside a frame" },
];

// A decoder, or a failure. done: the input so far ends at the end of a stream (a gzip member or a zstd frame).
// The z_stream stays in d.z: zlib checks that it does not move between calls.
function zlib_dec_open(kind) {
  const z = ZLIB_DEC[kind].lib();
  if (z === null) {
    return zlib_fail(2, ZLIB_DEC[kind].need);
  }
  const { s, ffi } = z;
  const d = { kind, done: false, started: false, pending: null, s, ffi };
  if (kind === 0) {
    d.z = new Uint8Array(ZLIB_Z.size);
    d.v = new DataView(d.z.buffer);
    // Window bits 15 + 32: a gzip or a zlib header, found from the first bytes.
    return s.inflateInit2_(ffi.ptr(d.z), 15 + 32, s.zlibVersion(), ZLIB_Z.size) === 0 ? d : io_fail(12);
  }
  d.st = kind === 1 ? s.BrotliDecoderCreateInstance(null, null, null) : s.ZSTD_createDCtx();
  return d.st ? d : io_fail(12);
}

function zlib_dec_close(d) {
  if (d.kind === 0) {
    d.s.inflateEnd(d.ffi.ptr(d.z));
  } else if (d.kind === 1) {
    d.s.BrotliDecoderDestroyInstance(d.st);
  } else {
    d.s.ZSTD_freeDCtx(d.st);
  }
}

function zlib_has_wrapper(a, b) {
  return (a === 0x1f && b === 0x8b)
    || ((a & 15) === 8 && (a >> 4) <= 7 && ((a * 256 + b) % 31) === 0);
}

function zlib_inflate_start(d, a, b) {
  d.started = true;
  if (zlib_has_wrapper(a, b)) {
    return null;
  }
  d.s.inflateEnd(d.ffi.ptr(d.z));
  d.z = new Uint8Array(ZLIB_Z.size);
  d.v = new DataView(d.z.buffer);
  return d.s.inflateInit2_(d.ffi.ptr(d.z), -15, d.s.zlibVersion(), ZLIB_Z.size) === 0
    ? null : zlib_fail(12, "raw inflate initialization failed");
}

// gzip -d reads the next member when bytes follow the end of one.
function zlib_inflate_feed(d, b, o) {
  const { s, ffi, v } = d;
  const zp = ffi.ptr(d.z);
  v.setBigUint64(ZLIB_Z.next_in, BigInt(zlib_in(ffi, b)), true);
  v.setUint32(ZLIB_Z.avail_in, b.length, true);
  for (;;) {
    if (d.done && v.getUint32(ZLIB_Z.avail_in, true) !== 0) {
      s.inflateReset(zp);
      d.done = false;
    }
    v.setBigUint64(ZLIB_Z.next_out, BigInt(o.ptr()), true);
    v.setUint32(ZLIB_Z.avail_out, o.cap - o.have, true);
    const r = s.inflate(zp, 0);
    const room = v.getUint32(ZLIB_Z.avail_out, true);
    o.have = o.cap - room;
    if (r === 1) {
      d.done = true;
      if (v.getUint32(ZLIB_Z.avail_in, true) === 0) {
        return null;
      }
      continue;
    }
    // Z_OK and Z_BUF_ERROR only ask for more room or input.
    if (r !== 0 && r !== -5) {
      const msg = Number(v.getBigUint64(ZLIB_Z.msg, true));
      return zlib_fail(22, msg ? new ffi.CString(msg).toString() : "inflate failed");
    }
    if (room !== 0) {
      return null;
    }
    if (!o.grow()) {
      return zlib_fail(27, "inflate output is larger than max");
    }
  }
}

function zlib_inflate_auto(d, b, o) {
  if (!d.started) {
    if (d.pending !== null) {
      if (b.length === 0) {
        return null;
      }
      const lead = d.pending;
      d.pending = null;
      const fail = zlib_inflate_start(d, lead, b[0]);
      if (fail !== null) {
        return fail;
      }
      const first = zlib_inflate_feed(d, Uint8Array.of(lead), o);
      return first ?? zlib_inflate_feed(d, b, o);
    }
    if (b.length === 0) {
      return null;
    }
    if (b.length === 1) {
      d.pending = b[0];
      return null;
    }
    const fail = zlib_inflate_start(d, b[0], b[1]);
    if (fail !== null) {
      return fail;
    }
  }
  return zlib_inflate_feed(d, b, o);
}


function zlib_brotli_feed(d, b, o) {
  const { s, ffi } = d;
  // available_in, next_in, available_out, next_out: each a size_t or a pointer the call moves.
  const io = new BigUint64Array([BigInt(b.length), BigInt(zlib_in(ffi, b)), 0n, 0n]);
  const at = (i) => ffi.ptr(io) + 8 * i;
  for (;;) {
    io[2] = BigInt(o.cap - o.have);
    io[3] = BigInt(o.ptr());
    const r = s.BrotliDecoderDecompressStream(d.st, at(0), at(1), at(2), at(3), null);
    o.have = o.cap - Number(io[2]);
    if (r === 1) {
      d.done = true;
      return io[0] !== 0n ? zlib_fail(22, "brotli input has bytes after the stream") : null;
    }
    if (r === 0) {
      return zlib_fail(22, s.BrotliDecoderErrorString(s.BrotliDecoderGetErrorCode(d.st)).toString());
    }
    if (r === 2) {
      return null;
    }
    if (!o.grow()) {
      return zlib_fail(27, "brotli output is larger than max");
    }
  }
}

// Frames follow one another; a skippable frame gives no output.
function zlib_zstd_feed(d, b, o) {
  const { s, ffi } = d;
  // ZSTD_inBuffer and ZSTD_outBuffer: pointer, size, pos.
  const src = new BigUint64Array([BigInt(zlib_in(ffi, b)), BigInt(b.length), 0n]);
  const dst = new BigUint64Array(3);
  for (;;) {
    dst[0] = BigInt(o.ptr());
    dst[1] = BigInt(o.cap - o.have);
    dst[2] = 0n;
    const r = s.ZSTD_decompressStream(d.st, ffi.ptr(dst), ffi.ptr(src));
    o.have += Number(dst[2]);
    if (s.ZSTD_isError(r)) {
      return zlib_fail(22, s.ZSTD_getErrorName(r).toString());
    }
    if (src[2] === src[1] && (Number(r) === 0 || dst[2] < dst[1])) {
      d.done = b.length !== 0 ? Number(r) === 0 : d.done;
      return null;
    }
    if (o.have === o.cap && !o.grow()) {
      return zlib_fail(27, "zstd output is larger than max");
    }
  }
}

// Decodes b into o: null, or a failure.
function zlib_dec_feed(d, b, o) {
  return [zlib_inflate_auto, zlib_brotli_feed, zlib_zstd_feed][d.kind](d, b, o);
}

function zlib_whole(kind, max, n, words) {
  const b = zlib_words_octets(n, words);
  if (b === null) {
    return io_fail(22);
  }
  const d = zlib_dec_open(kind);
  if (d.$ !== undefined) {
    return d;
  }
  const o = zlib_buf(d.ffi, b.length, Number(max));
  let fail = zlib_dec_feed(d, b, o);
  if (fail === null && !d.done) {
    fail = zlib_fail(22, ZLIB_DEC[kind].short);
  }
  zlib_dec_close(d);
  return fail ?? io_done(zlib_words(o.out, o.have));
}

function zstd_words(max, n, words) {
  return zlib_whole(2, max, n, words);
}

function inflate_words(max, n, words) {
  return zlib_whole(0, max, n, words);
}

function brotli_words(max, n, words) {
  return zlib_whole(1, max, n, words);
}

// Open decoders by id; id 0 is never used.
function zlib_decs() {
  return (globalThis.BEND_ZLIB_DECS ??= { next: 1, by: new Map() });
}

function dec_open(kind) {
  if (kind > 2) {
    return io_fail(22);
  }
  const d = zlib_dec_open(kind);
  if (d.$ !== undefined) {
    return d;
  }
  const t = zlib_decs();
  const id = t.next;
  t.next = (t.next % 0xfffffffe) + 1;
  t.by.set(id, d);
  return io_done(id);
}

function dec_feed(id, max, n, words) {
  const b = zlib_words_octets(n, words);
  const d = zlib_decs().by.get(id);
  if (b === null || d === undefined) {
    return io_fail(b === null ? 22 : 9);
  }
  const o = zlib_buf(d.ffi, b.length, Number(max));
  return zlib_dec_feed(d, b, o) ?? io_done(zlib_words(o.out, o.have));
}

function dec_finish(id) {
  const t = zlib_decs();
  const d = t.by.get(id);
  if (d === undefined) {
    return io_fail(9);
  }
  t.by.delete(id);
  zlib_dec_close(d);
  return d.done ? io_done({ $: CID(Unit) }) : zlib_fail(22, ZLIB_DEC[d.kind].short);
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
  const st = new Uint8Array(ZLIB_Z.size);
  const v = new DataView(st.buffer);
  const zp = ffi.ptr(st);
  // Level 6, window bits 15 + 16 (a gzip wrapper), memLevel 8, the default strategy.
  if (s.deflateInit2_(zp, 6, 8, 15 + 16, 8, 0, s.zlibVersion(), ZLIB_Z.size) !== 0) {
    return io_fail(12);
  }
  const cap = Number(s.deflateBound(zp, b.length));
  const out = new Uint8Array(cap + 1);
  v.setBigUint64(ZLIB_Z.next_in, BigInt(zlib_in(ffi, b)), true);
  v.setUint32(ZLIB_Z.avail_in, b.length, true);
  v.setBigUint64(ZLIB_Z.next_out, BigInt(ffi.ptr(out)), true);
  v.setUint32(ZLIB_Z.avail_out, cap, true);
  const r = s.deflate(zp, 4);
  const have = cap - v.getUint32(ZLIB_Z.avail_out, true);
  s.deflateEnd(zp);
  return r === 1 ? io_done(zlib_words(out, have)) : zlib_fail(22, "deflate did not finish");
}

io_eff(CID(zstd.words), zstd_words);
io_eff(CID(inflate.words), inflate_words);
io_eff(CID(gzip.words), gzip_words);
io_eff(CID(brotli.words), brotli_words);
io_eff(CID(dec.open), dec_open);
io_eff(CID(dec.feed), dec_feed);
io_eff(CID(dec.finish.id), dec_finish);
