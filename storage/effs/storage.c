#ifdef CID(Blob.hash.words)
#ifndef STORAGE_HASH_EFF
#define STORAGE_HASH_EFF
#include <dlfcn.h>
#include <stdio.h>

static int (*storage_sha256)(void*, const char*, const char*, const void*, size_t, unsigned char*, size_t*);
static int storage_crypto_state;

static bool storage_crypto_load(void) {
  if (storage_crypto_state) return storage_crypto_state > 0;
  storage_crypto_state = -1;
  const char* paths[] = {getenv("BEND_LIBCRYPTO"),
    "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib",
    "/usr/local/opt/openssl@3/lib/libcrypto.3.dylib", "libcrypto.3.dylib", "libcrypto.so.3"};
  for (size_t i = 0; i < sizeof(paths) / sizeof(*paths); ++i) {
    void* lib = paths[i] ? dlopen(paths[i], RTLD_NOW | RTLD_LOCAL) : NULL;
    if (!lib) continue;
    storage_sha256 = dlsym(lib, "EVP_Q_digest");
    if (storage_sha256) {
      storage_crypto_state = 1;
      return true;
    }
    dlclose(lib);
  }
  return false;
}

static Term blob_hash_words_run(Env e, Term* f, IoWork* w) {
  u64 n = (u32)f[0];
  Term raw = f[1];
  if (term_tag(raw) != TAG_BUF || n > (4ull << blk_cls(raw))) {
    term_drop(e, raw);
    return io_fail(e, EINVAL, "storage: file length exceeds its packed buffer");
  }
  if (!storage_crypto_load()) {
    term_drop(e, raw);
    return io_fail(e, ENOENT, "storage needs OpenSSL 3; set BEND_LIBCRYPTO to its path");
  }
  char header[32];
  size_t hl = (size_t)snprintf(header, sizeof(header), "file %u\n", (u32)n);
  unsigned char* bytes = io_mem(malloc(hl + n));
  memcpy(bytes, header, hl);
  u64 loc = blk_loc(e.mem, raw);
  for (u64 i = 0; i < (n + 3) / 4; ++i) {
    u32 word = (u32)blk_read(e.mem, false, loc, (u32)i);
    for (u64 j = 0; j < 4 && 4 * i + j < n; ++j) {
      bytes[hl + 4 * i + j] = (unsigned char)(word >> (8 * j));
    }
  }
  unsigned char digest[64];
  size_t size = 0;
  int ok = storage_sha256(NULL, "SHA256", NULL, bytes, hl + n, digest, &size);
  free(bytes);
  if (!ok || size != 32) {
    term_drop(e, raw);
    return io_fail(e, EINVAL, "storage: SHA-256 failed");
  }
  Term zero = 0;
  Term out = blk_new(e, false, 3, 0, 1, &zero);
  u64 at = blk_loc(e.mem, out);
  for (u32 i = 0; i < 8; ++i) {
    u32 word = (u32)digest[4 * i] | (u32)digest[4 * i + 1] << 8
      | (u32)digest[4 * i + 2] << 16 | (u32)digest[4 * i + 3] << 24;
    blk_write(e.mem, false, at, i, word);
  }
  return io_done(e, io_tup(e, raw, io_tup(e, 32, out)));
}

static void __attribute__((constructor)) blob_hash_words_use(void) {
  io_eff(CID(Blob.hash.words), blob_hash_words_run);
}
#endif
#endif

#ifdef CID(write.temp)
#ifndef STORAGE_TEMP_EFF
#define STORAGE_TEMP_EFF
#include <fcntl.h>
#include <unistd.h>

static Term write_temp_run(Env e, Term* f, IoWork* w) {
  u64 n;
  char* prefix = io_cstr(e, f[0], &n);
  if (!prefix || io_nul(prefix, n)) {
    free(prefix);
    return io_fail(e, EINVAL, NULL);
  }
  char* path = io_mem(realloc(prefix, n + 8));
  memcpy(path + n, ".XXXXXX", 8);
  int fd = mkstemp(path);
  int code = fd < 0 ? errno : 0;
  if (fd >= 0 && fcntl(fd, F_SETFD, FD_CLOEXEC) < 0) {
    code = errno;
    close(fd);
    unlink(path);
  }
  Term out = code ? io_fail(e, code, NULL)
    : io_done(e, io_tup(e, io_str(e, path, n + 7), io_hand(fd)));
  free(path);
  return out;
}

