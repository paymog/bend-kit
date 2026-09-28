// RESP decode benchmark in C with hiredis (see README.md).
#include <hiredis/hiredis.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

#define M(h, x) ((h) = (h) * 31u + (uint32_t)(x))

// The pre-order checksum in run.py.
static uint32_t walk(redisReply *r, uint32_t h) {
  switch (r->type) {
  case REDIS_REPLY_STATUS:
  case REDIS_REPLY_STRING:
    M(h, 1);
    M(h, r->len);
    for (size_t i = 0; i < r->len; i++) M(h, (unsigned char)r->str[i]);
    return h;
  case REDIS_REPLY_INTEGER:
    M(h, 2);
    return M(h, (uint32_t)(uint64_t)r->integer);
  case REDIS_REPLY_NIL:
    return M(h, 3);
  case REDIS_REPLY_BOOL:
    M(h, 8);
    return M(h, r->integer ? 1 : 0);
  case REDIS_REPLY_ARRAY:
    M(h, 4);
    for (size_t i = 0; i < r->elements; i++) h = walk(r->element[i], h);
    return M(h, 5);
  case REDIS_REPLY_MAP:
    M(h, 6);
    for (size_t i = 0; i < r->elements; i++) h = walk(r->element[i], h);
    return M(h, 7);
  default:
    exit(4);
  }
}

int main(void) {
  FILE *f = fopen("out/replies.resp", "rb");
  if (!f) return 1;
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  rewind(f);
  char *data = malloc(n);
  if (fread(data, 1, n, f) != (size_t)n) return 1;
  fclose(f);

  size_t cap = 1 << 16, count = 0;
  void **replies = malloc(cap * sizeof *replies);
  double t0 = now_ms();
  redisReader *reader = redisReaderCreate();
  void *reply;
  // 64 KiB at a time, as a socket delivers it: hiredis moves its unread bytes down after each 1 KiB read.
  for (long at = 0; at < n; at += 65536) {
    if (redisReaderFeed(reader, data + at, n - at < 65536 ? n - at : 65536) != REDIS_OK) return 2;
    for (;;) {
      if (redisReaderGetReply(reader, &reply) != REDIS_OK) return 3;
      if (!reply) break;
      if (count == cap) replies = realloc(replies, (cap *= 2) * sizeof *replies);
      replies[count++] = reply;
    }
  }
  double t1 = now_ms();

  uint32_t h = 0;
  for (size_t i = 0; i < count; i++) h = walk(replies[i], h);
  h += (uint32_t)count;
  printf("decode\t%.3f\t%u\n", t1 - t0, h);
  for (size_t i = 0; i < count; i++) freeReplyObject(replies[i]);
  redisReaderFree(reader);
  free(replies);
  free(data);
  return 0;
}
