// Random
// ======
// JS twin of random.c: OS entropy via crypto.getRandomValues.

function entropy() {
  const s = crypto.getRandomValues(new Uint32Array(4));
  return io_done(io_tup(s[0], s[1], s[2], s[3]));
}

io_eff(CID(entropy), entropy);
