# process

Run a command without a shell. Stdin, stdout, and stderr are byte-exact.

```bend
import bend-kit-process@0.2.0.1/process.bend as Proc
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
```

`run` takes the executable path, arguments, `KEY=VALUE` environment overrides, and a stdin `Bytes`. It returns the exit status, stdout, and stderr. The command is not passed to a shell, so `";"` in an argument is data.

`spawn` returns the pid and the child's stdin, stdout, and stderr as `File` handles. Close stdin to send EOF, drain both pipes, then `wait`. Draining after `wait`, or waiting before the drain, can deadlock on a full pipe.

The exit status is 0..255, or 128 plus the signal number. `env` entries override the inherited environment. They do not replace it.

`read_stdin`, `cwd`, `chdir`, `pid`, `exit`, and `signal.poll` are the process-level effects. On the JS target, `run` blocks other Bend fibers until the child exits. Use `spawn` when the program must stay responsive. JS signal polling uses Bun's FFI C compiler to install a signal-safe handler.

The effects require macOS or Linux. Proofs do not cover `effs/process.c` and `effs/process.js`. There is no bench: spawn-and-pipe time mostly measures the OS.
