import Base
import ./check.bend as Check

def run(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case Con{h2, Con{streams, Nil{}}}:
      do IO<Unit>:
        Check.h2.idle(h2)
        Check.h2.stream(streams)
    case _:
      IO.die(Unit, 1, "HTTP/2 needs two server base URLs")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    run(List.tail(&1, String, args))
