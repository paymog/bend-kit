# A diamond build run with real commands: order, single runs, reuse, invalidation, cycles, missing nodes, and a failed command.
import Base
import ./planner.bend as P
import bend-kit-files@0.4.0.1/files.bend as Files
import bend-kit-process@0.5.2.1/process.bend as Proc
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes

# A diamond whose middle tasks each sleep for a second, logging when they start (+) and end (-).
def PT() -> List<&2, P.Task>:
  [P.Task{"app2", ["lib2", "gen2"], ["sh", "-c", "echo app >> plog"], []},
   P.Task{"lib2", ["base2"], ["sh", "-c", "echo lib+ >> plog; sleep 1; echo lib- >> plog"], []},
   P.Task{"gen2", ["base2"], ["sh", "-c", "echo gen+ >> plog; sleep 1; echo gen- >> plog"], []},
   P.Task{"base2", [], ["sh", "-c", "echo base >> plog"], []}]

def probe.job(+c: Chan(U32)) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes> <- Proc.run("sleep", ["0.3"], [], ".", Bytes.new(0))
    s : Result<&1, &1, U32, Unit> <- Chan.send(U32, c, 1)
    return Unit{}

# Whether this runtime runs two commands at once. The JavaScript lane runs one at a time.
def probe() -> IO(Bool):
  do IO<Bool>:
    t0 : Nat <- IO.now()
    +c : Chan(U32) <- Chan.new(U32, 2)
    IO.spawn(Unit, probe.job(c))
    IO.spawn(Unit, probe.job(c))
    a : Maybe<&1, U32> <- Chan.recv(U32, c)
    b : Maybe<&1, U32> <- Chan.recv(U32, c)
    t1 : Nat <- IO.now()
    return Nat.is_lt(Nat.sub(t1, t0), 500n)

def ok(good: Bool, +name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad " ++ name)

def parallel(conc: Bool, +got: String) -> IO(Unit):
  match conc:
    case True{}:
      ok(Bool.or(Bool.or(String.eq(got, "base lib+ gen+ lib- gen- app"), String.eq(got, "base lib+ gen+ gen- lib- app")),
           Bool.or(String.eq(got, "base gen+ lib+ lib- gen- app"), String.eq(got, "base gen+ lib+ gen- lib- app"))),
        "the middle tasks of a diamond run at once, after base and before app: " ++ got)
    case False{}:
      ok(String.eq(got, "base lib+ lib- gen+ gen- app"),
        "this runtime runs one command at a time; the diamond still runs in order: " ++ got)

# Each task appends its name to log, then writes its output from its input and prerequisites.
def sh(+name: String, +script: String) -> List<&2, String>:
  ["sh", "-c", "echo " ++ name ++ " >> log && " ++ script]

def tasks(+gen: List<&2, String>) -> List<&2, P.Task>:
  [P.Task{"app", ["lib", "gen"], sh("app", "cat lib.out gen.out > app.out"), []},
   P.Task{"lib", ["base"], sh("lib", "cat base.out lib.txt > lib.out"), ["lib.txt"]},
   P.Task{"gen", ["base"], gen, ["gen.txt"]},
   P.Task{"base", [], sh("base", "cat base.txt > base.out"), ["base.txt"]}]

def GEN() -> List<&2, String>:
  sh("gen", "cat base.out gen.txt > gen.out")

# A failed command shows its exit code, stdout, and stderr.
def ran(s: P.Status, r: Maybe<&2, P.Ran>) -> String:
  match s r:
    case P.Failed{} Some{P.Exited{code, out, err}}:
      "[" ++ U32.show(code) ++ " out=" ++ out ++ " err=" ++ err ++ "]"
    case P.Failed{} Some{P.Unstarted{e}}:
      "[unstarted]"
    case _ _:
      ""

def shown(es: List<&2, P.Outcome>) -> String:
  match es:
    case Nil{}:
      ""
    case Con{P.Outcome{x, +s, r}, Nil{}}:
      x ++ ":" ++ P.Status.show(s) ++ ran(s, r)
    case Con{P.Outcome{x, +s, r}, t}:
      x ++ ":" ++ P.Status.show(s) ++ ran(s, r) ++ " " ++ shown(t)

def unstarted(r: Result<&1, &1, U32 & String, List<&2, P.Outcome>>) -> IO(Unit):
  match r:
    case Done{es}:
      +got : String = shown(es)
      ok(String.starts_with(got, "x:failed["), "a command that does not start fails: " ++ got)
    case Fail{(code, msg)}:
      IO.die(Unit, 1, "bad unstarted: " ++ msg)

def write(+path: String, +text: String) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open(path, "w"))
    r : File & Result<&1, &1, U32 & String, Unit> <- File.write(f, text)
    IO.try(Unit, P.stamps.closed(r))

