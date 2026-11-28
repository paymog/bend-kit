import Base
import ./check.bend as Check

def main() -> IO(Unit):
  Check.retry.stress(100n)
