// Deterministic, non-destructive regression check for process/effs/process.js.
// Loads the verbatim JS effect source against an in-memory fake libc and signal
// recorder (real bun:ffi buffer pointers, zero OS spawns or host kill calls)
// and verifies Linux and Darwin ABI layouts, P_PID selector, and FFI types.

const assert = require("assert");
const fs = require("fs");
const path = require("path");
const realFfi = require("bun:ffi");

const sourcePath = path.join(__dirname, "effs", "process.js");
const rawSource = fs.readFileSync(sourcePath, "utf8");
const expandedSource = rawSource.replace(/CID\(([^)]+)\)/g, (_, name) =>
  JSON.stringify(name === "Unit" ? "Unit" : "process:" + name),
);

function loadEffects({ platform, dlopenImpl, sysImpl }) {
  const registered = Object.create(null);
  const fakeProcess = {
    platform,
    env: { PATH: "/usr/bin:/bin" },
    pid: 31337,
    cwd: () => "/",
    chdir: () => {},
    exit: () => {},
  };
  const fakeOs = {
    constants: {
      errno: {
        ETIMEDOUT: platform === "darwin" ? 60 : 110,
        ENOSYS: platform === "darwin" ? 78 : 38,
      },
      signals: { SIGKILL: 9, SIGTERM: 15 },
    },
    hostname: () => "fake-host",
  };
  const fakeRequire = (id) => {
    if (id === "bun:ffi") {
      return {
        ...realFfi,
        dlopen: dlopenImpl,
        cc: () => {
          throw new Error("unexpected bun:ffi cc in selector-check");
        },
      };
    }
    if (id === "os") {
      return fakeOs;
    }
    throw new Error("unexpected require in bounded path: " + id);
  };
  const io_eff = (name, fn) => {
    registered[name] = fn;
  };
  const io_tup = (...xs) => xs.reduceRight((snd, fst) => ({ $: "Tuple", fst, snd }));
  const io_done = (value) => ({ $: "Done", value });
  const io_fail = (code) => ({ $: "Fail", code: code >>> 0 });

  const factory = new Function(
    "io_eff",
    "io_sys",
    "io_done",
    "io_fail",
    "io_tup",
    "require",
    "process",
    expandedSource + "\nreturn { process_bounded_libc, run_bounded_raw };",
  );
  return {
    registered,
    ...factory(io_eff, () => sysImpl, io_done, io_fail, io_tup, fakeRequire, fakeProcess),
  };
}

function bendList(items) {
  let cur = { $: "Nil" };
  for (let i = items.length - 1; i >= 0; i -= 1) {
    cur = { $: "Con", head: items[i], tail: cur };
  }
  return cur;
}

function checkFfiDescriptors() {
  for (const [platform, wantLib, wantNfds] of [
    ["linux", "libc.so.6", "u64"],
    ["darwin", "libSystem.dylib", "u32"],
  ]) {
    let seenLib = null;
    let seenDesc = null;
    const loaded = loadEffects({
      platform,
      dlopenImpl: (libName, desc) => {
        seenLib = libName;
        seenDesc = desc;
        return { symbols: {} };
      },
      sysImpl: {},
    });
    assert.strictEqual(
      loaded.run_bounded_raw.length,
      7,
      "run_bounded_raw must take 7 parameters without unused continuation k",
    );
    loaded.process_bounded_libc();
    assert.strictEqual(seenLib, wantLib, `${platform}: unexpected libc soname`);
    assert.deepStrictEqual(
      seenDesc.poll,
      { args: ["ptr", wantNfds, "i32"], returns: "i32" },
      `${platform}: poll nfds FFI type mismatch`,
    );
    assert.deepStrictEqual(
      seenDesc.waitid,
      { args: ["i32", "i32", "ptr", "i32"], returns: "i32" },
      `${platform}: waitid FFI signature mismatch`,
    );
  }
}

