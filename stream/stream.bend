# Bounded packed-byte transfers between files and TCP/TLS sockets.
import Base
import bend-kit-files@0.1.1.1/files.bend as Files
import bend-kit-wire@0.4.6.1/wire.bend as Wire

type Error is Data:
  BadChunk{}
  Limit{}
  Read{code: U32, message: String}
  Write{code: U32, message: String}

type Outcome is Data:
  Complete{count: U32}
  Failed{count: U32, error: Error}

# Internal pure decisions, separated from the trusted effects.
type ReadAction is Data:
  End{}
  Over{}
  Forward{}

def chunk.valid(+chunk: U32) -> Bool:
  U32.is_ge(chunk, 1) && U32.is_le(chunk, 1048576)

# The one-byte probe is only requested after the entire cap was forwarded.
def request(+chunk: U32, +remaining: U32) -> U32:
  match remaining:
    case 0:
      1
    case _:
      U32.min(chunk, remaining)

def read.action.flags(zero: Bool, probe: Bool) -> ReadAction:
  match zero:
    case True{}:
      End{}
    case False{}:
      match probe:
        case True{}:
          Over{}
        case False{}:
          Forward{}

def read.action(len: U32, remaining: U32) -> ReadAction:
  read.action.flags(U32.is_zero(len), U32.is_zero(remaining))

type Transfer<-S: Type, -D: Type> is Type:
  More{source: S, destination: D, count: U32}
  Stop{source: S, destination: D, outcome: Outcome}

