#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

int main(int argc, char **argv) {
  if (argc != 5) return 1;
  size_t cap = strtoul(argv[3], NULL, 10), chunk = strtoul(argv[4], NULL, 10), count = 0;
  if (!chunk || chunk > 1048576) return 1;
  FILE *src = fopen(argv[1], "rb"), *dst = fopen(argv[2], "wb");
  unsigned char *buf = malloc(chunk);
  if (!src || !dst || !buf) return 1;
  while (count < cap) {
    size_t remaining = cap - count;
    size_t n = fread(buf, 1, remaining < chunk ? remaining : chunk, src);
    if (ferror(src)) return 1;
    if (!n) break;
    if (fwrite(buf, 1, n, dst) != n) return 1;
    count += n;
  }
  if (fgetc(src) != EOF || ferror(src)) return 1;
  int a = fclose(src), b = fclose(dst);
  if (a || b) return 1;
  FILE *out = fopen(argv[2], "rb");
  if (!out) return 1;
  uint32_t hash = 2166136261u;
  size_t n;
  while ((n = fread(buf, 1, chunk, out)) != 0)
    for (size_t i = 0; i < n; i++) hash = (hash ^ buf[i]) * 16777619u;
  int bad = ferror(out);
  fclose(out);
  free(buf);
  if (bad) return 1;
  printf("%zu %u\n", count, hash);
  return 0;
}
