import Base
import ./ca_check.bend as Check

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    Check.main.args(~Check.run.stream, List.tail(&1, String, args))
