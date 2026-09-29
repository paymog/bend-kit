// OAuth2 benchmark in C: PKCE S256 with OpenSSL 3 libcrypto. C has no standard JSON parser, so parse is left out.
#include <openssl/evp.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

static double ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

int main(void) {
  char v[64] = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
  unsigned char d[32], b[48];
  double t0 = ms();
  for (int i = 0; i < 10000; i++) {
    EVP_Digest(v, strlen(v), d, NULL, EVP_sha256(), NULL);
    int n = EVP_EncodeBlock(b, d, 32);
    while (n > 0 && b[n - 1] == '=') n--;
    for (int j = 0; j < n; j++) v[j] = b[j] == '+' ? '-' : b[j] == '/' ? '_' : b[j];
    v[n] = 0;
  }
  printf("pkce\t%.3f\t%s\n", ms() - t0, v);
  return 0;
}