// Header-derived constants:
// - XNU bsd/sys/wait.h & glibc bits/waitflags.h: P_ALL = 0, P_PID = 1, P_PGID = 2
// - WNOHANG = 1, WEXITED = 4; WNOWAIT = 0x20 (Darwin) / 0x01000000 (Linux)
// - SIGCHLD = 20 (Darwin) / 17 (Linux); SA_NOCLDWAIT = 0x20 (Darwin) / 0x2 (Linux)
// - sa_flags offset = 12 (Darwin) / 136 (Linux); si_pid offset = 12 (Darwin) / 16 (Linux)
function runScenario(platform, scenario) {
  const mac = platform === "darwin";
  const P_ALL = 0;
  const P_PID = 1;
  const WNOHANG = 1;
  const WEXITED = 4;
  const WNOWAIT = mac ? 0x20 : 0x01000000;
  const SIGCHLD = mac ? 20 : 17;
  const SA_NOCLDWAIT = mac ? 0x20 : 0x2;
  const SA_FLAGS_OFF = mac ? 12 : 136;
  const SI_PID_OFF = mac ? 12 : 16;
  const ECHILD = 10;
  const EINVAL = 22;

  const state = {
    errno: 0,
    nextFd: 10,
    openFds: new Set(),
    streams: new Map(),
    children: new Map(scenario.initialChildren ?? []),
    spawns: 0,
    sigactions: [],
    pollNfds: [],
    waitids: [],
    waitpids: [],
    signals: [],
  };

  const sysImpl = {
    mac,
    ptr: realFfi.ptr,
    errno: () => state.errno,
    fcntl: (fd) => {
      assert(state.openFds.has(fd), `${platform}: fcntl on closed fd ${fd}`);
      return 0;
    },
    close: (fd) => {
      assert(state.openFds.has(fd), `${platform}: double or invalid close on fd ${fd}`);
      state.openFds.delete(fd);
      return 0;
    },
    read: (fd, bufPtr, len) => {
      assert(state.openFds.has(fd), `${platform}: read on closed fd ${fd}`);
      const queue = state.streams.get(fd) ?? [];
      if (queue.length === 0) {
        return 0;
      }
      const chunk = queue.shift();
      assert(chunk.length <= len, `${platform}: chunk larger than read buffer`);
      new Uint8Array(realFfi.toArrayBuffer(bufPtr, 0, chunk.length)).set(chunk);
      return chunk.length;
    },
    strerror: (code) => "errno " + code,
  };

  const fakeSymbols = {
    sigaction: (sig, actPtr, oldPtr) => {
      state.sigactions.push(sig);
      assert.strictEqual(sig, SIGCHLD, `${platform}: unexpected sigaction signal ${sig}`);
      assert.strictEqual(actPtr, null, `${platform}: sigaction must query only`);
      const view = new DataView(realFfi.toArrayBuffer(oldPtr, 0, 256));
      view.setBigUint64(0, scenario.sigchld === "ign" ? 1n : 0n, true);
      view.setInt32(SA_FLAGS_OFF, scenario.sigchld === "nocldwait" ? SA_NOCLDWAIT : 0, true);
      return 0;
    },
    pipe: (fdsPtr) => {
      const r = state.nextFd++;
      const w = state.nextFd++;
      state.openFds.add(r);
      state.openFds.add(w);
      const pair = new Int32Array(realFfi.toArrayBuffer(fdsPtr, 0, 8));
      pair[0] = r;
      pair[1] = w;
      return 0;
    },
    posix_spawn_file_actions_init: () => 0,
    posix_spawn_file_actions_destroy: () => 0,
    posix_spawn_file_actions_addchdir_np: () => 0,
    posix_spawn_file_actions_adddup2: () => 0,
    posix_spawn_file_actions_addclose: () => 0,
    posix_spawnattr_init: () => 0,
    posix_spawnattr_destroy: () => 0,
    posix_spawnattr_setsigdefault: () => 0,
    posix_spawnattr_setsigmask: () => 0,
    posix_spawnattr_setpgroup: () => 0,
    posix_spawnattr_setflags: () => 0,
    sigemptyset: () => 0,
    sigaddset: () => 0,
    posix_spawnp: (pidPtr) => {
      state.spawns += 1;
      const leaderPid = scenario.leaderPid ?? 4242;
      new Int32Array(realFfi.toArrayBuffer(pidPtr, 0, 4))[0] = leaderPid;
      // fds allocated by 3 pipe() calls: [10,11] stdin, [12,13] stdout, [14,15] stderr.
      state.streams.set(
        12,
        (scenario.stdoutChunks ?? []).map((s) => Buffer.from(s, "utf8")),
      );
      state.streams.set(
        14,
        (scenario.stderrChunks ?? []).map((s) => Buffer.from(s, "utf8")),
      );
      if (scenario.leaderInitial !== "reaped_before_check") {
        state.children.set(leaderPid, { ...(scenario.leaderInitial ?? { state: "exited", rawStatus: 0 }) });
      }
      return 0;
    },
    poll: (pfPtr, nfds) => {
      state.pollNfds.push(nfds);
      const pv = new Int16Array(realFfi.toArrayBuffer(pfPtr, 0, nfds * 8));
      for (let i = 0; i < nfds; i += 1) {
        pv[i * 4 + 3] = pv[i * 4 + 2];
      }
      return nfds;
    },
    write: (_fd, _ptr, count) => count,
    waitid: (idtype, id, infoPtr, options) => {
      const callIndex = state.waitids.length;
      state.waitids.push({ idtype, id, options });
      assert.strictEqual(
        options,
        WEXITED | WNOHANG | WNOWAIT,
        `${platform}: unexpected waitid flags 0x${options.toString(16)}`,
      );
      if (scenario.onWaitid) {
        scenario.onWaitid(state, callIndex);
      }
      const view = new DataView(realFfi.toArrayBuffer(infoPtr, 0, 256));
      if (idtype === P_ALL) {
        // XNU waitid_nocancel / Linux waitid with P_ALL ignores id completely.
        for (const [childPid, child] of state.children.entries()) {
          if (child.state === "exited") {
            view.setInt32(SI_PID_OFF, childPid, true);
            return 0;
          }
        }
        if (state.children.size > 0) {
          return 0;
        }
        state.errno = ECHILD;
        return -1;
      }
      if (idtype === P_PID) {
        const child = state.children.get(id);
        if (!child) {
          state.errno = ECHILD;
          return -1;
        }
        if (child.state === "exited") {
          view.setInt32(SI_PID_OFF, id, true);
        }
        return 0;
      }
      state.errno = EINVAL;
      return -1;
    },
    kill: (pid, sig) => {
      // Non-destructive recorder: never signals any OS process or group.
      state.signals.push({ pid, sig });
      const target = Math.abs(pid);
      const child = state.children.get(target);
      if (child && child.state === "running" && sig === 9) {
        child.state = "exited";
        child.rawStatus = 9;
      }
      return 0;
    },
    waitpid: (pid, statusPtr, options) => {
      state.waitpids.push({ pid, options });
      const child = state.children.get(pid);
      if (!child) {
        state.errno = ECHILD;
        return -1;
      }
      new Int32Array(realFfi.toArrayBuffer(statusPtr, 0, 4))[0] = child.rawStatus;
      state.children.delete(pid);
      return pid;
    },
  };

  const loaded = loadEffects({
    platform,
    dlopenImpl: () => ({ symbols: fakeSymbols }),
    sysImpl,
  });
  const result = loaded.registered["process:run.bounded.raw"](
    "/bin/fake",
    bendList([]),
    bendList([]),
    ".",
    scenario.stdin ?? "",
    scenario.ms ?? 5000,
    scenario.maxOut ?? 0,
  );
  assert.strictEqual(state.openFds.size, 0, `${platform}: leaked fake pipe fds`);
  return { result, state };
}

