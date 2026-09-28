// A local IPv6 listener for check.bend; the client connects before accept.
#if defined(CID(test.listen6)) || defined(CID(test.udp6))
static Term test_bound(Env e, int fd) {
  struct sockaddr_in6 a = { 0 };
  socklen_t len = sizeof(a);
  if (getsockname(fd, (struct sockaddr*)&a, &len) != 0) {
    int code = errno;
    close(fd);
    return io_fail(e, code, NULL);
  }
  return io_done(e, io_tup(e, io_hand(fd), (Term)ntohs(a.sin6_port)));
}
#endif

#ifdef CID(test.listen6)
Term test_listen6_run(Env e, Term* f, IoWork* w) {
  int fd = socket(AF_INET6, SOCK_STREAM, 0);
  if (fd < 0) return io_fail(e, errno, NULL);
  struct sockaddr_in6 a = { 0 };
  a.sin6_family = AF_INET6;
  a.sin6_port = 0;
  a.sin6_addr = in6addr_loopback;
  int on = 1;
  setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));
  if (bind(fd, (struct sockaddr*)&a, sizeof(a)) != 0 || listen(fd, 4) != 0) {
    int code = errno;
    close(fd);
    return io_fail(e, code, NULL);
  }
  return test_bound(e, fd);
}
static void __attribute__((constructor)) test_listen6_use(void) {
  io_eff(CID(test.listen6), test_listen6_run, 0);
}
#endif

#ifdef CID(test.udp6)
Term test_udp6_run(Env e, Term* f, IoWork* w) {
  int fd = socket(AF_INET6, SOCK_DGRAM, 0);
  if (fd < 0) return io_fail(e, errno, NULL);
  struct sockaddr_in6 a = { 0 };
  a.sin6_family = AF_INET6;
  a.sin6_port = 0;
  a.sin6_addr = in6addr_loopback;
  if (bind(fd, (struct sockaddr*)&a, sizeof(a)) != 0) {
    int code = errno;
    close(fd);
    return io_fail(e, code, NULL);
  }
  return test_bound(e, fd);
}
static void __attribute__((constructor)) test_udp6_use(void) {
  io_eff(CID(test.udp6), test_udp6_run, 0);
}
#endif
