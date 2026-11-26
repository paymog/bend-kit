# File reads for packed F32 arrays, kept outside the pure proof imports.
import Base
import ./f32array.bend as A
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-files@0.4.0.3/files.bend as Files

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

type Tensor is Type:
  Tensor{array: A.F32Array, bits: U32, used: U32, index: U32}

def tensor.byte(full: Bool, array: A.F32Array, +bits: U32, +used: U32, +index: U32, +width: U32) -> Tensor:
  match full:
    case True{}:
      Tensor{A.set(array, index, A.of_bits((bits << U32.to_nat(((4 - width : U32) * 8 : U32)) : U32))), 0, 0, (index + 1 : U32)}
    case False{}:
      Tensor{array, bits, used, index}

def tensor.take(state: Tensor, +width: U32, byte: U32) -> Tensor:
  Tensor{array, bits, +used, index} = state
  tensor.byte(U32.is_eq((used + 1 : U32), width), array,
    (bits .|. (byte << U32.to_nat((used * 8 : U32))) : U32),
    (used + 1 : U32), index, width)

def tensor.bytes(n: Nat, pair: Array<U32> & U32, +at: U32, state: Tensor, +width: U32) -> Tensor:
  match n:
    case 0n:
      state
    case 1n+p:
      (words, byte) = pair
      tensor.bytes(p, Bytes.peek(words, (at + 1 : U32)), (at + 1 : U32), tensor.take(state, width, byte), width)

type AtRead is Type:
  AtMore{file: File, hi: U32, lo: U32, left: U32, state: Tensor}
  AtStop{file: File, array: A.F32Array, result: Result<&1, &1, U32 & String, Unit>}

def read.at.stop(file: File, state: Tensor, result: Result<&1, &1, U32 & String, Unit>) -> AtRead:
  Tensor{array, bits, used, index} = state
  AtStop{file, array, result}

def read.at.next(done: Bool, file: File, hi: U32, lo: U32, left: U32, state: Tensor) -> AtRead:
  match done:
    case True{}:
      read.at.stop(file, state, Done{Unit{}})
    case False{}:
      AtMore{file, hi, lo, left, state}

def read.at.bytes(empty: Bool, file: File, +hi: U32, +lo: U32, +left: U32, state: Tensor, +got: U32, words: Array<U32>, +width: U32) -> AtRead:
  match empty:
    case True{}:
      read.at.stop(file, state, Fail{(5, "f32array: unexpected end of tensor")})
    case False{}:
      +next = (lo + got : U32)
      +carry = Bool.pick(U32, U32.is_lt(next, lo), 1, 0)
      read.at.next(U32.is_eq(got, left), file, (hi + carry : U32), next,
        (left - got : U32), tensor.bytes(U32.to_nat(got), Bytes.peek(words, 0), 0, state, width))

def read.at.step(pair: File & Result<&1, &1, U32 & String, U32 & Array<U32>>, hi: U32, lo: U32, left: U32, state: Tensor, +width: U32) -> AtRead:
  (file, result) = pair
  match result:
    case Fail{e}:
      read.at.stop(file, state, Fail{e})
    case Done{(+got, words)}:
      read.at.bytes(U32.is_eq(got, 0), file, hi, lo, left, state, got, words, width)

def read.at.loop(n: Nat, state: AtRead, +width: U32) -> IO(File & A.F32Array & Result<&1, &1, U32 & String, Unit>):
  match n:
    case 0n:
      match state:
        case AtMore{file, hi, lo, left, Tensor{array, bits, used, index}}:
          IO.pure(File & A.F32Array & Result<&1, &1, U32 & String, Unit>, (file, array, Fail{(5, "f32array: incomplete tensor")}))
        case AtStop{file, array, result}:
          IO.pure(File & A.F32Array & Result<&1, &1, U32 & String, Unit>, (file, array, result))
    case 1n+p:
      match state:
        case AtMore{file, +hi, +lo, +left, tensor}:
          do IO<File & A.F32Array & Result<&1, &1, U32 & String, Unit>>:
            pair : File & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Files.read.words.at(file, hi, lo, U32.min(left, 1048576))
            read.at.loop(p, read.at.step(pair, hi, lo, left, tensor, width), width)
        case AtStop{file, array, result}:
          IO.pure(File & A.F32Array & Result<&1, &1, U32 & String, Unit>, (file, array, result))

