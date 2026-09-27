// Shortest F32 benchmark: the C side (see README.md). Argument: N.
// C has no shortest printer; the obvious loop tries 1 to 9 digits until strtof reads x back.
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// Python repr style from x's shortest digits.
static void shortest(float x, char *out) {
  if (isnan(x)) { strcpy(out, "nan"); return; }
  if (isinf(x)) { strcpy(out, x < 0 ? "-inf" : "inf"); return; }
  if (x == 0) { strcpy(out, signbit(x) ? "-0.0" : "0.0"); return; }
  char buf[64];
  for (int p = 0; p < 9; p++) {
    snprintf(buf, sizeof buf, "%.*e", p, (double)x);
    if (strtof(buf, NULL) == x) break;
  }
  char *o = out, digits[16];
  int nd = 0, neg = buf[0] == '-';
  char *q = buf + neg;
  for (; *q != 'e'; q++) if (*q != '.') digits[nd++] = *q;
  while (nd > 1 && digits[nd - 1] == '0') nd--;
  int e = atoi(q + 1);
  if (neg) *o++ = '-';
  if (e < -4 || e >= 16) {
    *o++ = digits[0];
    if (nd > 1) { *o++ = '.'; memcpy(o, digits + 1, nd - 1); o += nd - 1; }
    o += sprintf(o, "e%c%02d", e < 0 ? '-' : '+', abs(e));
  } else if (e < 0) {
    *o++ = '0'; *o++ = '.';
    for (int i = 0; i < -e - 1; i++) *o++ = '0';
    memcpy(o, digits, nd); o += nd; *o = 0;
  } else if (e + 1 >= nd) {
    memcpy(o, digits, nd); o += nd;
    for (int i = 0; i < e + 1 - nd; i++) *o++ = '0';
    strcpy(o, ".0");
  } else {
    memcpy(o, digits, e + 1); o += e + 1; *o++ = '.';
    memcpy(o, digits + e + 1, nd - e - 1); o += nd - e - 1; *o = 0;
  }
}

int main(int argc, char **argv) {
  int n = argc > 1 ? atoi(argv[1]) : 50000;
  uint32_t *xs = malloc(n * sizeof *xs), s = 1;
  for (int i = 0; i < n; i++) xs[i] = s = s * 1664525u + 1013904223u;
  struct timespec a, b;
  clock_gettime(CLOCK_MONOTONIC, &a);
  uint32_t h = 2166136261u;
  char out[64];
  for (int i = 0; i < n; i++) {
    float x;
    memcpy(&x, &xs[i], 4);
    shortest(x, out);
    for (char *c = out; *c; c++) h = (h ^ (uint8_t)*c) * 16777619u;
    h = (h ^ '\n') * 16777619u;
  }
  clock_gettime(CLOCK_MONOTONIC, &b);
  printf("short\t%.3f\t%u\n", (b.tv_sec - a.tv_sec) * 1e3 + (b.tv_nsec - a.tv_nsec) / 1e6, h);
}
