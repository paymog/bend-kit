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

function loadEffects({ platform, dlopenImpl, sysImpl, parkImpl }) {
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
  const io_park_on = parkImpl ?? (() => {
    throw new Error("unexpected io_park_on in selector-check");
  });

  const factory = new Function(
    "io_eff",
    "io_sys",
    "io_done",
    "io_fail",
    "io_tup",
    "io_park_on",
    "require",
    "process",
    expandedSource + "\nreturn { process_bounded_libc, run_bounded_raw };",
  );
  return {
    registered,
    ...factory(io_eff, () => sysImpl, io_done, io_fail, io_tup, io_park_on, fakeRequire, fakeProcess),
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
  for (const [platform, wantLib] of [
    ["linux", "libc.so.6"],
    ["darwin", "libSystem.dylib"],
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
      8,
      "run_bounded_raw must take 8 parameters including continuation k",
    );
    assert.strictEqual(
      loaded.registered["process:run.raw"].length,
      6,
      "run_raw must take 6 parameters including continuation k",
    );
    loaded.process_bounded_libc();
    assert.strictEqual(seenLib, wantLib, `${platform}: unexpected libc soname`);
    assert.strictEqual(
      seenDesc.poll,
      undefined,
      `${platform}: cooperative JS runner must not bind blocking poll(2)`,
    );
    assert.deepStrictEqual(
      seenDesc.waitid,
      { args: ["i32", "i32", "ptr", "i32"], returns: "i32" },
      `${platform}: waitid FFI signature mismatch`,
    );
    if (platform === "linux") {
      assert.deepStrictEqual(
        seenDesc.posix_spawn_file_actions_addclosefrom_np,
        { args: ["ptr", "i32"], returns: "i32" },
        "linux: addclosefrom_np FFI signature mismatch",
      );
      assert.strictEqual(
        seenDesc.posix_spawn_file_actions_addclose,
        undefined,
        "linux: addclose is unnecessary when addclosefrom_np(3) is used",
      );
    } else {
      assert.strictEqual(
        seenDesc.posix_spawn_file_actions_addclosefrom_np,
        undefined,
        "darwin: must not dlopen Linux-only addclosefrom_np",
      );
      assert.deepStrictEqual(
        seenDesc.posix_spawn_file_actions_addclose,
        { args: ["ptr", "i32"], returns: "i32" },
        "darwin: addclose FFI signature mismatch",
      );
    }
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
    fcntlCalls: [],
    streams: new Map(),
    children: new Map(scenario.initialChildren ?? []),
    spawns: 0,
    spawnFlags: [],
    pgroups: [],
    closefromCalls: [],
    addcloseCalls: [],
    sigactions: [],
    parks: [],
    waitids: [],
    waitpids: [],
    signals: [],
  };

  const sysImpl = {
    mac,
    ptr: realFfi.ptr,
    errno: () => state.errno,
    fcntl: (fd, cmd, arg) => {
      assert(state.openFds.has(fd), `${platform}: fcntl on closed fd ${fd}`);
      state.fcntlCalls.push({ fd, cmd, arg });
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
      if (chunk === "EAGAIN") {
        state.errno = mac ? 35 : 11;
        return -1;
      }
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
    posix_spawn_file_actions_addclose: (_actions, fd) => {
      state.addcloseCalls.push(fd);
      return 0;
    },
    posix_spawn_file_actions_addclosefrom_np: (_actions, fromFd) => {
      state.closefromCalls.push(fromFd);
      return 0;
    },
    posix_spawnattr_init: () => 0,
    posix_spawnattr_destroy: () => 0,
    posix_spawnattr_setsigdefault: () => 0,
    posix_spawnattr_setsigmask: () => 0,
    posix_spawnattr_setpgroup: (_attrs, pgroup) => {
      state.pgroups.push(pgroup);
      return 0;
    },
    posix_spawnattr_setflags: (_attrs, flags) => {
      state.spawnFlags.push(flags);
      return 0;
    },
    sigemptyset: () => 0,
    sigaddset: () => 0,
    posix_spawnp: (pidPtr) => {
      state.spawns += 1;
      const leaderPid = scenario.leaderPid ?? 4242;
      new Int32Array(realFfi.toArrayBuffer(pidPtr, 0, 4))[0] = leaderPid;
      // fds allocated by 3 pipe() calls: [10,11] stdin, [12,13] stdout, [14,15] stderr.
      state.streams.set(
        12,
        (scenario.stdoutChunks ?? []).map((s) => (s === "EAGAIN" ? "EAGAIN" : Buffer.from(s, "utf8"))),
      );
      state.streams.set(
        14,
        (scenario.stderrChunks ?? []).map((s) => (s === "EAGAIN" ? "EAGAIN" : Buffer.from(s, "utf8"))),
      );
      if (scenario.leaderInitial !== "reaped_before_check") {
        state.children.set(leaderPid, { ...(scenario.leaderInitial ?? { state: "exited", rawStatus: 0 }) });
      }
      return 0;
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
      const callIndex = state.waitpids.length;
      state.waitpids.push({ pid, options });
      assert.strictEqual(options, WNOHANG, `${platform}: waitpid must use WNOHANG`);
      if (scenario.onWaitpid) {
        scenario.onWaitpid(state, callIndex);
      }
      const child = state.children.get(pid);
      if (!child) {
        state.errno = ECHILD;
        return -1;
      }
      if (child.state === "running") {
        return 0;
      }
      new Int32Array(realFfi.toArrayBuffer(statusPtr, 0, 4))[0] = child.rawStatus;
      state.children.delete(pid);
      return pid;
    },
  };

  let pendingPark = null;
  const loaded = loadEffects({
    platform,
    dlopenImpl: () => ({ symbols: fakeSymbols }),
    sysImpl,
    parkImpl: (fd, out, _k, more, at) => {
      state.parks.push({ fd, out, at });
      pendingPark = more;
    },
  });
  let result = scenario.unbounded
    ? loaded.registered["process:run.raw"](
        "/bin/fake",
        bendList([]),
        bendList([]),
        ".",
        scenario.stdin ?? "",
        () => {},
      )
    : loaded.registered["process:run.bounded.raw"](
        "/bin/fake",
        bendList([]),
        bendList([]),
        ".",
        scenario.stdin ?? "",
        scenario.ms ?? 5000,
        scenario.maxOut ?? 0,
        () => {},
      );
  let steps = 0;
  while (result === undefined) {
    assert(pendingPark !== null, `${platform}: effect returned undefined without parking`);
    steps += 1;
    assert(steps < 64, `${platform}: park loop did not terminate`);
    const next = pendingPark;
    pendingPark = null;
    result = next();
  }
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
    if (platform === "linux") {
      assert.deepStrictEqual(state.closefromCalls, [3], "linux: bounded spawn must close fds >= 3");
      assert.deepStrictEqual(state.spawnFlags, [0x02 | 0x04 | 0x08], "linux: bounded spawn flags");
    } else {
      assert.deepStrictEqual(state.closefromCalls, [], "darwin: must not call addclosefrom_np");
      assert.deepStrictEqual(state.spawnFlags, [0x4000 | 0x02 | 0x04 | 0x08], "darwin: bounded spawn must set POSIX_SPAWN_CLOEXEC_DEFAULT");
      assert.deepStrictEqual(state.addcloseCalls, [10, 11, 12, 13, 14, 15], "darwin: bounded spawn must close pipe fds > 2");
    }
    assert.deepStrictEqual(state.signals, [{ pid: -4242, sig: 9 }], `${platform}: expected group kill on held leader`);
    assert.deepStrictEqual(state.waitpids, [{ pid: 4242, options: 1 }], `${platform}: expected nonblocking leader reap`);
    assert.strictEqual(state.parks.length, 1, `${platform}: expected one cooperative park while waiting for leader exit`);
    assert.strictEqual(state.parks[0].fd, undefined, `${platform}: leader wait must park on timer, not closed pipe`);
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

  // 6. Cooperative parking on EAGAIN during pipe read and WNOHANG == 0 during final reap.
  {
    const { result, state } = runScenario(platform, {
      leaderPid: 4242,
      leaderInitial: { state: "exited", rawStatus: 0 },
      stdoutChunks: ["EAGAIN", "hello"],
      stderrChunks: ["EAGAIN", "err"],
      maxOut: 0,
      ms: 5000,
      onWaitpid: (st, idx) => {
        const leader = st.children.get(4242);
        if (idx === 0) {
          leader.state = "running";
        } else {
          leader.state = "exited";
          leader.rawStatus = 3 << 8;
        }
      },
    });
    assert(state.parks.length >= 2, `${platform}: expected cooperative parks on EAGAIN and WNOHANG`);
    assert.strictEqual(state.parks[0].fd, 12, `${platform}: pipe park must watch open stdout fd`);
    assert.strictEqual(state.waitpids.length, 2, `${platform}: expected retry after WNOHANG == 0`);
    assert.deepStrictEqual(
      result,
      {
        $: "Done",
        value: { $: "Tuple", fst: 3, snd: { $: "Tuple", fst: "hello", snd: "err" } },
      },
      `${platform}: cooperative pump must preserve stdout, stderr, and exit code`,
    );
  }

  // 7. Unbounded run.raw pumps cooperatively through shared process_posix_spawn
  //    (with FD isolation, without SETPGROUP, autoreap check, or group kill).
  {
    const { result, state } = runScenario(platform, {
      unbounded: true,
      leaderPid: 4242,
      leaderInitial: { state: "running", rawStatus: 0 },
      stdoutChunks: ["EAGAIN", "hi"],
      stderrChunks: [],
      onWaitpid: (st, idx) => {
        if (idx === 1) {
          const leader = st.children.get(4242);
          leader.state = "exited";
          leader.rawStatus = 5 << 8;
        }
      },
    });
    assert.strictEqual(state.sigactions.length, 0, `${platform}: run.raw must not run bounded autoreap check`);
    assert.strictEqual(state.waitids.length, 0, `${platform}: run.raw must not call waitid`);
    assert.strictEqual(state.signals.length, 0, `${platform}: run.raw must not signal process group`);
    assert.deepStrictEqual(state.pgroups, [], `${platform}: run.raw must not create a new process group`);
    if (platform === "linux") {
      assert.deepStrictEqual(state.closefromCalls, [3], "linux: run.raw must close fds >= 3");
      assert.deepStrictEqual(state.spawnFlags, [0x04 | 0x08], "linux: run.raw spawn flags");
    } else {
      assert.deepStrictEqual(state.closefromCalls, [], "darwin: run.raw must not call addclosefrom_np");
      assert.deepStrictEqual(state.spawnFlags, [0x4000 | 0x04 | 0x08], "darwin: run.raw must set POSIX_SPAWN_CLOEXEC_DEFAULT");
      assert.deepStrictEqual(state.addcloseCalls, [10, 11, 12, 13, 14, 15], "darwin: run.raw must close pipe fds > 2");
    }
    assert(state.parks.length >= 2, `${platform}: run.raw must park cooperatively on pipe and waitpid`);
    assert.deepStrictEqual(
      result,
      {
        $: "Done",
        value: { $: "Tuple", fst: 5, snd: { $: "Tuple", fst: "hi", snd: "" } },
      },
      `${platform}: run.raw must return stdout and exit status`,
    );
  }
}

function checkSpawnLifecycle(platform) {
  const mac = platform === "darwin";
  const state = {
    errno: 0,
    nextFd: 10,
    openFds: new Set(),
    fcntlCalls: [],
    spawnFlags: [],
    pgroups: [],
    closefromCalls: [],
    addcloseCalls: [],
    waitpidCalls: 0,
    parked: [],
  };
  const sysImpl = {
    mac,
    ptr: realFfi.ptr,
    errno: () => state.errno,
    fcntl: (fd, cmd, arg) => {
      assert(state.openFds.has(fd), `${platform} spawn: fcntl on closed fd ${fd}`);
      state.fcntlCalls.push({ fd, cmd, arg });
      return 0;
    },
    close: (fd) => {
      assert(state.openFds.has(fd), `${platform} spawn: invalid close on fd ${fd}`);
      state.openFds.delete(fd);
      return 0;
    },
  };
  const fakeSymbols = {
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
    posix_spawn_file_actions_addclose: (_a, fd) => {
      state.addcloseCalls.push(fd);
      return 0;
    },
    posix_spawn_file_actions_addclosefrom_np: (_a, fromFd) => {
      state.closefromCalls.push(fromFd);
      return 0;
    },
    posix_spawnattr_init: () => 0,
    posix_spawnattr_destroy: () => 0,
    posix_spawnattr_setsigdefault: () => 0,
    posix_spawnattr_setsigmask: () => 0,
    posix_spawnattr_setpgroup: (_a, g) => {
      state.pgroups.push(g);
      return 0;
    },
    posix_spawnattr_setflags: (_a, f) => {
      state.spawnFlags.push(f);
      return 0;
    },
    sigemptyset: () => 0,
    sigaddset: () => 0,
    posix_spawnp: (pidPtr) => {
      new Int32Array(realFfi.toArrayBuffer(pidPtr, 0, 4))[0] = 5150;
      return 0;
    },
    waitpid: (pid, statusPtr, options) => {
      assert.strictEqual(pid, 5150, `${platform} spawn: unexpected waitpid pid`);
      assert.strictEqual(options, 1, `${platform} spawn: waitpid must use WNOHANG`);
      state.waitpidCalls += 1;
      if (state.waitpidCalls === 1) {
        return 0;
      }
      new Int32Array(realFfi.toArrayBuffer(statusPtr, 0, 4))[0] = 19 << 8;
      return pid;
    },
  };
  const loaded = loadEffects({
    platform,
    dlopenImpl: () => ({ symbols: fakeSymbols }),
    sysImpl,
    parkImpl: (fd, out, k, more, at) => {
      state.parked.push({ fd, out, k, more, at });
    },
  });
  const spawned = loaded.registered["process:spawn"](
    "/bin/fake",
    bendList([]),
    bendList([]),
    ".",
  );
  assert.strictEqual(spawned.$, "Done", `${platform}: spawn must succeed via posix_spawnp`);
  assert.strictEqual(spawned.value.fst, 5150, `${platform}: spawn pid mismatch`);
  assert.deepStrictEqual([...state.openFds].sort((a, b) => a - b), [11, 12, 14], `${platform}: child pipe ends must be closed`);
  assert.strictEqual(state.fcntlCalls.filter((c) => c.cmd === 2 && c.arg === 1).length, 6, `${platform}: all 6 pipe fds must be CLOEXEC`);
  assert.strictEqual(state.fcntlCalls.filter((c) => c.cmd === 4).length, 0, `${platform}: spawn parent pipes must stay blocking for Base File.read`);
  assert.deepStrictEqual(state.pgroups, [], `${platform}: spawn must not create a new process group`);
  if (platform === "linux") {
    assert.deepStrictEqual(state.closefromCalls, [3], "linux: spawn must close fds >= 3");
    assert.deepStrictEqual(state.spawnFlags, [0x04 | 0x08], "linux: spawn flags");
  } else {
    assert.deepStrictEqual(state.closefromCalls, [], "darwin: spawn must not call addclosefrom_np");
    assert.deepStrictEqual(state.spawnFlags, [0x4000 | 0x04 | 0x08], "darwin: spawn must set POSIX_SPAWN_CLOEXEC_DEFAULT");
    assert.deepStrictEqual(state.addcloseCalls, [10, 11, 12, 13, 14, 15], "darwin: spawn must close pipe fds > 2");
  }
  assert.deepStrictEqual(
    loaded.registered["process:wait"](9999, () => {}),
    { $: "Fail", code: 10 },
    `${platform}: wait on untracked pid must fail ECHILD`,
  );
  const first = loaded.registered["process:wait"](5150, () => {});
  assert.strictEqual(first, undefined, `${platform}: wait on running child must park`);
  assert.strictEqual(state.parked.length, 1, `${platform}: expected one timer park`);
  const second = state.parked[0].more();
  assert.deepStrictEqual(second, { $: "Done", value: 19 }, `${platform}: wait must reap child status`);
  assert.deepStrictEqual(
    loaded.registered["process:wait"](5150, () => {}),
    { $: "Fail", code: 10 },
    `${platform}: second wait must fail ECHILD`,
  );
}

checkFfiDescriptors();
checkPlatformMatrix("linux");
checkPlatformMatrix("darwin");
checkSpawnLifecycle("linux");
checkSpawnLifecycle("darwin");
console.log("process selector and fake-ffi ownership ok");
