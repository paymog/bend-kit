#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define N (1u << 22)

static double now_ms(void) {
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
}

static uint32_t ends(const float *x) { return (uint32_t)(x[N - 1] + x[12345]); }

int main(void) {
	float *src = malloc(N * sizeof(float)), *b = malloc(N * sizeof(float));
	for (uint32_t i = 0; i < N; i++) {
		src[i] = (float)((i + 3) & 3);
		b[i] = (float)((i * 5 + 3) & 3);
	}
	uint8_t *bytes = malloc(N * 4);
	memcpy(bytes, src, N * 4); /* little-endian host */

	double t = now_ms();
	float *a = malloc(N * sizeof(float));
	memcpy(a, bytes, N * 4);
	printf("from_bytes\t%.6f\t%u\n", now_ms() - t, ends(a));

	t = now_ms();
	float s = 0;
	for (uint32_t i = 0; i < N; i++) s += a[i];
	printf("sum\t%.6f\t%u\n", now_ms() - t, (uint32_t)s);

	t = now_ms();
	float m = a[0];
	for (uint32_t i = 1; i < N; i++) m = a[i] > m ? a[i] : m;
	printf("max\t%.6f\t%u\n", now_ms() - t, (uint32_t)m);

	t = now_ms();
	float d = 0;
	for (uint32_t i = 0; i < N; i++) d += a[i] * b[i];
	printf("dot\t%.6f\t%u\n", now_ms() - t, (uint32_t)d);

	t = now_ms();
	for (uint32_t i = 0; i < N; i++) a[i] *= 2.0f;
	printf("map\t%.6f\t%u\n", now_ms() - t, ends(a));

	t = now_ms();
	for (uint32_t i = 0; i < N; i++) a[i] += b[i];
	printf("add\t%.6f\t%u\n", now_ms() - t, ends(a));

	t = now_ms();
	uint8_t *out = malloc(N * 4);
	memcpy(out, a, N * 4);
	printf("to_bytes\t%.6f\t%u\n", now_ms() - t, (uint32_t)(N * 4) + out[N * 4 - 1]);
	return 0;
}
