#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>

static double now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
}

static size_t n, b1, b2;
static unsigned shift;
static uint32_t reads;
static uint8_t *b, *copy;

static uint8_t *allocate(size_t size) {
    uint8_t *p = malloc(size);
    if (!p) exit(1);
    return p;
}

static uint32_t fill_buf(uint8_t *out) {
    for (size_t i = 0; i < n; i++) out[i] = (uint8_t)((i * 31 + 7) & 255);
    memcpy(out + n - 4, "\r\n\r\n", 4);
    return (uint32_t)out[12345 % n] + out[n - 1];
}

static uint32_t fill(void) {
    uint8_t *out = allocate(n);
    uint32_t cs = fill_buf(out);
    __asm__ volatile("" : : "r"(out) : "memory");
    free(out);
    return cs;
}

static uint32_t sum(void) {
    uint32_t cs = 0;
    for (size_t i = 0; i < n; i++) cs += b[i];
    return cs;
}

static uint32_t find(void) {
    void *p = memmem(b, n, "\r\n\r\n", 4);
    return p ? (uint32_t)((uint8_t *)p - b) : UINT32_MAX;
}

static uint32_t slice(void) {
    uint8_t *out = allocate(n / 2);
    memcpy(out, b + n / 4 + 1, n / 2);
    __asm__ volatile("" : : "r"(out) : "memory");
    uint32_t cs = (uint32_t)out[0] + out[n / 2 - 1];
    free(out);
    return cs;
}

static uint32_t concat(void) {
    uint8_t *out = NULL;
    size_t len = 0, cap = 0, chunk = n < 65536 ? n : 65536;
    for (size_t k = 0; k < n / chunk; k++) {
        if (len + chunk > cap) {
            cap = cap ? cap * 2 : chunk;
            uint8_t *grown = realloc(out, cap);
            if (!grown) { free(out); exit(1); }
            out = grown;
        }
        memset(out + len, (uint8_t)(k & 255), chunk);
        len += chunk;
    }
    if (len != n) exit(1);
    __asm__ volatile("" : : "r"(out) : "memory");
    uint32_t cs = (uint32_t)out[0] + out[len - 1];
    free(out);
    return cs;
}

static uint32_t random_reads(void) {
    uint32_t x = 1, acc = 0;
    for (uint32_t i = 0; i < reads; i++) {
        x = x * 1664525u + 1013904223u;
        acc += b[x >> shift];
    }
    return acc;
}

static uint32_t equal(void) { return memcmp(b, copy, n) == 0; }

static uint32_t build(size_t size) {
    uint8_t *out = NULL;
    size_t len = 0, cap = 0;
    for (size_t i = 0; i < size; i++) {
        if (len == cap) {
            cap = cap ? cap * 2 : 1;
            uint8_t *grown = realloc(out, cap);
            if (!grown) { free(out); exit(1); }
            out = grown;
        }
        out[len++] = (uint8_t)(i & 255);
    }
    __asm__ volatile("" : : "r"(out) : "memory");
    uint32_t cs = (uint32_t)size + out[len - 1];
    free(out);
    return cs;
}
static uint32_t build1(void) { return build(b1); }
static uint32_t build2(void) { return build(b2); }

static void measure(const char *name, uint32_t (*operation)(void)) {
    const char *raw = getenv("BYTES_BENCH_COUNT"), *warm = getenv("BYTES_BENCH_WARMUP");
    uint32_t count = raw ? strtoul(raw, NULL, 10) : 1;
    uint32_t warmup = warm ? strtoul(warm, NULL, 10) : 0;
    if (!count) exit(1);
    uint32_t last = 0, total = 0;
    for (uint32_t i = 0; i < warmup; i++) {
        last = operation();
        __asm__ volatile("" : "+r"(last) : : "memory");
    }
    double t0 = now_ms();
    for (uint32_t i = 0; i < count; i++) {
        __asm__ volatile("" : : : "memory");
        last = operation();
        total += last;
    }
    double ms = now_ms() - t0;
    printf("%s\t%.6f\t%u\t%u\t%u\n", name, ms, last, count, total);
}

int main(int argc, char **argv) {
    unsigned lg = argc > 1 ? atoi(argv[1]) : 28;
    n = (size_t)1 << lg;
    shift = 32 - lg;
    reads = argc > 2 ? strtoul(argv[2], NULL, 10) : 1u << 24;
    b1 = argc > 3 ? strtoul(argv[3], NULL, 10) : 1000000;
    b2 = argc > 4 ? strtoul(argv[4], NULL, 10) : 4000000;
    measure("fill", fill);
    b = allocate(n);
    fill_buf(b);
    measure("sum", sum);
    measure("find", find);
    measure("slice", slice);
    measure("concat", concat);
    measure("random", random_reads);
    copy = allocate(n);
    memcpy(copy, b, n);
    measure("equal", equal);
    char name[64];
    snprintf(name, sizeof(name), "build_%zu", b1);
    measure(name, build1);
    snprintf(name, sizeof(name), "build_%zu", b2);
    measure(name, build2);
    free(copy);
    free(b);
    return 0;
}
