// Concurrency benchmark: one CPU-bound job over 64 inputs, on 1 and 8 pthreads (see README.md).
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <time.h>

#define N 64
#define ROUNDS (1u << 20)

static uint32_t in[N], out[N];

static uint32_t job(uint32_t x) {
  for (uint32_t i = 0; i < ROUNDS; i++) x = (x ^ (x >> 13)) * 1664525u + 1013904223u;
  return x;
}

typedef struct { int lo, hi; } Part;

static void *run(void *p) {
  Part *part = p;
  for (int i = part->lo; i < part->hi; i++) out[i] = job(in[i]);
  return NULL;
}

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

static void op(const char *name, int workers) {
  pthread_t th[N];
  Part parts[N];
  double t0 = now_ms();
  for (int w = 0; w < workers; w++) {
    parts[w] = (Part){ N * w / workers, N * (w + 1) / workers };
    pthread_create(&th[w], NULL, run, &parts[w]);
  }
  for (int w = 0; w < workers; w++) pthread_join(th[w], NULL);
  double t1 = now_ms();
  uint32_t h = 0;
  for (int i = 0; i < N; i++) h = h * 31u + out[i];
  printf("%s\t%.1f\t%u\n", name, t1 - t0, h);
}

int main(void) {
  for (int i = 0; i < N; i++) in[i] = (uint32_t)i;
  op("map_1", 1);
  op("map_8", 8);
  return 0;
}
