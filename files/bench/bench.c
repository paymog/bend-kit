#include <stdint.h>
#include <stdio.h>

int main(void) {
  FILE* file = fopen("bench/fixture.bin", "rb");
  if (!file) return 1;
  uint8_t bytes[16384];
  uint32_t hash = 2166136261u;
  size_t n;
  while ((n = fread(bytes, 1, sizeof(bytes), file)) != 0) {
    for (size_t i = 0; i < n; i++) hash = (hash ^ bytes[i]) * 16777619u;
  }
  if (ferror(file)) return 1;
  fclose(file);
  printf("%u\n", hash);
  return 0;
}
