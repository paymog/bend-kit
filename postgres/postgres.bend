# Postgres client: protocol 3.0 over TCP or TLS, SCRAM-SHA-256, prepared queries, and a pool. Source: https://github.com/paymog/bend-kit/tree/main/postgres
import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import bend-kit-wire@0.4.2.0/wire.bend as Wire
import bend-kit-dns@0.5.0.0/dns.bend as Dns
import ./codec.bend as Codec
import ./scram.bend as Scram

# host is a name or a numeric address; TLS checks the certificate against it. With tls
# set, a server that refuses SSLRequest fails with NoTls rather than falling back to TCP.
# ms bounds each connect and read (0: none). user, pass, and db are byte strings (one Char per octet).
type Config is Data:
  Config{host: String, port: U32, tls: Bool, user: String, pass: String, db: String, ms: U32}

# TLS on, 10 s deadlines.
def config(+host: String, +port: U32, +user: String, +pass: String, +db: String) -> Config:
  Config{host, port, True{}, user, pass, db, 10000}

# A server error: the SQLSTATE code (for example "42P01") and the message.
type Err is Data:
  Err{code: String, message: String}

# A failed call closes its connection. Rejected carries the server's error during startup;
# Auth is an authentication method this client does not speak, or a SCRAM check that failed.
type Failure is Type:
  IoFail{code: U32, why: String}
  Closed{}
  Malformed{}
  NoTls{}
  Auth{why: String}
  Rejected{err: Err}

# A query's result. Rows holds the columns, the rows in order (None is NULL, values in text
# format), and the command tag ("SELECT 2", "INSERT 0 1"). Failed is an error the server
# reported for this query; the connection stays in step and can run the next one.
type Reply is Type:
  Rows{fields: List<&1, Codec.Field>, rows: List<&1, List<&1, Maybe<&1, Bytes.Bytes>>>, tag: Bytes.Bytes}
  Failed{err: Err}

# key names the pool bucket: TLS, user, host, port, and db (never the password).
# status is the last ReadyForQuery byte: 73 'I' idle, 84 'T' in a transaction, 69 'E' failed one.
type Conn is Type:
  Conn{tls: Bool, sock: Socket, rd: Codec.Reader, key: String, ms: U32, status: U32}

# A parameter in text format.
def text(+s: String) -> Maybe<&1, Bytes.Bytes>:
  Some{Bytes.from_string(s)}

