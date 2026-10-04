// Bend's live JS IO loop need not dispatch Bun signal callbacks. Read the same
// async-signal-safe native flag as the native deployment, without host callbacks.
const deploySignalPath = require("node:path").join(
  require("node:path").dirname(process.argv[1]), "signals.c");
// Retain this image for the process lifetime: SIGTERM still points into it.
const deploySignals = require("bun:ffi").cc({
  source: deploySignalPath,
  define: {CAMBER_SIGNAL_HOST: "1"},
  symbols: {
    camber_signal_install: {args: [], returns: "i32"},
    camber_signal_requested: {args: [], returns: "i32"},
    camber_signal_request: {args: [], returns: "void"},
  },
});
io_eff(CID(install), () => {
  if (deploySignals.symbols.camber_signal_install() !== 0) {
    throw new Error("signal installation failed");
  }
  return {$: CID(Unit)};
});
// Like Base Chan.send: Bool uses a primitive JS boolean, not a tagged object.
io_eff(CID(requested), () => deploySignals.symbols.camber_signal_requested() !== 0);
io_eff(CID(request), () => {
  deploySignals.symbols.camber_signal_request();
  return {$: CID(Unit)};
});
