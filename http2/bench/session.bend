import Base
import ../http2.bend as H
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

def payload.sum(b: Bytes.Bytes) -> U32:
  H.with_number(U32, Bytes.get.u32be(b, 0), b => a =>
    H.with_number(U32, Bytes.get.u32be(b, 4), b => z => (a + z : U32)))

def step(r: H.Reply, k: H.Client -> U32 -> Maybe<&2, U32>) -> Maybe<&2, U32>:
  match r:
    case H.Failed{error}:
      None{}
    case H.Advanced{c, Nil{}, Con{H.Pong{data}, Nil{}}}:
      k(c, payload.sum(data))
    case _:
      None{}

def run(n: Nat, c: H.Client, +sum: U32) -> Maybe<&2, U32>:
  match n:
    case 0n:
      Some{sum}
    case 1n+p:
      step(H.client.receive(c, Bytes.from_string("\u{0}\u{0}\u{8}\u{6}\u{1}\u{0}\u{0}\u{0}\u{0}12345678")),
        next => value => run(p, next, (sum + value : U32)))

def result(m: Maybe<&2, U32>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "HTTP/2 session failed")
    case Some{n}:
      IO.print(U32.show(n))

def started(r: H.Reply) -> IO(Unit):
  match r:
    case H.Failed{error}:
      IO.die(Unit, 1, "server SETTINGS failed")
    case H.Advanced{c, Con{ack, Nil{}}, Nil{}}:
      result(run(10000n, c, 0))
    case _:
      IO.die(Unit, 1, "server SETTINGS was not acknowledged")

def session(r: H.Client & Bytes.Bytes) -> IO(Unit):
  (c, preface) = r
  started(H.client.receive(c, Bytes.set(Bytes.new(9), 3, 4)))

def main() -> IO(Unit):
  session(H.client.start())
