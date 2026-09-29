// ZIP read benchmark in C with libarchive (see README.md). The C library has no ZIP reader.
#include <locale.h>
#include <archive.h>
#include <archive_entry.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <zlib.h>

typedef struct {
  char *name;
  unsigned char *data;
  size_t len;
  uint32_t method;
} entry;

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

static void die(const char *what) {
  fprintf(stderr, "%s\n", what ? what : "error");
  exit(1);
}

static uint32_t chk(const unsigned char *p, size_t n, uint32_t h) {
  for (size_t i = 0; i < n; i++) h = h * 31 + p[i];
  return h;
}

int main(void) {
  FILE *f = fopen("out/fixture.zip", "rb");
  if (!f) die("open out/fixture.zip");
  fseek(f, 0, SEEK_END);
  long size = ftell(f);
  rewind(f);
  unsigned char *zip = malloc(size);
  if (fread(zip, 1, size, f) != (size_t)size) die("read out/fixture.zip");
  fclose(f);

  // A UTF-8 name needs a UTF-8 locale, or libarchive cannot convert it.
  if (!setlocale(LC_CTYPE, "C.UTF-8") && !setlocale(LC_CTYPE, "en_US.UTF-8")) die("no UTF-8 locale");
  entry *es = NULL;
  size_t n = 0, cap = 0;
  double t0 = now_ms();
  struct archive *a = archive_read_new();
  archive_read_support_format_zip_seekable(a);  // walks the central directory
  if (archive_read_open_memory(a, zip, size) != ARCHIVE_OK) die(archive_error_string(a));
  struct archive_entry *e;
  int r;
  while ((r = archive_read_next_header(a, &e)) == ARCHIVE_OK) {
    if (n == cap) es = realloc(es, (cap = cap ? cap * 2 : 64) * sizeof *es);
    size_t len = archive_entry_size(e);
    unsigned char *d = malloc(len ? len : 1);
    size_t off = 0;
    for (la_ssize_t got; off < len && (got = archive_read_data(a, d + off, len - off)) > 0;) off += got;
    if (off != len) die(archive_error_string(a));
    // libarchive exposes no method field; its zip reader names each entry's format by method.
    const char *fmt = archive_format_name(a);
    uint32_t method = strstr(fmt, "(uncompressed)") ? 0 : strstr(fmt, "(deflation)") ? 8 : 0xFFFFFFFF;
    if (method == 0xFFFFFFFF) die(fmt);
    const char *name = archive_entry_pathname_utf8(e);
    if (!name) die("entry name is not UTF-8");
    es[n++] = (entry){strdup(name), d, len, method};
  }
  if (r != ARCHIVE_EOF) die(archive_error_string(a));
  archive_read_free(a);
  double t1 = now_ms();

  // libarchive checks each CRC-32 but does not expose it, so the checksum recomputes it with zlib.
  uint32_t h = 0;
  size_t total = 0;
  for (size_t i = 0; i < n; i++) {
    h = h * 31 + es[i].method;
    h = h * 31 + (uint32_t)crc32(0L, es[i].data, es[i].len);
    h = chk(es[i].data, es[i].len, chk((unsigned char *)es[i].name, strlen(es[i].name), h));
    total += es[i].len;
  }
  printf("read\t%.3f\t%u\n", t1 - t0, h);
  printf("entries\t0\t%zu\n", n);
  printf("bytes\t0\t%zu\n", total);
  return 0;
}
