import Base
import ./check.bend as Check
import ./pure.bend as Pure

def repeat(left: Nat) -> IO(Unit):
  match left:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        listener : Listener & U32 <- Check.local.listen()
        Check.retry.test(listener)
        repeat(p)

def main() -> IO(Unit):
  do IO<Unit>:
    Check.local.ok(String.eq(Check.retry.error(Pure.ErrRead{104, "connection reset"}), "ErrRead 104 connection reset"), "retry diagnostics: read error keeps errno and message")
    Check.local.ok(String.eq(Check.retry.error(Pure.ErrTimeout{}), "ErrTimeout"), "retry diagnostics: timeout stays distinct")
    repeat(100n)
