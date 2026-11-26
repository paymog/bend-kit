#ifndef COLLISION_COUNTS
#define COLLISION_COUNTS
static unsigned long long collision_calls, collision_bytes;
#endif

Term allocations_run(Env e, Term* f, IoWork* w) {
  char text[96];
  int n = snprintf(text, sizeof(text), "%llu:%llu", collision_calls, collision_bytes);
  collision_calls = collision_bytes = 0;
  Term out = io_str(e, text, n);
  collision_calls = collision_bytes = 0;
  return out;
}

static void __attribute__((constructor)) allocations_use(void) {
  io_eff(CID(allocations), allocations_run);
}
