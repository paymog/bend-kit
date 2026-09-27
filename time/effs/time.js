// Time
// ====
// The monotonic and wall clocks, as (secs hi, secs lo, nanos).

function time_raw(ns) {
  const s = ns / 1000000000n;
  const n = ns - s * 1000000000n;
  const u = BigInt.asUintN(64, s);
  return io_tup(Number(u >> 32n), Number(u & 0xffffffffn), Number(n));
}

function mono_raw() {
  return time_raw(process.hrtime.bigint());
}

// JS has no nanosecond wall clock; timeOrigin + now() gives about a microsecond.
function wall_raw() {
  const ms = performance.timeOrigin + performance.now();
  return time_raw(BigInt(Math.floor(ms)) * 1000000n + BigInt(Math.floor((ms % 1) * 1000000)));
}

io_eff(CID(mono.raw), mono_raw);
io_eff(CID(wall.raw), wall_raw);
