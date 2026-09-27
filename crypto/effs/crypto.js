// Crypto
// ======
// JS twins of crypto.c, through bun:ffi on the same libcrypto.

// Copies of wire_words and wire_words_octets in wire/effs/wire.js; keep them in step.
function crypto_words(b, n) {
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

function crypto_words_octets(n, a) {
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

function crypto_fail(code, why) {
  return { $: CID(Fail), error: io_tup(code, why) };
}

const CRYPTO_MISSING = "crypto needs OpenSSL 3 (libcrypto.3); set BEND_LIBCRYPTO to its path";

// libcrypto from BEND_LIBCRYPTO, else the first path that loads; null if none does.
function crypto_lib() {
  if (globalThis.BEND_CRYPTO !== undefined) {
    return globalThis.BEND_CRYPTO;
  }
  globalThis.BEND_CRYPTO = null;
  const ffi = require("bun:ffi");
  const p = "ptr", z = "u64", i = "i32";
  const syms = {
    EVP_Q_digest: { args: [p, p, p, p, z, p, p], returns: i },
    EVP_Q_mac: { args: [p, p, p, p, p, p, z, p, z, p, z, p], returns: p },
    EVP_MD_fetch: { args: [p, p, p], returns: p },
    EVP_MD_free: { args: [p], returns: "void" },
    EVP_PKEY_CTX_new_from_name: { args: [p, p, p], returns: p },
    EVP_PKEY_CTX_free: { args: [p], returns: "void" },
    EVP_PKEY_derive_init: { args: [p], returns: i },
    EVP_PKEY_CTX_set_hkdf_md: { args: [p, p], returns: i },
    EVP_PKEY_CTX_set1_hkdf_salt: { args: [p, p, i], returns: i },
    EVP_PKEY_CTX_set1_hkdf_key: { args: [p, p, i], returns: i },
    EVP_PKEY_CTX_add1_hkdf_info: { args: [p, p, i], returns: i },
    EVP_PKEY_derive: { args: [p, p, p], returns: i },
  };
  for (const path of [process.env.BEND_LIBCRYPTO, "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib",
    "/usr/local/opt/openssl@3/lib/libcrypto.3.dylib", "libcrypto.3.dylib", "libcrypto.so.3"]) {
    if (!path) {
      continue;
    }
    try {
      globalThis.BEND_CRYPTO = { s: ffi.dlopen(path, syms).symbols, ffi };
      break;
    } catch {
      continue;
    }
  }
  return globalThis.BEND_CRYPTO;
}

// A pointer to b; ffi.ptr refuses an empty array.
function crypto_ptr(ffi, b) {
  return ffi.ptr(b.length ? b : new Uint8Array(1));
}

function crypto_cstr(s) {
  return new TextEncoder().encode(s + "\0");
}

function digest_words(alg, n, words) {
  const b = crypto_words_octets(n, words);
  if (b === null || alg.includes("\0")) {
    return io_fail(22);
  }
  const c = crypto_lib();
  if (c === null) {
    return crypto_fail(2, CRYPTO_MISSING);
  }
  const { s, ffi } = c;
  const md = new Uint8Array(64);
  const len = new BigUint64Array(1);
  if (!s.EVP_Q_digest(null, crypto_ptr(ffi, crypto_cstr(alg)), null, crypto_ptr(ffi, b), b.length, ffi.ptr(md), ffi.ptr(len))) {
    return crypto_fail(22, "digest failed; alg must name an OpenSSL digest");
  }
  return io_done(crypto_words(md, Number(len[0])));
}

function hmac_words(alg, kn, kw, dn, dw) {
  const key = crypto_words_octets(kn, kw);
  const data = crypto_words_octets(dn, dw);
  if (key === null || data === null || alg.includes("\0")) {
    return io_fail(22);
  }
  const c = crypto_lib();
  if (c === null) {
    return crypto_fail(2, CRYPTO_MISSING);
  }
  const { s, ffi } = c;
  const md = new Uint8Array(64);
  const len = new BigUint64Array(1);
  const r = s.EVP_Q_mac(null, crypto_ptr(ffi, crypto_cstr("HMAC")), null, crypto_ptr(ffi, crypto_cstr(alg)), null,
    crypto_ptr(ffi, key), key.length, crypto_ptr(ffi, data), data.length, ffi.ptr(md), md.length, ffi.ptr(len));
  if (!r) {
    return crypto_fail(22, "hmac failed; alg must name an OpenSSL digest");
  }
  return io_done(crypto_words(md, Number(len[0])));
}

// An empty salt is left unset: HMAC pads a missing key with zeros, as RFC 5869 §2.2 asks.
function hkdf_words(alg, sn, sw, kn, kw, iln, iw, n) {
  const salt = crypto_words_octets(sn, sw);
  const ikm = crypto_words_octets(kn, kw);
  const info = crypto_words_octets(iln, iw);
  n = Number(n);
  if (salt === null || ikm === null || info === null || alg.includes("\0") || n === 0 || n > 255 * 64) {
    return io_fail(22);
  }
  const c = crypto_lib();
  if (c === null) {
    return crypto_fail(2, CRYPTO_MISSING);
  }
  const { s, ffi } = c;
  const out = new Uint8Array(n);
  const len = new BigUint64Array([BigInt(n)]);
  const md = s.EVP_MD_fetch(null, crypto_ptr(ffi, crypto_cstr(alg)), null);
  const ctx = s.EVP_PKEY_CTX_new_from_name(null, crypto_ptr(ffi, crypto_cstr("HKDF")), null);
  const ok = md && ctx && s.EVP_PKEY_derive_init(ctx) > 0 && s.EVP_PKEY_CTX_set_hkdf_md(ctx, md) > 0
    && (salt.length === 0 || s.EVP_PKEY_CTX_set1_hkdf_salt(ctx, ffi.ptr(salt), salt.length) > 0)
    && s.EVP_PKEY_CTX_set1_hkdf_key(ctx, crypto_ptr(ffi, ikm), ikm.length) > 0
    && (info.length === 0 || s.EVP_PKEY_CTX_add1_hkdf_info(ctx, ffi.ptr(info), info.length) > 0)
    && s.EVP_PKEY_derive(ctx, ffi.ptr(out), ffi.ptr(len)) > 0;
  s.EVP_PKEY_CTX_free(ctx);
  s.EVP_MD_free(md);
  if (!ok) {
    return crypto_fail(22, "hkdf failed; alg must name an OpenSSL digest, and n be at most 255 digest lengths");
  }
  return io_done(crypto_words(out, n));
}

// crypto.getRandomValues gives at most 65536 bytes a call.
function random_words(n) {
  const out = new Uint8Array(Number(n));
  for (let i = 0; i < out.length; i += 65536) {
    crypto.getRandomValues(out.subarray(i, i + 65536));
  }
  return io_done(crypto_words(out, out.length));
}

// The loop reads every octet, so its time depends only on the lengths.
function eq_ct_words(an, aw, bn, bw) {
  const a = crypto_words_octets(an, aw);
  const b = crypto_words_octets(bn, bw);
  if (a === null || b === null || a.length !== b.length) {
    return false;
  }
  let d = 0;
  for (let i = 0; i < a.length; i += 1) {
    d |= a[i] ^ b[i];
  }
  return d === 0;
}

io_eff(CID(digest.words), digest_words);
io_eff(CID(hmac.words), hmac_words);
io_eff(CID(hkdf.words), hkdf_words);
io_eff(CID(random.words), random_words);
io_eff(CID(eq.ct.words), eq_ct_words);
