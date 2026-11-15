# Reproducible property checks with generated inputs and greedy shrinking.
import Base
import bend-kit-random@0.1.0.1/random.bend as Rand
import ./generate.bend as Gen
import ./shrink.bend as Shrink

type Failure<-T: Type> is Type:
  Failure{seed: U32, trial: Nat, value: T}

# Scan candidates in order; a predicate returns its input so affine values work.
def smaller(~T: Type, ~test: T -> T & Bool, xs: List<&1, T>, tested: T & Bool) -> Maybe<&1, T>:
  match xs:
    case Nil{}:
      (candidate, ok) = tested
      match ok:
        case False{}:
          Some{candidate}
        case True{}:
          None{}
    case Con{x, rest}:
      (candidate, ok) = tested
      match ok:
        case False{}:
          Some{candidate}
        case True{}:
          smaller(~T, ~test, rest, test(x))

def smaller.start(~T: Type, ~test: T -> T & Bool, xs: List<&1, T>) -> Maybe<&1, T>:
  match xs:
    case Nil{}:
      None{}
    case Con{x, rest}:
      smaller(~T, ~test, rest, test(x))

def attempt.pair(~T: Type, ~shrink: T -> List<&1, T>, ~test: T -> T & Bool, pair: T & T) -> T & Maybe<&1, T>:
  (original, probe) = pair
  (original, smaller.start(~T, ~test, shrink(probe)))

def attempt(~T: Type, ~copy: T -> T & T, ~shrink: T -> List<&1, T>, ~test: T -> T & Bool, value: T) -> T & Maybe<&1, T>:
  attempt.pair(~T, ~shrink, ~test, copy(value))

# Each accepted failure restarts shrinking; fuel bounds user-supplied shrinkers.
def minimize(~T: Type, ~copy: T -> T & T, ~shrink: T -> List<&1, T>, ~test: T -> T & Bool,
  fuel: Nat, state: T & Maybe<&1, T>) -> T:
  match fuel:
    case 0n:
      (original, choice) = state
      Maybe.default(&1, T, choice, original)
    case 1n+p:
      (original, choice) = state
      match choice:
        case None{}:
          original
        case Some{candidate}:
          minimize(~T, ~copy, ~shrink, ~test, p, attempt(~T, ~copy, ~shrink, ~test, candidate))

def minimize.start(~T: Type, ~copy: T -> T & T, ~shrink: T -> List<&1, T>, ~test: T -> T & Bool,
  value: T) -> T:
  minimize(~T, ~copy, ~shrink, ~test, 1024n, attempt(~T, ~copy, ~shrink, ~test, value))

def draw.pair(~T: Type, ~test: T -> T & Bool, pair: T & Rand.Rng) -> (T & Bool) & Rand.Rng:
  (sample, next) = pair
  (test(sample), next)

def draw(~T: Type, ~gen: Rand.Rng -> T & Rand.Rng, ~test: T -> T & Bool, rng: Rand.Rng) -> (T & Bool) & Rand.Rng:
  draw.pair(~T, ~test, gen(rng))

def check.go(~T: Type, ~gen: Rand.Rng -> T & Rand.Rng, ~copy: T -> T & T,
  ~shrink: T -> List<&1, T>, ~test: T -> T & Bool,
  remaining: Nat, +seed: U32, +trial: Nat, state: (T & Bool) & Rand.Rng) -> Maybe<&1, Failure<T>>:
  match remaining:
    case 0n:
      None{}
    case 1n+p:
      match p:
        case 0n:
          (tested, next) = state
          (value, ok) = tested
          match ok:
            case False{}:
              Some{Failure{seed, trial, minimize.start(~T, ~copy, ~shrink, ~test, value)}}
            case True{}:
              None{}
        case 1n+q:
          (tested, next) = state
          (value, ok) = tested
          match ok:
            case False{}:
              Some{Failure{seed, trial, minimize.start(~T, ~copy, ~shrink, ~test, value)}}
            case True{}:
              check.go(~T, ~gen, ~copy, ~shrink, ~test, p, seed, (1n+trial), draw(~T, ~gen, ~test, next))

def check.start(~T: Type, ~gen: Rand.Rng -> T & Rand.Rng, ~copy: T -> T & T,
  ~shrink: T -> List<&1, T>, ~test: T -> T & Bool,
  remaining: Nat, seed: U32, rng: Rand.Rng) -> Maybe<&1, Failure<T>>:
  match remaining:
    case 0n:
      None{}
    case 1n+p:
      check.go(~T, ~gen, ~copy, ~shrink, ~test, remaining, seed, 0n, draw(~T, ~gen, ~test, rng))

# Return the first failure and its smallest reachable counterexample.
def check(~T: Type, ~gen: Rand.Rng -> T & Rand.Rng, ~copy: T -> T & T,
  ~shrink: T -> List<&1, T>, ~test: T -> T & Bool,
  +seed: U32, trials: Nat) -> Maybe<&1, Failure<T>>:
  check.start(~T, ~gen, ~copy, ~shrink, ~test, trials, seed, Rand.seed(seed))

# Print the seed and draw index so a failing check can be replayed.
def report(~T: Type, ~show: T -> String, result: Maybe<&1, Failure<T>>) -> IO(Bool):
  match result:
    case None{}:
      IO.pure(Bool, True{})
    case Some{Failure{seed, trial, value}}:
      do IO<Bool>:
        IO.print("property failed: seed=" ++ U32.show(seed) ++ " trial=" ++ Nat.show(trial) ++ " counterexample=" ++ show(value))
        return False{}

def run(~T: Type, ~gen: Rand.Rng -> T & Rand.Rng, ~copy: T -> T & T,
  ~shrink: T -> List<&1, T>, ~test: T -> T & Bool, ~show: T -> String,
  seed: U32, trials: Nat) -> IO(Bool):
  report(~T, ~show, check(~T, ~gen, ~copy, ~shrink, ~test, seed, trials))
