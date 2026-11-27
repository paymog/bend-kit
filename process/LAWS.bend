import Base
import ./process.bend as Process
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes

law run.failure:
  {Process.run.result(Fail{(2, "missing")}) == Fail{(2, "missing")} :
    Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>}

law run.output:
  {Process.run.result(Done{(7, "ok", "bad")}) ==
    Done{(7, Bytes.from_string("ok"), Bytes.from_string("bad"))} :
    Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>}

# A deadline miss is the host's ETIMEDOUT, passed as timeout: 110 on Linux,
# 60 on macOS.
law timed_out.host:
  {(Process.timed_out(110, 110), Process.timed_out(60, 60)) ==
    (True{}, True{}) : Bool & Bool}

# The other system's number is not a miss: on Linux 60 is ENOSTR. Nor are
# EFBIG or success.
law timed_out.other:
  {(Process.timed_out(110, 60), Process.timed_out(60, 110),
    Process.timed_out(110, 27), Process.timed_out(110, 0)) ==
    (False{}, False{}, False{}, False{}) : Bool & Bool & Bool & Bool}

law too_big.efbig:
  {Process.too_big(27) == True{} : Bool}

law too_big.other:
  {(Process.too_big(110), Process.too_big(60), Process.too_big(0)) ==
    (False{}, False{}, False{}) : Bool & Bool & Bool}
