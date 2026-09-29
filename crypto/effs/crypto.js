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
    PKCS5_PBKDF2_HMAC: { args: [p, i, p, i, i, p, i, p], returns: i },
    EVP_PBE_scrypt: { args: [p, z, p, z, z, z, z, z, p, z], returns: i },
    BIO_new_mem_buf: { args: [p, i], returns: p },
    BIO_free: { args: [p], returns: i },
    PEM_read_bio_PrivateKey: { args: [p, p, p, p], returns: p },
    PEM_read_bio_PUBKEY: { args: [p, p, p, p], returns: p },
    d2i_PUBKEY: { args: [p, p, "i64"], returns: p },
    EVP_PKEY_free: { args: [p], returns: "void" },
    EVP_PKEY_get_base_id: { args: [p], returns: i },
    EVP_PKEY_get_bits: { args: [p], returns: i },
    EVP_PKEY_get_group_name: { args: [p, p, z, p], returns: i },
    EVP_MD_CTX_new: { args: [], returns: p },
    EVP_MD_CTX_free: { args: [p], returns: "void" },
    EVP_DigestSignInit_ex: { args: [p, p, p, p, p, p, p], returns: i },
    EVP_DigestSign: { args: [p, p, p, p, z], returns: i },
    EVP_DigestVerifyInit_ex: { args: [p, p, p, p, p, p, p], returns: i },
    EVP_DigestVerify: { args: [p, p, z, p, z], returns: i },
    EVP_PKEY_CTX_set_rsa_padding: { args: [p, i], returns: i },
    ERR_clear_error: { args: [], returns: "void" },
    EVP_CIPHER_fetch: { args: [p, p, p], returns: p },
    EVP_CIPHER_free: { args: [p], returns: "void" },
    EVP_CIPHER_CTX_new: { args: [], returns: p },
    EVP_CIPHER_CTX_free: { args: [p], returns: "void" },
    EVP_CipherInit_ex2: { args: [p, p, p, p, i, p], returns: i },
    EVP_CipherUpdate: { args: [p, p, p, p, i], returns: i },
    EVP_CipherFinal_ex: { args: [p, p, p], returns: i },
    EVP_CIPHER_CTX_ctrl: { args: [p, i, i, p], returns: i },
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

function pbkdf2_words(alg, pn, pw, sn, sw, iters, n) {
  const pass = crypto_words_octets(pn, pw);
  const salt = crypto_words_octets(sn, sw);
  iters = Number(iters);
  n = Number(n);
  if (pass === null || salt === null || alg.includes("\0") || iters === 0 || iters > 0x7fffffff || n === 0 || n > 0x7fffffff) {
    return io_fail(22);
  }
  const c = crypto_lib();
  if (c === null) {
    return crypto_fail(2, CRYPTO_MISSING);
  }
  const { s, ffi } = c;
  const out = new Uint8Array(n);
  const md = s.EVP_MD_fetch(null, crypto_ptr(ffi, crypto_cstr(alg)), null);
  const ok = md && s.PKCS5_PBKDF2_HMAC(crypto_ptr(ffi, pass), pass.length, crypto_ptr(ffi, salt), salt.length, iters, md, n, ffi.ptr(out)) === 1;
  s.EVP_MD_free(md);
  if (!ok) {
    return crypto_fail(22, "pbkdf2 failed; alg must name an OpenSSL digest");
  }
  return io_done(crypto_words(out, n));
}