def read.got(r: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  match r:
    case (f, x):
      do IO<String>:
        File.close(f)
        IO.pass(String, x)

def read(+path: String) -> IO(String):
  do IO<String>:
    f : File <- IO.try(File, File.open(path, "r"))
    r : File & Result<&1, &1, U32 & String, String> <- File.read(f, 65536)
    read.got(r)

def build(+dir: String, +gen: List<&2, String>, +targets: List<&2, String>, +want: String, +name: String) -> IO(Unit):
  do IO<Unit>:
    es : List<&2, P.Outcome> <- IO.try(List<&2, P.Outcome>, P.build(tasks(gen), targets, dir, dir ++ "/stamps", 1))
    +got : String = shown(es)
    ok(String.eq(got, want), name ++ ": " ++ got)

def log(+dir: String, +want: String, +name: String) -> IO(Unit):
  do IO<Unit>:
    +got : String <- read(dir ++ "/log")
    ok(String.eq(got, want), name)

def refused(r: Result<&1, &1, U32 & String, List<&2, P.Outcome>>, +want: String, +name: String) -> IO(Unit):
  match r:
    case Done{es}:
      IO.die(Unit, 1, "bad " ++ name ++ ": planned " ++ shown(es))
    case Fail{(code, +msg)}:
      ok(String.eq(msg, want), name ++ ": " ++ msg)

def main() -> IO(Unit):
  do IO<Unit>:
    +dir : String <- IO.try(String, Files.temp_dir())
    write(dir ++ "/base.txt", "base\n")
    write(dir ++ "/lib.txt", "lib\n")
    write(dir ++ "/gen.txt", "gen 1\n")
    build(dir, GEN(), ["app"], "base:built lib:built gen:built app:built", "first build runs every task")
    log(dir, "base\nlib\ngen\napp\n", "each task runs once, after its prerequisites")
    +out : String <- read(dir ++ "/app.out")
    ok(String.eq(out, "base\nlib\nbase\ngen 1\n"), "the outputs flow along the edges")
    build(dir, GEN(), ["app"], "base:fresh lib:fresh gen:fresh app:fresh", "an unchanged build runs nothing")
    write(dir ++ "/gen.txt", "gen 2\n")
    build(dir, GEN(), ["app"], "base:fresh lib:fresh gen:built app:built", "a changed input reruns its task and its dependents")
    log(dir, "base\nlib\ngen\napp\ngen\napp\n", "only the stale tasks ran")
    build(dir, sh("gen", "echo boom >&2; exit 3"), ["app"], "base:fresh lib:fresh gen:failed[3 out= err=boom\n] app:skipped", "a failed command skips its dependents and keeps its output")
    r0 : Result<&1, &1, U32 & String, List<&2, P.Outcome>> <-
      P.build([P.Task{"x", [], ["/nonexistent/tool"], []}], ["x"], dir, dir ++ "/stamps3", 1)
    unstarted(r0)
    build(dir, GEN(), ["app"], "base:fresh lib:fresh gen:built app:built", "a failed task and its dependents run again")
    r1 : Result<&1, &1, U32 & String, List<&2, P.Outcome>> <-
      P.build([P.Task{"a", ["b"], [], []}, P.Task{"b", ["c"], [], []}, P.Task{"c", ["a"], [], []}], ["a"], dir, dir ++ "/stamps2", 2)
    refused(r1, "cycle: a -> b -> c -> a", "a cycle has no plan")
    r2 : Result<&1, &1, U32 & String, List<&2, P.Outcome>> <-
      P.build([P.Task{"a", ["b"], [], []}, P.Task{"b", ["nope"], [], []}], ["a"], dir, dir ++ "/stamps2", 2)
    refused(r2, "missing node nope, required by a -> b", "a missing node has no plan")
    log(dir, "base\nlib\ngen\napp\ngen\napp\ngen\ngen\napp\n", "a refused plan runs nothing")
    +conc : Bool <- probe()
    p : Result<&1, &1, U32 & String, List<&2, P.Outcome>> <- P.build(PT(), ["app2"], dir, dir ++ "/stamps4", 2)
    +plog : String <- read(dir ++ "/plog")
    parallel(conc, String.join(String.lines(String.trim_end(plog)), " "))
