// Crypto
// ======
// Hashes, HMAC, HKDF, PBKDF2, RSA and ECDSA signatures, and AES-256-GCM and ChaCha20-Poly1305 AEAD through
// OpenSSL 3 libcrypto, loaded with dlopen; secure random bytes from the OS.

#if defined(CID(digest.words)) || defined(CID(hmac.words)) || defined(CID(hkdf.words)) || defined(CID(pbkdf2.words)) || defined(CID(random.words)) || defined(CID(eq.ct.words)) \
  || defined(CID(rsa.sign.words)) || defined(CID(rsa.verify.words)) || defined(CID(rsa.verify.jwk.words)) \
  || defined(CID(ecdsa.sign.words)) || defined(CID(ecdsa.verify.words)) || defined(CID(ecdsa.verify.jwk.words)) \
  || defined(CID(aead.seal.words)) || defined(CID(aead.open.words))
#ifndef CRYPTO_EFFS
#define CRYPTO_EFFS
#include <dlfcn.h>
#include <string.h>
#include <unistd.h>
#ifdef __APPLE__
#include <sys/random.h>
#endif

// Copies of wire_words and wire_words_octets in wire/effs/wire.c; keep them in step.
static Term crypto_words(Env e, const unsigned char* p, u64 n) {
  u64  w    = (n + 3) / 4;
  u64  d    = 0;
  Term zero = 0;
  while ((1ull << d) < w) {
    d += 1;
  }
  Term a = blk_new(e, false, d, 0, 1, &zero);
  u64  l = blk_loc(e.mem, a);
  for (u64 k = 0; k < w; k += 1) {
    u32 x = 0;
    for (u64 j = 0; j < 4 && 4 * k + j < n; j += 1) {
      x |= (u32)p[4 * k + j] << (8 * j);
    }
    blk_write(e.mem, false, l, (u32)k, x);
  }
  return io_tup(e, (Term)n, a);
}

static unsigned char* crypto_words_octets(Env e, Term a, u64 n, u64* len, bool* bad) {
  u64* H = e.mem;
  bool b = term_tag(a) != TAG_BUF || n > (4ull << blk_cls(a));
  *bad   = *bad || b;
  *len   = b ? 0 : n;
  unsigned char* buf = io_mem(malloc(*len + 1));
  u64            l   = b ? 0 : blk_loc(H, a);
  for (u64 i = 0; i < *len; i += 1) {
    buf[i] = (unsigned char)(blk_read(H, false, l, (u32)(i / 4)) >> (8 * (i % 4)));
  }
  term_drop(e, a);
  return buf;
}

static Term crypto_out(Env e, const unsigned char* p, u64 n) {
  return io_done(e, crypto_words(e, p, n));
}

#endif
#endif

#if defined(CID(digest.words)) || defined(CID(hmac.words)) || defined(CID(hkdf.words)) || defined(CID(pbkdf2.words)) \
  || defined(CID(rsa.sign.words)) || defined(CID(rsa.verify.words)) || defined(CID(rsa.verify.jwk.words)) \
  || defined(CID(ecdsa.sign.words)) || defined(CID(ecdsa.verify.words)) || defined(CID(ecdsa.verify.jwk.words)) \
  || defined(CID(aead.seal.words)) || defined(CID(aead.open.words))
#ifndef CRYPTO_LIB
#define CRYPTO_LIB

#define CRYPTO_MISSING "crypto needs OpenSSL 3 (libcrypto.3); set BEND_LIBCRYPTO to its path"

static struct {
  int state;
  int (*q_digest)(void*, const char*, const char*, const void*, size_t, unsigned char*, size_t*);
  unsigned char* (*q_mac)(void*, const char*, const char*, const char*, const void*, const void*, size_t,
    const unsigned char*, size_t, unsigned char*, size_t, size_t*);
  void* (*md_fetch)(void*, const char*, const char*);
  void  (*md_free)(void*);
  void* (*ctx_new)(void*, const char*, const char*);
  void  (*ctx_free)(void*);
  int   (*derive_init)(void*);
  int   (*set_md)(void*, const void*);
  int   (*set_salt)(void*, const unsigned char*, int);
  int   (*set_key)(void*, const unsigned char*, int);
  int   (*add_info)(void*, const unsigned char*, int);
  int   (*derive)(void*, unsigned char*, size_t*);
  int   (*pbkdf2)(const char*, int, const unsigned char*, int, int, const void*, int, unsigned char*);
  void* (*bio_mem)(const void*, int);
  int   (*bio_free)(void*);
  void* (*pem_priv)(void*, void*, void*, void*);
  void* (*pem_pub)(void*, void*, void*, void*);
  void* (*d2i_pub)(void*, const unsigned char**, long);
  void  (*pkey_free)(void*);
  int   (*pkey_id)(const void*);
  int   (*pkey_bits)(const void*);
  int   (*group_name)(const void*, char*, size_t, size_t*);
  void* (*md_ctx_new)(void);
  void  (*md_ctx_free)(void*);
  int   (*sign_init)(void*, void**, const char*, void*, const char*, void*, const void*);
  int   (*sign)(void*, unsigned char*, size_t*, const unsigned char*, size_t);
  int   (*verify_init)(void*, void**, const char*, void*, const char*, void*, const void*);
  int   (*verify)(void*, const unsigned char*, size_t, const unsigned char*, size_t);
  int   (*set_padding)(void*, int);
  void  (*err_clear)(void);
  void* (*cipher_fetch)(void*, const char*, const char*);
  void  (*cipher_free)(void*);
  void* (*cipher_ctx_new)(void);
  void  (*cipher_ctx_free)(void*);
  int   (*cipher_init)(void*, const void*, const unsigned char*, const unsigned char*, int, const void*);
  int   (*cipher_update)(void*, unsigned char*, int*, const unsigned char*, int);
  int   (*cipher_final)(void*, unsigned char*, int*);
  int   (*cipher_ctrl)(void*, int, int, void*);
} crypto_lib;

