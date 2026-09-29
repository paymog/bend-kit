// Regex benchmark with POSIX extended regex (regex.h). See README.md.
#include <regex.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define REDOS_N 100000

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

static char *text(size_t size) {
  size_t e = size - 50, h = size - 20;
  char *s = malloc(size + 1);
  if (!s) return NULL;
  memset(s, 'x', size);
  memcpy(s + e, "user@host.com", 13);
  memcpy(s + h, "helloworld12", 12);
  s[size] = 0;
  return s;
}

static uint32_t mix(uint32_t acc, uint32_t x) {
  return acc * 31u + x;
}

static uint32_t chk_match(const regmatch_t *pm, int n) {
  uint32_t h = 0;
  for (int i = 0; i < n; i++) {
    if (pm[i].rm_so < 0)
      h *= 31u;
    else {
      h = mix(h, (uint32_t)pm[i].rm_so);
      h = mix(h, (uint32_t)pm[i].rm_eo);
    }
  }
  return h;
}

// ngroups 0 asks only whether a match exists (REG_NOSUB); chk is then 1 or 0.
static int run_one(const char *pat, const char *s, int ngroups, double *ms, uint32_t *chk) {
  regex_t re;
  if (regcomp(&re, pat, REG_EXTENDED | (ngroups ? 0 : REG_NOSUB)) != 0) return -1;
  regmatch_t pm[16];
  int n = ngroups < 16 ? ngroups : 16;
  double t0 = now_ms();
  int rc = regexec(&re, s, n, pm, 0);
  *ms = now_ms() - t0;
  *chk = rc == REG_NOMATCH ? 0 : ngroups ? chk_match(pm, n) : 1;
  regfree(&re);
  return 0;
}

static int want(const char *only, const char *name) {
  return !only || strcmp(only, name) == 0;
}

int main(int argc, char **argv) {
  size_t size = argc > 1 ? (size_t)strtoull(argv[1], NULL, 10) : (1u << 20);
  const char *only = argc > 2 ? argv[2] : NULL;
  char *s = text(size);
  if (!s) return 1;
  double ms;
  uint32_t chk;

  if (want(only, "is_match")) {
    if (run_one("hello[[:alnum:]_]+", s, 0, &ms, &chk) != 0) return 1;
    printf("is_match\t%.3f\t%u\n", ms, chk);
  }

  if (want(only, "is_match_early")) {
    if (run_one("x", s, 0, &ms, &chk) != 0) return 1;
    printf("is_match_early\t%.3f\t%u\n", ms, chk);
  }

  if (want(only, "is_match_live")) {
    if (run_one("xy", s, 0, &ms, &chk) != 0) return 1;
    printf("is_match_live\t%.3f\t%u\n", ms, chk);
  }

  if (want(only, "find_captures")) {
    if (run_one("([[:alnum:]_]+)@([[:alnum:]_]+)\\.com", s, 3, &ms, &chk) != 0) return 1;
    printf("find_captures\t%.3f\t%u\n", ms, chk);
  }
  if (want(only, "sparse")) {
    if (run_one("x@host\\.org", s, 1, &ms, &chk) != 0) return 1;
    printf("sparse\t%.3f\t%u\n", ms, chk);
  }
  if (want(only, "sparse_hit")) {
    char *hit = malloc(size + 1);
    if (!hit) return 1;
    memset(hit, 'x', size - 9);
    memcpy(hit + size - 9, "@host.org", 9);
    hit[size] = 0;
    if (run_one("x.{0,4}@host\\.org", hit, 1, &ms, &chk) != 0) return 1;
    printf("sparse_hit\t%.3f\t%u\n", ms, chk);
    free(hit);
  }


  if (want(only, "find_early")) {
    if (run_one("(x)x", s, 2, &ms, &chk) != 0) return 1;
    printf("find_early\t%.3f\t%u\n", ms, chk);
  }

  if (want(only, "redos")) {
    char *as = malloc(REDOS_N + 1);
    if (!as) return 1;
    memset(as, 'a', REDOS_N);
    as[REDOS_N] = 0;
    if (run_one("(a*)*b", as, 1, &ms, &chk) != 0) return 1;
    printf("redos\t%.3f\t%u\n", ms, chk);
    free(as);
  }

  if (want(only, "large")) {
    char large[1002];
    memset(large, 'x', 1000);
    large[1000] = 'y';
    large[1001] = 0;
    // RE_DUP_MAX is 255, so {1000} is written as {250}{4}.
    if (run_one("((x?){250}){4}y", large, 1, &ms, &chk) != 0) return 1;
    printf("large\t%.3f\t%u\n", ms, chk);
  }

  free(s);
  return 0;
}
