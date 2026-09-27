// Crypto benchmark in C: SHA-256 of 16 MiB of zero bytes through OpenSSL 3 libcrypto.
#include <openssl/evp.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define N 16777216

int main(void) {
  unsigned char*  in = calloc(N, 1);
  unsigned char   md[EVP_MAX_MD_SIZE];
  unsigned int    n  = 0;
  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);
  EVP_Digest(in, N, md, &n, EVP_sha256(), NULL);
  clock_gettime(CLOCK_MONOTONIC, &t1);
  printf("sha256\t%.3f\t", (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6);
  for (unsigned int i = 0; i < n; i += 1) {
    printf("%02x", md[i]);
  }
  printf("\n");
  free(in);
  return 0;
}