static bool crypto_load(void) {
  if (crypto_lib.state != 0) {
    return crypto_lib.state > 0;
  }
  crypto_lib.state = -1;
  const char* paths[] = { getenv("BEND_LIBCRYPTO"),
    "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib",
    "/usr/local/opt/openssl@3/lib/libcrypto.3.dylib", "libcrypto.3.dylib", "libcrypto.so.3" };
  void* h = NULL;
  for (u64 i = 0; h == NULL && i < sizeof(paths) / sizeof(paths[0]); i += 1) {
    h = paths[i] != NULL ? dlopen(paths[i], RTLD_NOW | RTLD_LOCAL) : NULL;
  }
  if (h == NULL) {
    return false;
  }
  crypto_lib.q_digest    = dlsym(h, "EVP_Q_digest");
  crypto_lib.q_mac       = dlsym(h, "EVP_Q_mac");
  crypto_lib.md_fetch    = dlsym(h, "EVP_MD_fetch");
  crypto_lib.md_free     = dlsym(h, "EVP_MD_free");
  crypto_lib.ctx_new     = dlsym(h, "EVP_PKEY_CTX_new_from_name");
  crypto_lib.ctx_free    = dlsym(h, "EVP_PKEY_CTX_free");
  crypto_lib.derive_init = dlsym(h, "EVP_PKEY_derive_init");
  crypto_lib.set_md      = dlsym(h, "EVP_PKEY_CTX_set_hkdf_md");
  crypto_lib.set_salt    = dlsym(h, "EVP_PKEY_CTX_set1_hkdf_salt");
  crypto_lib.set_key     = dlsym(h, "EVP_PKEY_CTX_set1_hkdf_key");
  crypto_lib.add_info    = dlsym(h, "EVP_PKEY_CTX_add1_hkdf_info");
  crypto_lib.derive      = dlsym(h, "EVP_PKEY_derive");
  crypto_lib.pbkdf2      = dlsym(h, "PKCS5_PBKDF2_HMAC");
  crypto_lib.bio_mem     = dlsym(h, "BIO_new_mem_buf");
  crypto_lib.bio_free    = dlsym(h, "BIO_free");
  crypto_lib.pem_priv    = dlsym(h, "PEM_read_bio_PrivateKey");
  crypto_lib.pem_pub     = dlsym(h, "PEM_read_bio_PUBKEY");
  crypto_lib.d2i_pub     = dlsym(h, "d2i_PUBKEY");
  crypto_lib.pkey_free   = dlsym(h, "EVP_PKEY_free");
  crypto_lib.pkey_id     = dlsym(h, "EVP_PKEY_get_base_id");
  crypto_lib.pkey_bits   = dlsym(h, "EVP_PKEY_get_bits");
  crypto_lib.group_name  = dlsym(h, "EVP_PKEY_get_group_name");
  crypto_lib.md_ctx_new  = dlsym(h, "EVP_MD_CTX_new");
  crypto_lib.md_ctx_free = dlsym(h, "EVP_MD_CTX_free");
  crypto_lib.sign_init   = dlsym(h, "EVP_DigestSignInit_ex");
  crypto_lib.sign        = dlsym(h, "EVP_DigestSign");
  crypto_lib.verify_init = dlsym(h, "EVP_DigestVerifyInit_ex");
  crypto_lib.verify      = dlsym(h, "EVP_DigestVerify");
  crypto_lib.set_padding = dlsym(h, "EVP_PKEY_CTX_set_rsa_padding");
  crypto_lib.err_clear   = dlsym(h, "ERR_clear_error");
  crypto_lib.cipher_fetch    = dlsym(h, "EVP_CIPHER_fetch");
  crypto_lib.cipher_free     = dlsym(h, "EVP_CIPHER_free");
  crypto_lib.cipher_ctx_new  = dlsym(h, "EVP_CIPHER_CTX_new");
  crypto_lib.cipher_ctx_free = dlsym(h, "EVP_CIPHER_CTX_free");
  crypto_lib.cipher_init     = dlsym(h, "EVP_CipherInit_ex2");
  crypto_lib.cipher_update   = dlsym(h, "EVP_CipherUpdate");
  crypto_lib.cipher_final    = dlsym(h, "EVP_CipherFinal_ex");
  crypto_lib.cipher_ctrl     = dlsym(h, "EVP_CIPHER_CTX_ctrl");
  bool ok = crypto_lib.q_digest && crypto_lib.q_mac && crypto_lib.md_fetch && crypto_lib.md_free
    && crypto_lib.ctx_new && crypto_lib.ctx_free && crypto_lib.derive_init && crypto_lib.set_md
    && crypto_lib.set_salt && crypto_lib.set_key && crypto_lib.add_info && crypto_lib.derive && crypto_lib.pbkdf2
    && crypto_lib.bio_mem && crypto_lib.bio_free && crypto_lib.pem_priv && crypto_lib.pem_pub && crypto_lib.d2i_pub
    && crypto_lib.pkey_free && crypto_lib.pkey_id && crypto_lib.pkey_bits && crypto_lib.group_name
    && crypto_lib.md_ctx_new && crypto_lib.md_ctx_free && crypto_lib.sign_init && crypto_lib.sign
    && crypto_lib.verify_init && crypto_lib.verify && crypto_lib.set_padding && crypto_lib.err_clear
    && crypto_lib.cipher_fetch && crypto_lib.cipher_free && crypto_lib.cipher_ctx_new && crypto_lib.cipher_ctx_free
    && crypto_lib.cipher_init && crypto_lib.cipher_update && crypto_lib.cipher_final && crypto_lib.cipher_ctrl;
  crypto_lib.state = ok ? 1 : -1;
  return ok;
}

