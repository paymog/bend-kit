# Live smoke against a Postgres configured for TLS and SCRAM-SHA-256. It creates and drops
# the table bend_smoke. Reads POSTGRES_HOST (localhost), POSTGRES_PORT (5432), POSTGRES_USER
# (postgres), POSTGRES_PASSWORD, and POSTGRES_DB (postgres). The server certificate must be
# valid for POSTGRES_HOST and trusted, for example through SSL_CERT_FILE.
import Base
import ./postgres.bend as P
import ./codec.bend as Codec
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

def join(+sep: String, xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{h, t}:
      match t:
        case Nil{}:
          h
        case Con{h2, t2}:
          h ++ sep ++ join(sep, Con{h2, t2})

def cell(m: Maybe<&1, Bytes.Bytes>) -> String:
  match m:
    case None{}:
      "NULL"
    case Some{b}:
      Bytes.to_string(b)

def cells(xs: List<&1, Maybe<&1, Bytes.Bytes>>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{cell(h), cells(t)}

def rows(xs: List<&1, List<&1, Maybe<&1, Bytes.Bytes>>>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{join("|", cells(h)), rows(t)}

def names(fs: List<&1, Codec.Field>) -> List<&2, String>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{Codec.Field{name, table, column, oid, size, modifier, format}, t}:
      Con{Bytes.to_string(name), names(t)}

def show(r: P.Reply) -> String:
  match r:
    case P.Rows{fs, rs, tag}:
      "[" ++ join(",", names(fs)) ++ "] [" ++ join("; ", rows(rs)) ++ "] " ++ Bytes.to_string(tag)
    case P.Failed{P.Err{code, message}}:
      "error " ++ code

def failure(e: P.Failure) -> String:
  match e:
    case P.IoFail{+code, why}:
      "io " ++ U32.show(code) ++ " " ++ why
    case P.Closed{}:
      "closed"
    case P.Malformed{}:
      "malformed"
    case P.NoTls{}:
      "server refused TLS"
    case P.Auth{why}:
      "auth " ++ why
    case P.Rejected{P.Err{code, message}}:
      "rejected " ++ code ++ " " ++ message

def check(same: Bool, +name: String, +want: String, +got: String) -> IO(Unit):
  match same:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.print("fail " ++ name ++ ": got " ++ got ++ ", want " ++ want)

def expect(+name: String, +want: String, +got: String) -> IO(Unit):
  check(String.eq(want, got), name, want, got)

def step.got(+name: String, +want: String, r: Result<&1, &1, P.Failure, P.Conn & P.Reply>) -> IO(Maybe<&1, P.Conn>):
  match r:
    case Fail{e}:
      do IO<Maybe<&1, P.Conn>>:
        IO.print("fail " ++ name ++ ": " ++ failure(e))
        return None{}
    case Done{(c, rep)}:
      do IO<Maybe<&1, P.Conn>>:
        expect(name, want, show(rep))
        return Some{c}

def step(+name: String, +want: String, +sql: String, params: List<&1, Maybe<&1, Bytes.Bytes>>, m: Maybe<&1, P.Conn>) -> IO(Maybe<&1, P.Conn>):
  match m:
    case None{}:
      IO.pure(Maybe<&1, P.Conn>, None{})
    case Some{c}:
      do IO<Maybe<&1, P.Conn>>:
        r : Result<&1, &1, P.Failure, P.Conn & P.Reply> <- P.query(c, sql, params)
        step.got(name, want, r)

def connected(r: Result<&1, &1, P.Failure, P.Conn>) -> IO(Maybe<&1, P.Conn>):
  match r:
    case Fail{e}:
      do IO<Maybe<&1, P.Conn>>:
        IO.print("fail connect: " ++ failure(e))
        return None{}
    case Done{c}:
      do IO<Maybe<&1, P.Conn>>:
        IO.print("ok connect over TLS")
        return Some{c}

# ---- pool: a clean connection comes back; one left inside a transaction does not.

def pid.got(r: Result<&1, &1, P.Failure, P.Conn & P.Reply>) -> IO(Maybe<&1, P.Conn & String>):
  match r:
    case Fail{e}:
      do IO<Maybe<&1, P.Conn & String>>:
        IO.print("fail pid: " ++ failure(e))
        return None{}
    case Done{(c, rep)}:
      IO.pure(Maybe<&1, P.Conn & String>, Some{(c, show(rep))})

def pid(c: P.Conn) -> IO(Maybe<&1, P.Conn & String>):
  do IO<Maybe<&1, P.Conn & String>>:
    r : Result<&1, &1, P.Failure, P.Conn & P.Reply> <- P.query(c, "SELECT pg_backend_pid()", Nil{})
    pid.got(r)

def differs(+name: String, +a: String, +b: String) -> IO(Unit):
  check(Bool.not(String.eq(a, b)), name, "a new backend", b)

def pool.f(+s1: String, p: P.Pool, b: Maybe<&1, P.Conn & String>) -> IO(Unit):
  match b:
    case None{}:
      P.pool.close(p)
    case Some{(c, s3)}:
      do IO<Unit>:
        differs("pool drops a connection inside a transaction", s1, s3)
        P.close(c)
        P.pool.close(p)

def pool.e(+s1: String, g: P.Pool & Result<&1, &1, P.Failure, P.Conn>) -> IO(Unit):
  (p, r) = g
  match r:
    case Fail{e}:
      do IO<Unit>:
        IO.print("fail pool get: " ++ failure(e))
        P.pool.close(p)
    case Done{c}:
      do IO<Unit>:
        b : Maybe<&1, P.Conn & String> <- pid(c)
        pool.f(s1, p, b)

def pool.d(+cfg: P.Config, +s1: String, p: P.Pool, r: Result<&1, &1, P.Failure, P.Conn & P.Reply>) -> IO(Unit):
  match r:
    case Fail{e}:
      do IO<Unit>:
        IO.print("fail begin: " ++ failure(e))
        P.pool.close(p)
    case Done{(c, rep)}:
      do IO<Unit>:
        p2 : P.Pool <- P.pool.put(p, c)
        g : P.Pool & Result<&1, &1, P.Failure, P.Conn> <- P.pool.get(p2, cfg)
        pool.e(s1, g)

def pool.c(+cfg: P.Config, +s1: String, p: P.Pool, b: Maybe<&1, P.Conn & String>) -> IO(Unit):
  match b:
    case None{}:
      P.pool.close(p)
    case Some{(c, s2)}:
      do IO<Unit>:
        expect("pool reuse", s1, s2)
        r : Result<&1, &1, P.Failure, P.Conn & P.Reply> <- P.query(c, "BEGIN", Nil{})
        pool.d(cfg, s1, p, r)

def pool.b(+cfg: P.Config, +s1: String, g: P.Pool & Result<&1, &1, P.Failure, P.Conn>) -> IO(Unit):
  (p, r) = g
  match r:
    case Fail{e}:
      do IO<Unit>:
        IO.print("fail pool get: " ++ failure(e))
        P.pool.close(p)
    case Done{c}:
      do IO<Unit>:
        b : Maybe<&1, P.Conn & String> <- pid(c)
        pool.c(cfg, s1, p, b)

def pool.a(+cfg: P.Config, a: Maybe<&1, P.Conn & String>) -> IO(Unit):
  match a:
    case None{}:
      IO.pure(Unit, Unit{})
    case Some{(c, s1)}:
      do IO<Unit>:
        p : P.Pool <- P.pool.put(P.pool.new(), c)
        g : P.Pool & Result<&1, &1, P.Failure, P.Conn> <- P.pool.get(p, cfg)
        pool.b(cfg, s1, g)

def pool(+cfg: P.Config, m: Maybe<&1, P.Conn>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("fail stopped")
    case Some{c}:
      do IO<Unit>:
        a : Maybe<&1, P.Conn & String> <- pid(c)
        pool.a(cfg, a)

def rejected(r: Result<&1, &1, P.Failure, P.Conn>) -> IO(Unit):
  match r:
    case Fail{e}:
      match e:
        case P.Rejected{P.Err{code, message}}:
          expect("wrong password", "28P01", code)
        case _:
          IO.print("fail wrong password: not a server rejection")
    case Done{c}:
      do IO<Unit>:
        IO.print("fail wrong password: connected")
        P.close(c)

def run(+cfg: P.Config, +bad: P.Config) -> IO(Unit):
  do IO<Unit>:
    c : Result<&1, &1, P.Failure, P.Conn> <- P.connect(cfg)
    m0 : Maybe<&1, P.Conn> <- connected(c)
    m1 : Maybe<&1, P.Conn> <- step("drop if exists", "[] [] DROP TABLE", "DROP TABLE IF EXISTS bend_smoke", Nil{}, m0)
    m2 : Maybe<&1, P.Conn> <- step("create", "[] [] CREATE TABLE", "CREATE TABLE bend_smoke (id int PRIMARY KEY, name text NOT NULL, note text)", Nil{}, m1)
    m3 : Maybe<&1, P.Conn> <- step("insert", "[] [] INSERT 0 1", "INSERT INTO bend_smoke VALUES ($1, $2, $3)", [P.text("1"), P.text("alice"), None{}], m2)
    m4 : Maybe<&1, P.Conn> <- step("insert quote", "[] [] INSERT 0 1", "INSERT INTO bend_smoke VALUES ($1, $2, $3)", [P.text("2"), P.text("bob o'neil"), P.text("x")], m3)
    m5 : Maybe<&1, P.Conn> <- step("select", "[id,name,note] [1|alice|NULL; 2|bob o'neil|x] SELECT 2", "SELECT id, name, note FROM bend_smoke WHERE id >= $1 ORDER BY id", [P.text("1")], m4)
    m6 : Maybe<&1, P.Conn> <- step("duplicate key", "error 23505", "INSERT INTO bend_smoke VALUES ($1, $2, $3)", [P.text("1"), P.text("again"), None{}], m5)
    m7 : Maybe<&1, P.Conn> <- step("missing table", "error 42P01", "SELECT * FROM bend_smoke_missing", Nil{}, m6)
    m8 : Maybe<&1, P.Conn> <- step("in step after errors", "[sum] [42] SELECT 1", "SELECT $1::int + 1 AS sum", [P.text("41")], m7)
    m9 : Maybe<&1, P.Conn> <- step("drop", "[] [] DROP TABLE", "DROP TABLE bend_smoke", Nil{}, m8)
    pool(cfg, m9)
    b : Result<&1, &1, P.Failure, P.Conn> <- P.connect(bad)
    rejected(b)

def env.or(+d: String, r: Result<&1, &1, U32 & String, String>) -> String:
  match r:
    case Fail{e}:
      d
    case Done{s}:
      s

def env(+name: String, +d: String) -> IO(String):
  do IO<String>:
    r : Result<&1, &1, U32 & String, String> <- IO.get_env(name)
    return env.or(d, r)

def run.at(+host: String, +port: U32, +user: String, +pass: String, +db: String) -> IO(Unit):
  run(P.config(host, port, user, pass, db), P.config(host, port, user, pass ++ "-wrong", db))

def main() -> IO(Unit):
  do IO<Unit>:
    host : String <- env("POSTGRES_HOST", "localhost")
    port : String <- env("POSTGRES_PORT", "5432")
    user : String <- env("POSTGRES_USER", "postgres")
    pass : String <- env("POSTGRES_PASSWORD", "")
    db : String <- env("POSTGRES_DB", "postgres")
    run.at(host, Maybe.default(&2, U32, U32.read(port), 5432), user, pass, db)
