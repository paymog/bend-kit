// Process
// =======
// spawn: Bun.spawn + libc pipe(2) fds for Base File.read/write.
// ponytail: run.raw blocks other Bend fibers in JS while the child runs;
// replace spawnSync with a nonblocking three-pipe pump if concurrency matters.
// wait: WNOHANG waitpid on tracked pid (not proc.exited: promises stall under io_run).

function process_einval() {
  return 22;
}

function process_wire_text(b, n) {
  let s = "";
  for (let i = 0; i < n; i += 8192) {
    s += String.fromCharCode.apply(null, b.subarray(i, Math.min(i + 8192, n)));
  }
  return s;
}

function process_octets(data) {
  const b = new Uint8Array(data.length);
  for (let i = 0; i < data.length; i += 1) {
    const c = data.charCodeAt(i);
    if (c > 255) {
      return null;
    }
    b[i] = c;
  }
  return b;
}

function process_has_nul(s) {
  for (let i = 0; i < s.length; i += 1) {
    if (s.charCodeAt(i) === 0) {
      return true;
    }
  }
  return false;
}

function process_parse_env(xs) {
  const overlay = Object.create(null);
  for (let cur = xs; cur.$ === "Con"; cur = cur.tail) {
    const entry = cur.head;
    if (process_has_nul(entry)) {
      return null;
    }
    const eq = entry.indexOf("=");
    if (eq <= 0) {
      return null;
    }
    overlay[entry.slice(0, eq)] = entry.slice(eq + 1);
  }
  return overlay;
}

function process_env(xs) {
  const overlay = process_parse_env(xs);
  if (overlay === null) {
    return null;
  }
  return { ...process.env, ...overlay };
}

function process_argv(cmd, args) {
  if (process_has_nul(cmd)) {
    return null;
  }
  const argv = [cmd];
  for (let cur = args; cur.$ === "Con"; cur = cur.tail) {
    const a = cur.head;
    if (process_has_nul(a)) {
      return null;
    }
    argv.push(a);
  }
  return argv;
}

function process_libc() {
  if (process_libc.lib === undefined) {
    const ffi = require("bun:ffi");
    const mac = process.platform === "darwin";
    process_libc.lib = ffi.dlopen(mac ? "libSystem.dylib" : "libc.so.6", {
      pipe: { args: [ffi.FFIType.ptr], returns: ffi.FFIType.i32 },
      waitpid: { args: [ffi.FFIType.i32, ffi.FFIType.ptr, ffi.FFIType.i32], returns: ffi.FFIType.i32 },
    }).symbols;
    process_libc.ptr = ffi.ptr;
  }
  return process_libc;
}

function process_pipe_pair() {
  const { lib, ptr } = process_libc();
  const fds = new Int32Array(2);
  if (lib.pipe(ptr(fds)) < 0) {
    return null;
  }
  return [fds[0], fds[1]];
}

function process_close_fd(fd) {
  try {
    require("fs").closeSync(fd);
  } catch (e) {
  }
}

function process_result(code, out, err) {
  return io_tup(code >>> 0, io_tup(out, err));
}

function process_exit_status(st) {
  if ((st & 0x7f) !== 0) {
    return ((st & 0x7f) + 128) >>> 0;
  }
  return (st >> 8) >>> 0;
}

function process_exit_code(proc, code) {
  if (code !== null && code !== undefined) {
    return code >>> 0;
  }
  const signal = require("os").constants.signals[proc.signalCode];
  return signal === undefined ? 127 : (128 + signal) >>> 0;
}

function process_host_fail(e) {
  if (typeof e?.errno === "number") {
    return Math.abs(e.errno);
  }
  if (e?.code === "ENOENT") {
    return 2;
  }
  return process_einval();
}

const process_procs = new Map();

function process_track(proc) {
  process_procs.set(proc.pid, proc);
}

function process_spawn_pipes(argv, environment, cwd) {
  const sys = io_sys();
  const si = process_pipe_pair();
  const so = process_pipe_pair();
  const se = process_pipe_pair();
  if (si === null || so === null || se === null) {
    if (si) {
      process_close_fd(si[0]);
      process_close_fd(si[1]);
    }
    if (so) {
      process_close_fd(so[0]);
      process_close_fd(so[1]);
    }
    if (se) {
      process_close_fd(se[0]);
      process_close_fd(se[1]);
    }
    return io_fail(sys.errno());
  }
  const [stdin_r, stdin_w] = si;
  const [stdout_r, stdout_w] = so;
  const [stderr_r, stderr_w] = se;
  let proc;
  try {
    proc = Bun.spawn({
      cmd: argv,
      env: environment,
      cwd,
      stdio: [stdin_r, stdout_w, stderr_w],
    });
  } catch (e) {
    process_close_fd(stdin_r);
    process_close_fd(stdin_w);
    process_close_fd(stdout_r);
    process_close_fd(stdout_w);
    process_close_fd(stderr_r);
    process_close_fd(stderr_w);
    return io_fail(process_host_fail(e));
  }
  process_close_fd(stdin_r);
  process_close_fd(stdout_w);
  process_close_fd(stderr_w);
  return {
    proc,
    stdin_w,
    stdout_r,
    stderr_r,
  };
}

