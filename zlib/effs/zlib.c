// Zlib
// ====
// Compression through the system C libraries, loaded with dlopen.

#ifdef CID(zstd.words)
#include <dlfcn.h>

// Copies of wire_words and wire_words_octets in wire/effs/wire.c; keep them in step.
static Term zlib_words(Env e, const char* p, u64 n) {
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
      x |= (u32)(uint8_t)p[4 * k + j] << (8 * j);
    }
    blk_write(e.mem, false, l, (u32)k, x);
  }
  return io_tup(e, (Term)n, a);
}

static char* zlib_words_octets(Env e, Term a, u64 n, u64* len, bool* bad) {
  u64* H = e.mem;
  *bad     = term_tag(a) != TAG_BUF || n > (4ull << blk_cls(a));
  *len     = *bad ? 0 : n;
  char* buf = io_mem(malloc(*len + 1));
  u64   l   = *bad ? 0 : blk_loc(H, a);
  for (u64 i = 0; i < *len; i += 1) {
    buf[i] = (char)(blk_read(H, false, l, (u32)(i / 4)) >> (8 * (i % 4)));
  }
  term_drop(e, a);
  return buf;
}

// ZSTD_inBuffer and ZSTD_outBuffer, stable since zstd 1.0.
typedef struct { const void* src; size_t size; size_t pos; } ZlibIn;
typedef struct { void* dst; size_t size; size_t pos; } ZlibOut;

static struct {
  int         state;
  void*       (*create)(void);
  size_t      (*release)(void*);
  size_t      (*stream)(void*, ZlibOut*, ZlibIn*);
  unsigned    (*is_error)(size_t);
  const char* (*name)(size_t);
} zlib_zstd;

static bool zlib_zstd_load(void) {
  if (zlib_zstd.state != 0) {
    return zlib_zstd.state > 0;
  }
  zlib_zstd.state = -1;
  const char* paths[] = { getenv("BEND_LIBZSTD"), "/opt/homebrew/lib/libzstd.1.dylib",
    "/usr/local/lib/libzstd.1.dylib", "libzstd.1.dylib", "libzstd.so.1" };
  void* h = NULL;
  for (u64 i = 0; h == NULL && i < sizeof(paths) / sizeof(paths[0]); i += 1) {
    h = paths[i] != NULL ? dlopen(paths[i], RTLD_NOW | RTLD_LOCAL) : NULL;
  }
  if (h == NULL) {
    return false;
  }
  zlib_zstd.create   = dlsym(h, "ZSTD_createDCtx");
  zlib_zstd.release  = dlsym(h, "ZSTD_freeDCtx");
  zlib_zstd.stream   = dlsym(h, "ZSTD_decompressStream");
  zlib_zstd.is_error = dlsym(h, "ZSTD_isError");
  zlib_zstd.name     = dlsym(h, "ZSTD_getErrorName");
  bool ok = zlib_zstd.create && zlib_zstd.release && zlib_zstd.stream && zlib_zstd.is_error && zlib_zstd.name;
  zlib_zstd.state = ok ? 1 : -1;
  return ok;
}

// ponytail: decodes on the loop thread; move to io_work if bodies get big enough to stall other effects.
Term zstd_words_run(Env e, Term* f, IoWork* w) {
  u64   max = (u64)(u32)f[0];
  u64   n   = 0;
  bool  bad = false;
  char* in  = zlib_words_octets(e, f[2], (u64)(u32)f[1], &n, &bad);
  if (bad) {
    free(in);
    return io_fail(e, EINVAL, NULL);
  }
  if (!zlib_zstd_load()) {
    free(in);
    return io_fail(e, ENOENT, "zstd needs libzstd.1; set BEND_LIBZSTD to its path");
  }
  void*       dctx = zlib_zstd.create();
  u64         cap  = n * 4 < 65536 ? 65536 : n * 4;
  cap              = cap < max ? cap : max;
  char*       out  = io_mem(malloc(cap + 1));
  u64         have = 0;
  ZlibIn      src  = { in, n, 0 };
  int         code = 0;
  const char* why  = NULL;
  for (;;) {
    ZlibOut dst = { out + have, cap - have, 0 };
    size_t  r   = zlib_zstd.stream(dctx, &dst, &src);
    have += dst.pos;
    if (zlib_zstd.is_error(r)) {
      code = EINVAL;
      why  = zlib_zstd.name(r);
      break;
    }
    if (r == 0 && src.pos == src.size) {
      break;
    }
    if (have == cap) {
      if (cap >= max) {
        code = EFBIG;
        why  = "zstd output is larger than max";
        break;
      }
      cap = cap * 2 < max ? cap * 2 : max;
      out = io_mem(realloc(out, cap + 1));
    } else if (src.pos == src.size) {
      code = EINVAL;
      why  = "zstd input ends inside a frame";
      break;
    }
  }
  zlib_zstd.release(dctx);
  free(in);
  Term t = code ? io_fail(e, code, why) : io_done(e, zlib_words(e, out, have));
  free(out);
  return t;
}

static void __attribute__((constructor)) zstd_words_use(void) {
  io_eff(CID(zstd.words), zstd_words_run, 0);
}

#endif
