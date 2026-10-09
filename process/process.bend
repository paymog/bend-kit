# Subprocesses and process-level OS access, with byte-exact input and output.
import Base
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# Environment entries are KEY=VALUE; they override inherited variables.
# The command is an executable name or path, never a shell expression.
# Exit status is 0..255, or 128 + the terminating signal number.
# cwd is the child's directory; relative paths start at the parent's directory.
def run.raw(cmd: String, args: List<&2, String>, env: List<&2, String>,
            cwd: String, stdin: String) ->
  IO(Result<&1, &1, U32 & String, U32 & String & String>):
  import "./effs/process.c"
  import "./effs/process.js"

# A streaming child: pid, writable stdin, readable stdout and stderr.
# Close stdin to send EOF; drain both outputs before wait to avoid pipe deadlock.
def spawn(cmd: String, args: List<&2, String>, env: List<&2, String>, cwd: String) ->
  IO(Result<&1, &1, U32 & String, U32 & File & File & File>):
  import "./effs/process.c"
  import "./effs/process.js"

# Reaps a spawned child. A signaled child has status 128 + signal number.
def wait(pid: U32) -> IO(Result<&1, &1, U32 & String, U32>):
  import "./effs/process.c"
  import "./effs/process.js"

# Read up to max bytes from this program's standard input; empty at EOF.
def read_stdin(max: U32) -> IO(Result<&1, &1, U32 & String, String>):
  import "./effs/process.c"
  import "./effs/process.js"

def stdin.read(max: U32) -> IO(Result<&1, &1, U32 & String, String>):
  read_stdin(max)

# Terminates this program with the supplied status.
def exit.raw(code: U32) -> IO(Unit):
  import "./effs/process.c"
  import "./effs/process.js"

def exit(code: U32) -> IO(Unit):
  exit.raw(code)

def cwd() -> IO(Result<&1, &1, U32 & String, String>):
  import "./effs/process.c"
  import "./effs/process.js"

def chdir(path: String) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/process.c"
  import "./effs/process.js"

def hostname() -> IO(Result<&1, &1, U32 & String, String>):
  import "./effs/process.c"
  import "./effs/process.js"

def pid() -> IO(U32):
  import "./effs/process.c"
  import "./effs/process.js"

# Install SIGINT/SIGTERM handlers and take one pending event; 0 means none.
def signal.poll() -> IO(U32):
  import "./effs/process.c"
  import "./effs/process.js"

def run.result(r: Result<&1, &1, U32 & String, U32 & String & String>) ->
  Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>:
  match r:
    case Fail{err}:
      Fail{err}
    case Done{(code, out, err)}:
      Done{(code, Bytes.from_string(out), Bytes.from_string(err))}

def run(cmd: String, args: List<&2, String>, env: List<&2, String>,
        cwd: String, stdin: Bytes.Bytes) ->
  IO(Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>):
  do IO<Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>>:
    result : Result<&1, &1, U32 & String, U32 & String & String> <-
      run.raw(cmd, args, env, cwd, Bytes.to_string(stdin))
    return run.result(result)