#endif
#endif

#ifdef CID(digest.words)

// ponytail: digests run on the loop thread; move them to io_work if inputs get big enough to stall other effects.
Term digest_words_run(Env e, Term* f, IoWork* w) {
  u64            alen = 0;
  char*          alg  = io_cstr(e, f[0], &alen);
  u64            n    = 0;
  bool           bad  = io_nul(alg, alen);
  unsigned char* in   = crypto_words_octets(e, f[2], (u64)(u32)f[1], &n, &bad);
  unsigned char  md[64];
  size_t         mdlen = 0;
  Term           t;
  if (bad) {
    t = io_fail(e, EINVAL, NULL);
  } else if (!crypto_load()) {
    t = io_fail(e, ENOENT, CRYPTO_MISSING);
  } else if (!crypto_lib.q_digest(NULL, alg, NULL, in, n, md, &mdlen)) {
    t = io_fail(e, EINVAL, "digest failed; alg must name an OpenSSL digest");
  } else {
    t = crypto_out(e, md, mdlen);
  }
  free(alg);
  free(in);
  return t;
}

static void __attribute__((constructor)) digest_words_use(void) {
  io_eff(CID(digest.words), digest_words_run, 0);
}

#endif

#ifdef CID(hmac.words)

Term hmac_words_run(Env e, Term* f, IoWork* w) {
  u64            alen   = 0;
  char*          alg    = io_cstr(e, f[0], &alen);
  u64            kn     = 0;
  u64            dn     = 0;
  bool           bad    = io_nul(alg, alen);
  unsigned char* key    = crypto_words_octets(e, f[2], (u64)(u32)f[1], &kn, &bad);
  unsigned char* data   = crypto_words_octets(e, f[4], (u64)(u32)f[3], &dn, &bad);
  unsigned char  md[64];
  size_t         mdlen  = 0;
  Term           t;
  if (bad) {
    t = io_fail(e, EINVAL, NULL);
  } else if (!crypto_load()) {
    t = io_fail(e, ENOENT, CRYPTO_MISSING);
  } else if (crypto_lib.q_mac(NULL, "HMAC", NULL, alg, NULL, key, kn, data, dn, md, sizeof md, &mdlen) == NULL) {
    t = io_fail(e, EINVAL, "hmac failed; alg must name an OpenSSL digest");
  } else {
    t = crypto_out(e, md, mdlen);
  }
  free(alg);
  free(key);
  free(data);
  return t;
}

static void __attribute__((constructor)) hmac_words_use(void) {
  io_eff(CID(hmac.words), hmac_words_run, 0);
}

#endif

#ifdef CID(hkdf.words)

// An empty salt is left unset: HMAC pads a missing key with zeros, as RFC 5869 §2.2 asks.
static bool crypto_hkdf(const char* alg, unsigned char* salt, u64 sn, unsigned char* ikm, u64 kn,
  unsigned char* info, u64 in, unsigned char* out, size_t n) {
  void* md  = crypto_lib.md_fetch(NULL, alg, NULL);
  void* ctx = crypto_lib.ctx_new(NULL, "HKDF", NULL);
  bool  ok  = md != NULL && ctx != NULL && crypto_lib.derive_init(ctx) > 0 && crypto_lib.set_md(ctx, md) > 0
    && (sn == 0 || crypto_lib.set_salt(ctx, salt, (int)sn) > 0)
    && crypto_lib.set_key(ctx, ikm, (int)kn) > 0
    && (in == 0 || crypto_lib.add_info(ctx, info, (int)in) > 0)
    && crypto_lib.derive(ctx, out, &n) > 0;
  crypto_lib.ctx_free(ctx);
  crypto_lib.md_free(md);
  return ok;
}

