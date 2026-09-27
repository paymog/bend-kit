function ipv6_serve(port, k) {
  const sys = io_sys();
  const fam = sys.mac ? 30 : 10;
  const ls = sys.socket(fam, 1, 0);
  if (ls < 0) return io_fail(sys.errno());
  const on = new Int32Array([1]);
  sys.setsockopt(ls, 41, 27, sys.ptr(on), 4);
  sys.setsockopt(ls, sys.mac ? 0xffff : 1, 2, sys.ptr(on), 4);
  const addr = new Uint8Array(28);
  if (sys.mac) { addr[0] = 28; addr[1] = 30; } else { addr[0] = 10; addr[1] = 0; }
  const p = Number(port) & 0xffff;
  addr[2] = (p >> 8) & 255; addr[3] = p & 255; addr[23] = 1;
  if (sys.bind(ls, sys.ptr(addr), addr.length) < 0 || sys.listen(ls, 1) < 0) { sys.close(ls); return io_fail(sys.errno()); }
  const cs = sys.accept(ls, 0, 0); sys.close(ls);
  if (cs < 0) return io_fail(sys.errno());
  const msg = new Uint8Array([111, 107]);
  const n = sys.send(cs, sys.ptr(msg), 2, 0); sys.close(cs);
  if (Number(n) !== 2) return io_fail(Number(n) < 0 ? sys.errno() : 5);
  return { $: CID(Unit) };
}
io_eff(CID(ipv6.serve), ipv6_serve);
