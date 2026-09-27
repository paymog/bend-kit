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

// Bun's node:zlib zstd stops after the first frame and passes truncated input, so call libzstd.
function zlib_zstd() {
  if (globalThis.BEND_ZSTD !== undefined) {
    return globalThis.BEND_ZSTD;
  }
  globalThis.BEND_ZSTD = null;
  const ffi = require("bun:ffi");
  const paths = [process.env.BEND_LIBZSTD, "/opt/homebrew/lib/libzstd.1.dylib",
    "/usr/local/lib/libzstd.1.dylib", "libzstd.1.dylib", "libzstd.so.1"];
  const syms = {
    ZSTD_createDCtx: { args: [], returns: "ptr" },
    ZSTD_freeDCtx: { args: ["ptr"], returns: "u64" },
    ZSTD_decompressStream: { args: ["ptr", "ptr", "ptr"], returns: "u64" },
    ZSTD_isError: { args: ["u64"], returns: "u32" },
    ZSTD_getErrorName: { args: ["u64"], returns: "cstring" },
  };
  for (const p of paths) {
    if (!p) {
      continue;
    }
    try {
      globalThis.BEND_ZSTD = { s: ffi.dlopen(p, syms).symbols, ffi };
      return globalThis.BEND_ZSTD;
    } catch {
      continue;
    }
  }
  return null;
}

function zstd_words(max, n, words) {
  const b = zlib_words_octets(n, words);
  if (b === null) {
    return io_fail(22);
  }
  const z = zlib_zstd();
  if (z === null) {
    return { $: CID(Fail), error: io_tup(2, "zstd needs libzstd.1; set BEND_LIBZSTD to its path") };
  }
  const { s, ffi } = z;
  max = Number(max);
  let cap = Math.min(Math.max(b.length * 4, 65536), max);
  let out = new Uint8Array(cap + 1);
  // ZSTD_inBuffer and ZSTD_outBuffer: pointer, size, pos.
  const src = new BigUint64Array([BigInt(ffi.ptr(b.length ? b : new Uint8Array(1))), BigInt(b.length), 0n]);
  const dst = new BigUint64Array([BigInt(ffi.ptr(out)), BigInt(cap), 0n]);
  const dctx = s.ZSTD_createDCtx();
  let fail = null;
  for (;;) {
    const r = s.ZSTD_decompressStream(dctx, ffi.ptr(dst), ffi.ptr(src));
    const have = Number(dst[2]);
    if (s.ZSTD_isError(r)) {
      fail = io_tup(22, s.ZSTD_getErrorName(r).toString());
      break;
    }
    if (Number(r) === 0 && src[2] === src[1]) {
      break;
    }
    if (have === cap) {
      if (cap >= max) {
        fail = io_tup(27, "zstd output is larger than max");
        break;
      }
      cap = Math.min(cap * 2, max);
      const grown = new Uint8Array(cap + 1);
      grown.set(out.subarray(0, have));
      out = grown;
      dst[0] = BigInt(ffi.ptr(out));
      dst[1] = BigInt(cap);
    } else if (src[2] === src[1]) {
      fail = io_tup(22, "zstd input ends inside a frame");
      break;
    }
  }
  s.ZSTD_freeDCtx(dctx);
  return fail ? { $: CID(Fail), error: fail } : io_done(zlib_words(out, Number(dst[2])));
}

io_eff(CID(zstd.words), zstd_words);
