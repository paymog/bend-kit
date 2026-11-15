// Time
// ====
// The monotonic and wall clocks, as (secs hi, secs lo, nanos).

#if defined(CID(mono.raw)) || defined(CID(wall.raw))
#ifndef TIME_EFFS
#define TIME_EFFS
#include <time.h>

static Term time_raw(Env e, clockid_t c) {
  struct timespec ts;
  clock_gettime(c, &ts);
  u64 s = (u64)(int64_t)ts.tv_sec;
  return io_tup(e, (Term)(u32)(s >> 32), io_tup(e, (Term)(u32)s, (Term)(u32)ts.tv_nsec));
}

#endif
#endif

#ifdef CID(mono.raw)

// macOS CLOCK_MONOTONIC ticks in microseconds; CLOCK_MONOTONIC_RAW ticks in nanoseconds.
Term mono_raw_run(Env e, Term* f, IoWork* w) {
#ifdef __APPLE__
  return time_raw(e, CLOCK_MONOTONIC_RAW);
#else
  return time_raw(e, CLOCK_MONOTONIC);
#endif
}

static void __attribute__((constructor)) mono_raw_use(void) {
  io_eff(CID(mono.raw), mono_raw_run);
}

#endif

#ifdef CID(wall.raw)

Term wall_raw_run(Env e, Term* f, IoWork* w) {
  return time_raw(e, CLOCK_REALTIME);
}

static void __attribute__((constructor)) wall_raw_use(void) {
  io_eff(CID(wall.raw), wall_raw_run);
}

#endif
