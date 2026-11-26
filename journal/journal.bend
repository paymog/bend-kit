# Append-only journal: checksummed frames, fsync'd appends, and crash recovery of the committed prefix. Source: https://github.com/paymog/bend-kit/tree/main/journal
import Base
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import ./pure.bend as Pure

# Effects. Each one finishes its write with fsync (F_FULLFSYNC on macOS in C) before it answers.

# Opens path for reading and appending, creating it, and fsyncs its directory. Answers the file and
# its whole contents. Fails with EFBIG when the file holds more than limit octets.
def open.words(path: String, limit: U32) -> IO(Result<&1, &1, U32 & String, File & U32 & Array<U32>>):
  import "./effs/journal.c"
  import "./effs/journal.js"

# Writes len octets of words at the end of file, then fsyncs it.
def append.words(file: File, len: U32, words: Array<U32>) -> IO(File & Result<&1, &1, U32 & String, Unit>):
  import "./effs/journal.c"
  import "./effs/journal.js"

# Cuts file to len octets, then fsyncs it.
def truncate(file: File, len: U32) -> IO(File & Result<&1, &1, U32 & String, Unit>):
  import "./effs/journal.c"
  import "./effs/journal.js"

# An open journal. max caps a record's length. end is the file's length. ok turns False when an
# append fails: what reached the disk is then unknown, so appends stop until the journal is reopened.
type Journal is Type:
  Journal{file: File, max: U32, end: U32, ok: Bool}

def open.cut(r: File & Result<&1, &1, U32 & String, Unit>, +max: U32, +end: U32, -A: Type, acc: A) -> IO(Result<&1, &1, U32 & String, Journal & A>):
  match r:
    case (file, Fail{e}):
      do IO<Result<&1, &1, U32 & String, Journal & A>>:
        File.close(file)
        return Fail{e}
    case (file, Done{u}):
      do IO<Result<&1, &1, U32 & String, Journal & A>>:
        return Done{(Journal{file, max, end, True{}}, acc)}

def open.tail(t: Pure.Tail, file: File, +max: U32, +pos: U32, -A: Type, acc: A) -> IO(Result<&1, &1, U32 & String, Journal & A>):
  match t:
    case Pure.Clean{}:
      do IO<Result<&1, &1, U32 & String, Journal & A>>:
        return Done{(Journal{file, max, pos, True{}}, acc)}
    case Pure.Torn{}:
      do IO<Result<&1, &1, U32 & String, Journal & A>>:
        r : File & Result<&1, &1, U32 & String, Unit> <- truncate(file, pos)
        open.cut(r, max, pos, A, acc)
    case Pure.Corrupt{why}:
      do IO<Result<&1, &1, U32 & String, Journal & A>>:
        File.close(file)
        return Fail{(22, "journal: corrupt frame at offset " ++ U32.show(pos) ++ ": " ++ why)}

def open.replayed(file: File, +max: U32, -A: Type, r: Pure.Replay<A, Pure.Cur>) -> IO(Result<&1, &1, U32 & String, Journal & A>):
  Pure.Replay{acc, t, rest} = r
  Pure.Cur{b, +pos} = rest
  open.tail(t, file, max, pos, A, acc)

def open.read(~A: Type, ~step: A -> Bytes.Bytes -> A, r: Result<&1, &1, U32 & String, File & U32 & Array<U32>>, +max: U32, acc: A) -> IO(Result<&1, &1, U32 & String, Journal & A>):
  match r:
    case Fail{e}:
      do IO<Result<&1, &1, U32 & String, Journal & A>>:
        return Fail{e}
    case Done{(file, (len, words))}:
      open.replayed(file, max, A, Pure.replay.bytes(~A, ~step, max, Bytes.Bytes{len, words}, acc))

# Opens the journal at path and folds step over its committed records, from acc.
# A torn tail is cut off and fsynced before open answers. A corrupt frame fails with EINVAL and
# its offset; the file is left as it is. max caps a record's length; limit caps the file's size.
def open(~A: Type, ~step: A -> Bytes.Bytes -> A, path: String, +max: U32, limit: U32, acc: A) -> IO(Result<&1, &1, U32 & String, Journal & A>):
  do IO<Result<&1, &1, U32 & String, Journal & A>>:
    r : Result<&1, &1, U32 & String, File & U32 & Array<U32>> <- open.words(path, limit)
    open.read(~A, ~step, r, max, acc)

def append.back(+max: U32, +end: U32, +len: U32, r: File & Result<&1, &1, U32 & String, Unit>) -> Journal & Result<&1, &1, U32 & String, Unit>:
  match r:
    case (file, Done{u}):
      (Journal{file, max, (end + len : U32), True{}}, Done{u})
    case (file, Fail{e}):
      (Journal{file, max, end, False{}}, Fail{e})

def append.write(file: File, +max: U32, +end: U32, f: Bytes.Bytes) -> IO(Journal & Result<&1, &1, U32 & String, Unit>):
  Bytes.Bytes{+len, words} = f
  do IO<Journal & Result<&1, &1, U32 & String, Unit>>:
    r : File & Result<&1, &1, U32 & String, Unit> <- append.words(file, len, words)
    return append.back(max, end, len, r)

def append.refuse(file: File, +max: U32, +end: U32, +ok: Bool, e: U32 & String) -> IO(Journal & Result<&1, &1, U32 & String, Unit>):
  do IO<Journal & Result<&1, &1, U32 & String, Unit>>:
    return (Journal{file, max, end, ok}, Fail{e})

# The file stays under 4 GiB, so every offset and the next open's read fit a U32.
def append.size(over: Bool, big: Bool, file: File, +max: U32, +end: U32, p: Bytes.Bytes) -> IO(Journal & Result<&1, &1, U32 & String, Unit>):
  match over big:
    case True{} _:
      append.refuse(file, max, end, True{}, (22, "journal: record over max"))
    case False{} True{}:
      append.refuse(file, max, end, True{}, (27, "journal: file would reach 4 GiB"))
    case False{} False{}:
      append.write(file, max, end, Pure.frame(p))

def append.ok(ok: Bool, file: File, +max: U32, +end: U32, p: Bytes.Bytes) -> IO(Journal & Result<&1, &1, U32 & String, Unit>):
  match ok:
    case False{}:
      append.refuse(file, max, end, False{}, (5, "journal: an append failed; reopen the journal"))
    case True{}:
      Bytes.Bytes{+len, buf} = p
      append.size(U32.is_gt(len, max), Bool.or(U32.is_gt(end, 4294967283), U32.is_lt((4294967283 - end : U32), len)), file, max, end, Bytes.Bytes{len, buf})

# Appends p as one frame and answers once it is fsynced: Done means durable, under the trust
# assumptions in README.md. After a Fail the record may or may not survive a reopen.
def append(j: Journal, p: Bytes.Bytes) -> IO(Journal & Result<&1, &1, U32 & String, Unit>):
  Journal{file, +max, +end, ok} = j
  append.ok(ok, file, max, end, p)

def close(j: Journal) -> IO(Unit):
  Journal{file, max, end, ok} = j
  File.close(file)
