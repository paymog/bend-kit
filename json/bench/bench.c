// JSON benchmark in C with cJSON (see README.md).
#include <cjson/cJSON.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

// Checksum: h = h*31 + b, u32, then add the length.
static unsigned chk(const char *s) {
  unsigned h = 0;
  size_t n = strlen(s);
  for (size_t i = 0; i < n; i++) h = h * 31 + (unsigned char)s[i];
  return h + (unsigned)n;
}

int main(void) {
  FILE *f = fopen("out/doc.json", "rb");
  if (!f) return 1;
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  rewind(f);
  char *data = malloc(n);
  if (fread(data, 1, n, f) != (size_t)n) return 1;
  fclose(f);

  double t0 = now_ms();
  cJSON *v = cJSON_ParseWithLength(data, n);
  double t1 = now_ms();
  if (!v) return 2;
  char *check = cJSON_PrintUnformatted(v);
  if (!check) return 3;
  printf("parse.bytes\t%.3f\t%u\n", t1 - t0, chk(check));

  t0 = now_ms();
  char *out = cJSON_PrintUnformatted(v);
  t1 = now_ms();
  if (!out) return 3;
  printf("encode.bytes\t%.3f\t%u\n", t1 - t0, chk(out));

  free(out);
  free(check);
  cJSON_Delete(v);
  free(data);
  return 0;
}
