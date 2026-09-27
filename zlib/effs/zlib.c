// Zlib
// ====
// Compression through the system C libraries, loaded with dlopen.

#if defined(CID(zstd.words)) || defined(CID(inflate.words)) || defined(CID(gzip.words)) || defined(CID(brotli.words))
#ifndef ZLIB_EFFS
#define ZLIB_EFFS
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

// The library named by the env variable, else the first path that loads.
static void* zlib_open(const char* var, const char* const* paths, u64 n) {
  const char* over = getenv(var);
  void*       h    = over != NULL ? dlopen(over, RTLD_NOW | RTLD_LOCAL) : NULL;
  for (u64 i = 0; h == NULL && i < n; i += 1) {
    h = dlopen(paths[i], RTLD_NOW | RTLD_LOCAL);
  }
  return h;
}

// Output that doubles from about 4x the input up to max bytes.
typedef struct { char* p; u64 cap; u64 have; u64 max; } ZlibBuf;

static ZlibBuf zlib_buf(u64 n, u64 max) {
  u64 cap = n * 4 < 65536 ? 65536 : n * 4;
  cap     = cap < max ? cap : max;
  return (ZlibBuf){ io_mem(malloc(cap + 1)), cap, 0, max };
}

static bool zlib_grow(ZlibBuf* b) {
  if (b->cap >= b->max) {
    return false;
  }
  b->cap = b->cap * 2 < b->max ? b->cap * 2 : b->max;
  b->p   = io_mem(realloc(b->p, b->cap + 1));
  return true;
}

// The answer: the output as words, or the failure. Frees in and the output.
static Term zlib_end(Env e, char* in, ZlibBuf* b, int code, const char* why) {
  Term t = code ? io_fail(e, code, why) : io_done(e, zlib_words(e, b->p, b->have));
  free(in);
  free(b->p);
  return t;
}

#endif
#endif

#ifdef CID(zstd.words)

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
  const char* paths[] = { "/opt/homebrew/lib/libzstd.1.dylib", "/usr/local/lib/libzstd.1.dylib",
    "libzstd.1.dylib", "libzstd.so.1" };
  void* h = zlib_open("BEND_LIBZSTD", paths, sizeof(paths) / sizeof(paths[0]));
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

// ponytail: the decoders run on the loop thread; move them to io_work if bodies get big enough to stall other effects.
Term zstd_words_run(Env e, Term* f, IoWork* w) {
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
  ZlibBuf     b    = zlib_buf(n, (u64)(u32)f[0]);
  ZlibIn      src  = { in, n, 0 };
  int         code = 0;
  const char* why  = NULL;
  for (;;) {
    ZlibOut dst = { b.p + b.have, b.cap - b.have, 0 };
    size_t  r   = zlib_zstd.stream(dctx, &dst, &src);
    b.have += dst.pos;
    if (zlib_zstd.is_error(r)) {
      code = EINVAL;
      why  = zlib_zstd.name(r);
      break;
    }
    if (r == 0 && src.pos == src.size) {
      break;
    }
    if (b.have == b.cap) {
      if (!zlib_grow(&b)) {
        code = EFBIG;
        why  = "zstd output is larger than max";
        break;
      }
    } else if (src.pos == src.size) {
      code = EINVAL;
      why  = "zstd input ends inside a frame";
      break;
    }
  }
  Term t = zlib_end(e, in, &b, code, why);
  zlib_zstd.release(dctx);
  return t;
}

static void __attribute__((constructor)) zstd_words_use(void) {
  io_eff(CID(zstd.words), zstd_words_run, 0);
}

#endif

#if defined(CID(inflate.words)) || defined(CID(gzip.words))
#ifndef ZLIB_LIBZ
#define ZLIB_LIBZ

// z_stream as zlib.h lays it out.
typedef struct {
  const unsigned char* next_in;
  unsigned             avail_in;
  unsigned long        total_in;
  unsigned char*       next_out;
  unsigned             avail_out;
  unsigned long        total_out;
  const char*          msg;
  void*                state;
  void*                zalloc;
  void*                zfree;
  void*                opaque;
  int                  data_type;
  unsigned long        adler;
  unsigned long        reserved;
} ZlibZ;

static struct {
  int           state;
  const char*   (*version)(void);
  int           (*inflate_init)(ZlibZ*, int, const char*, int);
  int           (*inflate)(ZlibZ*, int);
  int           (*inflate_reset)(ZlibZ*);
  int           (*inflate_end)(ZlibZ*);
  int           (*deflate_init)(ZlibZ*, int, int, int, int, int, const char*, int);
  int           (*deflate)(ZlibZ*, int);
  unsigned long (*deflate_bound)(ZlibZ*, unsigned long);
  int           (*deflate_end)(ZlibZ*);
} zlib_z;

