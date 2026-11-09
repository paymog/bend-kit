# process

Run an executable with literal arguments and a child working directory. Stdin, stdout, and stderr are byte-exact.

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

## Bounded runs

`run.bounded(cmd, args, env, cwd, stdin, ms, max_out)` is `run` for a child you do not trust to finish or to stay small. The child leads its own process group. When the call ends, for any reason, the whole group gets `SIGKILL`, and then the child is reaped, so no process the child started outlives the call. `run.bounded.raw` takes the same arguments with octet-string stdin.

- `ms` is a deadline for the whole call, in milliseconds; `0` means none. A miss fails with `ETIMEDOUT`. The deadline covers reading the output to its end and waiting for the child to exit. A background process that keeps stdout or stderr open holds the call until the deadline, as it holds `run` forever.
- `max_out` caps stdout and stderr, each, in bytes; `0` means no cap. Output of exactly `max_out` bytes is returned. One byte more fails with `EFBIG`, and the child is killed at once.
- A failed call returns no partial output.

`timed_out(code)` and `too_big(code)` classify the error code, so callers do not compare errno numbers: `ETIMEDOUT` is 110 on Linux and 60 on macOS, and `EFBIG` is 27 on both.

The group kill does not reach a descendant that leaves the group with `setsid` or `setpgid`. On the JS target, the child leads a new session, and Bun reaps it before the group kill. Members that are still alive keep the group id in use, so the kill reaches them.

## Deadlines and signals for spawned children

`wait.deadline(pid, ms)` is `wait` with a deadline in milliseconds (`0` means none). A miss fails with `ETIMEDOUT` and leaves the child unreaped. Then `wait`, `wait.deadline` or `kill` can follow.

`kill(pid, sig)` sends signal `sig` to a spawned child; `sig` `0` only checks that the child exists. Signal a child only before `wait` reaps it, because after that its pid can belong to another process.

`wait`, `wait.deadline`, and `kill` take a pid from 1 to 2147483647. `0` and larger values fail with `EINVAL`. The system calls would read them as a process group or as every process.

`read_stdin`, `cwd`, `chdir`, `pid`, `exit`, and `signal.poll` are process-level effects. On the JS target, `run` blocks other Bend fibers until the child exits. Use `spawn` when the program must stay responsive. JS signal polling uses Bun's FFI C compiler to install a signal-safe handler.

The effects require macOS or Linux. Proofs do not cover `effs/process.c` or `effs/process.js`. There is no pure hot path to benchmark. See [bench/README.md](bench/README.md) for the scope.

CI runs `check.bend` through the native and Bun backends. Its directory case starts two children that wait for stdin, reads a different directory-local file from each child, and checks the parent's directory. It also checks captured output and a missing child directory.
