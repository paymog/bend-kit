// UTF-8 through the locale converters; hex through libsodium, since C has no standard hex codec.
#include <locale.h>
#include <sodium.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <wchar.h>

#define REPS (1 << 18)

static const wchar_t SEED[] = L"Hello \u00e9 \u03a9 \u20ac \u4e2d \U0001f600\n";

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

static uint32_t chk_w(const wchar_t *s, size_t n) {
  uint32_t h = 0;
  for (size_t i = 0; i < n; i++) h = h * 31 + (uint32_t)s[i];
  return h + (uint32_t)n;
}

static uint32_t chk_b(const unsigned char *s, size_t n) {
  uint32_t h = 0;
  for (size_t i = 0; i < n; i++) h = h * 31 + s[i];
  return h + (uint32_t)n;
}

int main(void) {
  if (!setlocale(LC_CTYPE, "C.UTF-8") && !setlocale(LC_CTYPE, "en_US.UTF-8")) return 1;
  if (sodium_init() < 0) return 1;
  size_t seed = wcslen(SEED), cps = seed * REPS;
  wchar_t *text = malloc((cps + 1) * sizeof *text);
  for (size_t r = 0; r < REPS; r++) wmemcpy(text + r * seed, SEED, seed);
  text[cps] = 0;

  char *octets = malloc(cps * 4 + 1);
  const wchar_t *src = text;
  mbstate_t st = {0};
  double t0 = now_ms();
  size_t nb = wcsrtombs(octets, &src, cps * 4 + 1, &st);
  double ms = now_ms() - t0;
  if (nb == (size_t)-1) return 1;
  printf("utf8_encode\t%.3f\t%u\n", ms, chk_b((unsigned char *)octets, nb));

  wchar_t *back = malloc((cps + 1) * sizeof *back);
  const char *bsrc = octets;
  st = (mbstate_t){0};
  t0 = now_ms();
  size_t nw = mbsrtowcs(back, &bsrc, cps + 1, &st);
  ms = now_ms() - t0;
  if (nw == (size_t)-1) return 1;
  printf("utf8_decode\t%.3f\t%u\n", ms, chk_w(back, nw));

  char *hex = malloc(nb * 2 + 1);
  t0 = now_ms();
  sodium_bin2hex(hex, nb * 2 + 1, (unsigned char *)octets, nb);
  ms = now_ms() - t0;
  printf("hex_encode\t%.3f\t%u\n", ms, chk_b((unsigned char *)hex, nb * 2));

  unsigned char *bin = malloc(nb);
  size_t nbin;
  t0 = now_ms();
  int bad = sodium_hex2bin(bin, nb, hex, nb * 2, NULL, &nbin, NULL);
  ms = now_ms() - t0;
  if (bad) return 1;
  printf("hex_decode\t%.3f\t%u\n", ms, chk_b(bin, nbin));
  return 0;
}
