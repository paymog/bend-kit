let storageCoordination;
function disk_lock(path, exclusive) {
  if (path.includes("\0")) return io_fail(22);
  const fs = require("node:fs");
  if (!storageCoordination) {
    const ffi = require("bun:ffi");
    storageCoordination = ffi.dlopen(process.platform === "darwin" ? "libSystem.B.dylib" : "libc.so.6", {
      flock: {args: ["i32", "i32"], returns: "i32"},
      fcntl: {args: ["i32", "i32", "i32"], returns: "i32"},
    });
  }
  let fd;
  try {
    fd = fs.openSync(path, fs.constants.O_RDONLY | fs.constants.O_DIRECTORY | fs.constants.O_CLOEXEC);
    if (storageCoordination.symbols.fcntl(fd, 2, 1) < 0 ||
        storageCoordination.symbols.flock(fd, (exclusive === 2 ? 2 : 1) | 4) < 0) {
      const code = io_sys().errno();
      fs.closeSync(fd);
      return {$: CID(Fail), error: io_tup(code, "storage: store coordination lock unavailable")};
    }
    return io_done(fd);
  } catch (error) {
    if (fd !== undefined) fs.closeSync(fd);
    return io_fail(Math.abs(error.errno || 5));
  }
}
io_eff(CID(Disk.lock), disk_lock);
