import Base
import ../../zlib/bench/bench.bend as Caller

def main() -> IO(Unit):
  do IO<Unit>:
    g : Result<&1, &1, U32 & String, File> <- File.open("out/payload.gz", "r")
    Caller.opened(~Caller.op.inflate, g)
