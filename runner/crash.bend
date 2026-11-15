# check.bend runs this as a child process that dies at a chosen point: `bend crash.bend <mode> <path>`.
# attempt: completes job x, then dies inside job y's attempt.
# snapshot: completes job x, writes and fsyncs the compaction snapshot, then dies before the rename.
# compacted: completes job x, compacts the journal, then dies inside job z's attempt.
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-journal@0.3.0.1/journal.bend as J
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import ./runner.bend as R

def penc(s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def pdec(b: Bytes.Bytes) -> Maybe<&2, String>:
  Some{Bytes.to_string(b)}

def note.close(r: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (f, x) = r
  File.close(f)

def note(+log: String, +spec: String) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open(log, "a"))
    r : File & Result<&1, &1, U32 & String, Unit> <- File.write(f, spec ++ "\n")
    note.close(r)

def die.if(crash: Bool) -> IO(Retry.Outcome):
  match crash:
    case True{}:
      IO.die(Retry.Outcome, 9, "crash: killed inside an attempt")
    case False{}:
      IO.pure(Retry.Outcome, Retry.Settled{})

def work.go(xs: List<&2, String>) -> IO(Retry.Outcome):
  match xs:
    case Con{log, Con{+spec, Nil{}}}:
      do IO<Retry.Outcome>:
        note(log, spec)
        die.if(String.starts_with(spec, "crash:"))
    case _:
      IO.pure(Retry.Outcome, Retry.Settled{})

def work(s: String) -> IO(Retry.Outcome):
  work.go(String.split(s, '|'))

def target(s: String) -> String:
  "local"

def config() -> R.Config:
  R.Config{Retry.Policy{3n, 1n, 4, None{}}, Retry.Circuit{100n, 60000n, 60000n, 1n}, 5, 0}

def enq.got(y: R.Runner<String> & R.Out(Nat)) -> IO(R.Runner<String>):
  match y:
    case (r, Done{i}):
      IO.pure(R.Runner<String>, r)
    case (r, Fail{(c, m)}):
      IO.die(R.Runner<String>, 1, "crash: enqueue failed: " ++ m)

def enq(r: R.Runner<String>, +d: Nat, +x: String) -> IO(R.Runner<String>):
  do IO<R.Runner<String>>:
    y : R.Runner<String> & R.Out(Nat) <- R.enqueue(~String, ~penc, r, d, x)
    enq.got(y)

def ticked(t: R.Runner<String> & R.Out(Bool)) -> IO(R.Runner<String>):
  match t:
    case (r, Done{b}):
      IO.pure(R.Runner<String>, r)
    case (r, Fail{(c, m)}):
      IO.die(R.Runner<String>, 1, "crash: tick failed: " ++ m)

def ran(y: R.Ran(String)) -> IO(R.Runner<String>):
  match y:
    case (r, Done{u}):
      IO.pure(R.Runner<String>, r)
    case (r, Fail{(c, m)}):
      IO.die(R.Runner<String>, 1, "crash: compact failed: " ++ m)

def appended(x: J.Journal & R.Out(Unit)) -> IO(Unit):
  match x:
    case (j, Done{u}):
      do IO<Unit>:
        J.close(j)
        IO.die(Unit, 9, "crash: killed before the rename")
    case (j, Fail{(c, m)}):
      IO.die(Unit, 1, "crash: snapshot append failed: " ++ m)

def fst(x: J.Journal & Unit) -> J.Journal:
  (j, u) = x
  j

# The first half of R.compact: the snapshot is durable in path.compact, and the journal is not yet replaced.
def snapshot(+path: String, x: R.Runner<String> & R.State<String>) -> IO(Unit):
  (r, s) = x
  do IO<Unit>:
    j : J.Journal & Unit <- IO.try(J.Journal & Unit, J.open(~Unit, ~(a => b => a), path ++ ".compact", 1048576, 1048576, Unit{}))
    y : J.Journal & R.Out(Unit) <- J.append(fst(j), R.encode.snap(~String, ~penc, s))
    appended(y)

# One unit of capacity, so x completes before y starts.
def attempt(+path: String) -> IO(Unit):
  +log = path ++ ".log"
  do IO<Unit>:
    r0 : R.Runner<String> <- IO.try(R.Runner<String>, R.open(~String, ~penc, ~pdec, path, 4096, 1048576, config(), 1n))
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|ok:x")
    r2 : R.Runner<String> <- enq(r1, 1n, log ++ "|crash:y")
    y : R.Ran(String) <- R.drain(~String, ~penc, ~target, ~work, 100n, r2)
    IO.die(Unit, 1, "crash: the attempt did not kill the process")

# x is due now and y in 2096, so one tick runs x alone.
def snapped(+path: String) -> IO(Unit):
  +log = path ++ ".log"
  do IO<Unit>:
    r0 : R.Runner<String> <- IO.try(R.Runner<String>, R.open(~String, ~penc, ~pdec, path, 4096, 1048576, config(), 1n))
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|ok:x")
    r2 : R.Runner<String> <- enq(r1, Nat.mul(4000n, 1000000000n), log ++ "|ok:y")
    t : R.Runner<String> & R.Out(Bool) <- R.tick(~String, ~penc, ~target, ~work, r2)
    r3 : R.Runner<String> <- ticked(t)
    snapshot(path, R.state(String, r3))

def compacted(+path: String) -> IO(Unit):
  +log = path ++ ".log"
  do IO<Unit>:
    r0 : R.Runner<String> <- IO.try(R.Runner<String>, R.open(~String, ~penc, ~pdec, path, 4096, 1048576, config(), 1n))
    r1 : R.Runner<String> <- enq(r0, 0n, log ++ "|ok:x")
    t : R.Runner<String> & R.Out(Bool) <- R.tick(~String, ~penc, ~target, ~work, r1)
    r2 : R.Runner<String> <- ticked(t)
    y : R.Ran(String) <- R.compact(~String, ~penc, r2)
    r3 : R.Runner<String> <- ran(y)
    r4 : R.Runner<String> <- enq(r3, 0n, log ++ "|crash:z")
    z : R.Ran(String) <- R.drain(~String, ~penc, ~target, ~work, 100n, r4)
    IO.die(Unit, 1, "crash: the attempt did not kill the process")

def mode(snap: Bool, comp: Bool, +path: String) -> IO(Unit):
  match snap comp:
    case True{} _:
      snapped(path)
    case False{} True{}:
      compacted(path)
    case False{} False{}:
      attempt(path)

def run.go(+m: String, +path: String) -> IO(Unit):
  mode(String.eq(m, "snapshot"), String.eq(m, "compacted"), path)

def run(xs: List<String>) -> IO(Unit):
  match xs:
    case Con{prog, Con{m, Con{path, Nil{}}}}:
      run.go(m, path)
    case _:
      IO.die(Unit, 2, "usage: crash.bend <attempt|snapshot|compacted> <path>")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(args)
