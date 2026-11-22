import Base
import ./check.bend as Check

def run(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case Con{one, Con{key1, Con{two, Con{key2, Con{base, Nil{}}}}}}:
      Check.mtls.run(one, key1, two, key2, base)
    case _:
      IO.die(Unit, 1, "mTLS needs four certificate paths and a server base URL")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    run(List.tail(&1, String, args))