def bytes(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

# ---- errors

def err.put(+k: U32, +s: String, e: Err) -> Err:
  Err{+code, +message} = e
  Bool.pick(Err, U32.is_eq(k, 67), Err{s, message}, Bool.pick(Err, U32.is_eq(k, 77), Err{code, s}, Err{code, message}))

def err.go(fs: List<&1, Codec.Notice>, e: Err) -> Err:
  match fs:
    case Nil{}:
      e
    case Con{Codec.Notice{+k, v}, t}:
      err.go(t, err.put(k, Bytes.to_string(v), e))

# The C (SQLSTATE) and M (message) fields of an ErrorResponse.
def err.of(fs: List<&1, Codec.Notice>) -> Err:
  err.go(fs, Err{"", ""})

# ---- socket IO

def io.close(tls: Bool, s: Socket) -> IO(Unit):
  match tls:
    case True{}:
      Wire.tls.close(s)
    case False{}:
      Socket.close(s)

def io.send(tls: Bool, s: Socket, +len: U32, buf: Array<U32>) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match tls:
    case True{}:
      Wire.tls.send.words(s, len, buf)
    case False{}:
      Wire.send.words(s, len, buf)

def io.write(tls: Bool, s: Socket, data: Bytes.Bytes) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  Bytes.Bytes{+len, buf} = data
  io.send(tls, s, len, buf)

def io.recv(tls: Bool, s: Socket, +ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  match tls:
    case True{}:
      Wire.tls.recv.words(s, 65536, ms)
    case False{}:
      Wire.recv.words(s, 65536, ms)

def io.close.after(tls: Bool, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (s, r) = m
  io.close(tls, s)

# Sends Terminate, then closes the socket.
def close(c: Conn) -> IO(Unit):
  Conn{+tls, sock, rd, key, ms, status} = c
  do IO<Unit>:
    m : Socket & Result<&1, &1, U32 & String, Unit> <- io.write(tls, sock, Codec.encode(Codec.Terminate{}))
    io.close.after(tls, m)

def abort(-A: Type, c: Conn, why: Failure) -> IO(Result<&1, &1, Failure, A>):
  do IO<Result<&1, &1, Failure, A>>:
    close(c)
    return Fail{why}

def reject(-A: Type, c: Conn, fs: List<&1, Codec.Notice>) -> IO(Result<&1, &1, Failure, A>):
  abort(A, c, Rejected{err.of(fs)})

def send.after(+tls: Bool, rd: Codec.Reader, +key: String, +ms: U32, +status: U32, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&1, &1, Failure, Conn>):
  (s, r) = m
  match r:
    case Fail{(code, why)}:
      do IO<Result<&1, &1, Failure, Conn>>:
        io.close(tls, s)
        return Fail{IoFail{code, why}}
    case Done{u}:
      IO.pure(Result<&1, &1, Failure, Conn>, Done{Conn{tls, s, rd, key, ms, status}})

def send(c: Conn, data: Bytes.Bytes) -> IO(Result<&1, &1, Failure, Conn>):
  Conn{+tls, sock, rd, +key, +ms, +status} = c
  do IO<Result<&1, &1, Failure, Conn>>:
    m : Socket & Result<&1, &1, U32 & String, Unit> <- io.write(tls, sock, data)
    send.after(tls, rd, key, ms, status, m)

# RNext holds the reader after its last decode attempt; RFail a socket to close.
type Rd is Type:
  RNext{tls: Bool, sock: Socket, key: String, ms: U32, status: U32, r: Codec.Reader & Codec.Next}
  RFail{tls: Bool, sock: Socket, why: Failure}

def got.len(zero: Bool, +tls: Bool, +key: String, +ms: U32, +status: U32, rd: Codec.Reader, s: Socket, +len: U32, words: Array<U32>) -> Rd:
  match zero:
    case True{}:
      RFail{tls, s, Closed{}}
    case False{}:
      RNext{tls, s, key, ms, status, Codec.next(Codec.feed(rd, Bytes.Bytes{len, words}))}

def got(+tls: Bool, +key: String, +ms: U32, +status: U32, rd: Codec.Reader, m: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Rd:
  (s, r) = m
  match r:
    case Fail{(code, why)}:
      RFail{tls, s, IoFail{code, why}}
    case Done{(+len, words)}:
      got.len(U32.is_zero(len), tls, key, ms, status, rd, s, len, words)

def read.fail(tls: Bool, sock: Socket, why: Failure) -> IO(Result<&1, &1, Failure, Conn & Codec.Back>):
  do IO<Result<&1, &1, Failure, Conn & Codec.Back>>:
    io.close(tls, sock)
    return Fail{why}

# One recv per step. NoticeResponse and ParameterStatus may arrive at any time; they are skipped.
def read.loop(fuel: Nat, st: Rd) -> IO(Result<&1, &1, Failure, Conn & Codec.Back>):
  match fuel:
    case 0n:
      match st:
        case RNext{tls, sock, key, ms, status, r}:
          read.fail(tls, sock, Malformed{})
        case RFail{tls, sock, why}:
          read.fail(tls, sock, why)
    case 1n+f:
      match st:
        case RFail{tls, sock, why}:
          read.fail(tls, sock, why)
        case RNext{+tls, sock, +key, +ms, +status, r}:
          (rd, nx) = r
          match nx:
            case Codec.Got{Codec.NoticeResponse{fs}}:
              read.loop(f, RNext{tls, sock, key, ms, status, Codec.next(rd)})
            case Codec.Got{Codec.ParameterStatus{name, value}}:
              read.loop(f, RNext{tls, sock, key, ms, status, Codec.next(rd)})
            case Codec.Got{m}:
              IO.pure(Result<&1, &1, Failure, Conn & Codec.Back>, Done{(Conn{tls, sock, rd, key, ms, status}, m)})
            case Codec.Bad{}:
              read.fail(tls, sock, Malformed{})
            case Codec.Want{}:
              do IO<Result<&1, &1, Failure, Conn & Codec.Back>>:
                m : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- io.recv(tls, sock, ms)
                read.loop(f, got(tls, key, ms, status, rd, m))

# The next message. Bytes already read are decoded before the socket is asked for more.
# 2^24 reads of up to 64 KiB pass Postgres's 1 GiB field limit.
def read(c: Conn) -> IO(Result<&1, &1, Failure, Conn & Codec.Back>):
  Conn{tls, sock, rd, key, ms, status} = c
  read.loop(Nat.mul(65536n, 256n), RNext{tls, sock, key, ms, status, Codec.next(rd)})

# The next message after a send.
def reply(r: Result<&1, &1, Failure, Conn>) -> IO(Result<&1, &1, Failure, Conn & Codec.Back>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Failure, Conn & Codec.Back>, Fail{e})
    case Done{c}:
      read(c)

def exchange(c: Conn, m: Codec.Front) -> IO(Result<&1, &1, Failure, Conn & Codec.Back>):
  do IO<Result<&1, &1, Failure, Conn & Codec.Back>>:
    s : Result<&1, &1, Failure, Conn> <- send(c, Codec.encode(m))
    reply(s)

def set.status(c: Conn, +status: U32) -> Conn:
  Conn{tls, sock, rd, key, ms, old} = c
  Conn{tls, sock, rd, key, ms, status}

# ---- startup

# BackendKeyData, then ReadyForQuery.
def ready.loop(fuel: Nat, r: Result<&1, &1, Failure, Conn & Codec.Back>) -> IO(Result<&1, &1, Failure, Conn>):
  match fuel:
    case 0n:
      match r:
        case Fail{e}:
          IO.pure(Result<&1, &1, Failure, Conn>, Fail{e})
        case Done{(c, m)}:
          abort(Conn, c, Malformed{})
    case 1n+f:
      match r:
        case Fail{e}:
          IO.pure(Result<&1, &1, Failure, Conn>, Fail{e})
        case Done{(c, m)}:
          match m:
            case Codec.ReadyForQuery{+status}:
              IO.pure(Result<&1, &1, Failure, Conn>, Done{set.status(c, status)})
            case Codec.BackendKeyData{pid, key}:
              do IO<Result<&1, &1, Failure, Conn>>:
                m2 : Result<&1, &1, Failure, Conn & Codec.Back> <- read(c)
                ready.loop(f, m2)
            case Codec.ErrorResponse{fs}:
              reject(Conn, c, fs)
            case _:
              abort(Conn, c, Malformed{})

def ready(c: Conn) -> IO(Result<&1, &1, Failure, Conn>):
  do IO<Result<&1, &1, Failure, Conn>>:
    m : Result<&1, &1, Failure, Conn & Codec.Back> <- read(c)
    ready.loop(16n, m)

# AuthenticationOk, after a password or the SCRAM exchange.
def auth.done(r: Result<&1, &1, Failure, Conn & Codec.Back>) -> IO(Result<&1, &1, Failure, Conn>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Failure, Conn>, Fail{e})
    case Done{(c, m)}:
      match m:
        case Codec.AuthOk{}:
          ready(c)
        case Codec.ErrorResponse{fs}:
          reject(Conn, c, fs)
        case _:
          abort(Conn, c, Malformed{})

def sasl.verified(c: Conn, v: Result<&1, &1, U32 & String, Unit>) -> IO(Result<&1, &1, Failure, Conn>):
  match v:
    case Fail{(code, why)}:
      abort(Conn, c, Auth{why})
    case Done{u}:
      do IO<Result<&1, &1, Failure, Conn>>:
        m : Result<&1, &1, Failure, Conn & Codec.Back> <- read(c)
        auth.done(m)

# AuthenticationSASLFinal carries the server signature, which proves the server knew the password.
def sasl.final(fin: Scram.Final, r: Result<&1, &1, Failure, Conn & Codec.Back>) -> IO(Result<&1, &1, Failure, Conn>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Failure, Conn>, Fail{e})
    case Done{(c, m)}:
      match m:
        case Codec.AuthSASLFinal{data}:
          do IO<Result<&1, &1, Failure, Conn>>:
            v : Result<&1, &1, U32 & String, Unit> <- Scram.verify(fin, Bytes.to_string(data))
            sasl.verified(c, v)
        case Codec.ErrorResponse{fs}:
          reject(Conn, c, fs)
        case _:
          abort(Conn, c, Malformed{})

def sasl.respond(c: Conn, f: Result<&1, &1, U32 & String, Scram.Final & String>) -> IO(Result<&1, &1, Failure, Conn>):
  match f:
    case Fail{(code, why)}:
      abort(Conn, c, Auth{why})
    case Done{(fin, msg)}:
      do IO<Result<&1, &1, Failure, Conn>>:
        m : Result<&1, &1, Failure, Conn & Codec.Back> <- exchange(c, Codec.SASLResponse{bytes(msg)})
        sasl.final(fin, m)

def sasl.cont(st: Scram.First, +pass: String, r: Result<&1, &1, Failure, Conn & Codec.Back>) -> IO(Result<&1, &1, Failure, Conn>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Failure, Conn>, Fail{e})
    case Done{(c, m)}:
      match m:
        case Codec.AuthSASLContinue{data}:
          do IO<Result<&1, &1, Failure, Conn>>:
            f : Result<&1, &1, U32 & String, Scram.Final & String> <- Scram.respond(st, Bytes.to_string(data), pass)
            sasl.respond(c, f)
        case Codec.ErrorResponse{fs}:
          reject(Conn, c, fs)
        case _:
          abort(Conn, c, Malformed{})

def sasl.first(c: Conn, +pass: String, f: Result<&1, &1, U32 & String, Scram.First & String>) -> IO(Result<&1, &1, Failure, Conn>):
  match f:
    case Fail{(code, why)}:
      abort(Conn, c, Auth{why})
    case Done{(st, msg)}:
      do IO<Result<&1, &1, Failure, Conn>>:
        m : Result<&1, &1, Failure, Conn & Codec.Back> <- exchange(c, Codec.SASLInitial{bytes(Scram.mechanism()), bytes(msg)})
        sasl.cont(st, pass, m)

def sasl(ok: Bool, c: Conn, +user: String, +pass: String) -> IO(Result<&1, &1, Failure, Conn>):
  match ok:
    case True{}:
      do IO<Result<&1, &1, Failure, Conn>>:
        f : Result<&1, &1, U32 & String, Scram.First & String> <- Scram.first(user)
        sasl.first(c, pass, f)
    case False{}:
      abort(Conn, c, Auth{"server offers no " ++ Scram.mechanism()})

def has.mech(xs: List<&1, Bytes.Bytes>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      Bool.or(String.eq(Bytes.to_string(h), Scram.mechanism()), has.mech(t))

# The first message after StartupMessage picks the authentication method.
def auth(+user: String, +pass: String, r: Result<&1, &1, Failure, Conn & Codec.Back>) -> IO(Result<&1, &1, Failure, Conn>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Failure, Conn>, Fail{e})
    case Done{(c, m)}:
      match m:
        case Codec.AuthOk{}:
          ready(c)
        case Codec.AuthCleartext{}:
          do IO<Result<&1, &1, Failure, Conn>>:
            a : Result<&1, &1, Failure, Conn & Codec.Back> <- exchange(c, Codec.Password{bytes(pass)})
            auth.done(a)
        case Codec.AuthSASL{mechs}:
          sasl(has.mech(mechs), c, user, pass)
        case Codec.ErrorResponse{fs}:
          reject(Conn, c, fs)
        case Codec.AuthOther{+code, data}:
          abort(Conn, c, Auth{"unsupported authentication request " ++ U32.show(code)})
        case _:
          abort(Conn, c, Malformed{})

def startup(c: Conn, +user: String, +pass: String, +db: String) -> IO(Result<&1, &1, Failure, Conn>):
  do IO<Result<&1, &1, Failure, Conn>>:
    m : Result<&1, &1, Failure, Conn & Codec.Back> <- exchange(c, Codec.Startup{[Codec.Param{bytes("user"), bytes(user)}, Codec.Param{bytes("database"), bytes(db)}]})
    auth(user, pass, m)

def tls.done(+key: String, +ms: U32, +user: String, +pass: String, +db: String, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&1, &1, Failure, Conn>):
  (s, r) = m
  match r:
    case Fail{(code, why)}:
      do IO<Result<&1, &1, Failure, Conn>>:
        Wire.tls.close(s)
        return Fail{IoFail{code, why}}
    case Done{u}:
      startup(Conn{True{}, s, Codec.reader(), key, ms, 0}, user, pass, db)

def plain.fail(s: Socket, why: Failure) -> IO(Result<&1, &1, Failure, Conn>):
  do IO<Result<&1, &1, Failure, Conn>>:
    Socket.close(s)
    return Fail{why}

# 'S' starts TLS; 'N' refuses it. Anything else (an old server's error) is not an answer.
def ssl.byte(s: Socket, +key: String, +host: String, +user: String, +pass: String, +db: String, +ms: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> IO(Result<&1, &1, Failure, Conn>):
  (b, got) = r
  match got:
    case None{}:
      plain.fail(s, Closed{})
    case Some{c}:
      match c:
        case 83:
          do IO<Result<&1, &1, Failure, Conn>>:
            m : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect(s, host, ms)
            tls.done(key, ms, user, pass, db, m)
        case 78:
          plain.fail(s, NoTls{})
        case _:
          plain.fail(s, Malformed{})

# The answer is one byte, read alone so no byte sent before the TLS handshake is taken as data.
def ssl.answer(+key: String, +host: String, +user: String, +pass: String, +db: String, +ms: U32, a: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Result<&1, &1, Failure, Conn>):
  (s, r) = a
  match r:
    case Fail{(code, why)}:
      plain.fail(s, IoFail{code, why})
    case Done{(+len, words)}:
      ssl.byte(s, key, host, user, pass, db, ms, Bytes.get(Bytes.Bytes{len, words}, 0))

def ssl.sent(+key: String, +host: String, +user: String, +pass: String, +db: String, +ms: U32, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&1, &1, Failure, Conn>):
  (s, r) = m
  match r:
    case Fail{(code, why)}:
      plain.fail(s, IoFail{code, why})
    case Done{u}:
      do IO<Result<&1, &1, Failure, Conn>>:
        a : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Wire.recv.words(s, 1, ms)
        ssl.answer(key, host, user, pass, db, ms, a)

def ssl.ask(s: Socket, +key: String, +host: String, +user: String, +pass: String, +db: String, +ms: U32) -> IO(Result<&1, &1, Failure, Conn>):
  do IO<Result<&1, &1, Failure, Conn>>:
    m : Socket & Result<&1, &1, U32 & String, Unit> <- io.write(False{}, s, Codec.encode(Codec.SSLRequest{}))
    ssl.sent(key, host, user, pass, db, ms, m)

def dialed(r: Result<&1, &1, U32 & String, Socket>, tls: Bool, +key: String, +host: String, +user: String, +pass: String, +db: String, +ms: U32) -> IO(Result<&1, &1, Failure, Conn>):
  match r:
    case Fail{(code, why)}:
      IO.pure(Result<&1, &1, Failure, Conn>, Fail{IoFail{code, why}})
    case Done{s}:
      match tls:
        case True{}:
          ssl.ask(s, key, host, user, pass, db, ms)
        case False{}:
          startup(Conn{False{}, s, Codec.reader(), key, ms, 0}, user, pass, db)

def dial.after(r: Result<&1, &1, U32 & String, Socket>, +ip: String, +port: U32, +ms: U32) -> IO(Result<&1, &1, U32 & String, Socket>):
  match r:
    case Done{s}:
      IO.pure(Result<&1, &1, U32 & String, Socket>, Done{s})
    case Fail{e}:
      Wire.connect(ip, port, ms)

def dial.more(prev: IO(Result<&1, &1, U32 & String, Socket>), +ip: String, +port: U32, +ms: U32) -> IO(Result<&1, &1, U32 & String, Socket>):
  do IO<Result<&1, &1, U32 & String, Socket>>:
    r : Result<&1, &1, U32 & String, Socket> <- prev
    dial.after(r, ip, port, ms)

# Each address in turn, until one connects.
def dial(ips: List<&2, String>, +port: U32, +ms: U32, acc: IO(Result<&1, &1, U32 & String, Socket>)) -> IO(Result<&1, &1, U32 & String, Socket>):
  match ips:
    case Nil{}:
      acc
    case Con{ip, t}:
      dial(t, port, ms, dial.more(acc, ip, port, ms))

def key(cfg: Config) -> String:
  Config{+host, +port, +tls, +user, pass, +db, ms} = cfg
  +sep = {SCon{Chr{0}, SNil{}} : String}
  Bool.pick(String, tls, "tls", "tcp") ++ sep ++ user ++ sep ++ host ++ sep ++ U32.show(port) ++ sep ++ db

def connect.to(+k: String, cfg: Config) -> IO(Result<&1, &1, Failure, Conn>):
  Config{+host, +port, +tls, +user, +pass, +db, +ms} = cfg
  do IO<Result<&1, &1, Failure, Conn>>:
    ips : List<&2, String> <- Dns.resolve.all(host)
    r : Result<&1, &1, U32 & String, Socket> <- dial(ips, port, ms, IO.pure(Result<&1, &1, U32 & String, Socket>, Fail{(0, "no address for " ++ host)}))
    dialed(r, tls, k, host, user, pass, db, ms)

# TCP, SSLRequest and TLS when cfg.tls (checking the certificate and host name), StartupMessage,
# cleartext or SCRAM-SHA-256 authentication, then ReadyForQuery. MD5 is refused as Auth.
def connect(+cfg: Config) -> IO(Result<&1, &1, Failure, Conn>):
  connect.to(key(cfg), cfg)

# ---- queries

type Acc is Type:
  Acc{fields: List<&1, Codec.Field>, rows: List<&1, List<&1, Maybe<&1, Bytes.Bytes>>>, tag: Bytes.Bytes, err: Maybe<&1, Err>}

type Step is Type:
  Go{acc: Acc}
  Stop{acc: Acc, status: U32}
  Odd{}

def acc.fields(a: Acc, fs: List<&1, Codec.Field>) -> Acc:
  Acc{old, rows, tag, err} = a
  Acc{fs, rows, tag, err}

# Rows are kept newest first until ReadyForQuery.
def acc.row(a: Acc, cols: List<&1, Maybe<&1, Bytes.Bytes>>) -> Acc:
  Acc{fs, rows, tag, err} = a
  Acc{fs, Con{cols, rows}, tag, err}

def acc.tag(a: Acc, t: Bytes.Bytes) -> Acc:
  Acc{fs, rows, old, err} = a
  Acc{fs, rows, t, err}

def err.first(old: Maybe<&1, Err>, e: Err) -> Maybe<&1, Err>:
  match old:
    case None{}:
      Some{e}
    case Some{x}:
      Some{x}

def acc.err(a: Acc, e: Err) -> Acc:
  Acc{fs, rows, tag, old} = a
  Acc{fs, rows, tag, err.first(old, e)}

def absorb(a: Acc, m: Codec.Back) -> Step:
  match m:
    case Codec.DataRow{cols}:
      Go{acc.row(a, cols)}
    case Codec.RowDescription{fs}:
      Go{acc.fields(a, fs)}
    case Codec.CommandComplete{t}:
      Go{acc.tag(a, t)}
    case Codec.ErrorResponse{fs}:
      Go{acc.err(a, err.of(fs))}
    case Codec.ReadyForQuery{+s}:
      Stop{a, s}
    case Codec.ParseComplete{}:
      Go{a}
    case Codec.BindComplete{}:
      Go{a}
    case Codec.NoData{}:
      Go{a}
    case Codec.EmptyQuery{}:
      Go{a}
    case Codec.CloseComplete{}:
      Go{a}
    case Codec.PortalSuspended{}:
      Go{a}
    case _:
      Odd{}

def absorbed(a: Acc, r: Result<&1, &1, Failure, Conn & Codec.Back>) -> Result<&1, &1, Failure, Conn & Step>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{(c, m)}:
      Done{(c, absorb(a, m))}

def finish(c: Conn, +status: U32, a: Acc) -> IO(Result<&1, &1, Failure, Conn & Reply>):
  Acc{fs, rows, tag, err} = a
  match err:
    case None{}:
      IO.pure(Result<&1, &1, Failure, Conn & Reply>, Done{(set.status(c, status), Rows{fs, List.reverse(&1, List<&1, Maybe<&1, Bytes.Bytes>>, rows), tag})})
    case Some{e}:
      IO.pure(Result<&1, &1, Failure, Conn & Reply>, Done{(set.status(c, status), Failed{e})})

# After an ErrorResponse the server skips to Sync, so reading on to ReadyForQuery keeps
# the connection in step. A message that has no place in the reply closes it.
def collect(fuel: Nat, r: Result<&1, &1, Failure, Conn & Step>) -> IO(Result<&1, &1, Failure, Conn & Reply>):
  match fuel:
    case 0n:
      match r:
        case Fail{e}:
          IO.pure(Result<&1, &1, Failure, Conn & Reply>, Fail{e})
        case Done{(c, s)}:
          abort(Conn & Reply, c, Malformed{})
    case 1n+f:
      match r:
        case Fail{e}:
          IO.pure(Result<&1, &1, Failure, Conn & Reply>, Fail{e})
        case Done{(c, s)}:
          match s:
            case Go{a}:
              do IO<Result<&1, &1, Failure, Conn & Reply>>:
                m : Result<&1, &1, Failure, Conn & Codec.Back> <- read(c)
                collect(f, absorbed(a, m))
            case Stop{a, +status}:
              finish(c, status, a)
            case Odd{}:
              abort(Conn & Reply, c, Malformed{})

# The whole extended-query exchange for one statement, in one write.
def query.bytes(+sql: String, params: List<&1, Maybe<&1, Bytes.Bytes>>) -> Bytes.Bytes:
  Bytes.concat([
    Codec.encode(Codec.Parse{Bytes.new(0), bytes(sql), Nil{}}),
    Codec.encode(Codec.Bind{Bytes.new(0), Bytes.new(0), Nil{}, params, Nil{}}),
    Codec.encode(Codec.Describe{80, Bytes.new(0)}),
    Codec.encode(Codec.Execute{Bytes.new(0), 0}),
    Codec.encode(Codec.Sync{})])

# Runs sql (a byte string, parameters as $1, $2, ...) as an unnamed prepared statement:
# Parse, Bind, Describe, Execute, Sync. Parameters and results are in text format; None is NULL.
# A server error is a Failed reply on a live connection; a Failure has closed it.
def query(c: Conn, +sql: String, params: List<&1, Maybe<&1, Bytes.Bytes>>) -> IO(Result<&1, &1, Failure, Conn & Reply>):
  do IO<Result<&1, &1, Failure, Conn & Reply>>:
    s : Result<&1, &1, Failure, Conn> <- send(c, query.bytes(sql, params))
    m : Result<&1, &1, Failure, Conn & Codec.Back> <- reply(s)
    collect(Nat.mul(65536n, 65536n), absorbed(Acc{Nil{}, Nil{}, Bytes.new(0), None{}}, m))

# ---- pool

# Idle connections per key, up to cap per key.
type Pool is Type:
  Pool{cap: U32, idle: Map<&1, List<&1, Conn>>}

def pool.new.with(+cap: U32) -> Pool:
  Pool{cap, Map.new(&1, List<&1, Conn>)}

def pool.new() -> Pool:
  pool.new.with(8)

def pool.take(+cap: U32, +k: String, r: Map<&1, List<&1, Conn>> & Maybe<&1, List<&1, Conn>>) -> Pool & Maybe<&1, Conn>:
  (m, got) = r
  match got:
    case None{}:
      (Pool{cap, m}, None{})
    case Some{xs}:
      match xs:
        case Nil{}:
          (Pool{cap, m}, None{})
        case Con{c, t}:
          (Pool{cap, Map.set(&1, List<&1, Conn>, m, k, t)}, Some{c})

def pool.opened(p: Pool, r: Result<&1, &1, Failure, Conn>) -> IO(Pool & Result<&1, &1, Failure, Conn>):
  IO.pure(Pool & Result<&1, &1, Failure, Conn>, (p, r))

def pool.got(cfg: Config, r: Pool & Maybe<&1, Conn>) -> IO(Pool & Result<&1, &1, Failure, Conn>):
  (p, m) = r
  match m:
    case Some{c}:
      IO.pure(Pool & Result<&1, &1, Failure, Conn>, (p, Done{c}))
    case None{}:
      do IO<Pool & Result<&1, &1, Failure, Conn>>:
        c : Result<&1, &1, Failure, Conn> <- connect(cfg)
        pool.opened(p, c)

# The idle connection given back last, or a new one.
# ponytail: an idle connection the server has since closed fails on its first query; ping before reuse if that bites.
def pool.get(p: Pool, +cfg: Config) -> IO(Pool & Result<&1, &1, Failure, Conn>):
  Pool{+cap, idle} = p
  +k = key(cfg)
  pool.got(cfg, pool.take(cap, k, Map.pop(&1, List<&1, Conn>, idle, k)))

# The first n connections; the rest are closed.
def conns.cut(xs: List<&1, Conn>, n: Nat) -> IO(List<&1, Conn>):
  match xs:
    case Nil{}:
      IO.pure(List<&1, Conn>, Nil{})
    case Con{c, t}:
      match n:
        case 0n:
          do IO<List<&1, Conn>>:
            close(c)
            conns.cut(t, 0n)
        case 1n+k:
          do IO<List<&1, Conn>>:
            r : List<&1, Conn> <- conns.cut(t, k)
            return c <> r

def pool.keep(+cap: U32, +k: String, c: Conn, r: Map<&1, List<&1, Conn>> & Maybe<&1, List<&1, Conn>>) -> IO(Pool):
  (m, old) = r
  do IO<Pool>:
    xs : List<&1, Conn> <- conns.cut(c <> Maybe.default(&1, List<&1, Conn>, old, Nil{}), U32.to_nat(cap))
    return Pool{cap, Map.set(&1, List<&1, Conn>, m, k, xs)}

def pool.clean(clean: Bool, p: Pool, c: Conn) -> IO(Pool):
  match clean:
    case True{}:
      Pool{+cap, idle} = p
      Conn{tls, sock, rd, +k, ms, status} = c
      pool.keep(cap, k, Conn{tls, sock, rd, k, ms, status}, Map.pop(&1, List<&1, Conn>, idle, k))
    case False{}:
      do IO<Pool>:
        close(c)
        return p

def pool.left(p: Pool, +tls: Bool, sock: Socket, +key: String, +ms: U32, +status: U32, r: Codec.Reader & U32) -> IO(Pool):
  (rd, +n) = r
  pool.clean(Bool.and(U32.is_zero(n), U32.is_eq(status, 73)), p, Conn{tls, sock, rd, key, ms, status})

# Gives c back for reuse. A connection with unread bytes is out of step, and one inside a
# transaction would leak it to the next user, so either is closed instead.
def pool.put(p: Pool, c: Conn) -> IO(Pool):
  Conn{+tls, sock, rd, +key, +ms, +status} = c
  pool.left(p, tls, sock, key, ms, status, Codec.pending(rd))

def pool.close.go(xs: List<&1, List<&1, Conn>>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{cs, t}:
      do IO<Unit>:
        none : List<&1, Conn> <- conns.cut(cs, 0n)
        pool.close.go(t)

def pool.close(p: Pool) -> IO(Unit):
  Pool{cap, idle} = p
  pool.close.go(Map.values(&1, List<&1, Conn>, idle))
