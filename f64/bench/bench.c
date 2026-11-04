#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define N 1000

static const uint32_t HI[] = {1072693248u, 1073217536u, 1074266112u, 1017118720u, 0u, 3220176896u};
static const uint32_t LO[] = {0u, 0u, 0u, 0u, 1u, 0u};

static double make(uint32_t hi, uint32_t lo) {
  uint32_t w[2] = {lo, hi};
  double x;
  memcpy(&x, w, 8);
  return x;
}

static uint32_t hi(double x) {
  uint32_t w[2];
  memcpy(w, &x, 8);
  return w[1];
}

static uint32_t mix(double x) {
  uint32_t w[2];
  memcpy(w, &x, 8);
  return w[0] ^ w[1];
}

static uint32_t xs(uint32_t x) {
  x ^= x << 13;
  x ^= x >> 17;
  x ^= x << 5;
  return x;
}

static double ms(struct timespec a, struct timespec b) {
  return (b.tv_sec - a.tv_sec) * 1e3 + (b.tv_nsec - a.tv_nsec) / 1e6;
}

int main(void) {
  double v[6], nums[N];
  static char text[N][32];
  struct timespec t0, t1;
  uint32_t h = 0, x = 611;
  int i, j, n = 0;
  for (i = 0; i < 6; i++) v[i] = make(HI[i], LO[i]);
  clock_gettime(CLOCK_MONOTONIC, &t0);
  for (i = 0; i < 6; i++) {
    for (j = 0; j < 6; j++) {
      h ^= hi(v[i] + v[j]) ^ hi(v[i] * v[j]) ^ hi(v[i] / v[j]);
    }
  }
  clock_gettime(CLOCK_MONOTONIC, &t1);
  printf("fold\t%.3f\t%u\n", ms(t0, t1), h);

  for (i = 0; i < N; i++) {
    uint32_t a = xs(x), b = xs(a);
    x = b;
    if (((a >> 20) & 2047) != 2047) nums[n++] = make(a, b);
  }
  clock_gettime(CLOCK_MONOTONIC, &t0);
  for (i = 0; i < n; i++) snprintf(text[i], sizeof text[i], "%.17g", nums[i]);
  clock_gettime(CLOCK_MONOTONIC, &t1);
  h = 0;
  for (i = 0; i < n; i++) h ^= mix(strtod(text[i], NULL));
  printf("show\t%.3f\t%u\n", ms(t0, t1), h);

  clock_gettime(CLOCK_MONOTONIC, &t0);
  h = 0;
  for (i = 0; i < n; i++) h ^= mix(strtod(text[i], NULL));
  clock_gettime(CLOCK_MONOTONIC, &t1);
  printf("read\t%.3f\t%u\n", ms(t0, t1), h);
  return 0;
}
