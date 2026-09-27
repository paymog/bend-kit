// Crypto
// ======
// Hashes, HMAC, and HKDF through OpenSSL 3 libcrypto, loaded with dlopen; secure random bytes from the OS.

#if defined(CID(digest.words)) || defined(CID(hmac.words)) || defined(CID(hkdf.words)) || defined(CID(random.words)) || defined(CID(eq.ct.words))
#ifndef CRYPTO_EFFS
#define CRYPTO_EFFS
#include <dlfcn.h>
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

#if defined(CID(digest.words)) || defined(CID(hmac.words)) || defined(CID(hkdf.words))
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
  bool ok = crypto_lib.q_digest && crypto_lib.q_mac && crypto_lib.md_fetch && crypto_lib.md_free
    && crypto_lib.ctx_new && crypto_lib.ctx_free && crypto_lib.derive_init && crypto_lib.set_md
    && crypto_lib.set_salt && crypto_lib.set_key && crypto_lib.add_info && crypto_lib.derive;
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
