# Webhook verify benchmark: one fixed Standard Webhooks message, 10,000 verifies (see README.md).
import Base
import ../../time/time.bend as Clock
import ../webhooks.bend as Webhooks
import bend-kit-time@0.1.0.0/time.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# run.py signs the message at its start and passes the timestamp and signature in the environment.
def headers(ts: String, sig: String) -> Map<&2, List<&2, String>>:
  +h = Map.set(&2, List<&2, String>, Map.new(&2, List<&2, String>), "webhook-id", ["msg_p5jXN8AQM9LWM0D4loKWxJek"])
  +h2 = Map.set(&2, List<&2, String>, h, "webhook-timestamp", [ts])
  Map.set(&2, List<&2, String>, h2, "webhook-signature", [sig])

# The verified count and the last verified webhook-id.
def tally(r: Result<&1, &1, Webhooks.Err, String>, acc: U32 & String) -> U32 & String:
  match r:
    case Fail{e}:
      acc
    case Done{id}:
      (+n, last) = acc
      ((n + 1 : U32), id)

def fold(r: Bytes.Bytes & Result<&1, &1, Webhooks.Err, String>, acc: U32 & String) -> Bytes.Bytes & (U32 & String):
  (b, res) = r
  (b, tally(res, acc))

def loop(n: Nat, +now: Time.Instant, +h: Map<&2, List<&2, String>>, st: Bytes.Bytes & (U32 & String)) -> IO(U32 & String):
  match n:
    case 0n:
      (b, acc) = st
      IO.pure(U32 & String, acc)
    case 1n+p:
      (b, acc) = st
      do IO<U32 & String>:
        r : Bytes.Bytes & Result<&1, &1, Webhooks.Err, String> <- Webhooks.verify(["whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw"], now, h, b)
        loop(p, now, h, fold(r, acc))

def show(r: U32 & String) -> String:
  (+n, id) = r
  U32.show(n) ++ " " ++ id

def bench(+ts: String, sig: String) -> IO(Unit):
  now = Time.Instant.of_unix(Int.I64.from_u32(Maybe.default(&2, U32, U32.read(ts), 0)))
  do IO<Unit>:
    t0 : Clock.Duration <- Clock.mono()
    r : U32 & String <- loop(10000n, now, headers(ts, sig), (Bytes.from_string("{\"test\": 2432232314}"), (0, "")))
    t1 : Clock.Duration <- Clock.mono()
    IO.print("verify\t" ++ Clock.Duration.show_ms(Clock.Duration.sub(t1, t0)) ++ "\t" ++ show(r))

def main() -> IO(Unit):
  do IO<Unit>:
    ts : String <- IO.try(String, IO.get_env("WEBHOOK_TS"))
    sig : String <- IO.try(String, IO.get_env("WEBHOOK_SIG"))
    bench(ts, sig)
