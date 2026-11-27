function flush() {
  io_sync();
  return { $: CID(Unit) };
}

io_eff(CID(flush), flush);
