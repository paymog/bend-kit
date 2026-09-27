// Time benchmark: C with POSIX gmtime_r, strftime, strptime, and timegm (see README.md).
#define _GNU_SOURCE
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#define N 4096
#define T0 (-2208988800LL)
#define STEP 3155761LL

static double now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec * 1e3 + ts.tv_nsec / 1e6;
}

int main(void) {
  double   start = now_ms();
  uint32_t chk   = 0;
  long long t    = T0;
  for (int i = 0; i < N; i++) {
    time_t    tt = (time_t)t;
    struct tm tm;
    char      s[64];
    gmtime_r(&tt, &tm);
    size_t n = strftime(s, sizeof s, "%Y-%m-%dT%H:%M:%SZ", &tm);
    struct tm back = {0};
    strptime(s, "%Y-%m-%dT%H:%M:%SZ", &back);
    uint32_t sum = 0;
    for (size_t j = 0; j < n; j++) sum += (unsigned char)s[j];
    chk += sum + (uint32_t)(int64_t)timegm(&back);
    t += STEP;
  }
  printf("trip\t%.3f\t%u\n", now_ms() - start, chk);
  return 0;
}
