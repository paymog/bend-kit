// Process
// =======
// spawn: Bun.spawn + libc pipe(2) fds for Base File.read/write.
// ponytail: run.raw blocks other Bend fibers in JS while the child runs;
// replace spawnSync with a nonblocking three-pipe pump if concurrency matters.
// wait: WNOHANG waitpid on tracked pid (not proc.exited: promises stall under io_run).
// run.bounded.raw: libc posix_spawn through bun:ffi, so this code alone spawns,
// signals, and reaps the group leader; Bun never sees the child.

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

function process_bounded_libc() {
  if (process_bounded_libc.lib === undefined) {
    const ffi = require("bun:ffi");
    const mac = process.platform === "darwin";
    const T = { i: "i32", h: "i16", p: "ptr", U: "u64", I: "i64" };
    process_bounded_libc.lib = ffi.dlopen(mac ? "libSystem.dylib" : "libc.so.6",
      Object.fromEntries(("posix_spawnp:pppppp>i posix_spawn_file_actions_init:p>i"
        + " posix_spawn_file_actions_destroy:p>i posix_spawn_file_actions_adddup2:pii>i"
        + " posix_spawn_file_actions_addclose:pi>i posix_spawn_file_actions_addchdir_np:pp>i"
        + " posix_spawnattr_init:p>i posix_spawnattr_destroy:p>i posix_spawnattr_setflags:ph>i"
        + " posix_spawnattr_setpgroup:pi>i posix_spawnattr_setsigdefault:pp>i"
        + " posix_spawnattr_setsigmask:pp>i sigemptyset:p>i sigaddset:pi>i sigaction:ipp>i"
        + " pipe:p>i poll:pii>i write:ipU>I waitid:iipi>i waitpid:ipi>i kill:ii>i").split(" ")
        .map((s) => {
          const [name, args, ret] = s.split(/[:>]/);
          return [name, { args: [...args].map((a) => T[a]), returns: T[ret] }];
        }))).symbols;
    process_bounded_libc.mac = mac;
  }
  return process_bounded_libc;
}

function process_cstr(s) {
  return Buffer.from(s + "\0", "utf8");
}

// A NULL-terminated char* array; keep holds the strings alive.
function process_cstr_array(xs, keep) {
  const { ptr } = require("bun:ffi");
  const arr = new BigUint64Array(xs.length + 1);
  xs.forEach((x, i) => {
    const b = process_cstr(x);
    keep.push(b);
    arr[i] = BigInt(ptr(b));
  });
  keep.push(arr);
  return arr;
}

// True when the kernel would reap our children by itself (SIGCHLD ignored or
// SA_NOCLDWAIT): a leader's pid could then be reused before the group kill.
function process_autoreaps(c) {
  const { ptr, read } = require("bun:ffi");
  const sa = new Uint8Array(256);
  if (c.lib.sigaction(c.mac ? 20 : 17, null, ptr(sa)) < 0) {
    return true;
  }
  const handler = read.u64(ptr(sa), 0);
  const flags = read.i32(ptr(sa), c.mac ? 12 : 136);
  return handler === 1n || (flags & (c.mac ? 0x20 : 2)) !== 0;
}

// 0 while the leader is our unreaped child (exited.v tells whether it has
// exited); else the errno, such as ECHILD once anything else reaped it.
function process_leader_held(c, pid, exited) {
  const { ptr, read } = require("bun:ffi");
  const sys = io_sys();
  const info = new Uint8Array(256);
  const flags = 4 | 1 | (c.mac ? 0x20 : 0x01000000);
  for (;;) {
    info.fill(0);
    if (c.lib.waitid(c.mac ? 0 : 1, pid, ptr(info), flags) === 0) {
      exited.v = read.i32(ptr(info), c.mac ? 12 : 16) !== 0;
      return 0;
    }
    const code = sys.errno();
    if (code !== 4) {
      return code;
    }
  }
}

