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
