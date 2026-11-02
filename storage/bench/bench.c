// Storage benchmark: OpenSSL SHA-256 and POSIX hsearch (see README.md).
#include <openssl/sha.h>
#include <search.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

enum { FILE_OBJ, END_OBJ, ITEM_OBJ };
typedef struct { int kind; size_t len; char child[65], rest[65]; } Obj;

static void hex(const unsigned char *raw, size_t n, char out[65]) {
  unsigned char md[32];
  SHA256(raw, n, md);
  for (int i = 0; i < 32; i++) sprintf(out + 2 * i, "%02x", md[i]);
}

static void put(const unsigned char *raw, size_t n, Obj o, char out[65]) {
  hex(raw, n, out);
  ENTRY e = {.key = out, .data = NULL};
  if (hsearch(e, FIND)) return;
  Obj *heap = malloc(sizeof(Obj));
  *heap = o;
  e.key = strdup(out);
  e.data = heap;
  hsearch(e, ENTER);
}

// names[i] and digests[i] for i < n; the listing's digest goes to out.
static void listing(int n, char names[][8], char digests[][65], char out[65]) {
  char rest[65], line[256];
  put((const unsigned char *)"end\n", 4, (Obj){.kind = END_OBJ}, rest);
  for (int i = n - 1; i >= 0; i--) {
    int len = snprintf(line, sizeof line, "item %s %s %s\n", digests[i], rest, names[i]);
    Obj o = {.kind = ITEM_OBJ};
    memcpy(o.child, digests[i], 65);
    memcpy(o.rest, rest, 65);
    put((unsigned char *)line, (size_t)len, o, rest);
  }
  memcpy(out, rest, 65);
}

static size_t load(const char *d) {
  ENTRY e = {.key = (char *)d}, *hit = hsearch(e, FIND);
  Obj *o = hit->data;
  if (o->kind == FILE_OBJ) return o->len;
  if (o->kind == END_OBJ) return 0;
  return load(o->child) + load(o->rest);
}

int main(int argc, char **argv) {
  int k = argc > 1 ? atoi(argv[1]) : 16;
  hcreate((size_t)k * k * 4 + 64);
  unsigned char *data = malloc((size_t)k * k * 4096);
  for (int d = 0; d < k; d++)
    for (int f = 0; f < k; f++)
      for (int j = 0; j < 4096; j++) data[((size_t)d * k + f) * 4096 + j] = (unsigned char)((d * 31 + f * 7 + j) & 255);
  char (*names)[8] = malloc((size_t)k * 8), (*digests)[65] = malloc((size_t)k * 65);
  char (*top)[65] = malloc((size_t)k * 65), (*dnames)[8] = malloc((size_t)k * 8), root[65];
  unsigned char *raw = malloc(4096 + 32);
  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);
  for (int d = 0; d < k; d++) {
    for (int f = 0; f < k; f++) {
      int h = snprintf((char *)raw, 32, "file %d\n", 4096);
      memcpy(raw + h, data + ((size_t)d * k + f) * 4096, 4096);
      snprintf(names[f], 8, "f%02d", f);
      put(raw, (size_t)h + 4096, (Obj){.kind = FILE_OBJ, .len = 4096}, digests[f]);
    }
    snprintf(dnames[d], 8, "d%02d", d);
    listing(k, names, digests, top[d]);
  }
  listing(k, dnames, top, root);
  size_t n = load(root);
  clock_gettime(CLOCK_MONOTONIC, &t1);
  double ms = (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6;
  printf("commit\t%.3f\t%s\t%zu\n", ms, root, n);
  return 0;
}
