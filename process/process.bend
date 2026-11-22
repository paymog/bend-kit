# Subprocesses and process-level OS access, with byte-exact input and output.
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

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

# Like run.raw, bounded. The child leads its own process group. The call ends
# with SIGKILL to that group while it still holds the unreaped child, then
# reaps the child. ms is a deadline for the whole call (0: none); a miss is
# ETIMEDOUT. max_out caps stdout and stderr, each, in bytes (0: none); more is
# EFBIG. A descendant that keeps an output open holds the call until the
# deadline. A descendant that leaves the group (setsid, setpgid) escapes the
# kill. If anything else reaps the child first, nothing is signaled and the
# call fails with ECHILD; it also refuses (ECHILD) while SIGCHLD is ignored.
def run.bounded.raw(cmd: String, args: List<&2, String>, env: List<&2, String>,
                    cwd: String, stdin: String, ms: U32, max_out: U32) ->
  IO(Result<&1, &1, U32 & String, U32 & String & String>):
  import "./effs/process.c"
  import "./effs/process.js"

# Reaps a spawned child. A signaled child has status 128 + signal number.
# pid is 1..2147483647; 0 and larger are EINVAL, never group/any-child selectors.
def wait(pid: U32) -> IO(Result<&1, &1, U32 & String, U32>):
  import "./effs/process.c"
  import "./effs/process.js"

# Wait up to ms milliseconds; 0 means no deadline. ETIMEDOUT keeps the
# logical wait result available, not necessarily an unreaped OS child.
def wait.deadline(pid: U32, ms: U32) -> IO(Result<&1, &1, U32 & String, U32>):
  import "./effs/process.c"
  import "./effs/process.js"

# Signal one positive pid, not necessarily a spawned child; 0 probes access.
# The caller must account for PID reuse. This never selects a process group.
def kill(pid: U32, signal: U32) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/process.c"
  import "./effs/process.js"

# The host's ETIMEDOUT error code: 110 on Linux, 60 on macOS.
def etimedout() -> IO(U32):
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

# run with run.bounded.raw's deadline, output cap, and group kill.
def run.bounded(cmd: String, args: List<&2, String>, env: List<&2, String>,
                cwd: String, stdin: Bytes.Bytes, ms: U32, max_out: U32) ->
  IO(Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>):
  do IO<Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>>:
    result : Result<&1, &1, U32 & String, U32 & String & String> <-
      run.bounded.raw(cmd, args, env, cwd, Bytes.to_string(stdin), ms, max_out)
    return run.result(result)

# A deadline miss: code is the host's ETIMEDOUT, passed as timeout (from
# etimedout()), since ETIMEDOUT differs between systems.
def timed_out(timeout: U32, code: U32) -> Bool:
  U32.is_eq(code, timeout)

# Output past max_out: EFBIG is 27 on Linux and macOS.
def too_big(code: U32) -> Bool:
  U32.is_eq(code, 27)
