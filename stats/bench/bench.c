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

static uint32_t gcd(uint32_t a, uint32_t b) {
  while (b) {
    uint32_t r = a % b;
    a = b;
    b = r;
  }
  return a;
}

static uint32_t lcm(uint32_t a, uint32_t b) {
  if (!a || !b) return 0;
  uint64_t r = (uint64_t)(a / gcd(a, b)) * b;
  return r > UINT32_MAX ? 0x9E3779B9 : (uint32_t)r;
}

static uint32_t isqrt(uint32_t a, uint32_t b) {
  (void)b;
  uint32_t lo = 0, hi = 65536;
  while (lo + 1 < hi) {
    uint32_t mid = lo + (hi - lo) / 2;
    if (mid * mid <= a) lo = mid;
    else hi = mid;
  }
  return lo;
}

static void integers(size_t n) {
  uint32_t (*pairs)[2] = malloc((n + 55) * sizeof *pairs);
  if (!pairs) exit(1);
  const uint32_t edges[8][2] = {
    {0, 0}, {0, UINT32_MAX}, {UINT32_MAX, 0}, {UINT32_MAX, UINT32_MAX},
    {UINT32_MAX, 1}, {65535, 65536}, {65536, 65537}, {12, 18}
  };
  memcpy(pairs, edges, sizeof edges);
  uint32_t a = 0, b = 1;
  for (size_t i = 8; i < 55; i++) {
    pairs[i][0] = a;
    pairs[i][1] = b;
    uint32_t next = a + b;
    a = b;
    b = next;
  }
  uint32_t x = 44;
  for (size_t i = 55; i < n + 55; i++) {
    a = xs(x);
    x = xs(a);
    pairs[i][0] = a;
    pairs[i][1] = x;
  }
  const char *ops[] = {"gcd", "lcm", "isqrt"};
  uint32_t (*funcs[])(uint32_t, uint32_t) = {gcd, lcm, isqrt};
  for (int op = 0; op < 3; op++) {
    struct timespec t0, t1;
    uint32_t checksum = 0;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    for (size_t i = 0; i < n + 55; i++)
      checksum += funcs[op](pairs[i][0], pairs[i][1]);
    clock_gettime(CLOCK_MONOTONIC, &t1);
    printf("%s\t%.3f\t%u\n", ops[op], ms(t0, t1), checksum);
  }
  uint32_t *packed = malloc((n + 55) * 2 * sizeof *packed);
  if (!packed) exit(1);
  for (size_t i = 0; i < n + 55; i++) {
    packed[2 * i] = pairs[i][0];
    packed[2 * i + 1] = pairs[i][1];
  }
  struct timespec t0, t1;
  uint32_t checksum = 0;
  clock_gettime(CLOCK_MONOTONIC, &t0);
  for (size_t i = 0; i < (n + 55) * 2; i += 2)
    checksum += packed[i];
  clock_gettime(CLOCK_MONOTONIC, &t1);
  printf("packed_identity\t%.3f\t%u\n", ms(t0, t1), checksum);
  for (int op = 0; op < 3; op++) {
    checksum = 0;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    for (size_t i = 0; i < (n + 55) * 2; i += 2)
      checksum += funcs[op](packed[i], packed[i + 1]);
    clock_gettime(CLOCK_MONOTONIC, &t1);
    printf("packed_%s\t%.3f\t%u\n", ops[op], ms(t0, t1), checksum);
  }
  free(packed);
  free(pairs);
}

int main(int argc, char **argv) {
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
  integers(argc > 1 ? strtoul(argv[1], NULL, 10) : 2097152);
  return 0;
}