Term hkdf_words_run(Env e, Term* f, IoWork* w) {
  u64            alen = 0;
  char*          alg  = io_cstr(e, f[0], &alen);
  u64            sn   = 0;
  u64            kn   = 0;
  u64            in   = 0;
  u64            n    = (u64)(u32)f[7];
  bool           bad  = io_nul(alg, alen) || n == 0 || n > 255 * 64;
  unsigned char* salt = crypto_words_octets(e, f[2], (u64)(u32)f[1], &sn, &bad);
  unsigned char* ikm  = crypto_words_octets(e, f[4], (u64)(u32)f[3], &kn, &bad);
  unsigned char* info = crypto_words_octets(e, f[6], (u64)(u32)f[5], &in, &bad);
  unsigned char* out  = io_mem(malloc(n + 1));
  Term           t;
  if (bad || sn > INT32_MAX || kn > INT32_MAX || in > INT32_MAX) {
    t = io_fail(e, EINVAL, NULL);
  } else if (!crypto_load()) {
    t = io_fail(e, ENOENT, CRYPTO_MISSING);
  } else if (!crypto_hkdf(alg, salt, sn, ikm, kn, info, in, out, (size_t)n)) {
    t = io_fail(e, EINVAL, "hkdf failed; alg must name an OpenSSL digest, and n be at most 255 digest lengths");
  } else {
    t = crypto_out(e, out, n);
  }
  free(alg);
  free(salt);
  free(ikm);
  free(info);
  free(out);
  return t;
}

static void __attribute__((constructor)) hkdf_words_use(void) {
  io_eff(CID(hkdf.words), hkdf_words_run, 0);
}

#endif

#ifdef CID(pbkdf2.words)

// ponytail: runs on the loop thread; move to io_work if iteration counts get big enough to stall other effects.
Term pbkdf2_words_run(Env e, Term* f, IoWork* w) {
  u64            alen  = 0;
  char*          alg   = io_cstr(e, f[0], &alen);
  u64            pn    = 0;
  u64            sn    = 0;
  u32            iters = (u32)f[5];
  u64            n     = (u64)(u32)f[6];
  bool           bad   = io_nul(alg, alen) || iters == 0 || iters > INT32_MAX || n == 0 || n > INT32_MAX;
  unsigned char* pass  = crypto_words_octets(e, f[2], (u64)(u32)f[1], &pn, &bad);
  unsigned char* salt  = crypto_words_octets(e, f[4], (u64)(u32)f[3], &sn, &bad);
  unsigned char* out   = io_mem(malloc(bad ? 1 : n + 1));
  Term           t;
  if (bad || pn > INT32_MAX || sn > INT32_MAX) {
    t = io_fail(e, EINVAL, NULL);
  } else if (!crypto_load()) {
    t = io_fail(e, ENOENT, CRYPTO_MISSING);
  } else {
    void* md = crypto_lib.md_fetch(NULL, alg, NULL);
    bool  ok = md != NULL && crypto_lib.pbkdf2((const char*)pass, (int)pn, salt, (int)sn, (int)iters, md, (int)n, out) == 1;
    crypto_lib.md_free(md);
    t = ok ? crypto_out(e, out, n) : io_fail(e, EINVAL, "pbkdf2 failed; alg must name an OpenSSL digest");
  }
  free(alg);
  free(pass);
  free(salt);
  free(out);
  return t;
}

static void __attribute__((constructor)) pbkdf2_words_use(void) {
  io_eff(CID(pbkdf2.words), pbkdf2_words_run, 0);
}

#endif

#ifdef CID(random.words)

// getentropy gives at most 256 bytes a call.
Term random_words_run(Env e, Term* f, IoWork* w) {
  u64            n    = (u64)(u32)f[0];
  unsigned char* out  = io_mem(malloc(n + 1));
  int            code = 0;
  for (u64 i = 0; i < n && code == 0; i += 256) {
    code = getentropy(out + i, n - i < 256 ? n - i : 256) == 0 ? 0 : errno;
  }
  Term t = code ? io_fail(e, code, NULL) : crypto_out(e, out, n);
  free(out);
  return t;
}

static void __attribute__((constructor)) random_words_use(void) {
  io_eff(CID(random.words), random_words_run, 0);
}

#endif

#ifdef CID(eq.ct.words)

// The loop reads every octet, so its time depends only on the lengths.
Term eq_ct_words_run(Env e, Term* f, IoWork* w) {
  u64                    an  = 0;
  u64                    bn  = 0;
  bool                   bad = false;
  unsigned char*         a   = crypto_words_octets(e, f[1], (u64)(u32)f[0], &an, &bad);
  unsigned char*         b   = crypto_words_octets(e, f[3], (u64)(u32)f[2], &bn, &bad);
  volatile unsigned char d   = 0;
  for (u64 i = 0; i < an && an == bn; i += 1) {
    d |= a[i] ^ b[i];
  }
  bool eq = !bad && an == bn && d == 0;
  free(a);
  free(b);
  return term_pak(eq ? CID(True) : CID(False), 0);
}

static void __attribute__((constructor)) eq_ct_words_use(void) {
  io_eff(CID(eq.ct.words), eq_ct_words_run, 0);
}

#endif

#if defined(CID(rsa.sign.words)) || defined(CID(rsa.verify.words)) || defined(CID(rsa.verify.jwk.words)) \
  || defined(CID(ecdsa.sign.words)) || defined(CID(ecdsa.verify.words)) || defined(CID(ecdsa.verify.jwk.words))
