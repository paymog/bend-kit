// DNS
// ===
// JS twin of dns.c: getaddrinfo order, AF_UNSPEC, NUL-separated addresses.

function dns_lib() {
  if (globalThis.BEND_DNS === undefined) {
    const ffi = require("bun:ffi");
    const mac = process.platform === "darwin";
    globalThis.BEND_DNS = {
      mac,
      ptr: ffi.ptr,
      read: ffi.read,
      c: ffi.dlopen(mac ? "libSystem.dylib" : "libc.so.6", {
        getaddrinfo: {
          args: [ffi.FFIType.cstring, ffi.FFIType.cstring, ffi.FFIType.ptr, ffi.FFIType.ptr],
          returns: ffi.FFIType.i32,
        },
        freeaddrinfo: { args: [ffi.FFIType.ptr], returns: ffi.FFIType.void },
        inet_ntop: {
          args: [ffi.FFIType.i32, ffi.FFIType.ptr, ffi.FFIType.ptr, ffi.FFIType.u32],
          returns: ffi.FFIType.cstring,
        },
      }).symbols,
    };
  }
  return globalThis.BEND_DNS;
}

function dns_gai_code(gai) {
  const mac = dns_lib().mac;
  if (gai === 8 || gai === 7) {
    return 2;
  }
  if (gai === 2) {
    return mac ? 35 : 11;
  }
  if (gai === 3) {
    return 12;
  }
  return 5;
}

function dns_name(host) {
  const b = io_bytes(host);
  if (b.includes(0)) {
    return null;
  }
  return b.length === 0 ? "" : Buffer.from(b).toString("utf8");
}

function dns_ai_next(ai, mac) {
  return dns_lib().read.ptr(ai, mac ? 40 : 32);
}

function dns_ai_family(ai) {
  return dns_lib().read.i32(ai, 4);
}

function dns_ai_addr(ai, mac) {
  return dns_lib().read.ptr(ai, mac ? 32 : 24);
}

function dns_ntop(family, sa) {
  const { c, ptr, read, mac } = dns_lib();
  if (family === 2) {
    const sin = Buffer.alloc(4);
    for (let i = 0; i < 4; i += 1) {
      sin[i] = read.u8(sa, 4 + i);
    }
    const out = Buffer.alloc(16);
    c.inet_ntop(2, ptr(sin), ptr(out), 16);
    return out.toString("utf8").replace(/\0.*/, "");
  }
  if (family === 10 || family === 30) {
    const sin6 = Buffer.alloc(16);
    for (let i = 0; i < 16; i += 1) {
      sin6[i] = read.u8(sa, mac ? 8 + i : i);
    }
    const out = Buffer.alloc(46);
    c.inet_ntop(family === 30 ? 30 : 10, ptr(sin6), ptr(out), 46);
    return out.toString("utf8").replace(/\0.*/, "");
  }
  return null;
}

function lookup_all(host) {
  const name = dns_name(host);
  if (name === null) {
    return io_fail(22);
  }
  const { c, ptr, mac } = dns_lib();
  const hostz = Buffer.from(name + "\0");
  const hints = Buffer.alloc(48);
  hints.writeInt32LE(0, 4);
  hints.writeInt32LE(1, 8);
  const resSlot = Buffer.alloc(8);
  const gai = Number(c.getaddrinfo(ptr(hostz), null, ptr(hints), ptr(resSlot)));
  if (gai !== 0) {
    return io_fail(dns_gai_code(gai));
  }
  const ips = [];
  let ai = dns_lib().read.ptr(ptr(resSlot));
  while (ai) {
    const ip = dns_ntop(dns_ai_family(ai), dns_ai_addr(ai, mac));
    if (ip !== null) {
      ips.push(ip);
    }
    ai = dns_ai_next(ai, mac);
  }
  c.freeaddrinfo(dns_lib().read.ptr(ptr(resSlot)));
  if (ips.length === 0) {
    return io_fail(2);
  }
  return io_done(ips.join("\0"));
}

io_eff(CID(lookup.all), lookup_all);
