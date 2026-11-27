# Paired certified and proved Newton runs on the retained integer input.
import Base
import ../bench.bend as B
import ../../../time/time.bend as Time
import bend-kit-stats@0.1.8.0/stats.bend as Certified

def certified(a: U32, b: U32) -> U32:
  Certified.U32.isqrt(a)

def run(n: Nat) -> IO(Unit):
  +pairs = B.integer.inputs(n)
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    a : U32 = B.integer.sum(~B.integer.identity, pairs, 0)
    t1 : Time.Duration <- Time.mono()
    B.integer.line("identity_shared", t0, t1, a)
    t2 : Time.Duration <- Time.mono()
    b : U32 = B.integer.sum(~certified, pairs, 0)
    t3 : Time.Duration <- Time.mono()
    B.integer.line("certified_shared", t2, t3, b)
    t4 : Time.Duration <- Time.mono()
    c : U32 = B.integer.sum(~B.integer.isqrt, pairs, 0)
    t5 : Time.Duration <- Time.mono()
    B.integer.line("proved_shared", t4, t5, c)
    t6 : Time.Duration <- Time.mono()
    d : U32 = B.integer.sum(~B.integer.identity, pairs, 0)
    t7 : Time.Duration <- Time.mono()
    B.integer.line("identity_release", t6, t7, d)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    run(B.integer.count(args))