#ifndef CRYPTO_PK
#define CRYPTO_PK

// EVP_PKEY_RSA and EVP_PKEY_EC.
#define CRYPTO_RSA 6
#define CRYPTO_EC  408

// Each key type takes only its own digests, so an RS256 key can not verify an ES256 token or the reverse.
static bool crypto_pk_alg(int kind, const char* alg) {
  return strcmp(alg, "SHA256") == 0
    || (kind == CRYPTO_RSA && (strcmp(alg, "SHA384") == 0 || strcmp(alg, "SHA512") == 0));
}

static const char* crypto_pk_alg_why(int kind) {
  return kind == CRYPTO_RSA ? "rsa alg must be SHA256, SHA384, or SHA512" : "ecdsa alg must be SHA256";
}

// An RSA key of at least 2048 bits (RFC 7518 §3.3), or an EC key on P-256; RSA-PSS and other types fail.
static bool crypto_pk_kind(void* k, int kind) {
  char   g[32];
  size_t gn = 0;
  if (k == NULL || crypto_lib.pkey_id(k) != kind) {
    return false;
  }
  if (kind == CRYPTO_RSA) {
    return crypto_lib.pkey_bits(k) >= 2048;
  }
  return crypto_lib.group_name(k, g, sizeof g, &gn) == 1 && strcmp(g, "prime256v1") == 0;
}

// The empty passphrase stops OpenSSL from prompting on the terminal; an encrypted key fails to load.
static void* crypto_pem(const unsigned char* p, u64 n, bool priv) {
  void* bio = crypto_lib.bio_mem(p, (int)n);
  void* k   = bio == NULL ? NULL : (priv ? crypto_lib.pem_priv : crypto_lib.pem_pub)(bio, NULL, NULL, (void*)"");
  crypto_lib.bio_free(bio);
  return k;
}

// A DER header and body: tag, length (short or long form), then the n octets at p. Returns the octets written.
static u64 crypto_der(unsigned char* o, unsigned char tag, const unsigned char* p, u64 n) {
  u64 h = 1;
  u64 k = n < 128 ? 0 : n < 256 ? 1 : n < 65536 ? 2 : 3;
  o[0]  = tag;
  o[h++] = k == 0 ? (unsigned char)n : (unsigned char)(0x80 | k);
  for (u64 i = k; i > 0; i -= 1) {
    o[h++] = (unsigned char)(n >> (8 * (i - 1)));
  }
  memmove(o + h, p, n);
  return h + n;
}

// A DER INTEGER of the unsigned big-endian octets at p: leading zeros dropped, one added if the top bit is set.
static u64 crypto_der_uint(unsigned char* o, const unsigned char* p, u64 n) {
  unsigned char b[2056];
  while (n > 0 && p[0] == 0) {
    p += 1;
    n -= 1;
  }
  u64 pad = n == 0 || (p[0] & 0x80) ? 1 : 0;
  b[0]    = 0;
  memcpy(b + pad, p, n);
  return crypto_der(o, 0x02, b, n + pad);
}

// The DER ECDSA-Sig-Value of a raw JOSE r || s signature (RFC 7518 §3.4).
static u64 crypto_ec_der(unsigned char* o, const unsigned char* raw) {
  unsigned char in[80];
  u64           n = crypto_der_uint(in, raw, 32);
  n += crypto_der_uint(in + n, raw + 32, 32);
  return crypto_der(o, 0x30, in, n);
}

// The raw 64-octet r || s of a DER ECDSA-Sig-Value; false if it is malformed or a half is over 32 octets.
static bool crypto_ec_raw(const unsigned char* d, u64 n, unsigned char* out) {
  u64 i = 2;
  if (n < 2 || d[0] != 0x30 || d[1] != n - 2) {
    return false;
  }
  for (u64 h = 0; h < 2; h += 1) {
    if (i + 2 > n || d[i] != 0x02 || i + 2 + d[i + 1] > n) {
      return false;
    }
    const unsigned char* p = d + i + 2;
    u64                  l = d[i + 1];
    i += 2 + l;
    while (l > 0 && p[0] == 0) {
      p += 1;
      l -= 1;
    }
    if (l > 32) {
      return false;
    }
    memset(out + 32 * h, 0, 32 - l);
    memcpy(out + 32 * h + 32 - l, p, l);
  }
  return i == n;
}

