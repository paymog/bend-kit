# Stream-open benchmark: 200 small streams to the URL in argv 1, each on a new connection, then on one pool.
#   python3 keepalive.py 18095 &; ./streams http://127.0.0.1:18095/
import Base
import ../../time/time.bend as Time
import ../http.bend as Http
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

def body.step(fuel: Nat, +n: U32, m: Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Bytes.Bytes>>) -> IO(Http.Stream & U32):
  match fuel:
    case 0n:
      (st, r) = m
      IO.pure(Http.Stream & U32, (st, n))
    case 1n+f:
      (st, r) = m
      match r:
        case Fail{e}:
          IO.pure(Http.Stream & U32, (st, n))
        case Done{piece}:
          match piece:
            case None{}:
              IO.pure(Http.Stream & U32, (st, n))
            case Some{b}:
              Bytes.Bytes{+len, buf} = b
              do IO<Http.Stream & U32>:
                next : Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Bytes.Bytes>> <- Http.stream.read(st)
                body.step(f, (n + len : U32), next)

def body.all(st: Http.Stream) -> IO(Http.Stream & U32):
  do IO<Http.Stream & U32>:
    m : Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Bytes.Bytes>> <- Http.stream.read(st)
    body.step(64n, 0, m)

def fresh.end(+acc: U32, x: Http.Stream & U32) -> IO(U32):
  (st, +n) = x
  do IO<U32>:
    Http.stream.close(st)
    return (acc + n : U32)

def fresh.got(+acc: U32, r: Result<&1, &1, Http.Err, Http.Stream>) -> IO(U32):
  match r:
    case Fail{e}:
      IO.pure(U32, acc)
    case Done{st}:
      do IO<U32>:
        x : Http.Stream & U32 <- body.all(st)
        fresh.end(acc, x)

def fresh.loop(n: Nat, +url: String, +acc: U32) -> IO(U32):
  match n:
    case 0n:
      IO.pure(U32, acc)
    case 1n+k:
      do IO<U32>:
        r : Result<&1, &1, Http.Err, Http.Stream> <- Http.open("GET", url, Http.empty(), Bytes.new(0))
        got : U32 <- fresh.got(acc, r)
        fresh.loop(k, url, got)

def pooled.end(p: Http.Pool, +acc: U32, x: Http.Stream & U32) -> IO(Http.Pool & U32):
  (st, +n) = x
  do IO<Http.Pool & U32>:
    q : Http.Pool <- Http.pool.stream.close(p, st)
    return (q, (acc + n : U32))

def pooled.got(+acc: U32, pr: Http.Pool & Result<&1, &1, Http.Err, Http.Stream>) -> IO(Http.Pool & U32):
  (p, r) = pr
  match r:
    case Fail{e}:
      IO.pure(Http.Pool & U32, (p, acc))
    case Done{st}:
      do IO<Http.Pool & U32>:
        x : Http.Stream & U32 <- body.all(st)
        pooled.end(p, acc, x)

def pooled.loop(n: Nat, +url: String, x: Http.Pool & U32) -> IO(Http.Pool & U32):
  match n:
    case 0n:
      IO.pure(Http.Pool & U32, x)
    case 1n+k:
      (p, +acc) = x
      do IO<Http.Pool & U32>:
        pr : Http.Pool & Result<&1, &1, Http.Err, Http.Stream> <- Http.pool.open(p, "GET", url, Http.empty(), Bytes.new(0))
        y : Http.Pool & U32 <- pooled.got(acc, pr)
        pooled.loop(k, url, y)

def report(+t0: Time.Duration, +t1: Time.Duration, +t2: Time.Duration, +a: U32, x: Http.Pool & U32) -> IO(Unit):
  (p, +b) = x
  do IO<Unit>:
    Http.pool.close(p)
    IO.print({"fresh " ++ U32.show(a) ++ " " ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ " ms" : String})
    IO.print({"pooled " ++ U32.show(b) ++ " " ++ Time.Duration.show_ms(Time.Duration.sub(t2, t1)) ++ " ms" : String})

def run(+url: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    a : U32 <- fresh.loop(200n, url, 0)
    t1 : Time.Duration <- Time.mono()
    x : Http.Pool & U32 <- pooled.loop(200n, url, (Http.pool.new(), 0))
    t2 : Time.Duration <- Time.mono()
    report(t0, t1, t2, a, x)

def url(xs: List<&1, String>) -> String:
  match xs:
    case Nil{}:
      "http://127.0.0.1:18095/"
    case Con{x, t}:
      x

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    run(url(List.tail(&1, String, args)))