static bool zlib_z_load(void) {
  if (zlib_z.state != 0) {
    return zlib_z.state > 0;
  }
  zlib_z.state = -1;
  const char* paths[] = { "/usr/lib/libz.1.dylib", "libz.1.dylib", "libz.so.1" };
  void* h = zlib_open("BEND_LIBZ", paths, sizeof(paths) / sizeof(paths[0]));
  if (h == NULL) {
    return false;
  }
  zlib_z.version       = dlsym(h, "zlibVersion");
  zlib_z.inflate_init  = dlsym(h, "inflateInit2_");
  zlib_z.inflate       = dlsym(h, "inflate");
  zlib_z.inflate_reset = dlsym(h, "inflateReset");
  zlib_z.inflate_end   = dlsym(h, "inflateEnd");
  zlib_z.deflate_init  = dlsym(h, "deflateInit2_");
  zlib_z.deflate       = dlsym(h, "deflate");
  zlib_z.deflate_bound = dlsym(h, "deflateBound");
  zlib_z.deflate_end   = dlsym(h, "deflateEnd");
  bool ok = zlib_z.version && zlib_z.inflate_init && zlib_z.inflate && zlib_z.inflate_reset && zlib_z.inflate_end
    && zlib_z.deflate_init && zlib_z.deflate && zlib_z.deflate_bound && zlib_z.deflate_end;
  zlib_z.state = ok ? 1 : -1;
  return ok;
}

#endif
#endif

#ifdef CID(inflate.words)

// Window bits 15 + 32: a gzip or a zlib header, found from the first bytes.
Term inflate_words_run(Env e, Term* f, IoWork* w) {
  u64   n   = 0;
  bool  bad = false;
  char* in  = zlib_words_octets(e, f[2], (u64)(u32)f[1], &n, &bad);
  if (bad) {
    free(in);
    return io_fail(e, EINVAL, NULL);
  }
  if (!zlib_z_load()) {
    free(in);
    return io_fail(e, ENOENT, "inflate needs libz.1; set BEND_LIBZ to its path");
  }
  ZlibZ z = { 0 };
  if (zlib_z.inflate_init(&z, 15 + 32, zlib_z.version(), (int)sizeof(z)) != 0) {
    free(in);
    return io_fail(e, ENOMEM, NULL);
  }
  ZlibBuf     b    = zlib_buf(n, (u64)(u32)f[0]);
  int         code = 0;
  const char* why  = NULL;
  z.next_in        = (const unsigned char*)in;
  z.avail_in       = (unsigned)n;
  for (;;) {
    z.next_out  = (unsigned char*)b.p + b.have;
    z.avail_out = (unsigned)(b.cap - b.have);
    int r       = zlib_z.inflate(&z, 0);
    b.have      = b.cap - z.avail_out;
    if (r == 1) {  // Z_STREAM_END: gzip -d reads the next member, if any.
      if (z.avail_in == 0) {
        break;
      }
      zlib_z.inflate_reset(&z);
      continue;
    }
    if (r != 0 && r != -5) {  // Z_OK and Z_BUF_ERROR only ask for more room or input.
      code = EINVAL;
      why  = z.msg != NULL ? z.msg : "inflate failed";
      break;
    }
    if (z.avail_out == 0) {
      if (!zlib_grow(&b)) {
        code = EFBIG;
        why  = "inflate output is larger than max";
        break;
      }
    } else if (z.avail_in == 0) {
      code = EINVAL;
      why  = "inflate input ends inside a stream";
      break;
    }
  }
  Term t = zlib_end(e, in, &b, code, why);
  zlib_z.inflate_end(&z);
  return t;
}

static void __attribute__((constructor)) inflate_words_use(void) {
  io_eff(CID(inflate.words), inflate_words_run, 0);
}

#endif

#ifdef CID(gzip.words)

