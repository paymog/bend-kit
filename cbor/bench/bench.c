// CBOR benchmark in C with libcbor (see README.md).
#include <cbor.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

int main(void) {
  FILE *f = fopen("out/doc.cbor", "rb");
  if (!f) return 1;
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  rewind(f);
  unsigned char *data = malloc(n);
  if (fread(data, 1, n, f) != (size_t)n) return 1;
  fclose(f);

  double t0 = now_ms();
  struct cbor_load_result res;
  cbor_item_t *item = cbor_load(data, n, &res);
  double t1 = now_ms();
  if (!item || res.error.code != CBOR_ERR_NONE || res.read != (size_t)n) return 2;
  unsigned char *out = NULL;
  size_t cap = 0;
  size_t len = cbor_serialize_alloc(item, &out, &cap);
  double t2 = now_ms();
  if (len == 0) return 3;

  // Checksum: h = h*31 + b, u32, then add the length.
  unsigned h = 0;
  for (size_t i = 0; i < len; i++) h = h * 31 + out[i];
  h += (unsigned)len;
  printf("decode\t%.3f\t%u\n", t1 - t0, h);
  printf("encode\t%.3f\t%u\n", t2 - t1, h);
  cbor_decref(&item);
  free(out);
  free(data);
  return 0;
}
