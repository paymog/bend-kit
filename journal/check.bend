import Base
# bend-kit-bytes@0.3.0.0
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import bend-kit-hash@0.1.0.0/hash.bend as Hash
import bend-kit-files@0.1.1.1/files.bend as Files
import ./journal.bend as J

def ok(good: Bool, +name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad " ++ name)

def codes(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{c}, t}:
      Con{c, codes(t)}

def push(acc: List<&2, String>, p: Bytes.Bytes) -> List<&2, String>:
  Con{Bytes.to_string(p), acc}

def tail(t: J.Tail) -> String:
  match t:
    case J.Clean{}:
      "clean"
    case J.Torn{}:
      "torn"
    case J.Corrupt{why}:
      "corrupt:" ++ why

def render(r: J.Replay<List<&2, String>, J.Cur>) -> String:
  J.Replay{acc, t, rest} = r
  J.Cur{b, +pos} = rest
  String.join(List.reverse(&2, String, acc), ",") ++ "|" ++ tail(t) ++ "|" ++ U32.show(pos)

def run(+max: U32, b: Bytes.Bytes) -> String:
  render(J.replay.bytes(~List<&2, String>, ~push, max, b, Nil{}))

def log(xs: List<&2, String>) -> Bytes.Bytes:
  match xs:
    case Nil{}:
      Bytes.new(0)
    case Con{s, t}:
      Bytes.append(J.frame(Bytes.from_string(s)), log(t))

# Frames of 17, 14 and 18 octets: they end at 17, 31 and 49.
def sample() -> Bytes.Bytes:
  log(["alpha", "be", "gamma!"])

def prefix(+k: U32) -> Bytes.Bytes:
  Bytes.snd(Bytes.slice(sample(), 0, k))

def at.edge(+k: U32, +edge: U32, +done: String) -> String:
  done ++ "|" ++ Bool.pick(String, U32.is_eq(k, edge), "clean", "torn") ++ "|" ++ U32.show(edge)

# What recovery of the first k octets of sample() must give.
def expect(+k: U32) -> String:
  Bool.pick(String, U32.is_lt(k, 17), at.edge(k, 0, ""),
  Bool.pick(String, U32.is_lt(k, 31), at.edge(k, 17, "alpha"),
  Bool.pick(String, U32.is_lt(k, 49), at.edge(k, 31, "alpha,be"), at.edge(k, 49, "alpha,be,gamma!"))))

def cuts(n: Nat, +k: U32, +bad: U32) -> U32:
  match n:
    case 0n:
      bad
    case 1n+m:
      cuts(m, (k + 1 : U32), (bad + Bool.pick(U32, String.eq(run(64, prefix(k)), expect(k)), 0, 1) : U32))

def field(r: Bytes.Bytes & Maybe<&2, U32>) -> U32:
  (b, m) = r
  J.cur.field(m)

def abc() -> Bytes.Bytes:
  J.frame(Bytes.from_string("abc"))

def pure() -> IO(Unit):
  do IO<Unit>:
    ok(U32.is_eq(J.list.crc(codes("123456789")), 3421780262) && U32.is_eq(Hash.crc32.str("123456789"), 3421780262), "model CRC-32 and Hash.crc32 agree on the check value")
    ok(U32.is_eq(field(Bytes.get.u32le(abc(), 0)), 3) && U32.is_eq(field(Bytes.get.u32le(abc(), 4)), U32.not(3)) && U32.is_eq(field(Bytes.get.u32le(abc(), 8)), Hash.crc32.str("abc")) && String.eq(Bytes.to_string(Bytes.snd(Bytes.slice(abc(), 12, 3))), "abc"), "a frame is len, not len, crc32, payload")
    ok(U32.is_eq(cuts(50n, 0, 0), 0), "every cut of a 3-record log recovers exactly its committed prefix")
    ok(String.eq(run(64, Bytes.snd(Bytes.slice(Bytes.set(sample(), 29, 0), 0, 40))), "alpha|corrupt:checksum mismatch|17"), "a damaged payload is corrupt, even before a torn tail")
    ok(String.eq(run(64, Bytes.set(sample(), 17, 9)), "alpha|corrupt:length check mismatch|17"), "a damaged length is corrupt, not torn")
    ok(String.eq(run(4, sample()), "|corrupt:length over max|0"), "a length over max is corrupt")
    ok(String.eq(run(64, Bytes.append(sample(), Bytes.new(16))), "alpha,be,gamma!|corrupt:length check mismatch|49"), "a zero-filled tail is corrupt")

# The consumer: a durable task list. "add x" opens task x; "done x" closes it.
def without(xs: List<&2, String>, +x: String) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      +rest = without(t, x)
      Bool.pick(List<&2, String>, String.eq(h, x), rest, Con{h, rest})

def task(ts: List<&2, String>, p: Bytes.Bytes) -> List<&2, String>:
  +open = ts
  +s = Bytes.to_string(p)
  Bool.pick(List<&2, String>, String.starts_with(s, "add "), List.append(&2, String, open, [String.drop(s, 4n)]),
    Bool.pick(List<&2, String>, String.starts_with(s, "done "), without(open, String.drop(s, 5n)), open))

def open(+path: String) -> IO(J.Journal & List<&2, String>):
  IO.try(J.Journal & List<&2, String>, J.open(~List<&2, String>, ~task, path, 1024, 1048576, Nil{}))

def end(j: J.Journal) -> J.Journal & U32:
  J.Journal{file, +max, +end, ok} = j
  (J.Journal{file, max, end, ok}, end)

def tasks(ts: List<&2, String>) -> String:
  String.join(ts, ",")

def refusal(x: Result<&1, &1, U32 & String, Unit>) -> String:
  match x:
    case Done{u}:
      "accepted"
    case Fail{(c, m)}:
      m

def added(r: J.Journal & Result<&1, &1, U32 & String, Unit>) -> IO(J.Journal):
  match r:
    case (j, x):
      do IO<J.Journal>:
        u : Unit <- IO.try(Unit, IO.pure(Result<&1, &1, U32 & String, Unit>, x))
        return j

def add(j: J.Journal, +s: String) -> IO(J.Journal):
  do IO<J.Journal>:
    r : J.Journal & Result<&1, &1, U32 & String, Unit> <- J.append(j, Bytes.from_string(s))
    added(r)

def add.unless(empty: Bool, j: J.Journal, +s: String) -> IO(J.Journal):
  match empty:
    case True{}:
      IO.pure(J.Journal, j)
    case False{}:
      add(j, s)

# The open tasks and the file's end at open; then s is appended unless it is empty.
def visit.at(+s: String, r: J.Journal & U32, +ts: String) -> IO(String & U32):
  match r:
    case (j, +e):
      do IO<String & U32>:
        j2 : J.Journal <- add.unless(String.is_empty(s), j, s)
        J.close(j2)
        return (ts, e)

def visit.opened(+s: String, a: J.Journal & List<&2, String>) -> IO(String & U32):
  match a:
    case (j, ts):
      visit.at(s, end(j), tasks(ts))

def visit(+path: String, +s: String) -> IO(String & U32):
  do IO<String & U32>:
    a : J.Journal & List<&2, String> <- open(path)
    visit.opened(s, a)

def over.end(+why: String, r: J.Journal & U32) -> IO(String & U32):
  match r:
    case (j, +e):
      do IO<String & U32>:
        J.close(j)
        return (why, e)

# A record over max: the refusal and the end after it.
def over.at(r: J.Journal & Result<&1, &1, U32 & String, Unit>) -> IO(String & U32):
  match r:
    case (j, x):
      over.end(refusal(x), end(j))

def over.opened(a: J.Journal & List<&2, String>) -> IO(String & U32):
  match a:
    case (j, ts):
      do IO<String & U32>:
        r : J.Journal & Result<&1, &1, U32 & String, Unit> <- J.append(j, Bytes.new(2000))
        over.at(r)

def over(+path: String) -> IO(String & U32):
  do IO<String & U32>:
    a : J.Journal & List<&2, String> <- open(path)
    over.opened(a)

def seen(r: String & U32, +want: String, +at: U32, +name: String) -> IO(Unit):
  match r:
    case (got, +e):
      ok(String.eq(got, want) && U32.is_eq(e, at), name)

def written(r: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match r:
    case (f, x):
      do IO<Unit>:
        File.close(f)
        u : Unit <- IO.try(Unit, IO.pure(Result<&1, &1, U32 & String, Unit>, x))
        return Unit{}

# Writes s as raw octets, as a crash or a disk might leave them.
def raw(+path: String, +mode: String, +s: String) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open(path, mode))
    r : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(f, codes(s))
    written(r)

def refused(r: Result<&1, &1, U32 & String, J.Journal & List<&2, String>>) -> String:
  match r:
    case Done{(j, ts)}:
      "opened"
    case Fail{(c, m)}:
      m

def corrupt(+path: String) -> IO(String):
  do IO<String>:
    e : Result<&1, &1, U32 & String, J.Journal & List<&2, String>> <- J.open(~List<&2, String>, ~task, path, 1024, 1048576, Nil{})
    return refused(e)

def seed(a: J.Journal & List<&2, String>) -> IO(Unit):
  match a:
    case (j0, ts):
      do IO<Unit>:
        j1 : J.Journal <- add(j0, "add write laws")
        j2 : J.Journal <- add(j1, "add prove laws")
        j3 : J.Journal <- add(j2, "done write laws")
        J.close(j3)

def stable(+a: String, b: String) -> Bool:
  String.eq(a, "journal: corrupt frame at offset 17: checksum mismatch") && String.eq(b, a)

# Frames of 26, 26 and 27 octets end at 79; "add ship it" ends at 102.
def durable(+dir: String) -> IO(Unit):
  +path = dir ++ "/tasks.journal"
  do IO<Unit>:
    a : J.Journal & List<&2, String> <- open(path)
    seed(a)
    b : String & U32 <- visit(path, "")
    seen(b, "prove laws", 79, "reopen replays every acknowledged append")
    raw(path, "a", String.take(Bytes.to_string(J.frame(Bytes.from_string("add lost"))), 7n))
    c : String & U32 <- visit(path, "add ship it")
    seen(c, "prove laws", 79, "a torn append is cut off at open")
    d : String & U32 <- visit(path, "")
    seen(d, "prove laws,ship it", 102, "an append after recovery lands on the committed prefix")
    o : String & U32 <- over(path)
    seen(o, "journal: record over max", 102, "a record over max is refused before any write")
    raw(path, "w", Bytes.to_string(Bytes.set(sample(), 29, 0)))
    e1 : String <- corrupt(path)
    e2 : String <- corrupt(path)
    ok(stable(e1, e2), "open refuses a corrupt journal and leaves it as it is")
    r1 : Result<&1, &1, U32 & String, Unit> <- Files.remove(path)
    r2 : Result<&1, &1, U32 & String, Unit> <- Files.remove(dir)
    return Unit{}

def main() -> IO(Unit):
  do IO<Unit>:
    pure()
    dir : String <- IO.try(String, Files.temp_dir())
    durable(dir)