// scrypt (RFC 7914) takes 128 r (N + p + 2) octets of workspace; maxmem bounds that plus the n output octets.
// Every U32 and their sums stay below 2^53, so Number math is exact.
// ponytail: runs on the loop thread; move off it if large costs stall the loop.
function scrypt_words(pn, pw, sn, sw, N, r, p, maxmem, n) {
  [pn, sn, N, r, p, maxmem, n] = [pn, sn, N, r, p, maxmem, n].map(Number);
  const block = 128 * r;
  if (N < 2 || (N & (N - 1)) !== 0 || r === 0 || p === 0 || n === 0 || maxmem === 0 || r > Math.floor(maxmem / 128)
    || N + p + 2 > Math.floor(maxmem / block) || n > maxmem - block * (N + p + 2)) {
    return crypto_fail(22, "scrypt needs N a power of 2 >= 2, positive r, p, n, and 128 r (N + p + 2) + n <= maxmem");
  }
  if (pn > 4 * pw.length || sn > 4 * sw.length) {
    return io_fail(22);
  }
  const pass = crypto_words_octets(pn, pw);
  const salt = crypto_words_octets(sn, sw);
  const c = crypto_lib();
  if (c === null) {
    pass.fill(0);
    return crypto_fail(2, CRYPTO_MISSING);
  }
  const { s, ffi } = c;
  const out = new Uint8Array(n);
  const ok = s.EVP_PBE_scrypt(crypto_ptr(ffi, pass), pass.length, crypto_ptr(ffi, salt), salt.length,
    N, r, p, maxmem, ffi.ptr(out), n) === 1;
  pass.fill(0);
  if (!ok) {
    out.fill(0);
    s.ERR_clear_error();
    return crypto_fail(22, "scrypt failed; OpenSSL also needs N < 2^(16 r) and p r < 2^30");
  }
  const result = crypto_words(out, n);
  out.fill(0);
  return io_done(result);
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

// EVP_PKEY_RSA and EVP_PKEY_EC.
const CRYPTO_RSA = 6;
const CRYPTO_EC = 408;

// Each key type takes only its own digests, so an RS256 key can not verify an ES256 token or the reverse.
function crypto_pk_alg(kind, alg) {
  return alg === "SHA256" || (kind === CRYPTO_RSA && (alg === "SHA384" || alg === "SHA512"));
}

function crypto_pk_alg_why(kind) {
  return kind === CRYPTO_RSA ? "rsa alg must be SHA256, SHA384, or SHA512" : "ecdsa alg must be SHA256";
}

// An RSA key of at least 2048 bits (RFC 7518 §3.3), or an EC key on P-256; RSA-PSS and other types fail.
function crypto_pk_kind(c, k, kind) {
  const { s, ffi } = c;
  if (!k || s.EVP_PKEY_get_base_id(k) !== kind) {
    return false;
  }
  if (kind === CRYPTO_RSA) {
    return s.EVP_PKEY_get_bits(k) >= 2048;
  }
  const g = new Uint8Array(32);
  const gn = new BigUint64Array(1);
  return s.EVP_PKEY_get_group_name(k, ffi.ptr(g), g.length, ffi.ptr(gn)) === 1
    && new TextDecoder().decode(g.subarray(0, Number(gn[0]))) === "prime256v1";
}

// The empty passphrase stops OpenSSL from prompting on the terminal; an encrypted key fails to load.
function crypto_pem(c, p, priv) {
  const { s, ffi } = c;
  const bio = s.BIO_new_mem_buf(crypto_ptr(ffi, p), p.length);
  const pass = crypto_cstr("");
  const k = bio ? (priv ? s.PEM_read_bio_PrivateKey : s.PEM_read_bio_PUBKEY)(bio, null, null, ffi.ptr(pass)) : null;
  s.BIO_free(bio);
  return k;
}

// A DER header and body: tag, length (short or long form), then the octets of p.
function crypto_der(tag, p) {
  const n = p.length;
  const len = [];
  for (let m = n; m > 0; m = Math.floor(m / 256)) {
    len.unshift(m & 255);
  }
  return [tag, ...(n < 128 ? [n] : [0x80 | len.length, ...len]), ...p];
}

// A DER INTEGER of unsigned big-endian octets: leading zeros dropped, one added if the top bit is set.
function crypto_der_uint(p) {
  let i = 0;
  while (i < p.length && p[i] === 0) {
    i += 1;
  }
  const b = Array.from(p.subarray(i));
  return crypto_der(0x02, b.length === 0 || b[0] & 0x80 ? [0, ...b] : b);
}

// The DER ECDSA-Sig-Value of a raw JOSE r || s signature (RFC 7518 §3.4).
function crypto_ec_der(raw) {
  return crypto_der(0x30, [...crypto_der_uint(raw.subarray(0, 32)), ...crypto_der_uint(raw.subarray(32, 64))]);
}

// The raw 64-octet r || s of a DER ECDSA-Sig-Value; null if it is malformed or a half is over 32 octets.
function crypto_ec_raw(d) {
  const out = new Uint8Array(64);
  let i = 2;
  if (d.length < 2 || d[0] !== 0x30 || d[1] !== d.length - 2) {
    return null;
  }
  for (let h = 0; h < 2; h += 1) {
    if (i + 2 > d.length || d[i] !== 0x02 || i + 2 + d[i + 1] > d.length) {
      return null;
    }
    let p = d.subarray(i + 2, i + 2 + d[i + 1]);
    i += 2 + d[i + 1];
    while (p.length > 0 && p[0] === 0) {
      p = p.subarray(1);
    }
    if (p.length > 32) {
      return null;
    }
    out.set(p, 32 * h + 32 - p.length);
  }
  return i === d.length ? out : null;
}

// A SubjectPublicKeyInfo key from JWK parts (RFC 7518 §6.2-6.3): RSA n and e, or P-256 x and y, as big-endian
// octets. null if they do not fit; RSA also needs an odd e of at least 3, since e = 1 lets anyone sign.
function crypto_jwk(c, kind, a, b) {
  const { s, ffi } = c;
  let spki;
  if (kind === CRYPTO_EC) {
    if (a.length !== 32 || b.length !== 32) {
      return null;
    }
    const id = [0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07];
    spki = crypto_der(0x30, [...id, ...crypto_der(0x03, [0, 4, ...a, ...b])]);
  } else {
    let z = 0;
    while (z < b.length && b[z] === 0) {
      z += 1;
    }
    // 16384 bits is OpenSSL's largest RSA modulus.
    const en = b.length - z;
    if (a.length > 2049 || en === 0 || en > 8 || (b[b.length - 1] & 1) === 0 || (en === 1 && b[z] < 3)) {
      return null;
    }
    const id = [0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00];
    const key = crypto_der(0x30, [...crypto_der_uint(a), ...crypto_der_uint(b)]);
    spki = crypto_der(0x30, [...id, ...crypto_der(0x03, [0, ...key])]);
  }
  const der = new Uint8Array(spki);
  const pp = new BigUint64Array([BigInt(ffi.ptr(der))]);
  return s.d2i_PUBKEY(null, ffi.ptr(pp), der.length);
}

// PKCS#1 v1.5 for RSA; ECDSA gives DER, turned into raw r || s. null on failure.
function crypto_sign(c, k, kind, alg, d) {
  const { s, ffi } = c;
  const ctx = s.EVP_MD_CTX_new();
  const pctx = new BigUint64Array(1);
  const n = new BigUint64Array(1);
  const name = crypto_cstr(alg);
  let sig = null;
  if (ctx && s.EVP_DigestSignInit_ex(ctx, ffi.ptr(pctx), ffi.ptr(name), null, null, k, null) === 1
    && (kind !== CRYPTO_RSA || s.EVP_PKEY_CTX_set_rsa_padding(Number(pctx[0]), 1) > 0)
    && s.EVP_DigestSign(ctx, null, ffi.ptr(n), crypto_ptr(ffi, d), d.length) === 1) {
    const out = new Uint8Array(Number(n[0]));
    if (s.EVP_DigestSign(ctx, ffi.ptr(out), ffi.ptr(n), crypto_ptr(ffi, d), d.length) === 1) {
      sig = out.subarray(0, Number(n[0]));
    }
  }
  s.EVP_MD_CTX_free(ctx);
  return sig !== null && kind === CRYPTO_EC ? crypto_ec_raw(sig) : sig;
}

// 1 for a valid signature, 0 for an invalid one (any length or encoding), -1 when OpenSSL can not set up.
function crypto_verify(c, k, kind, alg, d, sig) {
  const { s, ffi } = c;
  if (kind === CRYPTO_EC) {
    if (sig.length !== 64) {
      return 0;
    }
    sig = new Uint8Array(crypto_ec_der(sig));
  }
  const ctx = s.EVP_MD_CTX_new();
  const pctx = new BigUint64Array(1);
  const name = crypto_cstr(alg);
  const r = ctx && s.EVP_DigestVerifyInit_ex(ctx, ffi.ptr(pctx), ffi.ptr(name), null, null, k, null) === 1
    && (kind !== CRYPTO_RSA || s.EVP_PKEY_CTX_set_rsa_padding(Number(pctx[0]), 1) > 0)
    ? (s.EVP_DigestVerify(ctx, crypto_ptr(ffi, sig), sig.length, crypto_ptr(ffi, d), d.length) === 1 ? 1 : 0)
    : -1;
  s.EVP_MD_CTX_free(ctx);
  return r;
}

function crypto_sign_run(kind, alg, kn, kw, dn, dw) {
  const key = crypto_words_octets(kn, kw);
  const data = crypto_words_octets(dn, dw);
  if (key === null || data === null || alg.includes("\0")) {
    return io_fail(22);
  }
  if (!crypto_pk_alg(kind, alg)) {
    return crypto_fail(22, crypto_pk_alg_why(kind));
  }
  const c = crypto_lib();
  if (c === null) {
    return crypto_fail(2, CRYPTO_MISSING);
  }
  const k = crypto_pem(c, key, true);
  let r;
  if (!crypto_pk_kind(c, k, kind)) {
    r = crypto_fail(22, kind === CRYPTO_RSA ? "key must be an unencrypted PEM RSA private key of at least 2048 bits"
      : "key must be an unencrypted PEM EC private key on P-256");
  } else {
    const sig = crypto_sign(c, k, kind, alg, data);
    r = sig === null ? crypto_fail(22, "signing failed") : io_done(crypto_words(sig, sig.length));
  }
  c.s.EVP_PKEY_free(k);
  c.s.ERR_clear_error();
  return r;
}

// parts is [len, words] of the PEM key, or of both JWK parts.
function crypto_verify_run(kind, jwk, alg, parts, dn, dw, sn, sw) {
  const a = crypto_words_octets(parts[0], parts[1]);
  const b = jwk ? crypto_words_octets(parts[2], parts[3]) : new Uint8Array(0);
  const data = crypto_words_octets(dn, dw);
  const sig = crypto_words_octets(sn, sw);
  if (a === null || b === null || data === null || sig === null || alg.includes("\0")) {
    return io_fail(22);
  }
  if (!crypto_pk_alg(kind, alg)) {
    return crypto_fail(22, crypto_pk_alg_why(kind));
  }
  const c = crypto_lib();
  if (c === null) {
    return crypto_fail(2, CRYPTO_MISSING);
  }
  const k = jwk ? crypto_jwk(c, kind, a, b) : crypto_pem(c, a, false);
  let r;
  if (!crypto_pk_kind(c, k, kind)) {
    r = crypto_fail(22, jwk ? (kind === CRYPTO_RSA ? "jwk must give an RSA n of at least 2048 bits and an odd e >= 3"
      : "jwk must give 32-octet x and y of a P-256 point")
      : (kind === CRYPTO_RSA ? "key must be a PEM RSA public key of at least 2048 bits"
        : "key must be a PEM EC public key on P-256"));
  } else {
    const v = crypto_verify(c, k, kind, alg, data, sig);
    r = v < 0 ? crypto_fail(22, "verify failed to start") : io_done(v === 1);
  }
  c.s.EVP_PKEY_free(k);
  c.s.ERR_clear_error();
  return r;
}

// ponytail: signatures run on the loop thread (about 1 ms for RSA-2048 signing); move off it if that stalls.
function rsa_sign_words(alg, kn, kw, dn, dw) {
  return crypto_sign_run(CRYPTO_RSA, alg, kn, kw, dn, dw);
}

function rsa_verify_words(alg, kn, kw, dn, dw, sn, sw) {
  return crypto_verify_run(CRYPTO_RSA, false, alg, [kn, kw], dn, dw, sn, sw);
}

function rsa_verify_jwk_words(alg, nn, nw, en, ew, dn, dw, sn, sw) {
  return crypto_verify_run(CRYPTO_RSA, true, alg, [nn, nw, en, ew], dn, dw, sn, sw);
}

function ecdsa_sign_words(alg, kn, kw, dn, dw) {
  return crypto_sign_run(CRYPTO_EC, alg, kn, kw, dn, dw);
}

function ecdsa_verify_words(alg, kn, kw, dn, dw, sn, sw) {
  return crypto_verify_run(CRYPTO_EC, false, alg, [kn, kw], dn, dw, sn, sw);
}

function ecdsa_verify_jwk_words(alg, xn, xw, yn, yw, dn, dw, sn, sw) {
  return crypto_verify_run(CRYPTO_EC, true, alg, [xn, xw, yn, yw], dn, dw, sn, sw);
}

// EVP_CTRL_AEAD_GET_TAG and EVP_CTRL_AEAD_SET_TAG; both ciphers take a 32-octet key, 12-octet nonce, 16-octet tag.
const CRYPTO_GET_TAG = 0x10;
const CRYPTO_SET_TAG = 0x11;
const CRYPTO_INT_MAX = 0x7fffffff;

// Seal gives ciphertext || tag; open takes it and gives plaintext only once the tag checks. AAD and data stay
// within the int EVP counts, so seal's output is at most INT_MAX + 16 octets and fits a U32.
function crypto_aead(enc, alg, kn, kw, nn, nw, an, aw, dn, dw) {
  if (alg.includes("\0") || kn !== 32 || nn !== 12 || an > CRYPTO_INT_MAX || dn > CRYPTO_INT_MAX || (!enc && dn < 16)) {
    return io_fail(22);
  }
  const key = crypto_words_octets(kn, kw);
  const nonce = crypto_words_octets(nn, nw);
  const aad = crypto_words_octets(an, aw);
  const data = crypto_words_octets(dn, dw);
  if (key === null || nonce === null || aad === null || data === null) {
    key?.fill(0);
    data?.fill(0);
    return io_fail(22);
  }
  if (alg !== "AES-256-GCM" && alg !== "CHACHA20-POLY1305") {
    key.fill(0);
    data.fill(0);
    return crypto_fail(22, "aead alg must be AES-256-GCM or CHACHA20-POLY1305");
  }
  const c = crypto_lib();
  if (c === null) {
    key.fill(0);
    data.fill(0);
    return crypto_fail(2, CRYPTO_MISSING);
  }
  const { s, ffi } = c;
  const n = enc ? data.length : data.length - 16;
  const input = data.subarray(0, n);
  const tag = enc ? null : data.slice(n);
  // enc: n octets of ciphertext then the tag; open: the plaintext staging, wiped unless the tag checks.
  const out = new Uint8Array(enc ? n + 16 : n);
  const outl = new Int32Array(1);
  const cipher = s.EVP_CIPHER_fetch(null, ffi.ptr(crypto_cstr(alg === "AES-256-GCM" ? alg : "ChaCha20-Poly1305")), null);
  const ctx = s.EVP_CIPHER_CTX_new();
  const ok = cipher && ctx && s.EVP_CipherInit_ex2(ctx, cipher, ffi.ptr(key), ffi.ptr(nonce), enc ? 1 : 0, null) === 1
    && (aad.length === 0 || s.EVP_CipherUpdate(ctx, null, ffi.ptr(outl), ffi.ptr(aad), aad.length) === 1)
    && (n === 0 || (s.EVP_CipherUpdate(ctx, ffi.ptr(out), ffi.ptr(outl), ffi.ptr(input), n) === 1 && outl[0] === n))
    && (enc || s.EVP_CIPHER_CTX_ctrl(ctx, CRYPTO_SET_TAG, 16, ffi.ptr(tag)) === 1)
    && s.EVP_CipherFinal_ex(ctx, crypto_ptr(ffi, out), ffi.ptr(outl)) === 1 && outl[0] === 0
    && (!enc || s.EVP_CIPHER_CTX_ctrl(ctx, CRYPTO_GET_TAG, 16, ffi.ptr(out.subarray(n))) === 1);
  s.EVP_CIPHER_CTX_free(ctx);
  s.EVP_CIPHER_free(cipher);
  s.ERR_clear_error();
  key.fill(0);
  if (!ok) {
    out.fill(0);
    data.fill(0);
    return crypto_fail(22, enc ? "aead seal failed" : "aead open failed; ciphertext, tag, nonce, or aad do not authenticate");
  }
  const result = crypto_words(out, out.length);
  out.fill(0);
  data.fill(0);
  return io_done(result);
}

function aead_seal_words(alg, kn, kw, nn, nw, an, aw, dn, dw) {
  return crypto_aead(true, alg, kn, kw, nn, nw, an, aw, dn, dw);
}

function aead_open_words(alg, kn, kw, nn, nw, an, aw, dn, dw) {
  return crypto_aead(false, alg, kn, kw, nn, nw, an, aw, dn, dw);
}

io_eff(CID(digest.words), digest_words);
io_eff(CID(hmac.words), hmac_words);
io_eff(CID(hkdf.words), hkdf_words);
io_eff(CID(pbkdf2.words), pbkdf2_words);
io_eff(CID(scrypt.words), scrypt_words);
io_eff(CID(random.words), random_words);
io_eff(CID(eq.ct.words), eq_ct_words);
io_eff(CID(rsa.sign.words), rsa_sign_words);
io_eff(CID(rsa.verify.words), rsa_verify_words);
io_eff(CID(rsa.verify.jwk.words), rsa_verify_jwk_words);
io_eff(CID(ecdsa.sign.words), ecdsa_sign_words);
io_eff(CID(ecdsa.verify.words), ecdsa_verify_words);
io_eff(CID(ecdsa.verify.jwk.words), ecdsa_verify_jwk_words);
io_eff(CID(aead.seal.words), aead_seal_words);
io_eff(CID(aead.open.words), aead_open_words);
