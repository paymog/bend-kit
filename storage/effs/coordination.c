#ifdef CID(Disk.lock)
#ifndef STORAGE_COORDINATION_EFF
#define STORAGE_COORDINATION_EFF
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>

static Term disk_lock_run(Env e, Term* f, IoWork* w) {
  u64 n;
  char* path = io_cstr(e, f[0], &n);
  if (!path || io_nul(path, n)) {
    free(path);
    return io_fail(e, EINVAL, NULL);
  }
  int fd = open(path, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
  free(path);
  if (fd < 0) return io_fail(e, errno, NULL);
  int mode = (u32)f[1] == 2 ? LOCK_EX : LOCK_SH;
  if (flock(fd, mode | LOCK_NB) < 0) {
    int code = errno;
    close(fd);
    return io_fail(e, code, "storage: store coordination lock unavailable");
  }
  return io_done(e, io_hand(fd));
}

static void __attribute__((constructor)) disk_lock_use(void) {
  io_eff(CID(Disk.lock), disk_lock_run);
}
#endif
#endif
