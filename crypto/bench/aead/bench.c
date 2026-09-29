// AEAD benchmark in C: 4,096 chained seals of 4 KiB with AES-256-GCM and ChaCha20-Poly1305, through OpenSSL 3 libcrypto.
#include <openssl/evp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define N 4096
#define M 4096

static double ms(struct timespec t0, struct timespec t1) {
  return (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6;
}

// Seal i encrypts the first M octets of seal i-1's output under nonce i (little-endian, then 8 zeros). No AAD.
static void run(const char* op, const char* alg) {
  unsigned char    key[32], nonce[12] = {0}, a[M + 16] = {0}, b[M + 16], md[32];
  unsigned char *  in = a, *out = b, *t;
  int              n;
  struct timespec  t0, t1;
  EVP_CIPHER*      c   = EVP_CIPHER_fetch(NULL, alg, NULL);
  EVP_CIPHER_CTX*  ctx = EVP_CIPHER_CTX_new();
  memset(key, 0x42, sizeof key);
  clock_gettime(CLOCK_MONOTONIC, &t0);
  for (unsigned int i = 0; i < N; i += 1) {
    nonce[0] = i, nonce[1] = i >> 8, nonce[2] = i >> 16, nonce[3] = i >> 24;
    if (!c || !ctx || EVP_EncryptInit_ex2(ctx, c, key, nonce, NULL) != 1 || EVP_EncryptUpdate(ctx, out, &n, in, M) != 1
        || EVP_EncryptFinal_ex(ctx, out + n, &n) != 1 || EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, 16, out + M) != 1) {
      fprintf(stderr, "%s failed\n", op);
      exit(1);
    }
    t = in, in = out, out = t;
  }
  clock_gettime(CLOCK_MONOTONIC, &t1);
  EVP_Digest(in, M + 16, md, NULL, EVP_sha256(), NULL);
  printf("%s\t%.3f\t", op, ms(t0, t1));
  for (int i = 0; i < 32; i += 1) {
    printf("%02x", md[i]);
  }
  printf("\n");
  EVP_CIPHER_CTX_free(ctx);
  EVP_CIPHER_free(c);
}

int main(void) {
  run("aes-256-gcm", "AES-256-GCM");
  run("chacha20-poly1305", "ChaCha20-Poly1305");
  return 0;
}
