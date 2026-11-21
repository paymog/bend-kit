# File reads for packed F32 arrays, kept outside the pure proof imports.
import Base
import ./f32array.bend as A
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-files@0.4.0.0/files.bend as Files

# A file read in progress: more bytes to read, or the final result.
type Read is Type:
  More{file: File, acc: Bytes.Bytes, left: U32}
  Stop{file: File, result: Result<&1, &1, U32 & String, Bytes.Bytes>}

def read.next(more: Bool, file: File, acc: Bytes.Bytes, +left: U32) -> Read:
  match more:
    case True{}:
      More{file, acc, left}
    case False{}:
      Stop{file, Done{acc}}

# A read of no bytes ends the loop early, so a file that shrank stops there.
def read.step(got: File & Result<&1, &1, U32 & String, Bytes.Bytes>, acc: Bytes.Bytes, +left: U32) -> Read:
  (file, r) = got
  match r:
    case Fail{e}:
      Stop{file, Fail{e}}
    case Done{Bytes.Bytes{+m, buf}}:
      +rest = (left - U32.min(m, left) : U32)
      read.next(Bool.and(U32.is_ne(m, 0), U32.is_ne(rest, 0)), file, Bytes.append(acc, Bytes.Bytes{m, buf}), rest)

# Each pass reads at least one byte or stops, so left + 1 passes are enough.
def read.loop(n: Nat, st: Read) -> IO(File & Result<&1, &1, U32 & String, Bytes.Bytes>):
  match n:
    case 0n:
      match st:
        case More{file, acc, left}:
          IO.pure(File & Result<&1, &1, U32 & String, Bytes.Bytes>, (file, Done{acc}))
        case Stop{file, result}:
          IO.pure(File & Result<&1, &1, U32 & String, Bytes.Bytes>, (file, result))
    case 1n+p:
      match st:
        case More{file, acc, +left}:
          do IO<File & Result<&1, &1, U32 & String, Bytes.Bytes>>:
            got : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Files.read_bytes(file, U32.min(left, 1048576))
            read.loop(p, read.step(got, acc, left))
        case Stop{file, result}:
          IO.pure(File & Result<&1, &1, U32 & String, Bytes.Bytes>, (file, result))

def read.sized(sz: File & Result<&1, &1, U32 & String, U32>) -> IO(File & Result<&1, &1, U32 & String, Bytes.Bytes>):
  (file, r) = sz
  match r:
    case Fail{e}:
      IO.pure(File & Result<&1, &1, U32 & String, Bytes.Bytes>, (file, Fail{e}))
    case Done{+n}:
      read.loop(1n+U32.to_nat(n), read.next(U32.is_ne(n, 0), file, Bytes.new(0), n))

def read.decode(m: Maybe<&1, A.F32Array>) -> Result<&1, &1, U32 & String, A.F32Array>:
  match m:
    case None{}:
      Fail{(22, "f32array: the file size is not a multiple of 4")}
    case Some{a}:
      Done{a}

def read.fin(~f: Bytes.Bytes -> Maybe<&1, A.F32Array>, got: File & Result<&1, &1, U32 & String, Bytes.Bytes>) -> File & Result<&1, &1, U32 & String, A.F32Array>:
  (file, r) = got
  match r:
    case Fail{e}:
      (file, Fail{e})
    case Done{b}:
      (file, read.decode(f(b)))

def read.with(~f: Bytes.Bytes -> Maybe<&1, A.F32Array>, file: File) -> IO(File & Result<&1, &1, U32 & String, A.F32Array>):
  do IO<File & Result<&1, &1, U32 & String, A.F32Array>>:
    sz : File & Result<&1, &1, U32 & String, U32> <- File.size(file)
    got : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- read.sized(sz)
    return read.fin(~f, got)

# The rest of an open file, four little-endian bytes per element. Fails EINVAL when its size is not a multiple of 4.
def read.le(file: File) -> IO(File & Result<&1, &1, U32 & String, A.F32Array>):
  read.with(~A.from_bytes.le, file)

# The rest of an open file, four big-endian bytes per element. Fails EINVAL when its size is not a multiple of 4.
def read.be(file: File) -> IO(File & Result<&1, &1, U32 & String, A.F32Array>):
  read.with(~A.from_bytes.be, file)
