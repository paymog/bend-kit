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
