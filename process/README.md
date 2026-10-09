# process

Run an executable with literal arguments and a child working directory. Stdin, stdout, and stderr are byte-exact.

```bend
import bend-kit-process@0.3.0.0/process.bend as Proc
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
```

`run(cmd, args, env, cwd, stdin)` takes the executable path, arguments, `KEY=VALUE` environment overrides, the child's working directory, and a stdin `Bytes`. It returns the exit status, stdout, and stderr. Arguments are passed literally to the executable.

`spawn(cmd, args, env, cwd)` returns the pid and the child's stdin, stdout, and stderr as `File` handles. Close stdin to send EOF, drain both pipes, then `wait`. Waiting before draining can deadlock on a full pipe.

`cwd` applies to the child before the executable starts. A relative directory is resolved from the parent's working directory; `"."` uses that directory. The parent's directory stays unchanged. Paths containing spaces are passed as one directory value. A directory that cannot be opened produces a spawn error.

When migrating from `0.2.0.0`, pass `"."` after `env` to keep using the parent's directory. `run.raw` takes the same directory argument before its octet-string stdin.

The exit status is 0..255, or 128 plus the signal number. `env` entries override the inherited environment. They do not replace it.

`read_stdin`, `cwd`, `chdir`, `pid`, `exit`, and `signal.poll` are the process-level effects. On the JS target, `run` blocks other Bend fibers until the child exits. Use `spawn` when the program must stay responsive. JS signal polling uses Bun's FFI C compiler to install a signal-safe handler.

The effects require macOS or Linux. Proofs do not cover `effs/process.c` and `effs/process.js`. There is no bench: spawn-and-pipe time mostly measures the OS.

CI runs `check.bend` through the native and Bun backends. Its directory case starts two children that wait for stdin, reads a different directory-local file from each child, and checks the parent's directory. It also checks captured output and a missing child directory.
