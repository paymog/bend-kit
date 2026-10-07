#include "bench.pb-c.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

int main(int argc, char **argv) {
  unsigned loops = argc > 1 ? (unsigned)strtoul(argv[1], NULL, 10) : 100;
  FILE *f = fopen("fixture.bin", "rb");
  if (!f) return 1;
  unsigned char input[4096];
  size_t size = fread(input, 1, sizeof(input), f);
  fclose(f);
  uint64_t checksum = 0;
  struct timespec start, end;
  clock_gettime(CLOCK_MONOTONIC, &start);
  for (unsigned i = 0; i < loops; i++) {
    Kit__Bench__Sample *m = kit__bench__sample__unpack(NULL, size, input);
    if (!m) return 2;
    size_t n = kit__bench__sample__get_packed_size(m);
    unsigned char *out = malloc(n);
    if (!out) return 3;
    kit__bench__sample__pack(m, out);
    for (size_t j = 0; j < n; j++) checksum += out[j];
    free(out);
    kit__bench__sample__free_unpacked(m, NULL);
  }
  clock_gettime(CLOCK_MONOTONIC, &end);
  double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;
  printf("%llu\t%.6f\n", (unsigned long long)checksum, ms);
  return 0;
}
