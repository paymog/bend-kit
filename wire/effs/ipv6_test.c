// An IPv6 loopback UDP socket on an OS-picked port for check.bend.
#ifdef CID(test.udp6)
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
  io_eff(CID(test.udp6), test_udp6_run);
}
#endif
