# Flush observation markers without yielding to other Bend computations.
import Base

def flush() -> IO(Unit):
  import "./probe_stdout.c"
  import "./probe_stdout.js"
