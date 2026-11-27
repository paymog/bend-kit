#ifndef F32ARRAY_CONVERT
#define F32ARRAY_CONVERT

// Cell lanes and Bytes words use the same native packed-U32 block layout.
static Term f32array_convert(Env e, u32 n, Term a, bool big, u32 minimum) {
  if (n >= (1u << 30)) {
    err_post(e.mem, ERR_ARRS);
    return a;
  }
  u32 depth = minimum;
  while ((1ull << depth) < n) ++depth;
  u64 old_count = 1ull << blk_cls(a);
  u64 count = 1ull << depth;
  u64 src = blk_loc(e.mem, a);
  if (count != old_count) {
    Term zero = 0;
    Term b = blk_new(e, false, depth, 0, 1, &zero);
    u64 dst = blk_loc(e.mem, b);
    for (u64 i = 0; i < n; ++i) {
      u32 word = blk_read(e.mem, false, src, (u32)(i & (old_count - 1)));
      blk_write(e.mem, false, dst, (u32)i, big ? __builtin_bswap32(word) : word);
    }
    term_sink(e, a);
    return b;
  }
  if (big || n < count) {
    if (blk_shr(a)) {
      Term b = blk_copy(e, a);
      term_sink(e, a);
      a = b;
      src = blk_loc(e.mem, a);
    }
    if (big) {
      for (u64 i = 0; i < n; ++i) {
        u32 word = blk_read(e.mem, false, src, (u32)i);
        blk_write(e.mem, false, src, (u32)i, __builtin_bswap32(word));
      }
    }
    for (u64 i = n; i < count; ++i) blk_write(e.mem, false, src, (u32)i, 0);
  }
  return a;
}

#endif

#ifdef CID(from_bytes.raw)
static Term from_bytes_raw_run(Env e, Term* f, IoWork* w) {
  return f32array_convert(e, (u32)f[0], f[1], (u32)f[2] != 0, 3);
}
static void __attribute__((constructor)) from_bytes_raw_use(void) {
  io_eff(CID(from_bytes.raw), from_bytes_raw_run);
}
#endif

#ifdef CID(to_bytes.raw)
static Term to_bytes_raw_run(Env e, Term* f, IoWork* w) {
  return f32array_convert(e, (u32)f[0], f[1], (u32)f[2] != 0, 0);
}
static void __attribute__((constructor)) to_bytes_raw_use(void) {
  io_eff(CID(to_bytes.raw), to_bytes_raw_run);
}
#endif
