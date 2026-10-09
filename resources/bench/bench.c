// Resources benchmark: libdispatch counting semaphore (see README.md).
#include <dispatch/dispatch.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int main(int argc, char **argv) {
  long rounds = 1L << (argc > 1 ? atoi(argv[1]) : 14);
  dispatch_semaphore_t pool = dispatch_semaphore_create(64);
  uint32_t admitted = 0, refused = 0;
  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);
  for (long i = 0; i < rounds; i++) {
    for (int k = 0; k < 65; k++) {
      if (dispatch_semaphore_wait(pool, DISPATCH_TIME_NOW) == 0) admitted++;
      else refused++;
    }
    for (int k = 0; k < 64; k++) dispatch_semaphore_signal(pool);
  }
  uint32_t chk = admitted * 31u + refused;
  clock_gettime(CLOCK_MONOTONIC, &t1);
  double ms = (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6;
  printf("lease\t%.3f\t%u\n", ms, chk);
  dispatch_release(pool);
  return 0;
}
