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

static uint32_t fill_buf(uint8_t *b, size_t n) {
	for (size_t i = 0; i < n; i++)
		b[i] = (uint8_t)((i * 31 + 7) & 255);
	b[n - 4] = 13;
	b[n - 3] = 10;
	b[n - 2] = 13;
	b[n - 1] = 10;
	return (uint32_t)b[12345] + (uint32_t)b[n - 1];
}

static int build(size_t n) {
	uint8_t *out = NULL;
	size_t len = 0, cap = 0;
	double t0 = now_ms();
	for (size_t i = 0; i < n; i++) {
		if (len == cap) {
			size_t next = cap ? cap * 2 : 1;
			uint8_t *grown = realloc(out, next);
			if (!grown) { free(out); return 1; }
			out = grown;
			cap = next;
		}
		out[len++] = (uint8_t)(i & 255);
	}
	uint32_t cs = (uint32_t)n + out[len - 1];
	printf("build_%zu\t%.6f\t%u\n", n, now_ms() - t0, cs);
	free(out);
	return 0;
}

int main(int argc, char **argv) {
	int L = 28;
	if (argc > 1)
		L = atoi(argv[1]);
	size_t n = (size_t)1 << L;
	uint32_t reads = argc > 2 ? strtoul(argv[2], NULL, 10) : 1u << 24;
	size_t b1 = argc > 3 ? strtoul(argv[3], NULL, 10) : 1000000;
	size_t b2 = argc > 4 ? strtoul(argv[4], NULL, 10) : 4000000;

	double t0, t1;
	uint32_t cs;

	t0 = now_ms();
	uint8_t *b = malloc(n);
	if (!b) return 1;
	cs = fill_buf(b, n);
	t1 = now_ms();
	printf("fill\t%.6f\t%u\n", t1 - t0, cs);

	t0 = now_ms();
	uint32_t sum = 0;
	for (size_t i = 0; i < n; i++)
		sum += b[i];
	t1 = now_ms();
	printf("sum\t%.6f\t%u\n", t1 - t0, sum);

	static const uint8_t needle[] = {13, 10, 13, 10};
	t0 = now_ms();
	void *p = memmem(b, n, needle, 4);
	t1 = now_ms();
	size_t find_idx = p ? (size_t)((uint8_t *)p - b) : (size_t)-1;
	printf("find\t%.6f\t%u\n", t1 - t0, (uint32_t)find_idx);

	size_t slice_start = n / 4 + 1;
	size_t slice_len = n / 2;
	t0 = now_ms();
	uint8_t *s = malloc(slice_len);
	memcpy(s, b + slice_start, slice_len);
	cs = (uint32_t)s[0] + (uint32_t)s[slice_len - 1];
	t1 = now_ms();
	printf("slice\t%.6f\t%u\n", t1 - t0, cs);
	free(s);

	t0 = now_ms();
	uint8_t *out = NULL;
	size_t out_len = 0;
	size_t out_cap = 0;
	size_t chunks = n / 65536;
	for (size_t k = 0; k < chunks; k++) {
		if (out_len + 65536 > out_cap) {
			size_t new_cap = out_cap ? out_cap * 2 : 65536;
			while (new_cap < out_len + 65536)
				new_cap *= 2;
			uint8_t *tmp = realloc(out, new_cap);
			if (!tmp) return 1;
			out = tmp;
			out_cap = new_cap;
		}
		uint8_t byte = (uint8_t)(k & 255);
		memset(out + out_len, byte, 65536);
		out_len += 65536;
	}
	t1 = now_ms();
	if (out_len != n)
		return 1;
	cs = (uint32_t)out[0] + (uint32_t)out[out_len - 1];
	printf("concat\t%.6f\t%u\n", t1 - t0, cs);
	free(out);

	uint32_t x = 1, acc = 0;
	unsigned shift = 32 - (unsigned)L;
	t0 = now_ms();
	for (uint32_t i = 0; i < reads; i++) {
		x = x * 1664525u + 1013904223u;
		uint32_t idx = x >> shift;
		acc += b[idx];
	}
	t1 = now_ms();
	printf("random\t%.6f\t%u\n", t1 - t0, acc);

	uint8_t *c = malloc(n);
	memcpy(c, b, n);
	t0 = now_ms();
	int eq = memcmp(b, c, n) == 0;
	t1 = now_ms();
	printf("equal\t%.6f\t%u\n", t1 - t0, eq ? 1u : 0u);

	if (build(b1) || build(b2))
		return 1;

	free(c);
	free(b);
	return 0;
}
