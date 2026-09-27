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

  long n2 = argc > 2 ? atol(argv[2]) : 10000000;
  volatile int32_t d = 1000;
  t0 = now_ms();
  uint32_t xi = 1, ai = 0;
  for (long i = 0; i < n2; i++) {
    xi = xi * 1664525u + 1013904223u;
    ai += (uint32_t)((int32_t)xi / d);
  }
  printf("i32\t%.3f\t%d\n", now_ms() - t0, (int32_t)ai);
  t0 = now_ms();
  uint16_t x16 = 1;
  for (long i = 0; i < n2; i++) x16 = (uint16_t)(x16 * 25173u + 13849u);
  printf("u16\t%.3f\t%u\n", now_ms() - t0, x16);
  t0 = now_ms();
  uint8_t x8 = 1;
  for (long i = 0; i < n2; i++) x8 = (uint8_t)(x8 * 77u + 13u);
  printf("u8\t%.3f\t%u\n", now_ms() - t0, x8);
  return 0;
}
