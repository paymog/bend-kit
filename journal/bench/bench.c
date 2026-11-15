// Journal recovery benchmark: zlib crc32 and a straight scan (see README.md).
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <zlib.h>

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

static uint32_t rd32(const unsigned char *p) {
  return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void wr32(unsigned char *p, uint32_t v) {
  p[0] = (unsigned char)v;
  p[1] = (unsigned char)(v >> 8);
  p[2] = (unsigned char)(v >> 16);
  p[3] = (unsigned char)(v >> 24);
}

int main(int argc, char **argv) {
  unsigned lg = argc > 1 ? (unsigned)atoi(argv[1]) : 20;
  uint32_t n = 1u << lg;
  size_t cap = (size_t)n * 75; // 12 + max payload 63
  unsigned char *buf = malloc(cap);
  if (!buf) return 1;
  size_t len = 0;
  for (uint32_t i = 0; i < n; i++) {
    uint32_t plen = 16u + ((i * 7u) % 48u);
    unsigned char *frame = buf + len;
    for (uint32_t j = 0; j < plen; j++) frame[12 + j] = (unsigned char)((i * 31u + j) & 255u);
    uint32_t sum = (uint32_t)crc32(0L, frame + 12, plen);
    wr32(frame, plen);
    wr32(frame + 4, ~plen);
    wr32(frame + 8, sum);
    len += 12u + plen;
  }

  double t0 = now_ms();
  uint32_t acc = 0, count = 0;
  size_t off = 0;
  while (off + 12 <= len) {
    uint32_t plen = rd32(buf + off);
    uint32_t nlen = rd32(buf + off + 4);
    uint32_t want = rd32(buf + off + 8);
    if (nlen != ~plen || plen > 64u || off + 12 + plen > len) {
      fprintf(stderr, "bad frame\n");
      return 1;
    }
    if ((uint32_t)crc32(0L, buf + off + 12, plen) != want) {
      fprintf(stderr, "bad frame\n");
      return 1;
    }
    acc = acc * 31u + plen + buf[off + 12];
    count++;
    off += 12u + plen;
  }
  if (off != len || count != n) {
    fprintf(stderr, "bad frame\n");
    return 1;
  }
  double t1 = now_ms();
  printf("recover\t%.3f\t%u\t%u\n", t1 - t0, acc, count);
  free(buf);
  return 0;
}
