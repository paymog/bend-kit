# Read-only current-format journal replay, before crash recovery.
import Base
import ./model.bend as Model
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import bend-kit-files@0.4.0.1/files.bend as Files
import bend-kit-journal@0.4.0.0/pure.bend as J

type Inspection<-A: Data> is Data:
  Inspection{state: Model.State<A>, tail: J.Tail, end: U32}

def Out(-A: Type) -> Type:
  Result<&1, &1, U32 & String, A>

type Replay<-A: Data> is Data:
  Accepted{state: Model.State<A>, offset: U32, index: U32}
  Rejected{offset: U32, index: U32}

def stepped(~A: Data, +offset: U32, +index: U32, len: U32, s: Maybe<&2, Model.State<A>>) -> Replay<A>:
  match s:
    case None{}:
      Rejected{offset, index}
    case Some{s}:
      Accepted{s, (offset + 12 + len : U32), (index + 1 : U32)}

def step(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, acc: Replay<A>, b: Bytes.Bytes) -> Replay<A>:
  match acc:
    case Rejected{offset, index}:
      Rejected{offset, index}
    case Accepted{s, offset, index}:
      Bytes.Bytes{+len, words} = b
      stepped(~A, offset, index, len, Model.replay.step(~A, ~pdec, Some{s}, Bytes.Bytes{len, words}))

def finish(~A: Data, r: J.Replay<Replay<A>, J.Cur>) -> Out(Inspection<A>):
  match r:
    case J.Replay{acc, J.Corrupt{why}, J.Cur{b, +pos}}:
      Fail{(22, "runner inspect: corrupt frame at offset " ++ U32.show(pos) ++ ": " ++ why)}
    case J.Replay{Rejected{offset, index}, J.Clean{}, J.Cur{b, pos}}:
      Fail{(22, "runner inspect: undecodable record at offset " ++ U32.show(offset) ++ ", index " ++ U32.show(index))}
    case J.Replay{Rejected{offset, index}, J.Torn{}, J.Cur{b, pos}}:
      Fail{(22, "runner inspect: undecodable record at offset " ++ U32.show(offset) ++ ", index " ++ U32.show(index) ++ " before torn suffix")}
    case J.Replay{Accepted{s, offset, index}, J.Clean{}, J.Cur{b, pos}}:
      Done{Inspection{s, J.Clean{}, pos}}
    case J.Replay{Accepted{s, offset, index}, J.Torn{}, J.Cur{b, pos}}:
      Done{Inspection{s, J.Torn{}, pos}}

def bytes(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, max: U32, b: Bytes.Bytes) -> Out(Inspection<A>):
  finish(~A, J.replay.bytes(~Replay<A>, ~(s => p => step(~A, ~pdec, s, p)), max, b, Accepted{Model.new(A), 0, 0}))

def read.more(over: Bool, f: File, +left: U32, b: Bytes.Bytes, acc: Bytes.Bytes, next: File -> U32 -> Bytes.Bytes -> IO(Out(Bytes.Bytes))) -> IO(Out(Bytes.Bytes)):
  match over:
    case True{}:
      do IO<Out(Bytes.Bytes)>:
        File.close(f)
        return Fail{(27, "runner inspect: file exceeds limit")}
    case False{}:
      Bytes.Bytes{+len, words} = b
      next(f, (left - len : U32), Bytes.append(acc, Bytes.Bytes{len, words}))

def read.got(r: File & Out(Bytes.Bytes), +left: U32, acc: Bytes.Bytes, next: File -> U32 -> Bytes.Bytes -> IO(Out(Bytes.Bytes))) -> IO(Out(Bytes.Bytes)):
  match r:
    case (f, Fail{e}):
      do IO<Out(Bytes.Bytes)>:
        File.close(f)
        return Fail{e}
    case (f, Done{Bytes.Bytes{0, words}}):
      do IO<Out(Bytes.Bytes)>:
        File.close(f)
        return Done{acc}
    case (f, Done{Bytes.Bytes{+len, words}}):
      read.more(U32.is_gt(len, left), f, left, Bytes.Bytes{len, words}, acc, next)

def read(n: Nat, f: File, +left: U32, acc: Bytes.Bytes) -> IO(Out(Bytes.Bytes)):
  match n:
    case 0n:
      do IO<Out(Bytes.Bytes)>:
        File.close(f)
        return Fail{(27, "runner inspect: file exceeds limit")}
    case 1n+p:
      do IO<Out(Bytes.Bytes)>:
        r : File & Out(Bytes.Bytes) <- Files.read_bytes(f, U32.min(1048576, Bool.pick(U32, U32.is_eq(left, 0), 1, left)))
        read.got(r, left, acc, f => left => b => read(p, f, left, b))

def opened(x: Out(File), +limit: U32) -> IO(Out(Bytes.Bytes)):
  match x:
    case Fail{e}:
      IO.pure(Out(Bytes.Bytes), Fail{e})
    case Done{f}:
      read(2n+U32.to_nat(limit), f, limit, Bytes.new(0))

def file.got(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, max: U32, r: Out(Bytes.Bytes)) -> Out(Inspection<A>):
  match r:
    case Fail{e}:
      Fail{e}
    case Done{b}:
      bytes(~A, ~pdec, max, b)

def file(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, path: String, max: U32, limit: U32) -> IO(Out(Inspection<A>)):
  do IO<Out(Inspection<A>)>:
    f : Out(File) <- File.open(path, "r")
    r : Out(Bytes.Bytes) <- opened(f, limit)
    return file.got(~A, ~pdec, max, r)
