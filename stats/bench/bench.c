#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define N 10000

static uint32_t xs(uint32_t x) {
  x ^= x << 13;
  x ^= x >> 17;
  x ^= x << 5;
  return x;
}

static uint32_t mix(double x) {
  uint32_t w[2];
  memcpy(w, &x, 8);
  return w[0] ^ w[1];
}

static double ms(struct timespec a, struct timespec b) {
  return (b.tv_sec - a.tv_sec) * 1e3 + (b.tv_nsec - a.tv_nsec) / 1e6;
}

static int cmp(const void *a, const void *b) {
  double x = *(const double *)a, y = *(const double *)b;
  return (x > y) - (x < y);
}

static double mean(const double *v, int n) {
  double s = 0;
  for (int i = 0; i < n; i++) s += v[i];
  return s / n;
}

static double variance(const double *v, int n) {
  double m = mean(v, n), s = 0;
  for (int i = 0; i < n; i++) s += (v[i] - m) * (v[i] - m);
  return s / (n - 1);
}

static double median(const double *v, int n) {
  double *s = malloc(n * sizeof *s);
  memcpy(s, v, n * sizeof *s);
  qsort(s, n, sizeof *s, cmp);
  int i = (n - 1) / 2;
  double r = (n - 1) % 2 ? s[i] + 0.5 * (s[i + 1] - s[i]) : s[i];
  free(s);
  return r;
}

static double histogram(const double *v, int n) {
  double edges[101];
  uint32_t counts[100] = {0};
  for (int i = 0; i <= 100; i++) edges[i] = i * 10486;
  for (int i = 0; i < n; i++) {
    double x = v[i];
    if (!(edges[0] <= x && x <= edges[100])) continue;
    int lo = 1, hi = 100;
    while (lo < hi) {
      int mid = lo + (hi - lo) / 2;
      if (x < edges[mid]) hi = mid;
      else lo = mid + 1;
    }
    counts[lo - 1]++;
  }
  double sum = 0;
  for (int i = 0; i < 100; i++) sum += (i + 1) * counts[i];
  return sum;
}

int main(void) {
  static double v[N];
  struct timespec t0, t1;
  uint32_t x = 44;
  double r;
  for (int i = 0; i < N; i++) {
    x = xs(x);
    v[i] = x >> 12;
  }
  clock_gettime(CLOCK_MONOTONIC, &t0);
  r = mean(v, N);
  clock_gettime(CLOCK_MONOTONIC, &t1);
  printf("mean\t%.3f\t%u\n", ms(t0, t1), mix(r));
  clock_gettime(CLOCK_MONOTONIC, &t0);
  r = variance(v, N);
  clock_gettime(CLOCK_MONOTONIC, &t1);
  printf("variance\t%.3f\t%u\n", ms(t0, t1), mix(r));
  clock_gettime(CLOCK_MONOTONIC, &t0);
  r = median(v, N);
  clock_gettime(CLOCK_MONOTONIC, &t1);
  printf("median\t%.3f\t%u\n", ms(t0, t1), mix(r));
  clock_gettime(CLOCK_MONOTONIC, &t0);
  r = histogram(v, N);
  clock_gettime(CLOCK_MONOTONIC, &t1);
  printf("histogram\t%.3f\t%u\n", ms(t0, t1), mix(r));
  return 0;
}
