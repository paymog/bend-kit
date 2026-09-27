// Hash benchmark in C (see README.md). The C library has no hashes; zlib is the popular one for CRC-32 and Adler-32.
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <zlib.h>

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
  free(buf);
  return 0;
}
