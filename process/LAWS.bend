import Base
import ./process.bend as Process
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

law run.failure:
  {Process.run.result(Fail{(2, "missing")}) == Fail{(2, "missing")} :
    Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>}

law run.output:
  {Process.run.result(Done{(7, "ok", "bad")}) ==
    Done{(7, Bytes.from_string("ok"), Bytes.from_string("bad"))} :
    Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>}
