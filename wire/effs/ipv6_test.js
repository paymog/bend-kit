function test_bound(fd) {
  const sys = io_sys();
  const ffi = require("bun:ffi");
  const libc = ffi.dlopen(sys.mac ? "libSystem.dylib" : "libc.so.6", {
    getsockname: { args: ["i32", "ptr", "ptr"], returns: "i32" },
  }).symbols;
  const addr = new Uint8Array(28);
  const len = new Uint32Array([addr.length]);
  if (libc.getsockname(fd, ffi.ptr(addr), ffi.ptr(len)) !== 0) {
    const code = sys.errno();
    sys.close(fd);
    return io_fail(code);
  }
  return io_done(io_tup(fd, (addr[2] << 8) | addr[3]));
}

function test_addr6(port) {
  const sys = io_sys();
  const family = sys.mac ? 30 : 10;
  const addr = new Uint8Array(28);
  if (sys.mac) { addr[0] = 28; addr[1] = family; } else { addr[0] = family; }
  addr[2] = (Number(port) >> 8) & 255;
  addr[3] = Number(port) & 255;
  addr[23] = 1;
  return addr;
}

function test_listen6(port) {
  const sys = io_sys();
  const fd = sys.socket(sys.mac ? 30 : 10, 1, 0);
  if (fd < 0) return io_fail(sys.errno());
  const addr = test_addr6(port);
  const on = new Int32Array([1]);
  sys.setsockopt(fd, sys.mac ? 0xffff : 1, 2, sys.ptr(on), 4);
  if (sys.bind(fd, sys.ptr(addr), addr.length) !== 0 || sys.listen(fd, 4) !== 0) {
    const code = sys.errno();
    sys.close(fd);
    return io_fail(code);
  }
  return test_bound(fd);
}
io_eff(CID(test.listen6), test_listen6);

function test_udp6(port) {
  const sys = io_sys();
  const fd = sys.socket(sys.mac ? 30 : 10, 2, 0);
  if (fd < 0) return io_fail(sys.errno());
  const addr = test_addr6(port);
  if (sys.bind(fd, sys.ptr(addr), addr.length) !== 0) {
    const code = sys.errno();
    sys.close(fd);
    return io_fail(code);
  }
  return test_bound(fd);
}
io_eff(CID(test.udp6), test_udp6);