// Level 6, window bits 15 + 16 (a gzip wrapper), memLevel 8, the default strategy.
Term gzip_words_run(Env e, Term* f, IoWork* w) {
  u64   n   = 0;
  bool  bad = false;
  char* in  = zlib_words_octets(e, f[1], (u64)(u32)f[0], &n, &bad);
  if (bad) {
    free(in);
    return io_fail(e, EINVAL, NULL);
  }
  if (!zlib_z_load()) {
    free(in);
    return io_fail(e, ENOENT, "gzip needs libz.1; set BEND_LIBZ to its path");
  }
  ZlibZ z = { 0 };
  if (zlib_z.deflate_init(&z, 6, 8, 15 + 16, 8, 0, zlib_z.version(), (int)sizeof(z)) != 0) {
    free(in);
    return io_fail(e, ENOMEM, NULL);
  }
  u64     cap = (u64)zlib_z.deflate_bound(&z, (unsigned long)n);
  ZlibBuf b   = { io_mem(malloc(cap + 1)), cap, 0, cap };
  z.next_in   = (const unsigned char*)in;
  z.avail_in  = (unsigned)n;
  z.next_out  = (unsigned char*)b.p;
  z.avail_out = (unsigned)cap;
  int r       = zlib_z.deflate(&z, 4);  // Z_FINISH
  b.have      = cap - z.avail_out;
  Term t      = zlib_end(e, in, &b, r == 1 ? 0 : EINVAL, "deflate did not finish");
  zlib_z.deflate_end(&z);
  return t;
}

static void __attribute__((constructor)) gzip_words_use(void) {
  io_eff(CID(gzip.words), gzip_words_run, 0);
}

#endif

#ifdef CID(brotli.words)

static struct {
  int         state;
  void*       (*create)(void*, void*, void*);
  void        (*destroy)(void*);
  int         (*stream)(void*, size_t*, const uint8_t**, size_t*, uint8_t**, size_t*);
  int         (*error)(void*);
  const char* (*text)(int);
} zlib_br;

static bool zlib_br_load(void) {
  if (zlib_br.state != 0) {
    return zlib_br.state > 0;
  }
  zlib_br.state = -1;
  const char* paths[] = { "/opt/homebrew/lib/libbrotlidec.1.dylib", "/usr/local/lib/libbrotlidec.1.dylib",
    "libbrotlidec.1.dylib", "libbrotlidec.so.1" };
  void* h = zlib_open("BEND_LIBBROTLIDEC", paths, sizeof(paths) / sizeof(paths[0]));
  if (h == NULL) {
    return false;
  }
  zlib_br.create  = dlsym(h, "BrotliDecoderCreateInstance");
  zlib_br.destroy = dlsym(h, "BrotliDecoderDestroyInstance");
  zlib_br.stream  = dlsym(h, "BrotliDecoderDecompressStream");
  zlib_br.error   = dlsym(h, "BrotliDecoderGetErrorCode");
  zlib_br.text    = dlsym(h, "BrotliDecoderErrorString");
  bool ok = zlib_br.create && zlib_br.destroy && zlib_br.stream && zlib_br.error && zlib_br.text;
  zlib_br.state = ok ? 1 : -1;
  return ok;
}

Term brotli_words_run(Env e, Term* f, IoWork* w) {
  u64   n   = 0;
  bool  bad = false;
  char* in  = zlib_words_octets(e, f[2], (u64)(u32)f[1], &n, &bad);
  if (bad) {
    free(in);
    return io_fail(e, EINVAL, NULL);
  }
  if (!zlib_br_load()) {
    free(in);
    return io_fail(e, ENOENT, "brotli needs libbrotlidec.1; set BEND_LIBBROTLIDEC to its path");
  }
  void* s = zlib_br.create(NULL, NULL, NULL);
  if (s == NULL) {
    free(in);
    return io_fail(e, ENOMEM, NULL);
  }
  ZlibBuf        b    = zlib_buf(n, (u64)(u32)f[0]);
  size_t         ain  = (size_t)n;
  const uint8_t* nin  = (const uint8_t*)in;
  int            code = 0;
  const char*    why  = NULL;
  for (;;) {
    size_t   aout = (size_t)(b.cap - b.have);
    uint8_t* nout = (uint8_t*)b.p + b.have;
    int      r    = zlib_br.stream(s, &ain, &nin, &aout, &nout, NULL);
    b.have        = b.cap - aout;
    if (r == 1) {  // BROTLI_DECODER_RESULT_SUCCESS
      code = ain != 0 ? EINVAL : 0;
      why  = "brotli input has bytes after the stream";
      break;
    }
    if (r == 0) {  // BROTLI_DECODER_RESULT_ERROR
      code = EINVAL;
      why  = zlib_br.text(zlib_br.error(s));
      break;
    }
    if (r == 3) {  // BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT
      if (!zlib_grow(&b)) {
        code = EFBIG;
        why  = "brotli output is larger than max";
        break;
      }
    } else {
      code = EINVAL;
      why  = "brotli input ends inside the stream";
      break;
    }
  }
  Term t = zlib_end(e, in, &b, code, why);
  zlib_br.destroy(s);
  return t;
}

static void __attribute__((constructor)) brotli_words_use(void) {
  io_eff(CID(brotli.words), brotli_words_run, 0);
}

#endif
