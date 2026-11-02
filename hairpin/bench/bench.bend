# 1000 sequential GETs on one client: a base URL, a default header, and keep-alive sockets.
# Then 1000 GETs of a flaky URL with 2 retries and a closed circuit breaker: each answers 503, then 200.
import Base
import ../hairpin.bend as Hairpin
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import bend-kit-http@0.38.1.1/http.bend as Http
import bend-kit-time@0.3.0.0/time.bend as Time
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

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
    t0 : Nat <- Time.mono.us()
    r : Hairpin.Client & U32 <- loop(1000n, url, 0, (c, Fail{Hairpin.ErrHttp{Http.ErrBad{}}}))
    t1 : Nat <- Time.mono.us()
    report(op, t0, t1, r)

def main() -> IO(Unit):
  c = Hairpin.header(Hairpin.base(Hairpin.new(), "http://127.0.0.1:47840/api/"), "x-bench", "1")
  d = Hairpin.circuit(Hairpin.retry(Hairpin.base(Hairpin.new(), "http://127.0.0.1:47840/api/"), 2), Retry.Circuit{5n, 10000n, 30000n, 1n})
  do IO<Unit>:
    run("get_1000", "item", c)
    run("retry_1000", "flaky", d)
