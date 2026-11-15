#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
struct task { uint32_t deadline, id; };
static int compare(const void *a, const void *b) {
    const struct task *x = a, *y = b;
    if (x->deadline != y->deadline) return x->deadline < y->deadline ? -1 : 1;
    return (x->id > y->id) - (x->id < y->id);
}
int main(void) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    struct task queue[1024];
    for (uint32_t i = 0; i < 1024; ++i) queue[i] = (struct task){(i * 37) % 64, i};
    qsort(queue, 1024, sizeof(queue[0]), compare);
    uint32_t checksum = 0;
    for (unsigned i = 0; i < 1024; ++i) checksum = checksum * 31 + queue[i].id;
    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.6f\t%u\n", ms, checksum);
}
