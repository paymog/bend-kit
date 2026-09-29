// IP address benchmark in C with inet_pton/inet_ntop (see README.md). No DNS: inet_pton only reads literals.
#include <arpa/inet.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>

#define ROUNDS 10000
#define N(a) (sizeof(a) / sizeof *(a))

static const char *ADDRS[] = {
    "0.0.0.0",
    "127.0.0.1",
    "192.168.1.254",
    "255.255.255.255",
    "10.0.0.1",
    "::",
    "::1",
    "2001:db8::1",
    "2001:DB8:0:0:0:0:0:1",
    "2001:0db8:0000:0000:0001:0000:0000:0001",
    "fe80::1:2:3:4",
    "1:0:0:2:0:0:0:3",
    "1:2:3:4:5:6:7:8",
    "1::",
    "2001:db8:0:1:1:1:1:1",
    "::ffff:192.0.2.128",
    "::ffff:c000:280",
    "64:ff9b::192.0.2.33",
    "ff02::fb",
    "2001:db8:85a3::8a2e:370:7334",
    "",
    "1.2.3",
    "1.2.3.4.5",
    "256.1.1.1",
    "01.2.3.4",
    "1.2.3.4 ",
    "1.2.3.\xd9\xa4",
    "1.2.3.4:80",
    "1:2:3:4:5:6:7",
    "1:2:3:4:5:6:7:8:9",
    "1:2:3:4:5:6:7::8",
    "1::2::3",
    "12345::",
    "1:2:3:4:5:6:7:",
    ":1:2:3:4:5:6:7",
    "[::1]",
    "fe80::1%en0",
    "::ffff:1.2.3",
    "1.2.3.4::1",
    "1:2:3:4:5:6:7:8::",
};

static const char *PREFIXES[] = {
    "10.0.0.0/8",
    "192.168.0.0/16",
    "192.168.1.0/24",
    "0.0.0.0/0",
    "203.0.113.7/32",
    "2001:db8::/32",
    "fe80::/10",
    "::/0",
    "::1/128",
    "2001:db8:85a3::/48",
    "10.0.0.0/33",
    "2001:db8::/129",
    "10.0.0.0/",
    "/8",
    "10.0.0.0/8/8",
    "10.0.0.0/-1",
};

static const char *PROBES[] = {
    "10.1.2.3",
    "11.0.0.1",
    "192.168.1.77",
    "192.168.2.1",
    "203.0.113.7",
    "203.0.113.8",
    "8.8.8.8",
    "2001:db8::1",
    "2001:db8:85a3::8a2e:370:7334",
    "2001:db9::1",
    "fe80::1",
    "febf:ffff::1",
    "fec0::1",
    "::1",
    "::",
};

typedef struct {
  unsigned char a[16];
  int fam;
} addr;

typedef struct {
  addr ip;
  int bits;
} prefix;

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

static int parse(const char *s, addr *out) {
  if (strchr(s, '%')) return 0;
  if (inet_pton(AF_INET, s, out->a) == 1) {
    // Darwin's inet_pton accepts leading-zero octets; the other variants reject them.
    for (const char *p = s; p && *p; p = strchr(p, '.')) {
      if (*p == '.') p++;
      if (*p == '0' && p[1] >= '0' && p[1] <= '9') return 0;
    }
    return out->fam = AF_INET, 1;
  }
  if (inet_pton(AF_INET6, s, out->a) == 1) return out->fam = AF_INET6, 1;
  return 0;
}

// Address before one '/', then 1-3 decimal digits with no leading zero, at most the family's width.
static int prefix_parse(const char *s, prefix *p) {
  const char *slash = strchr(s, '/');
  if (!slash || slash - s >= 64) return 0;
  char head[64];
  memcpy(head, s, slash - s);
  head[slash - s] = 0;
  if (!parse(head, &p->ip)) return 0;
  const char *d = slash + 1;
  size_t n = strlen(d);
  if (n == 0 || n > 3 || (n > 1 && d[0] == '0')) return 0;
  int bits = 0;
  for (size_t i = 0; i < n; i++) {
    if (d[i] < '0' || d[i] > '9') return 0;
    bits = bits * 10 + (d[i] - '0');
  }
  if (bits > (p->ip.fam == AF_INET ? 32 : 128)) return 0;
  p->bits = bits;
  return 1;
}

static int contains(const prefix *p, const addr *x) {
  if (p->ip.fam != x->fam) return 0;
  int full = p->bits / 8, rem = p->bits % 8;
  if (memcmp(p->ip.a, x->a, full)) return 0;
  return !rem || ((p->ip.a[full] ^ x->a[full]) & (0xFF00 >> rem) & 0xFF) == 0;
}

static uint32_t addr_rounds(void) {
  uint32_t h = 0;
  char buf[INET6_ADDRSTRLEN];
  for (int r = 0; r < ROUNDS; r++)
    for (size_t i = 0; i < N(ADDRS); i++) {
      addr a;
      if (!parse(ADDRS[i], &a)) {
        h = h * 31 + 1;
        continue;
      }
      h = h * 31 + 2;
      for (const char *c = inet_ntop(a.fam, a.a, buf, sizeof buf); *c; c++) h = h * 31 + (unsigned char)*c;
    }
  return h;
}

static uint32_t cidr_rounds(void) {
  uint32_t h = 0;
  addr ps[N(PROBES)];
  for (int r = 0; r < ROUNDS; r++) {
    size_t np = 0;
    for (size_t i = 0; i < N(PROBES); i++) np += parse(PROBES[i], &ps[np]);
    for (size_t i = 0; i < N(PREFIXES); i++) {
      prefix p;
      if (!prefix_parse(PREFIXES[i], &p)) {
        h *= 3;
        continue;
      }
      for (size_t j = 0; j < np; j++) h = h * 3 + (contains(&p, &ps[j]) ? 2 : 1);
    }
  }
  return h;
}

int main(void) {
  double t0 = now_ms();
  uint32_t h = addr_rounds();
  printf("addr\t%.3f\t%u\n", now_ms() - t0, h);
  t0 = now_ms();
  h = cidr_rounds();
  printf("cidr\t%.3f\t%u\n", now_ms() - t0, h);
  return 0;
}
