// TTY
// ===
// Standard output as a terminal: isatty, TIOCGWINSZ and NO_COLOR. Same answers as tty/effs/tty.js.

#ifndef TTY_EFFS
#define TTY_EFFS

#if defined(CID(stdout_tty)) || defined(CID(size)) || defined(CID(color_enabled))
#include <stdlib.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define tty_bool(b) term_pak((b) ? CID(True) : CID(False), 0)
#endif

#ifdef CID(stdout_tty)

Term tty_stdout_run(Env e, Term* f, IoWork* w) {
  return tty_bool(isatty(STDOUT_FILENO));
}

static void __attribute__((constructor)) tty_stdout_use(void) {
  io_eff(CID(stdout_tty), tty_stdout_run, 0);
}

#endif

#ifdef CID(size)

// None unless stdout is a terminal reporting nonzero columns and rows; no guessed default.
Term tty_size_run(Env e, Term* f, IoWork* w) {
  struct winsize ws;
  if (!isatty(STDOUT_FILENO) || ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) != 0 || ws.ws_col == 0
    || ws.ws_row == 0) {
    return term_pak(CID(None), 0);
  }
  return io_box(e, CID(Some), io_tup(e, (Term)(u32)ws.ws_col, (Term)(u32)ws.ws_row));
}

static void __attribute__((constructor)) tty_size_use(void) {
  io_eff(CID(size), tty_size_run, 0);
}

#endif

#ifdef CID(color_enabled)

// NO_COLOR disables color whenever it is set, even empty.
Term tty_color_run(Env e, Term* f, IoWork* w) {
  return tty_bool(isatty(STDOUT_FILENO) && getenv("NO_COLOR") == NULL);
}

static void __attribute__((constructor)) tty_color_use(void) {
  io_eff(CID(color_enabled), tty_color_run, 0);
}

#endif

#endif
