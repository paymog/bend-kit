# 1000 sequential GETs on one client: a base URL, a default header, and keep-alive sockets.
# Then 1000 GETs of a flaky URL with 2 retries and a closed circuit breaker: each answers 503, then 200.
import Base
import ../hairpin.bend as Hairpin
import ../retry.bend as Retry
import ../../http/http.bend as Http
import bend-kit-time@0.1.0.0/time.bend as Time
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# A failed request scores 0, so it changes the checksum.
def score(r: Result<&1, &1, Hairpin.Err, Http.Res>) -> U32:
  match r:
    case Fail{e}:
      0
    case Done{res}:
      Http.Res{status, headers, body} = res
      Bytes.Bytes{len, buf} = body
      (status + len : U32)

# r: the last client and result. The first call passes a placeholder Fail.
def loop(n: Nat, +url: String, +sum: U32, r: Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res>) -> IO(Hairpin.Client & U32):
  match n:
    case 0n:
      (c, m) = r
      IO.pure(Hairpin.Client & U32, (c, (sum + score(m) : U32)))
    case 1n+p:
      (c, m) = r
      +next = (sum + score(m) : U32)
      do IO<Hairpin.Client & U32>:
        got : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(c, url)
        loop(p, url, next, got)

# Microseconds on the monotonic clock.
def us(r: U32 & U32 & U32) -> Nat:
  (hi, lo, ns) = r
  Nat.add(Nat.mul(Nat.add(Nat.mul(U32.to_nat(hi), 1n+4294967295n), U32.to_nat(lo)), 1000000n), U32.to_nat((ns / 1000 : U32)))

def pad3(+s: String) -> String:
  Bool.pick(String, Nat.is_lt(String.length(s), 2n), "00" ++ s, Bool.pick(String, Nat.is_lt(String.length(s), 3n), "0" ++ s, s))

def show.ms(+d: Nat) -> String:
  Nat.show(Nat.div(d, 1000n)) ++ "." ++ pad3(Nat.show(Nat.mod(d, 1000n)))

def report(+op: String, +t0: Nat, +t1: Nat, r: Hairpin.Client & U32) -> IO(Unit):
  (c, +sum) = r
  do IO<Unit>:
    Hairpin.close(c)
    IO.print(op ++ "\t" ++ show.ms((t1 - t0 : Nat)) ++ "\t" ++ U32.show(sum))

def run(+op: String, +url: String, c: Hairpin.Client) -> IO(Unit):
  do IO<Unit>:
    t0 : U32 & U32 & U32 <- Time.mono.raw()
    r : Hairpin.Client & U32 <- loop(1000n, url, 0, (c, Fail{Hairpin.ErrHttp{Http.ErrBad{}}}))
    t1 : U32 & U32 & U32 <- Time.mono.raw()
    report(op, us(t0), us(t1), r)

def main() -> IO(Unit):
  c = Hairpin.header(Hairpin.base(Hairpin.new(), "http://127.0.0.1:47840/api/"), "x-bench", "1")
  d = Hairpin.circuit(Hairpin.retry(Hairpin.base(Hairpin.new(), "http://127.0.0.1:47840/api/"), 2), Retry.Circuit{5n, 10000n, 30000n, 1n})
  do IO<Unit>:
    run("get_1000", "item", c)
    run("retry_1000", "flaky", d)
