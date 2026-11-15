// Bits benchmark in C: zlib's inflate on the raw DEFLATE payload. C's standard library has no bit reader.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <zlib.h>

static double ms(struct timespec a, struct timespec b) {
  return (b.tv_sec - a.tv_sec) * 1e3 + (b.tv_nsec - a.tv_nsec) / 1e6;
}

int main(void) {
  FILE *f = fopen("out/payload.bin", "rb");
  if (!f) return 1;
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  fseek(f, 0, SEEK_SET);
  unsigned char *in = malloc(n);
  if (fread(in, 1, n, f) != (size_t)n) return 1;
  fclose(f);
  size_t cap = (size_t)n * 2;
  unsigned char *out = malloc(cap);

  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);
  z_stream z = {0};
  if (inflateInit2(&z, -15) != Z_OK) return 1;
  z.next_in = in;
  z.avail_in = n;
  z.next_out = out;
  z.avail_out = cap;
  if (inflate(&z, Z_FINISH) != Z_STREAM_END) return 1;
  size_t len = z.total_out;
  inflateEnd(&z);
  clock_gettime(CLOCK_MONOTONIC, &t1);
  uint32_t h = 0;
  for (size_t i = 0; i < len; i++) h = h * 31 + out[i];
  printf("huffman\t%.3f\t%u\n", ms(t0, t1), h);
  return 0;
}
