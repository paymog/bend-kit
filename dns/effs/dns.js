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

// struct addrinfo: ai_family at 4 and ai_next at 40 on both; ai_addr at 32 (macOS) or 24 (Linux).
function dns_ntop(ai, mac) {
  const { c, ptr, read } = dns_lib();
  const family = read.i32(ai, 4);
  const sa = read.ptr(ai, mac ? 32 : 24);
  const v6 = family === (mac ? 30 : 10);
  if (family !== 2 && !v6) {
    return null;
  }
  // sin_addr is at 4, sin6_addr at 8, on both.
  const n = v6 ? 16 : 4;
  const addr = Buffer.alloc(n);
  for (let i = 0; i < n; i += 1) {
    addr[i] = read.u8(sa, (v6 ? 8 : 4) + i);
  }
  const out = Buffer.alloc(46);
  c.inet_ntop(family, ptr(addr), ptr(out), 46);
  return out.toString("utf8").replace(/\0.*/, "");
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
  const first = dns_lib().read.ptr(ptr(resSlot));
  for (let ai = first; ai; ai = dns_lib().read.ptr(ai, 40)) {
    const ip = dns_ntop(ai, mac);
    if (ip !== null) {
      ips.push(ip);
    }
  }
  c.freeaddrinfo(first);
  if (ips.length === 0) {
    return io_fail(2);
  }
  return io_done(ips.join("\0"));
}

io_eff(CID(lookup.all), lookup_all);
