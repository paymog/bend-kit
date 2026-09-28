# Download benchmark: fetches the URL in argv 1 and prints the body length and the time.
#   python3 dl.py 18094 &; ./fetch16 http://127.0.0.1:18094/cl
import Base
import ../../time/time.bend as Time
import ../http.bend as Http
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def report(+t0: Time.Duration, +t1: Time.Duration, r: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("fail")
    case Done{res}:
      Http.Res{status, headers, body} = res
      Bytes.Bytes{+len, buf} = body
      IO.print({U32.show(status) ++ " " ++ U32.show(len) ++ " " ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ " ms" : String})

def url(xs: List<&1, String>) -> String:
  match xs:
    case Nil{}:
      "http://127.0.0.1:18094/cl"
    case Con{x, t}:
      x

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    t0 : Time.Duration <- Time.mono()
    r : Result<&1, &1, Http.Err, Http.Res> <- Http.fetch("GET", url(args), Http.set(Http.empty(), "accept-encoding", "identity"), Bytes.new(0))
    t1 : Time.Duration <- Time.mono()
    report(t0, t1, r)
