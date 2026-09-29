// scrypt benchmark in C: one 32-octet key from N = 16384, r = 8, p = 1, through OpenSSL 3 EVP_PBE_scrypt.
#include <openssl/evp.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

int main(void) {
  const char*     pass = "pleaseletmein";
  const char*     salt = "SodiumChloride";
  unsigned char   key[32];
  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);
  int ok = EVP_PBE_scrypt(pass, strlen(pass), (const unsigned char*)salt, strlen(salt), 16384, 8, 1, 64u << 20, key, sizeof key);
  clock_gettime(CLOCK_MONOTONIC, &t1);
  if (ok != 1) {
    fprintf(stderr, "scrypt failed\n");
    return 1;
  }
  printf("scrypt\t%.3f\t", (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6);
  for (int i = 0; i < 32; i += 1) {
    printf("%02x", key[i]);
  }
  printf("\n");
  return 0;
}
