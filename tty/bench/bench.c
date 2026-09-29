// tty width/pad_right benchmark: the C side, libc wcswidth (see README.md).
#include <locale.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <wchar.h>

#define COLS 20
#define MAXLEN 16

static const uint32_t BASE[9] = {0x21, 0x21, 0x21, 0x3B1, 0x4E00, 0xAC00, 0x3041, 0x300, 0xFF01};
static const uint32_t SPAN[9] = {94, 94, 94, 25, 512, 512, 86, 52, 94};

static double ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

// Each string is MAXLEN + 1 wide chars, NUL-terminated.
static int pad_right(const wchar_t *s, int cols, wchar_t *out) {
  int n = (int)wcslen(s), w = wcswidth(s, n), i = 0;
  for (; i < n; i++) out[i] = s[i];
  for (; w < cols; w++) out[i++] = L' ';
  out[i] = 0;
  return i;
}

int main(int argc, char **argv) {
  if (!setlocale(LC_ALL, "en_US.UTF-8") && !setlocale(LC_ALL, "C.UTF-8")) return fprintf(stderr, "no UTF-8 locale\n"), 1;
  int n = argc > 1 ? atoi(argv[1]) : 20000;
  wchar_t *xs = calloc((size_t)n * (MAXLEN + 1), sizeof *xs);
  uint32_t s = 1;
  for (int i = 0; i < n; i++) {
    s = s * 1664525u + 1013904223u;
    int k = 1 + (s >> 16) % 16;
    wchar_t *x = xs + (size_t)i * (MAXLEN + 1);
    for (int j = 0; j < k; j++) {
      s = s * 1664525u + 1013904223u;
      uint32_t v = s >> 8, c = v % 9;
      x[j] = (wchar_t)(BASE[c] + v / 9 % SPAN[c]);
    }
  }

  double t0 = ms();
  uint64_t total = 0;
  for (int i = 0; i < n; i++) {
    wchar_t *x = xs + (size_t)i * (MAXLEN + 1);
    total += wcswidth(x, wcslen(x));
  }
  double t1 = ms();
  printf("chk\twidth\t%llu\nms\twidth\t%.3f\n", (unsigned long long)total, t1 - t0);

  wchar_t buf[MAXLEN + COLS + 1];
  uint32_t h = 2166136261u;
  uint64_t len = 0;
  t0 = ms();
  for (int i = 0; i < n; i++) {
    int m = pad_right(xs + (size_t)i * (MAXLEN + 1), COLS, buf);
    for (int j = 0; j < m; j++) h = (h ^ (uint32_t)buf[j]) * 16777619u;
    h = (h ^ '\n') * 16777619u;
    len += m + 1;
  }
  t1 = ms();
  printf("chk\tpad\t%u\nchk\tpadlen\t%llu\nms\tpad\t%.3f\n", h, (unsigned long long)len, t1 - t0);
  free(xs);
  return 0;
}