// A SubjectPublicKeyInfo key from JWK parts (RFC 7518 §6.2-6.3): RSA n and e, or P-256 x and y, as big-endian
// octets. NULL if they do not fit; RSA also needs an odd e of at least 3, since e = 1 lets anyone sign.
static void* crypto_jwk(int kind, const unsigned char* a, u64 an, const unsigned char* b, u64 bn) {
  static const unsigned char rsa_id[] = { 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00 };
  static const unsigned char ec_id[]  = { 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08,
    0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07 };
  unsigned char x[2200];
  unsigned char y[2200];
  u64           n;
  if (kind == CRYPTO_EC) {
    if (an != 32 || bn != 32) {
      return NULL;
    }
    x[0] = 0;
    x[1] = 4;
    memcpy(x + 2, a, 32);
    memcpy(x + 34, b, 32);
    memcpy(y, ec_id, sizeof ec_id);
    n = sizeof ec_id + crypto_der(y + sizeof ec_id, 0x03, x, 66);
  } else {
    u64 z = 0;
    while (z < bn && b[z] == 0) {
      z += 1;
    }
    // 16384 bits is OpenSSL's largest RSA modulus.
    if (an > 2049 || bn - z == 0 || bn - z > 8 || (b[bn - 1] & 1) == 0 || (bn - z == 1 && b[z] < 3)) {
      return NULL;
    }
    n    = crypto_der_uint(y, a, an);
    n   += crypto_der_uint(y + n, b, bn);
    x[0] = 0;
    n    = 1 + crypto_der(x + 1, 0x30, y, n);
    memcpy(y, rsa_id, sizeof rsa_id);
    n = sizeof rsa_id + crypto_der(y + sizeof rsa_id, 0x03, x, n);
  }
  n                      = crypto_der(x, 0x30, y, n);
  const unsigned char* p = x;
  return crypto_lib.d2i_pub(NULL, &p, (long)n);
}

// PKCS#1 v1.5 for RSA; ECDSA gives DER, turned into raw r || s. *o is always malloc'd; the caller frees it.
static bool crypto_sign(void* k, int kind, const char* alg, const unsigned char* d, u64 dn, unsigned char** o, size_t* on) {
  void*  ctx  = crypto_lib.md_ctx_new();
  void*  pctx = NULL;
  size_t n    = 0;
  bool   ok   = ctx != NULL && crypto_lib.sign_init(ctx, &pctx, alg, NULL, NULL, k, NULL) == 1
    && (kind != CRYPTO_RSA || crypto_lib.set_padding(pctx, 1) > 0)
    && crypto_lib.sign(ctx, NULL, &n, d, dn) == 1;
  unsigned char* s = io_mem(malloc(n + 1));
  ok               = ok && crypto_lib.sign(ctx, s, &n, d, dn) == 1;
  crypto_lib.md_ctx_free(ctx);
  if (ok && kind == CRYPTO_EC) {
    unsigned char* r = io_mem(malloc(64));
    ok               = crypto_ec_raw(s, n, r);
    free(s);
    s = r;
    n = 64;
  }
  *o  = s;
  *on = n;
  return ok;
}

// 1 for a valid signature, 0 for an invalid one (any length or encoding), -1 when OpenSSL can not set up.
static int crypto_verify(void* k, int kind, const char* alg, const unsigned char* d, u64 dn, const unsigned char* s, u64 sn) {
  unsigned char der[80];
  if (kind == CRYPTO_EC) {
    if (sn != 64) {
      return 0;
    }
    sn = crypto_ec_der(der, s);
    s  = der;
  }
  void* ctx  = crypto_lib.md_ctx_new();
  void* pctx = NULL;
  int   r    = ctx != NULL && crypto_lib.verify_init(ctx, &pctx, alg, NULL, NULL, k, NULL) == 1
      && (kind != CRYPTO_RSA || crypto_lib.set_padding(pctx, 1) > 0)
    ? crypto_lib.verify(ctx, s, sn, d, dn) == 1
    : -1;
  crypto_lib.md_ctx_free(ctx);
  return r;
}

// ponytail: signatures run on the loop thread (about 1 ms for RSA-2048 signing); move to io_work if that stalls.
static Term crypto_sign_run(Env e, Term* f, int kind) {
  u64            alen = 0;
  char*          alg  = io_cstr(e, f[0], &alen);
  u64            kn   = 0;
  u64            dn   = 0;
  bool           bad  = io_nul(alg, alen);
  unsigned char* key  = crypto_words_octets(e, f[2], (u64)(u32)f[1], &kn, &bad);
  unsigned char* data = crypto_words_octets(e, f[4], (u64)(u32)f[3], &dn, &bad);
  Term           t;
  if (bad || kn > INT32_MAX) {
    t = io_fail(e, EINVAL, NULL);
  } else if (!crypto_pk_alg(kind, alg)) {
    t = io_fail(e, EINVAL, crypto_pk_alg_why(kind));
  } else if (!crypto_load()) {
    t = io_fail(e, ENOENT, CRYPTO_MISSING);
  } else {
    void*          k   = crypto_pem(key, kn, true);
    unsigned char* sig = NULL;
    size_t         sn  = 0;
    if (!crypto_pk_kind(k, kind)) {
      t = io_fail(e, EINVAL, kind == CRYPTO_RSA ? "key must be an unencrypted PEM RSA private key of at least 2048 bits"
                                               : "key must be an unencrypted PEM EC private key on P-256");
    } else if (!crypto_sign(k, kind, alg, data, dn, &sig, &sn)) {
      t = io_fail(e, EINVAL, "signing failed");
    } else {
      t = crypto_out(e, sig, sn);
    }
    free(sig);
    crypto_lib.pkey_free(k);
    crypto_lib.err_clear();
  }
  free(alg);
  free(key);
  free(data);
  return t;
}

