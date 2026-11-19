# process

Run an executable with literal arguments and a child working directory. Stdin, stdout, and stderr are byte-exact.

`wait` accepts PID values from `1` through `2147483647`. Zero and larger values return `EINVAL` before reaching the host wait operation; they cannot select a process group or an arbitrary child.

## Bounded runs

`run.bounded(cmd, args, env, cwd, stdin, ms, max_out)` is `run` for a child you do not trust to finish or to stay small. `run.bounded.raw` takes the same arguments with octet-string stdin.

- `ms` is a deadline for the whole call, in milliseconds; `0` means none. A miss fails with the host's `ETIMEDOUT`. The deadline covers reading the output to its end and waiting for the child to exit. A background process that keeps stdout or stderr open holds the call until the deadline, as it holds `run` forever.
- `max_out` caps stdout and stderr, each, in bytes; `0` means no cap. Output of exactly `max_out` bytes is returned. One byte more fails with `EFBIG`, and the child is killed at once.
- A failed call returns no partial output.

`timed_out(timeout, code)` and `too_big(code)` classify the error code. Pass `etimedout()` as `timeout`, because `ETIMEDOUT` is 110 on Linux and 60 on macOS; `EFBIG` is 27 on both.

The child leads its own process group. When the call ends, for any reason, the group gets `SIGKILL` while the call still holds the unreaped child, so the group id cannot have been reused. Then the child is reaped. Both targets spawn, signal and reap the child themselves: the native target in C, the JS target through libc `posix_spawn` over `bun:ffi`, so Bun never sees or reaps the child. Nothing else in the program may reap the leader concurrently: the ownership check and the group signal are not atomic. If the check finds the leader already reaped, the call returns `ECHILD` without signaling the group. While `SIGCHLD` is ignored, or set to `SA_NOCLDWAIT`, the kernel reaps children by itself, so the call refuses with `ECHILD`.

The group kill is not containment. A descendant that leaves the group with `setsid` or `setpgid` escapes it, and so does anything it started. A descendant that inherited a pipe can hold the call until the deadline. The deadline bounds the call, not the cleanup: the kill and the final reap come after it, so the call can return a little later than `ms`. It is not a hard real-time bound.

The JS target needs `bun:ffi`, and `posix_spawn_file_actions_addchdir_np` from glibc 2.29 or later, or from macOS 10.15 or later. It was tested with Bun 1.4.2, the version CI pins, and with Bun 1.4.4.

```bend
import bend-kit-process@0.5.1.0/process.bend as Proc
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
```

`process.bend` imports `bend-kit-bytes@0.3.3.0`. Use this bytes version for `run` input and output.

`run(cmd, args, env, cwd, stdin)` takes the executable name or path, arguments, `KEY=VALUE` environment overrides, the child's working directory, and stdin as `Bytes`. It returns an `IO` result with the exit status, stdout, and stderr, or an error. It does not pass the command to a shell. Thus, `";"` in an argument is data.

`cwd` applies to the child before the executable starts. A relative directory is resolved from the parent's working directory; `"."` uses that directory. The parent's directory stays unchanged. Paths containing spaces are passed as one directory value. A directory that cannot be opened produces a spawn error.

When migrating from `0.3.0.0`, pass `"."` after `env` to keep using the parent's directory. `run.raw` takes the same directory argument before its octet-string stdin.

`spawn(cmd, args, env, cwd)` returns an `IO` result with the child PID and its stdin, stdout, and stderr as `File` handles. Close stdin to send EOF. Drain both output pipes before you call `wait`. Waiting before you drain them can deadlock on a full pipe.

The exit status is 0 to 255, or 128 plus the signal number. `env` entries override the inherited environment. They do not replace it.

`read_stdin`, `cwd`, `chdir`, `pid`, `exit`, and `signal.poll` are process-level effects. On the JS target, `run` blocks other Bend fibers until the child exits. Use `spawn` when the program must stay responsive. JS signal polling uses Bun's FFI C compiler to install a signal-safe handler.

The effects require macOS or Linux. Proofs do not cover `effs/process.c` or `effs/process.js`. There is no pure hot path to benchmark. See [bench/README.md](bench/README.md) for the scope.

CI runs `check.bend` through the native and Bun backends. Its directory case starts two children that wait for stdin, reads a different directory-local file from each child, and checks the parent's directory. It also checks captured output and a missing child directory.
