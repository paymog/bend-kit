# Live smoke against a local Redis or Valkey on REDIS_PORT (default 6379). It flushes db 9.
import Base
import ./redis.bend as R
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

def esc(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, t}:
      Bool.pick(String, U32.is_eq(c, 13), "\\r", Bool.pick(String, U32.is_eq(c, 10), "\\n", SCon{Chr{c}, SNil{}})) ++ esc(t)

def wire(m: Maybe<&1, Bytes.Bytes>) -> String:
  match m:
    case Some{b}:
      esc(Bytes.to_string(b))
    case None{}:
      "<no RESP form>"

def show(v: R.Val) -> String:
  wire(R.encode(v))

def shows(vs: List<&1, R.Val>) -> List<&2, String>:
  match vs:
    case Nil{}:
      Nil{}
    case Con{v, t}:
      Con{show(v), shows(t)}

def joined(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{h, t}:
      h ++ " " ++ joined(t)

def failure(e: R.Failure) -> String:
  match e:
    case R.IoFail{+code, why}:
      "io " ++ U32.show(code) ++ " " ++ why
    case R.Closed{}:
      "closed"
    case R.Malformed{}:
      "malformed"
    case R.Rejected{v}:
      "rejected " ++ show(v)

def report.eq(same: Bool, +name: String, +a: String, +b: String) -> IO(Unit):
  match same:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.print("fail " ++ name ++ ": got " ++ b ++ "want " ++ a)

def report(+name: String, +want: List<&2, String>, got: List<&2, String>) -> IO(Unit):
  +a = joined(want)
  +b = joined(got)
  report.eq(String.eq(a, b), name, a, b)

type Step is Type:
  Step{name: String, cmds: List<&1, List<&1, Bytes.Bytes>>, want: List<&2, String>}

def one(+name: String, +argv: List<&2, String>, +want: String) -> Step:
  Step{name, [R.args(argv)], [esc(want)]}

# Checks the replies to the step before, then sends the next one.
def run(steps: List<&1, Step>, +name: String, +want: List<&2, String>, r: Result<&1, &1, R.Failure, R.Conn & List<&1, R.Val>>) -> IO(Maybe<&1, R.Conn>):
  match steps:
    case Nil{}:
      match r:
        case Fail{e}:
          do IO<Maybe<&1, R.Conn>>:
            IO.print("fail " ++ name ++ ": " ++ failure(e))
            return None{}
        case Done{(c, vs)}:
          do IO<Maybe<&1, R.Conn>>:
            report(name, want, shows(vs))
            return Some{c}
    case Con{Step{+n2, cmds, +w2}, rest}:
      match r:
        case Fail{e}:
          do IO<Maybe<&1, R.Conn>>:
            IO.print("fail " ++ name ++ ": " ++ failure(e))
            return None{}
        case Done{(c, vs)}:
          do IO<Maybe<&1, R.Conn>>:
            report(name, want, shows(vs))
            r2 : Result<&1, &1, R.Failure, R.Conn & List<&1, R.Val>> <- R.pipeline(c, cmds)
            run(rest, n2, w2, r2)

def connected(r: Result<&1, &1, R.Failure, R.Conn>) -> Result<&1, &1, R.Failure, R.Conn & List<&1, R.Val>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{c}:
      Done{(c, Nil{})}

# DBSIZE counts db 9 only, so its 5 keys show that SELECT ran.
def batch() -> Step:
  Step{"pipeline",
    [R.args(["SET", "a", "10"]), R.args(["INCR", "a"]), R.args(["GET", "a"]), R.args(["HSET", "h", "f", "v"]),
     R.args(["HGETALL", "h"]), R.args(["RPUSH", "l", "x", "y"]), R.args(["LRANGE", "l", "0", "-1"]),
     R.args(["SISMEMBER", "s", "x"]), R.args(["NOSUCHCOMMAND"]), R.args(["DBSIZE"])],
    [esc("+OK\r\n"), esc(":11\r\n"), esc("$2\r\n11\r\n"), esc(":1\r\n"), esc("%1\r\n$1\r\nf\r\n$1\r\nv\r\n"),
     esc(":2\r\n"), esc("*2\r\n$1\r\nx\r\n$1\r\ny\r\n"), esc(":0\r\n"),
     esc("-ERR unknown command 'NOSUCHCOMMAND', with args beginning with: \r\n"), esc(":5\r\n")]}

def steps() -> List<&1, Step>:
  [ one("flushdb", ["FLUSHDB"], "+OK\r\n"),
    one("set", ["SET", "k", "v\r\n1"], "+OK\r\n"),
    one("get", ["GET", "k"], "$4\r\nv\r\n1\r\n"),
    one("get missing", ["GET", "nope"], "_\r\n"),
    one("incr", ["INCR", "n"], ":1\r\n"),
    one("incrby", ["INCRBY", "n", "-9223372036854775807"], ":-9223372036854775806\r\n"),
    batch() ]

def cfg(+port: U32) -> R.Config:
  R.Config{"localhost", port, False{}, "", "", 9, 5000}

def pool.c(+id: String, p: R.Pool, r: Result<&1, &1, R.Failure, R.Conn & R.Val>) -> IO(Unit):
  match r:
    case Fail{e}:
      do IO<Unit>:
        IO.print("fail pool reuse: " ++ failure(e))
        R.pool.close(p)
    case Done{(c, v)}:
      do IO<Unit>:
        report("pool reuse", [id], [show(v)])
        p2 : R.Pool <- R.pool.put(p, c)
        R.pool.close(p2)

def pool.b(+id: String, got: R.Pool & Result<&1, &1, R.Failure, R.Conn>) -> IO(Unit):
  (p, r) = got
  match r:
    case Fail{e}:
      do IO<Unit>:
        IO.print("fail pool get: " ++ failure(e))
        R.pool.close(p)
    case Done{c}:
      do IO<Unit>:
        r3 : Result<&1, &1, R.Failure, R.Conn & R.Val> <- R.command(c, R.args(["CLIENT", "ID"]))
        pool.c(id, p, r3)

# The connection given back is the one the pool hands out next: its CLIENT ID matches.
def pool.a(+port: U32, r: Result<&1, &1, R.Failure, R.Conn & R.Val>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("fail client id: " ++ failure(e))
    case Done{(c, v)}:
      do IO<Unit>:
        p : R.Pool <- R.pool.put(R.pool.new(), c)
        got : R.Pool & Result<&1, &1, R.Failure, R.Conn> <- R.pool.get(p, cfg(port))
        pool.b(show(v), got)

def done(+port: U32, m: Maybe<&1, R.Conn>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("fail stopped")
    case Some{c}:
      do IO<Unit>:
        r : Result<&1, &1, R.Failure, R.Conn & R.Val> <- R.command(c, R.args(["CLIENT", "ID"]))
        pool.a(port, r)

def rejected(r: Result<&1, &1, R.Failure, R.Conn>) -> IO(Unit):
  match r:
    case Fail{e}:
      match e:
        case R.Rejected{v}:
          IO.print("ok wrong password")
        case R.IoFail{code, why}:
          IO.print("fail wrong password: io")
        case R.Closed{}:
          IO.print("fail wrong password: closed")
        case R.Malformed{}:
          IO.print("fail wrong password: malformed")
    case Done{c}:
      do IO<Unit>:
        IO.print("fail wrong password: connected")
        R.close(c)

def port(r: Result<&1, &1, U32 & String, String>) -> U32:
  match r:
    case Fail{e}:
      6379
    case Done{s}:
      Maybe.default(&2, U32, U32.read(s), 6379)

def main.at(+p: U32) -> IO(Unit):
  do IO<Unit>:
    c : Result<&1, &1, R.Failure, R.Conn> <- R.connect(cfg(p))
    m : Maybe<&1, R.Conn> <- run(steps(), "connect", Nil{}, connected(c))
    done(p, m)
    bad : Result<&1, &1, R.Failure, R.Conn> <- R.connect(R.Config{"127.0.0.1", p, False{}, "nobody", "nope", 0, 5000})
    rejected(bad)

def main() -> IO(Unit):
  do IO<Unit>:
    e : Result<&1, &1, U32 & String, String> <- IO.get_env("REDIS_PORT")
    main.at(port(e))
