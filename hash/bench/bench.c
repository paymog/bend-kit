// Hash benchmark in C (see README.md). The C library has no hashes; zlib is the popular one for CRC-32 and Adler-32.
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <zlib.h>
#include <sodium.h>

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

int main(void) {
  const size_t n = 16777213;
  unsigned char *buf = malloc(n);
  for (size_t i = 0; i < n; i++) buf[i] = i % 251;

  double t0 = now_ms();
  unsigned long c = crc32(0L, buf, n);
  double t1 = now_ms();
  printf("crc32\t%.3f\t%08lx\n", t1 - t0, c);

  t0 = now_ms();
  unsigned long a = adler32(1L, buf, n);
  t1 = now_ms();
  printf("adler32\t%.3f\t%08lx\n", t1 - t0, a);

  unsigned long s = 0;
  t0 = now_ms();
  for (int i = 0; i < 100000; i++) s = crc32(0L, buf, 16);
  t1 = now_ms();
  printf("crc32_short\t%.3f\t%08lx\n", t1 - t0, s);
  unsigned char key[crypto_shorthash_siphash24_KEYBYTES] = {0};
  unsigned char digest[crypto_shorthash_siphash24_BYTES];
  t0 = now_ms();
  if (crypto_shorthash_siphash24(digest, buf, n, key) != 0) return 1;
  t1 = now_ms();
  printf("siphash24\t%.3f\t", t1 - t0);
  for (size_t i = sizeof(digest); i > 0; i--) printf("%02x", digest[i - 1]);
  printf("\n");
  free(buf);
  return 0;
}
