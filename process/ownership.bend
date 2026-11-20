# Run by ownership-check.sh with SIGCHLD ignored, so the kernel reaps every
# child at once and run.bounded can never hold its leader. run.bounded must
# then fail with ECHILD before it spawns anything, so no group is signaled.
# The script checks that the marker command never ran.
import Base
import ./process.bend as Proc
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

def ownership.yes(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("process ownership ok")
    case False{}:
      IO.die(Unit, 1, "run.bounded without its leader must fail with ECHILD")

# ECHILD is 10 on Linux and on macOS.
def ownership.expect(value: Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>) -> IO(Unit):
  match value:
    case Fail{(code, _)}:
      ownership.yes(U32.is_eq(code, 10))
    case Done{_}:
      IO.die(Unit, 1, "run.bounded ran although SIGCHLD is ignored")

def main() -> IO(Unit):
  do IO<Unit>:
    held : Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes> <-
      Proc.run.bounded("/bin/sh", ["-c", "echo ran > .process-ownership-marker"], [], ".",
        Bytes.from_string(""), 5000, 0)
    ownership.expect(held)
