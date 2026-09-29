// TTY
// ===
// JS twin of tty.c: process.stdout's terminal state and NO_COLOR.

// Bool crosses as a host boolean, as in Base's chan.js.
function tty_is_tty() {
  return process.stdout.isTTY === true;
}

function tty_stdout() {
  return tty_is_tty();
}

// None unless stdout is a terminal reporting nonzero columns and rows; no guessed default.
function tty_size() {
  const cols = process.stdout.columns;
  const rows = process.stdout.rows;
  if (!tty_is_tty() || !(cols > 0) || !(rows > 0)) {
    return { $: CID(None) };
  }
  return { $: CID(Some), value: io_tup(cols >>> 0, rows >>> 0) };
}

// NO_COLOR disables color whenever it is set, even empty.
function tty_color() {
  return tty_is_tty() && !Object.hasOwn(process.env, "NO_COLOR");
}

io_eff(CID(stdout_tty), tty_stdout);
io_eff(CID(size), tty_size);
io_eff(CID(color_enabled), tty_color);