// Spawns argv as the leader of a new process group, with three pipes.
function process_bounded_spawn(c, argv, environment, cwd) {
  const { ptr } = require("bun:ffi");
  const sys = io_sys();
  const fds = new Int32Array(6).fill(-1);
  const close_all = () => fds.forEach((fd) => fd >= 0 && sys.close(fd));
  for (let i = 0; i < 6; i += 2) {
    if (c.lib.pipe(ptr(fds.subarray(i, i + 2))) < 0) {
      const code = sys.errno();
      close_all();
      return { code };
    }
  }
  const nonblock = c.mac ? 0x4 : 0x800;
  for (const fd of fds) {
    if (sys.fcntl(fd, 2, 1) < 0) {
      const code = sys.errno();
      close_all();
      return { code };
    }
  }
  for (const fd of [fds[1], fds[2], fds[4]]) {
    const fl = sys.fcntl(fd, 3, 0);
    if (fl < 0 || sys.fcntl(fd, 4, fl | nonblock) < 0) {
      const code = sys.errno();
      close_all();
      return { code };
    }
  }
  const keep = [];
  const args = process_cstr_array(argv, keep);
  const envp = process_cstr_array(Object.entries(environment).map(([k, v]) => k + "=" + v), keep);
  const dir = process_cstr(cwd);
  const actions = new Uint8Array(256);
  const attrs = new Uint8Array(512);
  const defaults = new Uint8Array(128);
  const mask = new Uint8Array(128);
  const pid = new Int32Array(1);
  let rc = c.lib.posix_spawn_file_actions_init(ptr(actions));
  if (rc !== 0) {
    close_all();
    return { code: rc };
  }
  rc = c.lib.posix_spawn_file_actions_addchdir_np(ptr(actions), ptr(dir));
  rc = rc || c.lib.posix_spawn_file_actions_adddup2(ptr(actions), fds[0], 0);
  rc = rc || c.lib.posix_spawn_file_actions_adddup2(ptr(actions), fds[3], 1);
  rc = rc || c.lib.posix_spawn_file_actions_adddup2(ptr(actions), fds[5], 2);
  for (const fd of fds) {
    rc = rc || c.lib.posix_spawn_file_actions_addclose(ptr(actions), fd);
  }
  let attrs_ready = false;
  if (rc === 0) {
    rc = c.lib.posix_spawnattr_init(ptr(attrs));
    attrs_ready = rc === 0;
  }
  if (rc === 0) {
    c.lib.sigemptyset(ptr(defaults));
    c.lib.sigaddset(ptr(defaults), 13);
    c.lib.sigemptyset(ptr(mask));
    rc = c.lib.posix_spawnattr_setsigdefault(ptr(attrs), ptr(defaults));
    rc = rc || c.lib.posix_spawnattr_setsigmask(ptr(attrs), ptr(mask));
    rc = rc || c.lib.posix_spawnattr_setpgroup(ptr(attrs), 0);
    rc = rc || c.lib.posix_spawnattr_setflags(ptr(attrs), 0x02 | 0x04 | 0x08);
  }
  if (rc === 0) {
    rc = c.lib.posix_spawnp(ptr(pid), ptr(keep[0]), ptr(actions), ptr(attrs), ptr(args), ptr(envp));
  }
  if (attrs_ready) {
    c.lib.posix_spawnattr_destroy(ptr(attrs));
  }
  c.lib.posix_spawn_file_actions_destroy(ptr(actions));
  for (const i of [0, 3, 5]) {
    sys.close(fds[i]);
    fds[i] = -1;
  }
  if (rc !== 0) {
    close_all();
    return { code: rc };
  }
  return { code: 0, pid: pid[0], in_w: fds[1], out_r: fds[2], err_r: fds[4] };
}

// Writes stdin and reads stdout and stderr until both close, the deadline
// passes (ETIMEDOUT) or a stream passes limit (EFBIG). Closes every fd.
function process_bounded_pump(c, job, inb, deadline, limit) {
  const { ptr } = require("bun:ffi");
  const sys = io_sys();
  const fds = { in: inb.length ? job.in_w : -1, out: job.out_r, err: job.err_r };
  if (!inb.length) {
    sys.close(job.in_w);
  }
  const close = (name) => {
    sys.close(fds[name]);
    fds[name] = -1;
  };
  const close_all = () => ["in", "out", "err"].forEach((n) => fds[n] >= 0 && close(n));
  const chunks = { out: [], err: [] };
  const lens = { out: 0, err: 0 };
  const buf = new Uint8Array(65536);
  const etimedout_code = etimedout();
  let written = 0;
  for (;;) {
    const names = ["in", "out", "err"].filter((n) => fds[n] >= 0);
    if (!names.includes("out") && !names.includes("err")) {
      close_all();
      break;
    }
    let left = -1;
    if (deadline) {
      left = Math.ceil(deadline - performance.now());
      if (left <= 0) {
        close_all();
        return { code: etimedout_code };
      }
      left = Math.min(left, 2147483647);
    }
    const pf = new Int32Array(names.length * 2);
    const pv = new Int16Array(pf.buffer);
    names.forEach((n, i) => {
      pf[i * 2] = fds[n];
      pv[i * 4 + 2] = n === "in" ? 4 : 1;
    });
    const ready = c.lib.poll(ptr(pf), names.length, left);
    if (ready < 0) {
      const code = sys.errno();
      if (code === 4) {
        continue;
      }
      close_all();
      return { code };
    }
    for (let i = 0; i < names.length; i += 1) {
      const n = names[i];
      if (pv[i * 4 + 3] === 0) {
        continue;
      }
      if (n === "in") {
        const r = Number(c.lib.write(fds.in, ptr(inb, written), inb.length - written));
        if (r < 0) {
          const code = sys.errno();
          if (code === 32) {
            close("in");
          } else if (code !== 4 && code !== (c.mac ? 35 : 11)) {
            close_all();
            return { code };
          }
        } else {
          written += r;
          if (written >= inb.length) {
            close("in");
          }
        }
        continue;
      }
      const r = Number(sys.read(fds[n], ptr(buf), buf.length));
      if (r < 0) {
        const code = sys.errno();
        if (code === 4 || code === (c.mac ? 35 : 11)) {
          continue;
        }
        close_all();
        return { code };
      }
      if (r === 0) {
        close(n);
        continue;
      }
      if (limit && r > limit - lens[n]) {
        close_all();
        return { code: 27 };
      }
      chunks[n].push(Buffer.from(buf.subarray(0, r)));
      lens[n] += r;
    }
  }
  return { code: 0, out: Buffer.concat(chunks.out), err: Buffer.concat(chunks.err) };
}