// A PEM key is f[1..2]; JWK parts are f[1..2] and f[3..4]. Data and signature follow.
static Term crypto_verify_run(Env e, Term* f, int kind, bool jwk) {
  u64            alen = 0;
  char*          alg  = io_cstr(e, f[0], &alen);
  u64            j    = jwk ? 2 : 0;
  u64            an   = 0;
  u64            bn   = 0;
  u64            dn   = 0;
  u64            sn   = 0;
  bool           bad  = io_nul(alg, alen);
  unsigned char* a    = crypto_words_octets(e, f[2], (u64)(u32)f[1], &an, &bad);
  unsigned char* b    = jwk ? crypto_words_octets(e, f[4], (u64)(u32)f[3], &bn, &bad) : NULL;
  unsigned char* d    = crypto_words_octets(e, f[4 + j], (u64)(u32)f[3 + j], &dn, &bad);
  unsigned char* s    = crypto_words_octets(e, f[6 + j], (u64)(u32)f[5 + j], &sn, &bad);
  Term           t;
  if (bad || an > INT32_MAX) {
    t = io_fail(e, EINVAL, NULL);
  } else if (!crypto_pk_alg(kind, alg)) {
    t = io_fail(e, EINVAL, crypto_pk_alg_why(kind));
  } else if (!crypto_load()) {
    t = io_fail(e, ENOENT, CRYPTO_MISSING);
  } else {
    void* k = jwk ? crypto_jwk(kind, a, an, b, bn) : crypto_pem(a, an, false);
    int   r = crypto_pk_kind(k, kind) ? crypto_verify(k, kind, alg, d, dn, s, sn) : -2;
    if (r == -2) {
      t = io_fail(e, EINVAL, jwk ? (kind == CRYPTO_RSA ? "jwk must give an RSA n of at least 2048 bits and an odd e >= 3"
                                                       : "jwk must give 32-octet x and y of a P-256 point")
                                 : (kind == CRYPTO_RSA ? "key must be a PEM RSA public key of at least 2048 bits"
                                                       : "key must be a PEM EC public key on P-256"));
    } else if (r < 0) {
      t = io_fail(e, EINVAL, "verify failed to start");
    } else {
      t = io_done(e, term_pak(r ? CID(True) : CID(False), 0));
    }
    crypto_lib.pkey_free(k);
    crypto_lib.err_clear();
  }
  free(alg);
  free(a);
  free(b);
  free(d);
  free(s);
  return t;
}

#endif
#endif

#ifdef CID(rsa.sign.words)
Term rsa_sign_words_run(Env e, Term* f, IoWork* w) {
  return crypto_sign_run(e, f, CRYPTO_RSA);
}
static void __attribute__((constructor)) rsa_sign_words_use(void) {
  io_eff(CID(rsa.sign.words), rsa_sign_words_run, 0);
}
#endif

#ifdef CID(rsa.verify.words)
Term rsa_verify_words_run(Env e, Term* f, IoWork* w) {
  return crypto_verify_run(e, f, CRYPTO_RSA, false);
}
static void __attribute__((constructor)) rsa_verify_words_use(void) {
  io_eff(CID(rsa.verify.words), rsa_verify_words_run, 0);
}
#endif

#ifdef CID(rsa.verify.jwk.words)
Term rsa_verify_jwk_words_run(Env e, Term* f, IoWork* w) {
  return crypto_verify_run(e, f, CRYPTO_RSA, true);
}
static void __attribute__((constructor)) rsa_verify_jwk_words_use(void) {
  io_eff(CID(rsa.verify.jwk.words), rsa_verify_jwk_words_run, 0);
}
#endif

#ifdef CID(ecdsa.sign.words)
Term ecdsa_sign_words_run(Env e, Term* f, IoWork* w) {
  return crypto_sign_run(e, f, CRYPTO_EC);
}
static void __attribute__((constructor)) ecdsa_sign_words_use(void) {
  io_eff(CID(ecdsa.sign.words), ecdsa_sign_words_run, 0);
}
#endif

#ifdef CID(ecdsa.verify.words)
Term ecdsa_verify_words_run(Env e, Term* f, IoWork* w) {
  return crypto_verify_run(e, f, CRYPTO_EC, false);
}
static void __attribute__((constructor)) ecdsa_verify_words_use(void) {
  io_eff(CID(ecdsa.verify.words), ecdsa_verify_words_run, 0);
}
#endif

#ifdef CID(ecdsa.verify.jwk.words)
Term ecdsa_verify_jwk_words_run(Env e, Term* f, IoWork* w) {
  return crypto_verify_run(e, f, CRYPTO_EC, true);
}
static void __attribute__((constructor)) ecdsa_verify_jwk_words_use(void) {
  io_eff(CID(ecdsa.verify.jwk.words), ecdsa_verify_jwk_words_run, 0);
}
#endif

#if defined(CID(aead.seal.words)) || defined(CID(aead.open.words))
#ifndef CRYPTO_AEAD
#define CRYPTO_AEAD

// EVP_CTRL_AEAD_GET_TAG and EVP_CTRL_AEAD_SET_TAG; both algs take a 32-octet key, 12-octet nonce, 16-octet tag.
#define CRYPTO_GET_TAG 0x10
#define CRYPTO_SET_TAG 0x11
#define CRYPTO_TAG     16

