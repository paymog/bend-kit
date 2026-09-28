# 1000 sequential GETs on one client: a base URL, a default header, and keep-alive sockets.
import Base
import ../hairpin.bend as Hairpin
import bend-kit-http@0.23.0.1/http.bend as Http
import ../../time/time.bend as Time
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# A failed request scores 0, so it changes the checksum.
def score(r: Result<&1, &1, Http.Err, Http.Res>) -> U32:
  match r:
    case Fail{e}:
      0
    case Done{res}:
      Http.Res{status, headers, body} = res
      Bytes.Bytes{len, buf} = body
      (status + len : U32)

# r: the last client and result. The first call passes a placeholder Fail.
def loop(n: Nat, +sum: U32, r: Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>) -> IO(Hairpin.Client & U32):
  match n:
    case 0n:
      (c, m) = r
      IO.pure(Hairpin.Client & U32, (c, (sum + score(m) : U32)))
    case 1n+p:
      (c, m) = r
      +next = (sum + score(m) : U32)
      do IO<Hairpin.Client & U32>:
        got : Hairpin.Client & Result<&1, &1, Http.Err, Http.Res> <- Hairpin.get(c, "item")
        loop(p, next, got)

def report(+t0: Time.Duration, +t1: Time.Duration, r: Hairpin.Client & U32) -> IO(Unit):
  (c, +sum) = r
  do IO<Unit>:
    Hairpin.close(c)
    IO.print("get_1000\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(sum))

def main() -> IO(Unit):
  c = Hairpin.header(Hairpin.base(Hairpin.new(), "http://127.0.0.1:47840/api/"), "x-bench", "1")
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    r : Hairpin.Client & U32 <- loop(1000n, 0, (c, Fail{Http.ErrBad{}}))
    t1 : Time.Duration <- Time.mono()
    report(t0, t1, r)