function checkPlatformMatrix(platform) {
  // 1. Blocking review defect: leader externally reaped while an unrelated child
  //    stays alive and pump fails on max_out (EFBIG). Must use P_PID (1), fail
  //    with ECHILD (10), and NEVER signal -leaderPid.
  {
    const { result, state } = runScenario(platform, {
      leaderPid: 4242,
      leaderInitial: "reaped_before_check",
      initialChildren: [[9001, { state: "running", rawStatus: 0 }]],
      stdoutChunks: ["12345"],
      maxOut: 4,
      ms: 5000,
    });
    assert.strictEqual(state.signals.length, 0, `${platform}: must not signal lost leader group`);
    assert.deepStrictEqual(result, { $: "Fail", code: 10 }, `${platform}: cap+lost leader must fail ECHILD`);
    assert.strictEqual(state.waitpids.length, 0, `${platform}: must not waitpid lost leader`);
    assert.strictEqual(state.waitids.length, 1, `${platform}: expected one waitid probe`);
    assert.strictEqual(state.waitids[0].idtype, 1, `${platform}: waitid must pass P_PID (1)`);
    assert.strictEqual(state.waitids[0].id, 4242, `${platform}: waitid must target leader pid`);
  }

  // 2. Lost leader after pipe EOF with ms = 0 (no deadline) while an unrelated
  //    sibling stays alive: P_ALL would spin forever; P_PID fails ECHILD at once.
  {
    const { result, state } = runScenario(platform, {
      leaderPid: 4242,
      leaderInitial: "reaped_before_check",
      initialChildren: [[9001, { state: "running", rawStatus: 0 }]],
      stdoutChunks: ["done"],
      maxOut: 0,
      ms: 0,
    });
    assert.strictEqual(state.signals.length, 0, `${platform}: must not signal lost leader group`);
    assert.deepStrictEqual(result, { $: "Fail", code: 10 }, `${platform}: EOF+lost leader (ms=0) must fail ECHILD`);
    assert.strictEqual(state.waitids.length, 1, `${platform}: must not spin on live sibling`);
    assert.strictEqual(state.waitids[0].idtype, 1, `${platform}: waitid must pass P_PID (1)`);
  }

  // 3. Lost leader while an exited-unreaped sibling zombie exists: P_ALL would
  //    see the sibling's si_pid != 0 and send SIGKILL to -4242; P_PID fails ECHILD.
  {
    const { result, state } = runScenario(platform, {
      leaderPid: 4242,
      leaderInitial: "reaped_before_check",
      initialChildren: [[9002, { state: "exited", rawStatus: 0 }]],
      stdoutChunks: [],
      maxOut: 0,
      ms: 0,
    });
    assert.strictEqual(state.signals.length, 0, `${platform}: must not signal lost leader group`);
    assert.deepStrictEqual(result, { $: "Fail", code: 10 }, `${platform}: zombie sibling must not mask lost leader`);
    assert.strictEqual(state.waitpids.length, 0, `${platform}: must not waitpid lost leader`);
    assert(state.children.has(9002), `${platform}: unrelated zombie sibling must stay untouched`);
  }

  // 4. Held running leader alongside an exited-unreaped sibling zombie: P_ALL
  //    would misread the zombie sibling as leader exit and SIGKILL the running
  //    leader early (137). P_PID waits for leader 4242 to exit cleanly (0).
  {
    const { result, state } = runScenario(platform, {
      leaderPid: 4242,
      leaderInitial: { state: "running", rawStatus: 0 },
      initialChildren: [[9003, { state: "exited", rawStatus: 7 << 8 }]],
      stdoutChunks: ["ok"],
      maxOut: 0,
      ms: 5000,
      onWaitid: (st, idx) => {
        if (idx === 1) {
          const leader = st.children.get(4242);
          leader.state = "exited";
          leader.rawStatus = 0;
        }
      },
    });
    assert.strictEqual(state.waitids.length, 2, `${platform}: must poll running leader until it exits`);
    assert(state.waitids.every((w) => w.idtype === 1 && w.id === 4242), `${platform}: every poll must use P_PID`);
    assert.deepStrictEqual(state.signals, [{ pid: -4242, sig: 9 }], `${platform}: expected group kill on held leader`);
    assert.deepStrictEqual(state.waitpids, [{ pid: 4242, options: 0 }], `${platform}: expected leader reap`);
    assert(state.children.has(9003), `${platform}: sibling zombie must remain for its own waiter`);
    assert.deepStrictEqual(
      result,
      {
        $: "Done",
        value: { $: "Tuple", fst: 0, snd: { $: "Tuple", fst: "ok", snd: "" } },
      },
      `${platform}: held leader must keep exit status 0 rather than early SIGKILL 137`,
    );
  }

  // 5. Kernel autoreap (SIGCHLD = SIG_IGN and SA_NOCLDWAIT): refuses with ECHILD
  //    before posix_spawnp and sends no signals.
  for (const mode of ["ign", "nocldwait"]) {
    const { result, state } = runScenario(platform, {
      sigchld: mode,
      stdoutChunks: ["never"],
    });
    assert.deepStrictEqual(result, { $: "Fail", code: 10 }, `${platform} (${mode}): must refuse with ECHILD`);
    assert.strictEqual(state.spawns, 0, `${platform} (${mode}): must not spawn`);
    assert.strictEqual(state.signals.length, 0, `${platform} (${mode}): must not signal`);
  }
}

checkFfiDescriptors();
checkPlatformMatrix("linux");
checkPlatformMatrix("darwin");
console.log("process selector and fake-ffi ownership ok");
