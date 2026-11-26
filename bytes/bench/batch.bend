import Base
import ../../time/time.bend as Time

def count(value: Result<&1, &1, U32 & String, String>, fallback: U32) -> U32:
  match value:
    case Done{text}:
      Maybe.default(&2, U32, U32.read(text), fallback)
    case Fail{error}:
      fallback

def add(~S: Type, r: S & U32, acc: U32) -> S & (U32 & U32):
  (state, +value) = r
  (state, (value, (acc + value : U32)))

def advance(~S: Type, ~step: S -> S & U32, r: S & (U32 & U32)) -> S & (U32 & U32):
  (state, (last, acc)) = r
  add(~S, step(state), acc)

def loop(~S: Type, ~step: S -> S & U32, fuel: Nat, r: S & (U32 & U32)) -> S & (U32 & U32):
  match fuel:
    case 0n:
      r
    case 1n+rest:
      loop(~S, ~step, rest, advance(~S, ~step, r))

def done(~S: Type, +name: String, +iterations: U32, t0: Time.Duration, r: S & (U32 & U32)) -> IO(S):
  (next, (last, total)) = r
  do IO<S>:
    t1 : Time.Duration <- Time.mono()
    IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(last) ++ "\t" ++ U32.show(iterations) ++ "\t" ++ U32.show(total))
    return next

def timed(~S: Type, ~step: S -> S & U32, +name: String, +iterations: U32, state: S) -> IO(S):
  do IO<S>:
    t0 : Time.Duration <- Time.mono()
    done(~S, name, iterations, t0, loop(~S, ~step, U32.to_nat(iterations), (state, (0, 0))))

def state(~S: Type, r: S & (U32 & U32)) -> S:
  (next, checks) = r
  next

def run(~S: Type, ~step: S -> S & U32, name: String, initial: S) -> IO(S):
  do IO<S>:
    raw : Result<&1, &1, U32 & String, String> <- IO.get_env("BYTES_BENCH_COUNT")
    warm : Result<&1, &1, U32 & String, String> <- IO.get_env("BYTES_BENCH_WARMUP")
    ready : S = state(~S, loop(~S, ~step, U32.to_nat(count(warm, 0)), (initial, (0, 0))))
    timed(~S, ~step, name, U32.max(count(raw, 1), 1), ready)
