import Base
import ./process.bend as Process
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

law run.failure:
  {Process.run.result(Fail{(2, "missing")}) == Fail{(2, "missing")} :
    Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>}

law run.output:
  {Process.run.result(Done{(7, "ok", "bad")}) ==
    Done{(7, Bytes.from_string("ok"), Bytes.from_string("bad"))} :
    Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>}

# A deadline miss is ETIMEDOUT on either system.
law timed_out.linux:
  {Process.timed_out(110) == True{} : Bool}

law timed_out.macos:
  {Process.timed_out(60) == True{} : Bool}

# Other failures are not deadline misses: EFBIG, ENOENT, success.
law timed_out.other:
  {(Process.timed_out(27), Process.timed_out(2), Process.timed_out(0)) ==
    (False{}, False{}, False{}) : Bool & Bool & Bool}

law too_big.efbig:
  {Process.too_big(27) == True{} : Bool}

law too_big.other:
  {(Process.too_big(110), Process.too_big(60), Process.too_big(0)) ==
    (False{}, False{}, False{}) : Bool & Bool & Bool}
