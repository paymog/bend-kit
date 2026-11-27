static Term flush_run(Env e, Term* f, IoWork* w) {
  io_sync();
  return term_pak(CID(Unit), 0);
}

static void __attribute__((constructor)) flush_use(void) {
  io_eff(CID(flush), flush_run);
}
