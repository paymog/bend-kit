// CommonMark render benchmark: cmark (see README.md).
#include <cmark.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define N 100
#define R 10

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

static uint32_t fnv(const char *s, size_t n) {
  uint32_t h = 2166136261u;
  for (size_t i = 0; i < n; i++) h = (h ^ (unsigned char)s[i]) * 16777619u;
  return h;
}

int main(void) {
  static char doc[1 << 16];
  size_t len = 0;
  for (int i = 0; i < N; i++)
    len += sprintf(doc + len,
                   "## Section %d\n\nSome *emphasis*, **strong**, `code <tag>`, and a [link](https://example.com/%d?a=1&b=2 \"title %d\").\n"
                   "Text with &amp; entities &lt; and <span class=\"x\">inline html</span>.\n\n"
                   "- item one\n- item two with `code`\n  - nested *item* %d\n\n1. first\n2. second\n\n"
                   "> A quote with **bold** text\n> across lines.\n\n```python\ndef f(x):\n    return x < %d\n```\n\n---\n\n",
                   i, i, i, i, i);
  char *first = cmark_markdown_to_html(doc, len, CMARK_OPT_UNSAFE);
  uint32_t chk = fnv(first, strlen(first));
  free(first);
  double t0 = now_ms();
  size_t total = 0;
  for (int r = 0; r < R; r++) {
    char *html = cmark_markdown_to_html(doc, len, CMARK_OPT_UNSAFE);
    total += strlen(html);
    free(html);
  }
  double ms = now_ms() - t0;
  printf("render\t%.3f\t%u\n", ms, chk);
  printf("len\trender\t%zu\n", total);
  return 0;
}
