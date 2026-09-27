// Random
// ======
// OS entropy for random/random.bend.

#ifndef RANDOM_EFFS
#define RANDOM_EFFS

#include <errno.h>
#include <stdint.h>
#include <unistd.h>
#if defined(__APPLE__)
#include <sys/random.h>
#endif

#ifdef CID(entropy)

Term entropy_run(Env e, Term* f, IoWork* w) {
  uint32_t s[4];
  if (getentropy(s, sizeof s) != 0) {
    return io_fail(e, errno, NULL);
  }
  return io_done(e, io_tup(e, (Term)s[0],
    io_tup(e, (Term)s[1], io_tup(e, (Term)s[2], (Term)s[3]))));
}

static void __attribute__((constructor)) entropy_use(void) {
  io_eff(CID(entropy), entropy_run, 0);
}

#endif

#endif