function run_raw(cmd, args, env, cwd, stdin, k) {
  const argv = process_argv(cmd, args);
  if (argv === null || process_has_nul(cwd)) {
    return io_fail(process_einval());
  }
  const environment = process_env(env);
  if (environment === null) {
    return io_fail(process_einval());
  }
  const inb = process_octets(stdin);
  if (inb === null) {
    return io_fail(process_einval());
  }
  try {
    const r = Bun.spawnSync({
      cmd: argv,
      env: environment,
      cwd,
      stdin: inb,
      stdout: "pipe",
      stderr: "pipe",
    });
    const proc = { signalCode: r.signalCode };
    const code = r.signalCode ? process_exit_code(proc, null) : (r.exitCode >>> 0);
    return io_done(process_result(
      code,
      process_wire_text(r.stdout, r.stdout.length),
      process_wire_text(r.stderr, r.stderr.length),
    ));
  } catch (e) {
    return io_fail(process_host_fail(e));
  }
}

function spawn(cmd, args, env, cwd) {
  const argv = process_argv(cmd, args);
  if (argv === null || process_has_nul(cwd)) {
    return io_fail(process_einval());
  }
  const environment = process_env(env);
  if (environment === null) {
    return io_fail(process_einval());
  }
  const spawned = process_spawn_pipes(argv, environment, cwd);
  if (spawned.$ === "Fail") {
    return spawned;
  }
  const { proc, stdin_w, stdout_r, stderr_r } = spawned;
  process_track(proc);
  const files = io_tup(stdin_w, io_tup(stdout_r, stderr_r));
  return io_done(io_tup(proc.pid >>> 0, files));
}

function wait(pid, k) {
  const proc = process_procs.get(Number(pid));
  if (proc === undefined) {
    return io_fail(10);
  }
  const { lib, ptr } = process_libc();
  const check = () => {
    if (proc.exitCode !== null) {
      process_procs.delete(Number(pid));
      return io_done(process_exit_code(proc, proc.exitCode));
    }
    const status = new Int32Array([0]);
    const r = Number(lib.waitpid(Number(pid), ptr(status), 1));
    if (r > 0) {
      process_procs.delete(Number(pid));
      return io_done(process_exit_status(status[0]));
    }
    if (r < 0) {
      process_procs.delete(Number(pid));
      return io_fail(io_sys().errno());
    }
    io_park_on(undefined, false, k, check, performance.now() + 5);
    return undefined;
  };
  return check();
}

function read_stdin(max, k) {
  const sys = io_sys();
  const len = Math.min(Number(max), 2147483647);
  const b = new Uint8Array(Math.max(len, 1));
  if (len === 0) {
    return io_done("");
  }
  const go = () => {
    const n = Number(sys.read(0, sys.ptr(b), len));
    if (n < 0) {
      const code = sys.errno();
      if (code === (sys.mac ? 35 : 11) || code === 4) {
        io_park_on(0, false, k, go);
        return undefined;
      }
      return io_fail(code);
    }
    return io_done(process_wire_text(b, n));
  };
  io_park_on(0, false, k, go);
  return undefined;
}

function exit_raw(code) {
  process.exit(Number(code));
  return { $: "Unit" };
}

function cwd() {
  try {
    return io_done(process.cwd());
  } catch (e) {
    return io_fail(Math.abs(e.errno ?? 5));
  }
}

function chdir(path) {
  if (process_has_nul(path)) {
    return io_fail(process_einval());
  }
  try {
    process.chdir(path);
    return io_done({ $: "Unit" });
  } catch (e) {
    const code = e.errno ?? (e.code === "ENOENT" ? 2 : e.code === "EACCES" ? 13 : e.code === "ERR_INVALID_ARG_TYPE" ? 22 : 5);
    return io_fail(Math.abs(code));
  }
}

function hostname() {
  try {
    return io_done(require("os").hostname());
  } catch (e) {
    return io_fail(Math.abs(e.errno ?? 5));
  }
}

function pid() {
  return process.pid >>> 0;
}

let process_signal_native;

function signal_poll() {
  if (process_signal_native === undefined) {
    // Bend's synchronous IO loop does not dispatch Bun's JS signal callbacks.
    // A C handler only stores sig_atomic_t; never enter JavaScript from a signal.
    const fs = require("fs");
    const os = require("os");
    const path = require("path");
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "bend-kit-signal-"));
    const file = path.join(dir, "signal.c");
    try {
      fs.writeFileSync(file, `
        #include <signal.h>
        static volatile sig_atomic_t pending;
        static void on_signal(int sig) { pending = sig; }
        int process_signal_poll(void) {
          static int installed;
          if (!installed) {
            struct sigaction sa = {0};
            sa.sa_handler = on_signal;
            sigemptyset(&sa.sa_mask);
            sigaction(SIGINT, &sa, 0);
            sigaction(SIGTERM, &sa, 0);
            installed = 1;
          }
          int value = pending;
          pending = 0;
          return value;
        }
      `);
      process_signal_native = require("bun:ffi").cc({
        source: file,
        symbols: { process_signal_poll: { args: [], returns: "i32" } },
      }).symbols.process_signal_poll;
    } finally {
      fs.unlinkSync(file);
      fs.rmdirSync(dir);
    }
  }
  return process_signal_native() >>> 0;
}

// Standalone JS builds use the older effect registry; bundled builds collect
// functions by name. Register explicitly only when that registry is present.
if (typeof io_eff === "function") {
  for (const [name, fn] of Object.entries({
    run_raw, spawn, wait, read_stdin, exit_raw, cwd, chdir, hostname, pid, signal_poll,
  })) {
    const effect = name === "run_raw" ? "run.raw"
      : name === "exit_raw" ? "exit.raw"
      : name === "signal_poll" ? "signal.poll" : name;
    io_eff("process." + effect, fn);
  }
}
