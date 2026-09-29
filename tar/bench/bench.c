// Tar benchmark in C with libarchive (see README.md).
#include <archive.h>
#include <archive_entry.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct {
  int dir;
  char *name;
  unsigned char *data;
  size_t len;
} Ent;

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

// Entries in archive order, or exit on anything but regular files and directories.
static Ent *decode(const unsigned char *buf, size_t n, size_t *count) {
  struct archive *a = archive_read_new();
  archive_read_support_format_tar(a);
  if (archive_read_open_memory(a, buf, n) != ARCHIVE_OK) exit(2);
  size_t cap = 1024, k = 0;
  Ent *es = malloc(cap * sizeof *es);
  struct archive_entry *e;
  int r;
  while ((r = archive_read_next_header(a, &e)) == ARCHIVE_OK) {
    if (k == cap) es = realloc(es, (cap *= 2) * sizeof *es);
    Ent *x = &es[k++];
    mode_t t = archive_entry_filetype(e);
    if (t != AE_IFREG && t != AE_IFDIR) exit(3);
    x->dir = t == AE_IFDIR;
    const char *p = archive_entry_pathname_utf8(e);
    if (!p) exit(4);
    x->name = strdup(p);
    x->len = x->dir ? 0 : (size_t)archive_entry_size(e);
    x->data = malloc(x->len + 1);
    if (archive_read_data(a, x->data, x->len) != (la_ssize_t)x->len) exit(5);
  }
  if (r != ARCHIVE_EOF) exit(6);
  archive_read_free(a);
  *count = k;
  return es;
}

static unsigned char *encode(const Ent *es, size_t k, size_t cap, size_t *used) {
  unsigned char *out = malloc(cap);
  struct archive *w = archive_write_new();
  archive_write_set_format_pax_restricted(w);
  if (archive_write_open_memory(w, out, cap, used) != ARCHIVE_OK) exit(7);
  struct archive_entry *e = archive_entry_new();
  for (size_t i = 0; i < k; i++) {
    archive_entry_clear(e);
    archive_entry_set_pathname_utf8(e, es[i].name);
    archive_entry_set_filetype(e, es[i].dir ? AE_IFDIR : AE_IFREG);
    archive_entry_set_perm(e, es[i].dir ? 0755 : 0644);
    archive_entry_set_size(e, (la_int64_t)es[i].len);
    archive_entry_set_mtime(e, 0, 0);
    if (archive_write_header(w, e) != ARCHIVE_OK) exit(8);
    if (es[i].len && archive_write_data(w, es[i].data, es[i].len) != (la_ssize_t)es[i].len) exit(9);
  }
  archive_entry_free(e);
  if (archive_write_close(w) != ARCHIVE_OK) exit(10);
  archive_write_free(w);
  return out;
}

// Checksum (see run.py): per entry fold kind, name bytes + length, file data bytes + length; add the count.
static unsigned fold(const unsigned char *p, size_t n, unsigned h) {
  for (size_t i = 0; i < n; i++) h = h * 31 + p[i];
  return h * 31 + (unsigned)n;
}

static unsigned checksum(const Ent *es, size_t k) {
  unsigned h = 0;
  for (size_t i = 0; i < k; i++) {
    size_t m = strlen(es[i].name);
    if (es[i].dir) {
      if (m && es[i].name[m - 1] == '/') m--;
      h = fold((const unsigned char *)es[i].name, m, h * 31 + 2);
    } else {
      h = fold(es[i].data, es[i].len, fold((const unsigned char *)es[i].name, m, h * 31 + 1));
    }
  }
  return h + (unsigned)k;
}

int main(void) {
  setlocale(LC_ALL, "en_US.UTF-8");
  FILE *f = fopen("out/input.tar", "rb");
  if (!f) return 1;
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  rewind(f);
  unsigned char *data = malloc(n);
  if (fread(data, 1, n, f) != (size_t)n) return 1;
  fclose(f);

  size_t k, k2, used = 0;
  double t0 = now_ms();
  Ent *es = decode(data, n, &k);
  double t1 = now_ms();
  // pax_restricted writes at most one extra header per entry, so twice the input is room enough.
  unsigned char *out = encode(es, k, 2 * (size_t)n + 65536, &used);
  double t2 = now_ms();

  Ent *back = decode(out, used, &k2);
  printf("decode\t%.3f\t%u\n", t1 - t0, checksum(es, k));
  printf("encode\t%.3f\t%u\n", t2 - t1, checksum(back, k2));
  return 0;
}
