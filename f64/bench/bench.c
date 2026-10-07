#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

static const uint32_t HI[] = {1072693248u, 1073217536u, 1074266112u, 1017118720u, 0u, 3220176896u};
static const uint32_t LO[] = {0u, 0u, 0u, 0u, 1u, 0u};

static double f(int i) {
  uint32_t w[2] = {LO[i], HI[i]};
  double x;
  memcpy(&x, w, 8);
  return x;
}

static uint32_t hi(double x) {
  uint32_t w[2];
  memcpy(w, &x, 8);
  return w[1];
}

int main(void) {
  double xs[6];
  struct timespec t0, t1;
  uint32_t h = 0;
  int i, j;
  for (i = 0; i < 6; i++) xs[i] = f(i);
  clock_gettime(CLOCK_MONOTONIC, &t0);
  for (i = 0; i < 6; i++) {
    for (j = 0; j < 6; j++) {
      h ^= hi(xs[i] + xs[j]) ^ hi(xs[i] * xs[j]) ^ hi(xs[i] / xs[j]);
    }
  }
  clock_gettime(CLOCK_MONOTONIC, &t1);
  printf("fold\t%.3f\t%u\n",
    (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6, h);
  return 0;
}
