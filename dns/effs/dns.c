// DNS
// ===
// OS resolver for dns/dns.bend lookup effect.

#ifndef DNS_EFFS
#define DNS_EFFS

#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <stdlib.h>
#include <string.h>

static u32 dns_gai_code(int gai) {
  switch (gai) {
    case EAI_NONAME:
    case EAI_NODATA:
      return ENOENT;
    case EAI_AGAIN:
      return EAGAIN;
    case EAI_MEMORY:
      return ENOMEM;
    default:
      return EIO;
  }
}

static void dns_addrs_grow(char** buf, u64* cap, u64 need) {
  if (need <= *cap) {
    return;
  }
  u64 ncap = *cap ? *cap : 64;
  while (ncap < need) {
    ncap *= 2;
  }
  *buf = io_mem(realloc(*buf, ncap));
  *cap = ncap;
}

static void dns_addrs_push(char** buf, u64* len, u64* cap, const char* ip) {
  u64 n = strlen(ip);
  u64 need = *len + (*len ? 1 : 0) + n;
  dns_addrs_grow(buf, cap, need);
  if (*len != 0) {
    (*buf)[(*len)++] = '\0';
  }
  memcpy(*buf + *len, ip, n);
  *len += n;
}

#endif

#ifdef CID(lookup.all)

static void dns_lookup_all_call(IoWork* w) {
  struct addrinfo  hints = { 0 };
  struct addrinfo* res   = NULL;
  hints.ai_family        = AF_UNSPEC;
  hints.ai_socktype      = SOCK_STREAM;
  int gai = getaddrinfo((char*)w->data, NULL, &hints, &res);
  if (gai != 0) {
    w->code = dns_gai_code(gai);
    w->text = NULL;
    return;
  }
  char* buf = NULL;
  u64   len = 0;
  u64   cap = 0;
  for (struct addrinfo* ai = res; ai != NULL; ai = ai->ai_next) {
    if (ai->ai_family == AF_INET) {
      char                ip[INET_ADDRSTRLEN];
      struct sockaddr_in* in = (struct sockaddr_in*)ai->ai_addr;
      inet_ntop(AF_INET, &in->sin_addr, ip, sizeof(ip));
      dns_addrs_push(&buf, &len, &cap, ip);
    } else if (ai->ai_family == AF_INET6) {
      char                 ip[INET6_ADDRSTRLEN];
      struct sockaddr_in6* in6 = (struct sockaddr_in6*)ai->ai_addr;
      inet_ntop(AF_INET6, &in6->sin6_addr, ip, sizeof(ip));
      dns_addrs_push(&buf, &len, &cap, ip);
    }
  }
  freeaddrinfo(res);
  if (len == 0) {
    free(buf);
    w->code = ENOENT;
    w->text = NULL;
    return;
  }
  w->text = buf;
  w->size = len;
  w->code = 0;
}

static Term dns_lookup_all_pack(Env e, IoWork* w) {
  free(w->data);
  if (w->code != 0) {
    free(w->text);
    return io_fail(e, w->code, NULL);
  }
  Term r = io_done(e, io_str(e, w->text, w->size));
  free(w->text);
  return r;
}

Term lookup_all_run(Env e, Term* f, IoWork* w) {
  w->data = io_cstr(e, f[0], &w->size);
  if (w->data == NULL || io_nul(w->data, w->size)) {
    free(w->data);
    w->data = NULL;
    return io_fail(e, EINVAL, NULL);
  }
  return io_work(w, dns_lookup_all_call, dns_lookup_all_pack);
}

static void __attribute__((constructor)) dns_lookup_all_use(void) {
  io_eff(CID(lookup.all), lookup_all_run);
}

#endif
