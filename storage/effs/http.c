#ifndef STORAGE_HTTP_EFF
#define STORAGE_HTTP_EFF
#include <dlfcn.h>
#include <stdio.h>

static void* (*storage_http_ctx_new)(void);
static void (*storage_http_ctx_free)(void*);
static const void* (*storage_http_sha256)(void);
static int (*storage_http_init)(void*, const void*, void*);
static int (*storage_http_update)(void*, const void*, size_t);
static int (*storage_http_final)(void*, unsigned char*, unsigned int*);
static int storage_http_crypto_state;

static bool storage_http_crypto_load(void) {
  if (storage_http_crypto_state) return storage_http_crypto_state > 0;
  storage_http_crypto_state = -1;
  const char* paths[] = {getenv("BEND_LIBCRYPTO"),
    "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib",
    "/usr/local/opt/openssl@3/lib/libcrypto.3.dylib", "libcrypto.3.dylib", "libcrypto.so.3"};
  for (size_t i = 0; i < sizeof(paths) / sizeof(*paths); ++i) {
    void* lib = paths[i] ? dlopen(paths[i], RTLD_NOW | RTLD_LOCAL) : NULL;
    if (!lib) continue;
    storage_http_ctx_new = dlsym(lib, "EVP_MD_CTX_new");
    storage_http_ctx_free = dlsym(lib, "EVP_MD_CTX_free");
    storage_http_sha256 = dlsym(lib, "EVP_sha256");
    storage_http_init = dlsym(lib, "EVP_DigestInit_ex");
    storage_http_update = dlsym(lib, "EVP_DigestUpdate");
    storage_http_final = dlsym(lib, "EVP_DigestFinal_ex");
    if (storage_http_ctx_new && storage_http_ctx_free && storage_http_sha256 &&
        storage_http_init && storage_http_update && storage_http_final) {
      storage_http_crypto_state = 1;
      return true;
    }
    dlclose(lib);
  }
  return false;
}

static Term inspect_run(Env e, Term* f, IoWork* w) {
  u64 pn, dn;
  char* path = io_cstr(e, f[0], &pn);
  char* want = io_cstr(e, f[1], &dn);
  if (!path || !want || io_nul(path, pn) || dn != 64) {
    free(path); free(want);
    return io_fail(e, EINVAL, NULL);
  }
  if (!storage_http_crypto_load()) {
    free(path); free(want);
    return io_fail(e, ENOENT, "storage needs OpenSSL 3; set BEND_LIBCRYPTO to its path");
  }
  FILE* file = fopen(path, "rb");
  free(path);
  if (!file) { int code = errno; free(want); return io_fail(e, code, NULL); }
  void* ctx = storage_http_ctx_new();
  int code = 0;
  const char* why = NULL;
  if (!ctx || !storage_http_init(ctx, storage_http_sha256(), NULL)) code = EIO;
  unsigned char buffer[65536], head[400], digest[32];
  size_t hl = 0;
  bool newline = false, long_head = false;
  uint64_t total = 0;
  while (!code) {
    size_t n = fread(buffer, 1, sizeof(buffer), file);
    if (!n) { if (ferror(file)) code = errno ? errno : EIO; break; }
    total += n;
    if (total > UINT32_MAX) { code = EFBIG; break; }
    if (!storage_http_update(ctx, buffer, n)) { code = EIO; break; }
    for (size_t i = 0; i < n && !newline && !long_head; ++i) {
      if (buffer[i] == '\n') newline = true;
      else if (hl == sizeof(head)) long_head = true;
      else head[hl++] = buffer[i];
    }
  }
  unsigned int size = 0;
  if (!code && (!storage_http_final(ctx, digest, &size) || size != 32)) code = EIO;
  if (ctx) storage_http_ctx_free(ctx);
  if (fclose(file) && !code) code = errno;
  char message[160];
  if (!code) {
    char hex[65];
    for (size_t i = 0; i < 32; ++i) snprintf(hex + 2 * i, 3, "%02x", digest[i]);
    if (memcmp(hex, want, 64)) {
      code = EINVAL;
      snprintf(message, sizeof(message), "storage: object %s does not match its digest", want);
      why = message;
    }
  }
  free(want);
  if (!code && (!newline || long_head ||
      ((hl < 5 || memcmp(head, "file ", 5)) && total != hl + 1))) {
    code = EINVAL;
    why = "storage: object does not decode";
  }
  if (code) return io_fail(e, code, why);
  return io_done(e, io_tup(e, (u32)total, io_str(e, (char*)head, hl)));
}

static void __attribute__((constructor)) inspect_use(void) {
  io_eff(CID(inspect), inspect_run);
}
#endif
