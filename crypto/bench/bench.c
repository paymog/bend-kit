// Crypto benchmark in C: SHA-256 of 16 MiB of zero bytes, and PBKDF2-HMAC-SHA-256, through OpenSSL 3 libcrypto.
#include <openssl/evp.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define N 16777216

static double ms(struct timespec t0, struct timespec t1) {
  return (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6;
}

static void hex(const unsigned char* p, unsigned int n) {
  for (unsigned int i = 0; i < n; i += 1) {
    printf("%02x", p[i]);
  }
  printf("\n");
}

int main(void) {
  unsigned char*  in = calloc(N, 1);
  unsigned char   md[EVP_MAX_MD_SIZE];
  unsigned int    n  = 0;
  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);
  EVP_Digest(in, N, md, &n, EVP_sha256(), NULL);
  clock_gettime(CLOCK_MONOTONIC, &t1);
  printf("sha256\t%.3f\t", ms(t0, t1));
  hex(md, n);
  clock_gettime(CLOCK_MONOTONIC, &t0);
  PKCS5_PBKDF2_HMAC("password", 8, (const unsigned char*)"salt", 4, 100000, EVP_sha256(), 32, md);
  clock_gettime(CLOCK_MONOTONIC, &t1);
  printf("pbkdf2\t%.3f\t", ms(t0, t1));
  hex(md, 32);
  free(in);
  return 0;
}
