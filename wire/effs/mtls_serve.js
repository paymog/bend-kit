function mtls_serve(port, k) {
  const { spawnSync } = require("child_process");
  const p = String(Number(port) & 0xffff);
  const r = spawnSync("openssl", [
    "s_server",
    "-accept", p,
    "-Verify", "1",
    "-CAfile", "test/mtls/ca.pem",
    "-cert", "test/mtls/server.pem",
    "-key", "test/mtls/server.key",
    "-naccept", "1",
    "-quiet",
  ], { stdio: "ignore" });
  if (r.error || r.status !== 0) {
    return io_fail(r.error && r.error.errno ? r.error.errno : 127);
  }
  return { $: CID(Unit) };
}
io_eff(CID(mtls.serve), mtls_serve);
