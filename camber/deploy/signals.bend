# Dedicated-process signal bridge, not runtime cancellation.
import Base

def install() -> IO(Unit):
  import "./signals.c"
  import "./signals.js"

def requested() -> IO(Bool):
  import "./signals.c"
  import "./signals.js"

def request() -> IO(Unit):
  import "./signals.c"
  import "./signals.js"
