// Integer benchmark: the C side (see README.md). Argument: N.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

int main(int argc, char **argv) {
  long n = argc > 1 ? atol(argv[1]) : 16384;
  volatile uint64_t av = 6364136223846793005ULL, cv = 1442695040888963407ULL, mv = 1000003;
  uint64_t a = av, c = cv, m = mv;

  double t0 = now_ms();
  uint64_t x = 1;
  for (long i = 0; i < n; i++) x = x * a + c;
  printf("lcg\t%.3f\t%llu\n", now_ms() - t0, (unsigned long long)x);

  uint64_t *xs = malloc(n * sizeof *xs);
  uint32_t s = 1;
  for (long i = 0; i < n; i++) {
    uint32_t hi = s * 1664525u + 1013904223u;
    uint32_t lo = hi * 1664525u + 1013904223u;
    s = lo;
    xs[i] = (uint64_t)hi << 32 | lo;
  }
  t0 = now_ms();
  uint64_t acc = 0;
  for (long i = 0; i < n; i++) acc += xs[i] % m;
  printf("rem\t%.3f\t%llu\n", now_ms() - t0, (unsigned long long)acc);
  free(xs);
  return 0;
}