// Volatile stores, so the compiler can not drop the wipe of a buffer about to be freed.
static void crypto_wipe(unsigned char* p, u64 n) {
  volatile unsigned char* v = p;
  for (u64 i = 0; i < n; i += 1) {
    v[i] = 0;
  }
}

// Seal writes the m octets of ciphertext at d to o, then the tag at o + m. Open reads the tag at d + m and writes
// m octets of plaintext to o (o may be d); they are only authentic when this returns true.
static bool crypto_aead(const char* name, bool enc, const unsigned char* key, const unsigned char* nonce,
  const unsigned char* aad, u64 an, unsigned char* d, u64 m, unsigned char* o) {
  void* c   = crypto_lib.cipher_fetch(NULL, name, NULL);
  void* ctx = crypto_lib.cipher_ctx_new();
  int   a   = 0;
  int   n   = 0;
  int   k   = 0;
  bool  ok  = c != NULL && ctx != NULL && crypto_lib.cipher_init(ctx, c, key, nonce, enc ? 1 : 0, NULL) == 1
    && (an == 0 || crypto_lib.cipher_update(ctx, NULL, &a, aad, (int)an) == 1)
    && (m == 0 || crypto_lib.cipher_update(ctx, o, &n, d, (int)m) == 1)
    && (enc || crypto_lib.cipher_ctrl(ctx, CRYPTO_SET_TAG, CRYPTO_TAG, d + m) > 0)
    && crypto_lib.cipher_final(ctx, o + n, &k) == 1 && (u64)n + (u64)k == m
    && (!enc || crypto_lib.cipher_ctrl(ctx, CRYPTO_GET_TAG, CRYPTO_TAG, o + m) > 0);
  crypto_lib.cipher_ctx_free(ctx);
  crypto_lib.cipher_free(c);
  crypto_lib.err_clear();
  return ok;
}

// f is alg, key, nonce, aad, data; lengths are at most INT32_MAX for EVP's int, so a sealed length fits a U32.
// Open decrypts in place and wipes the stage, so plaintext leaves only once the tag checks out.
static Term crypto_aead_run(Env e, Term* f, bool enc) {
  u64            alen  = 0;
  char*          alg   = io_cstr(e, f[0], &alen);
  u64            kn    = 0;
  u64            nn    = 0;
  u64            an    = 0;
  u64            dn    = 0;
  u64            key_n = (u32)f[1];
  u64            nonce_n = (u32)f[3];
  u64            aad_n = (u32)f[5];
  u64            data_n = (u32)f[7];
  bool           bad = io_nul(alg, alen) || key_n != 32 || nonce_n != 12 || aad_n > INT32_MAX
    || data_n > INT32_MAX || (!enc && data_n < CRYPTO_TAG);
  unsigned char* key   = crypto_words_octets(e, f[2], bad ? 0 : key_n, &kn, &bad);
  unsigned char* nonce = crypto_words_octets(e, f[4], bad ? 0 : nonce_n, &nn, &bad);
  unsigned char* aad   = crypto_words_octets(e, f[6], bad ? 0 : aad_n, &an, &bad);
  unsigned char* data  = crypto_words_octets(e, f[8], bad ? 0 : data_n, &dn, &bad);
  const char*    name  = strcmp(alg, "AES-256-GCM") == 0 ? "AES-256-GCM"
            : strcmp(alg, "CHACHA20-POLY1305") == 0 ? "ChaCha20-Poly1305"
                                                    : NULL;
  Term           t;
  if (bad) {
    t = io_fail(e, EINVAL, NULL);
  } else if (name == NULL) {
    t = io_fail(e, EINVAL, "aead alg must be AES-256-GCM or CHACHA20-POLY1305");
  } else if (!crypto_load()) {
    t = io_fail(e, ENOENT, CRYPTO_MISSING);
  } else if (enc) {
    unsigned char* out = io_mem(malloc(dn + CRYPTO_TAG));
    t = crypto_aead(name, true, key, nonce, aad, an, data, dn, out) ? crypto_out(e, out, dn + CRYPTO_TAG)
                                                                     : io_fail(e, EINVAL, "aead seal failed");
    free(out);
  } else {
    u64 m = dn - CRYPTO_TAG;
    t     = crypto_aead(name, false, key, nonce, aad, an, data, m, data)
          ? crypto_out(e, data, m)
          : io_fail(e, EINVAL, "aead open failed; ciphertext, tag, nonce, or aad do not authenticate");
  }
  crypto_wipe(key, kn);
  crypto_wipe(data, dn);
  free(alg);
  free(key);
  free(nonce);
  free(aad);
  free(data);
  return t;
}

#endif
#endif

#ifdef CID(aead.seal.words)
Term aead_seal_words_run(Env e, Term* f, IoWork* w) {
  return crypto_aead_run(e, f, true);
}
static void __attribute__((constructor)) aead_seal_words_use(void) {
  io_eff(CID(aead.seal.words), aead_seal_words_run, 0);
}
#endif

#ifdef CID(aead.open.words)
Term aead_open_words_run(Env e, Term* f, IoWork* w) {
  return crypto_aead_run(e, f, false);
}
static void __attribute__((constructor)) aead_open_words_use(void) {
  io_eff(CID(aead.open.words), aead_open_words_run, 0);
}
#endif