static void __attribute__((constructor)) write_temp_use(void) {
  io_eff(CID(write.temp), write_temp_run);
}
#endif
#endif

#if defined(CID(write.durable)) || defined(CID(write.sync))
#ifndef STORAGE_DURABLE_EFF
#define STORAGE_DURABLE_EFF
#include <fcntl.h>
#include <unistd.h>

static int storage_sync(const char* path, bool directory, bool fail_fullsync) {
  int fd = open(path, O_RDONLY | O_CLOEXEC | (directory ? O_DIRECTORY : 0));
  if (fd < 0) return errno;
  int rc;
  do { rc = fsync(fd); } while (rc < 0 && errno == EINTR);
  int code = rc < 0 ? errno : 0;
  if (!code && fail_fullsync) code = EIO;
#ifdef __APPLE__
  if (!code) {
    do { rc = fcntl(fd, F_FULLFSYNC); } while (rc < 0 && errno == EINTR);
    if (rc < 0) code = errno;
  }
#endif
  if (close(fd) < 0 && !code) code = errno;
  return code;
}

static void storage_parent(char* path) {
  char* slash = strrchr(path, '/');
  if (!slash) strcpy(path, ".");
  else if (slash == path) path[1] = 0;
  else *slash = 0;
}

static void write_durable_call(IoWork* w) {
  char* tmp = w->data;
  char* path = w->text;
  if (!tmp[0]) {
    for (;;) {
      w->code = storage_sync(path, true, false);
      if (w->code || !strcmp(path, "/") || !strcmp(path, ".")) return;
      storage_parent(path);
    }
  }
  if (w->word == 1) { w->code = EIO; return; }
  w->code = storage_sync(tmp, false, w->word == 7);
  if (w->code) return;
  if (w->word == 2 || w->word == 3) { w->code = EIO; return; }
  if (rename(tmp, path) < 0) { w->code = errno; return; }
  if (w->word == 4 || w->word == 5) { w->code = EIO; return; }
  storage_parent(path);
  w->code = storage_sync(path, true, false);
  if (w->code) return;
  storage_parent(tmp);
  w->code = storage_sync(tmp, true, false);
  if (!w->code && w->word == 6) w->code = EIO;
}

static Term write_durable_pack(Env e, IoWork* w) {
  free(w->data);
  free(w->text);
  return w->code ? io_fail(e, w->code, NULL) : io_done(e, term_pak(CID(Unit), 0));
}

static Term write_durable_run(Env e, Term* f, IoWork* w) {
  u64 tn, pn;
  w->data = io_cstr(e, f[0], &tn);
  w->text = io_cstr(e, f[1], &pn);
  if (!w->data || !w->text || io_nul(w->data, tn) || io_nul(w->text, pn) || !pn) {
    free(w->data);
    free(w->text);
    return io_fail(e, EINVAL, NULL);
  }
  w->word = (u32)f[2];
  return io_work(w, write_durable_call, write_durable_pack);
}

#ifdef CID(write.durable)
static void __attribute__((constructor)) write_durable_use(void) {
  io_eff(CID(write.durable), write_durable_run);
}
#endif

#ifdef CID(write.sync)
static void write_sync_call(IoWork* w) {
  w->code = storage_sync(w->data, false, false);
}

static Term write_sync_run(Env e, Term* f, IoWork* w) {
  u64 n;
  w->data = io_cstr(e, f[0], &n);
  w->text = NULL;
  if (!w->data || io_nul(w->data, n)) {
    free(w->data);
    return io_fail(e, EINVAL, NULL);
  }
  return io_work(w, write_sync_call, write_durable_pack);
}

static void __attribute__((constructor)) write_sync_use(void) {
  io_eff(CID(write.sync), write_sync_run);
}
#endif
#endif
#endif
