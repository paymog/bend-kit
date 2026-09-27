// One-shot ::1 TCP listener for wire/check.bend.
#ifdef CID(ipv6.serve)
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
Term ipv6_serve_run(Env e, Term* f, IoWork* w) {
  u16 port = (u16)(u32)f[0];
  int ls   = socket(AF_INET6, SOCK_STREAM, 0);
  if (ls < 0) return io_fail(e, (u32)errno, NULL);
  int on = 1;
  setsockopt(ls, IPPROTO_IPV6, IPV6_V6ONLY, &on, sizeof(on));
  setsockopt(ls, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));
  struct sockaddr_in6 addr = { 0 };
  addr.sin6_family = AF_INET6;
  addr.sin6_port = htons(port);
  addr.sin6_addr = in6addr_loopback;
  if (bind(ls, (struct sockaddr*)&addr, sizeof(addr)) != 0 || listen(ls, 1) != 0) {
    close(ls); return io_fail(e, (u32)errno, NULL);
  }
  int cs = accept(ls, NULL, NULL);
  close(ls);
  if (cs < 0) return io_fail(e, (u32)errno, NULL);
  const char msg[] = "ok";
  ssize_t n = send(cs, msg, 2, 0);
  close(cs);
  if (n != 2) return io_fail(e, n < 0 ? (u32)errno : EIO, NULL);
  return term_pak(CID(Unit), 0);
}
static void __attribute__((constructor)) ipv6_serve_use(void) { io_eff(CID(ipv6.serve), ipv6_serve_run, 0); }
#endif