def file.read(source: File, max: U32, tls: Bool, ms: U32) ->
  IO(File & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Files.read.words(source, max)

def file.write(destination: File, len: U32, words: Array<U32>, tls: Bool) ->
  IO(File & Result<&1, &1, U32 & String, Unit>):
  Files.write.words(destination, len, words)

def socket.read.tls(tls: Bool, source: Socket, max: U32, ms: U32) ->
  IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  match tls:
    case True{}:
      Wire.tls.recv.words(source, max, ms)
    case False{}:
      Wire.recv.words(source, max, ms)

def socket.read(source: Socket, max: U32, tls: Bool, ms: U32) ->
  IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  socket.read.tls(tls, source, max, ms)

def socket.write.tls(tls: Bool, destination: Socket, len: U32, words: Array<U32>) ->
  IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match tls:
    case True{}:
      Wire.tls.send.words(destination, len, words)
    case False{}:
      Wire.send.words(destination, len, words)

def socket.write(destination: Socket, len: U32, words: Array<U32>, tls: Bool) ->
  IO(Socket & Result<&1, &1, U32 & String, Unit>):
  socket.write.tls(tls, destination, len, words)

def transfer.written(~S: Type, ~D: Type, source: S, count: U32, len: U32,
  pair: D & Result<&1, &1, U32 & String, Unit>) -> Transfer<S, D>:
  (destination, result) = pair
  match result:
    case Fail{(code, message)}:
      Stop{source, destination, Failed{count, Write{code, message}}}
    case Done{unit}:
      More{source, destination, (count + len : U32)}

def transfer.action(~S: Type, ~D: Type,
  ~write: D -> U32 -> Array<U32> -> Bool -> IO(D & Result<&1, &1, U32 & String, Unit>),
  action: ReadAction, source: S, destination: D, count: U32, +len: U32,
  words: Array<U32>, tls: Bool) -> IO(Transfer<S, D>):
  match action:
    case End{}:
      IO.pure(Transfer<S, D>, Stop{source, destination, Complete{count}})
    case Over{}:
      IO.pure(Transfer<S, D>, Stop{source, destination, Failed{count, Limit{}}})
    case Forward{}:
      do IO<Transfer<S, D>>:
        pair : D & Result<&1, &1, U32 & String, Unit> <- write(destination, len, words, tls)
        return transfer.written(~S, ~D, source, count, len, pair)

def transfer.read(~S: Type, ~D: Type,
  ~write: D -> U32 -> Array<U32> -> Bool -> IO(D & Result<&1, &1, U32 & String, Unit>),
  pair: S & Result<&1, &1, U32 & String, U32 & Array<U32>>,
  destination: D, count: U32, remaining: U32, tls: Bool) -> IO(Transfer<S, D>):
  (source, result) = pair
  match result:
    case Fail{(code, message)}:
      IO.pure(Transfer<S, D>, Stop{source, destination, Failed{count, Read{code, message}}})
    case Done{(+len, words)}:
      transfer.action(~S, ~D, ~write, read.action(len, remaining),
        source, destination, count, len, words, tls)

# cap+1 reads suffice even if every successful nonempty read contains one byte.
# Fuel is first among runtime parameters; no fixed read ceiling or unsafe recursion.
def transfer.loop(~S: Type, ~D: Type,
  ~read: S -> U32 -> Bool -> U32 -> IO(S & Result<&1, &1, U32 & String, U32 & Array<U32>>),
  ~write: D -> U32 -> Array<U32> -> Bool -> IO(D & Result<&1, &1, U32 & String, Unit>),
  fuel: Nat, state: Transfer<S, D>, +tls: Bool, +chunk: U32, +cap: U32, +ms: U32) ->
  IO(S & D & Outcome):
  match fuel:
    case 0n:
      match state:
        case Stop{source, destination, outcome}:
          IO.pure(S & D & Outcome, (source, destination, outcome))
        case More{source, destination, count}:
          # Unreachable under the read.words bounds and positive-progress contract.
          IO.pure(S & D & Outcome, (source, destination, Failed{count, Limit{}}))
    case 1n+rest:
      match state:
        case Stop{source, destination, outcome}:
          IO.pure(S & D & Outcome, (source, destination, outcome))
        case More{source, destination, +count}:
          +remaining = (cap - count : U32)
          do IO<S & D & Outcome>:
            pair : S & Result<&1, &1, U32 & String, U32 & Array<U32>> <-
              read(source, request(chunk, remaining), tls, ms)
            next : Transfer<S, D> <- transfer.read(~S, ~D, ~write,
              pair, destination, count, remaining, tls)
            transfer.loop(~S, ~D, ~read, ~write, rest, next, tls, chunk, cap, ms)

def transfer.start(~S: Type, ~D: Type,
  ~read: S -> U32 -> Bool -> U32 -> IO(S & Result<&1, &1, U32 & String, U32 & Array<U32>>),
  ~write: D -> U32 -> Array<U32> -> Bool -> IO(D & Result<&1, &1, U32 & String, Unit>),
  valid: Bool, source: S, destination: D, tls: Bool, chunk: U32, +cap: U32, ms: U32) ->
  IO(S & D & Outcome):
  match valid:
    case False{}:
      IO.pure(S & D & Outcome, (source, destination, Failed{0, BadChunk{}}))
    case True{}:
      transfer.loop(~S, ~D, ~read, ~write, 1n+U32.to_nat(cap),
        More{source, destination, 0}, tls, chunk, cap, ms)

# Return both handles on every outcome; never close or retry a failed chunk.
def file.file(source: File, destination: File, +chunk: U32, cap: U32) ->
  IO(File & File & Outcome):
  transfer.start(~File, ~File, ~file.read, ~file.write,
    chunk.valid(chunk), source, destination, False{}, chunk, cap, 0)

def file.socket(source: File, destination: Socket, tls: Bool, +chunk: U32, cap: U32) ->
  IO(File & Socket & Outcome):
  transfer.start(~File, ~Socket, ~file.read, ~socket.write,
    chunk.valid(chunk), source, destination, tls, chunk, cap, 0)

# ms is the unchanged per-read Wire deadline, including the one-byte cap probe.
def socket.file(source: Socket, destination: File, tls: Bool, +chunk: U32, cap: U32, ms: U32) ->
  IO(Socket & File & Outcome):
  transfer.start(~Socket, ~File, ~socket.read, ~file.write,
    chunk.valid(chunk), source, destination, tls, chunk, cap, ms)