// Like run_raw, in a new process group, with a deadline and a per-stream
// output cap. The group kill is sent only while this call still holds the
// unreaped leader, so the group id cannot have been reused. If anything else
// reaped the leader, nothing is signaled and the call fails with ECHILD.
function run_bounded_raw(cmd, args, env, cwd, stdin, ms, max_out, k) {
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
  const echild = 10;
  let c;
  try {
    c = process_bounded_libc();
  } catch (e) {
    return io_fail(process_errno_named("ENOSYS"));
  }
  if (process_autoreaps(c)) {
    return io_fail(echild);
  }
  const deadline = Number(ms) ? performance.now() + Number(ms) : 0;
  const job = process_bounded_spawn(c, argv, environment, cwd);
  if (job.code) {
    return io_fail(job.code);
  }
  const pumped = process_bounded_pump(c, job, inb, deadline, Number(max_out));
  let failed = pumped.code;
  const exited = { v: false };
  let held = false;
  if (failed) {
    held = process_leader_held(c, job.pid, exited) === 0;
  } else {
    const etimedout_code = etimedout();
    let nap = 1;
    for (;;) {
      const r = process_leader_held(c, job.pid, exited);
      if (r !== 0) {
        failed = r;
        break;
      }
      if (exited.v) {
        held = true;
        break;
      }
      if (deadline && performance.now() >= deadline) {
        failed = etimedout_code;
        held = true;
        break;
      }
      const wait = deadline ? Math.min(nap, Math.max(1, deadline - performance.now())) : nap;
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, wait);
      nap = Math.min(nap * 2, 16);
    }
  }
  if (!held) {
    return io_fail(echild);
  }
  c.lib.kill(-job.pid, 9);
  const { ptr } = require("bun:ffi");
  const status = new Int32Array(1);
  let r;
  do {
    r = c.lib.waitpid(job.pid, ptr(status), 0);
  } while (r < 0 && io_sys().errno() === 4);
  if (!failed && r < 0) {
    failed = io_sys().errno();
  }
  if (failed) {
    return io_fail(failed);
  }
  return io_done(process_result(
    process_exit_status(status[0]),
    process_wire_text(pumped.out, pumped.out.length),
    process_wire_text(pumped.err, pumped.err.length),
  ));
}

function process_errno_named(name) {
  const code = require("os").constants.errno[name];
  return typeof code === "number" ? code : process_einval();
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

// The host's ETIMEDOUT: 110 on Linux, 60 on macOS.
function etimedout() {
  const code = require("os").constants.errno.ETIMEDOUT;
  return (typeof code === "number" ? code : (process.platform === "darwin" ? 60 : 110)) >>> 0;
}

function wait(pid, k) {
  const n = Number(pid);
  if (!Number.isInteger(n) || n < 1 || n > 2147483647) {
    return io_fail(process_einval());
  }
  const proc = process_procs.get(n);
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
  return { $: CID(Unit) };
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
    return io_done({ $: CID(Unit) });
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

io_eff(CID(run.raw), run_raw);
io_eff(CID(run.bounded.raw), run_bounded_raw);
io_eff(CID(spawn), spawn);
io_eff(CID(wait), wait);
io_eff(CID(etimedout), etimedout);
io_eff(CID(read_stdin), read_stdin);
io_eff(CID(exit.raw), exit_raw);
io_eff(CID(cwd), cwd);
io_eff(CID(chdir), chdir);
io_eff(CID(hostname), hostname);
io_eff(CID(pid), pid);
io_eff(CID(signal.poll), signal_poll);