def read.at.valid(+hi: U32, +lo: U32, +n: U32, +width: U32) -> Bool:
  +bytes = (n * width : U32)
  +carry = Bool.pick(U32, U32.is_lt((lo + bytes : U32), lo), 1, 0)
  Bool.and(U32.is_le(n, (4294967292 / width : U32)),
    Bool.and(U32.is_lt(hi, 2147483648), U32.is_lt((hi + carry : U32), 2147483648)))

def read.at.into.start(valid: Bool, file: File, hi: U32, lo: U32, +n: U32, +width: U32, array: A.F32Array, start: U32) -> IO(File & A.F32Array & Result<&1, &1, U32 & String, Unit>):
  match valid:
    case False{}:
      IO.pure(File & A.F32Array & Result<&1, &1, U32 & String, Unit>, (file, array, Fail{(22, "f32array: source or destination range is invalid")}))
    case True{}:
      +bytes = (n * width : U32)
      read.at.loop(1n+U32.to_nat(bytes),
        read.at.next(U32.is_eq(n, 0), file, hi, lo, bytes, Tensor{array, 0, 0, start}), width)

def read.at.into.with(file: File, +hi: U32, +lo: U32, +n: U32, +width: U32, array: A.F32Array, +start: U32) -> IO(File & A.F32Array & Result<&1, &1, U32 & String, Unit>):
  A.F32Array{+len, buf} = array
  read.at.into.start(Bool.and(read.at.valid(hi, lo, n, width),
    Bool.and(U32.is_le(start, len), U32.is_le(n, (len - U32.min(start, len) : U32)))),
    file, hi, lo, n, width, A.F32Array{len, buf}, start)

# Both handles return on error; complete elements read before an IO error stay written.
def read.le.at.into(file: File, hi: U32, lo: U32, n: U32, array: A.F32Array, start: U32) -> IO(File & A.F32Array & Result<&1, &1, U32 & String, Unit>):
  read.at.into.with(file, hi, lo, n, 4, array, start)

def read.bf16.at.into(file: File, hi: U32, lo: U32, n: U32, array: A.F32Array, start: U32) -> IO(File & A.F32Array & Result<&1, &1, U32 & String, Unit>):
  read.at.into.with(file, hi, lo, n, 2, array, start)

def read.at.result(pair: File & A.F32Array & Result<&1, &1, U32 & String, Unit>) -> File & Result<&1, &1, U32 & String, A.F32Array>:
  (file, array, result) = pair
  match result:
    case Fail{e}:
      (file, Fail{e})
    case Done{unit}:
      (file, Done{array})

def read.at.start(valid: Bool, file: File, hi: U32, lo: U32, +n: U32, width: U32) -> IO(File & Result<&1, &1, U32 & String, A.F32Array>):
  match valid:
    case False{}:
      IO.pure(File & Result<&1, &1, U32 & String, A.F32Array>, (file, Fail{(22, "f32array: tensor size or offset is out of range")}))
    case True{}:
      do IO<File & Result<&1, &1, U32 & String, A.F32Array>>:
        pair : File & A.F32Array & Result<&1, &1, U32 & String, Unit> <- read.at.into.start(True{}, file, hi, lo, n, width, A.new(n), 0)
        return read.at.result(pair)

def read.at.with(file: File, +hi: U32, +lo: U32, +n: U32, +width: U32) -> IO(File & Result<&1, &1, U32 & String, A.F32Array>):
  read.at.start(read.at.valid(hi, lo, n, width), file, hi, lo, n, width)

# Exactly n elements at hi * 2^32 + lo bytes; the file position does not move.
def read.le.at(file: File, hi: U32, lo: U32, n: U32) -> IO(File & Result<&1, &1, U32 & String, A.F32Array>):
  read.at.with(file, hi, lo, n, 4)

# Little-endian BF16 bits become the top 16 bits of each F32, without arithmetic.
def read.bf16.at(file: File, hi: U32, lo: U32, n: U32) -> IO(File & Result<&1, &1, U32 & String, A.F32Array>):
  read.at.with(file, hi, lo, n, 2)
