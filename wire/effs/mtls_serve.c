// One-shot TLS listener with mandatory client certs for wire/check.bend.
#ifdef CID(mtls.serve)
#include <errno.h>
#include <stdio.h>
#include <unistd.h>

Term mtls_serve_run(Env e, Term* f, IoWork* w) {
  u16 port = (u16)(u32)f[0];
  char portstr[16];
  snprintf(portstr, sizeof(portstr), "%u", (unsigned)port);
  execlp("openssl", "openssl", "s_server",
    "-accept", portstr,
    "-Verify", "1",
    "-CAfile", "test/mtls/ca.pem",
    "-cert", "test/mtls/server.pem",
    "-key", "test/mtls/server.key",
    "-naccept", "1",
    "-quiet",
    NULL);
  return io_fail(e, (u32)errno, "openssl s_server failed");
}

static void __attribute__((constructor)) mtls_serve_use(void) {
  io_eff(CID(mtls.serve), mtls_serve_run, 0);
}
#endif
