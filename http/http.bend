# HTTP/1.1 and HTTP/2 client, with an HTTP/1.1 server. Source: https://github.com/paymog/bend-kit/tree/main/http
import Base
import ./admission.bend as Admission
import ./completion.bend as Completion
import bend-kit-wire@0.4.8.1/wire.bend as Wire
import bend-kit-http2@0.6.0.0/http2.bend as H2
import bend-kit-http2@0.6.0.0/hpack.bend as Hpack
import bend-kit-bytes@0.3.3.1/bytes.bend as HBytes
import bend-kit-time@0.3.0.2/pure.bend as Time
import bend-kit-time@0.3.0.2/time.bend as Clock
import ./pure.bend as Pure
import bend-kit-concurrency@0.2.0.0/concurrency.bend as Conc
import bend-kit-url@0.4.1.0/url.bend as Url
import bend-kit-json@0.7.3.0/json.bend as Json
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import bend-kit-dns@0.8.0.0/dns.bend as Dns
import bend-kit-zlib@0.7.0.1/native.bend as ZNative


def clock.instant(v: Clock.Instant) -> Time.Instant:
  match v:
    case Clock.Instant{s, n}:
      Time.Instant{s, n}

def clock.duration(v: Clock.Duration) -> Time.Duration:
  match v:
    case Clock.Duration{s, n}:
      Time.Duration{s, n}

def clock.now() -> IO(Time.Instant):
  do IO<Time.Instant>:
    now : Clock.Instant <- Clock.now()
    return clock.instant(now)

def clock.mono() -> IO(Time.Duration):
  do IO<Time.Duration>:
    now : Clock.Duration <- Clock.mono()
    return clock.duration(now)

type Reply is Type:
  Reply{response: Pure.Res, receipt: Completion.Receipt}

def reply.complete(~D: Data, ~done: Completion.Completion<D> -> IO(Unit), payload: D, response: Pure.Res) -> Reply:
  Reply{response, Completion.receipt(~D, ~done, payload)}


# The body type and its conversions, so a caller needs no bytes import.
def io.recv.words(tls: Bool, s: Socket, max: U32, ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  match tls:
    case True{}:
      Wire.tls.recv.words(s, max, ms)
    case False{}:
      Wire.recv.words(s, max, ms)

def io.send.words(tls: Bool, s: Socket, +len: U32, buf: Array<U32>) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match tls:
    case True{}:
      Wire.tls.send.words(s, len, buf)
    case False{}:
      Wire.send.words(s, len, buf)

def io.send.bytes(tls: Bool, s: Socket, b: Bytes.Bytes) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  Bytes.Bytes{+len, buf} = b
  io.send.words(tls, s, len, buf)

def io.close(tls: Bool, s: Socket) -> IO(Unit):
  match tls:
    case True{}:
      Wire.tls.close(s)
    case False{}:
      Socket.close(s)

def fetch.close(tls: Bool, s: Socket, r: Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  do IO<Result<&1, &1, Pure.Err, Pure.Res>>:
    io.close(tls, s)
    return r

# none: no response byte arrived, so an idempotent request may be retried (RFC 9112 §9.3.1).
# sock: the socket, when it can take another request.
def fetch.bad(tls: Bool, s: Socket, e: Maybe<&2, Pure.Err>) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  match e:
    case None{}:
      fetch.close(tls, s, Fail{Pure.ErrBad{}})
    case Some{err}:
      fetch.close(tls, s, Fail{err})

def fetch.shut(tls: Bool, s: Socket, r: Result<&1, &1, Pure.Err, Pure.Res>, none: Bool) -> IO(Pure.Out):
  do IO<Pure.Out>:
    x : Result<&1, &1, Pure.Err, Pure.Res> <- fetch.close(tls, s, r)
    return Pure.fetch.boxed(x, none)

def fetch.hold.go(tls: Bool, s: Socket, res: Pure.Res, left: Maybe<&1, Bytes.Bytes>) -> IO(Pure.Out):
  match left:
    case Some{x}:
      IO.pure(Pure.Out, Pure.OutDone{res, Some{s}, x})
    case None{}:
      fetch.shut(tls, s, Done{res}, False{})

def fetch.hold(tls: Bool, close: Bool, s: Socket, res: Pure.Res, left: Maybe<&1, Bytes.Bytes>) -> IO(Pure.Out):
  Pure.Res{status, +headers, body} = res
  fetch.hold.go(tls, s, Pure.Res{status, headers, body}, Pure.again(close, headers, left))

def fetch.failout(tls: Bool, s: Socket, e: Maybe<&2, Pure.Err>, none: Bool) -> IO(Pure.Out):
  do IO<Pure.Out>:
    r : Result<&1, &1, Pure.Err, Pure.Res> <- fetch.bad(tls, s, e)
    return Pure.fetch.boxed(r, none)

# Read state: the response so far and the bytes read, or how it ended.
# none: no byte arrived, so an idempotent request may be retried.
@unsafe
def fetch.loop(+close: Bool, +head: Bool, +tls: Bool, +ms: U32, st: Socket & Pure.Fl) -> IO(Pure.Out):
  (s, fl) = st
  match fl:
    case Pure.FlMore{rv, +n}:
      do IO<Pure.Out>:
        m : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- io.recv.words(tls, s, 65536, ms)
        fetch.loop(close, head, tls, ms, Pure.fetch.next(head, rv, n, m))
    case Pure.FlBad{err, none}:
      fetch.failout(tls, s, err, none)
    case Pure.FlDone{res, rest}:
      fetch.hold(tls, close, s, res, rest)

def exchange.sent(+tls: Bool, +ms: U32, +close: Bool, +head: Bool, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Pure.Out):
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      fetch.shut(tls, s, Fail{Pure.err.or_late(code, Pure.ErrWrite{code, why})}, True{})
    case Done{u}:
      fetch.loop(close, head, tls, ms, (s, Pure.FlMore{Pure.rv.start(), 0}))

def exchange.go(+tls: Bool, +ms: U32, +close: Bool, +head: Bool, s: Socket, wire: Bytes.Bytes) -> IO(Pure.Out):
  do IO<Pure.Out>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- io.send.bytes(tls, s, wire)
    exchange.sent(tls, ms, close, head, sent)

def exchange(+tls: Bool, +ms: U32, +close: Bool, +head: Bool, s: Socket, wire: Bytes.Bytes) -> IO(Maybe<&1, Socket> & Result<&1, &1, Pure.Err, Pure.Res> & Bytes.Bytes):
  do IO<Maybe<&1, Socket> & Result<&1, &1, Pure.Err, Pure.Res> & Bytes.Bytes>:
    o : Pure.Out <- exchange.go(tls, ms, close, head, s, wire)
    return Pure.exchange.tup(o)

# Paths to a PEM client chain and its private key for mutual TLS.
type Conn is Type:
  Conn{tls: Bool, s: Socket}
  ConnH2{s: Socket, client: H2.Client}

type H2Reader is Type:
  H2Reader{s: Socket, client: H2.Client, id: U32, events: List<&1, H2.ClientEvent>}

type H2Step is Type:
  H2Pending{reader: H2Reader}
  H2Event{got: Result<&1, &1, Pure.Err, H2Reader & H2.ClientEvent>}

type Pool is Type:
  Pool{cap: U32, idle: Map<&1, List<&1, Conn>>}

def pool.new.with(+cap: U32) -> Pool:
  Pool{cap, Map.new(&1, List<&1, Conn>)}

# Up to 8 idle sockets per origin.
def pool.new() -> Pool:
  pool.new.with(8)

def pool.take.of(+cap: U32, +key: String, r: Map<&1, List<&1, Conn>> & Maybe<&1, List<&1, Conn>>) -> Pool & Maybe<&1, Conn>:
  (m, got) = r
  match got:
    case None{}:
      (Pool{cap, m}, None{})
    case Some{xs}:
      match xs:
        case Nil{}:
          (Pool{cap, m}, None{})
        case Con{c, t}:
          (Pool{cap, Map.set(&1, List<&1, Conn>, m, key, t)}, Some{c})

# The socket given back last.
def pool.take(p: Pool, +key: String) -> Pool & Maybe<&1, Conn>:
  Pool{+cap, idle} = p
  pool.take.of(cap, key, Map.pop(&1, List<&1, Conn>, idle, key))

def conn.close(c: Conn) -> IO(Unit):
  match c:
    case Conn{tls, s}:
      io.close(tls, s)
    case ConnH2{s, client}:
      Wire.tls.close(s)

# The first n sockets; the rest are closed.
def conns.cut(xs: List<&1, Conn>, n: Nat) -> IO(List<&1, Conn>):
  match xs:
    case Nil{}:
      IO.pure(List<&1, Conn>, Nil{})
    case Con{c, t}:
      match n:
        case 0n:
          do IO<List<&1, Conn>>:
            conn.close(c)
            conns.cut(t, 0n)
        case 1n+k:
          do IO<List<&1, Conn>>:
            r : List<&1, Conn> <- conns.cut(t, k)
            return c <> r

def pool.give.of(+cap: U32, +key: String, c: Conn, limit: Nat,
    r: Map<&1, List<&1, Conn>> & Maybe<&1, List<&1, Conn>>) -> IO(Pool):
  (m, old) = r
  do IO<Pool>:
    xs : List<&1, Conn> <- conns.cut(c <> Maybe.default(&1, List<&1, Conn>, old, Nil{}), limit)
    return Pool{cap, Map.set(&1, List<&1, Conn>, m, key, xs)}

# Past the limit (cap for HTTP/1.1, one session for HTTP/2), close the oldest idle connection.
def pool.give(p: Pool, +key: String, c: Conn) -> IO(Pool):
  Pool{+cap, idle} = p
  match c:
    case Conn{tls, s}:
      pool.give.of(cap, key, Conn{tls, s}, U32.to_nat(cap), Map.pop(&1, List<&1, Conn>, idle, key))
    case ConnH2{s, client}:
      pool.give.of(cap, key, ConnH2{s, client}, Bool.pick(Nat, U32.is_zero(cap), 0n, 1n),
        Map.pop(&1, List<&1, Conn>, idle, key))

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

# RFC 9110 §9.2.2
def conn.tls(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&1, &1, Pure.Err, Conn>):
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      do IO<Result<&1, &1, Pure.Err, Conn>>:
        Wire.tls.close(s)
        return Fail{Pure.err.or_late(code, Pure.ErrTls{code, why})}
    case Done{u}:
      IO.pure(Result<&1, &1, Pure.Err, Conn>, Done{Conn{True{}, s}})

def conn.h2.sent(client: H2.Client, r: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&1, &1, Pure.Err, Conn>):
  (s, sent) = r
  match sent:
    case Fail{(+code, why)}:
      do IO<Result<&1, &1, Pure.Err, Conn>>:
        Wire.tls.close(s)
        return Fail{Pure.err.or_late(code, Pure.ErrWrite{code, why})}
    case Done{u}:
      IO.pure(Result<&1, &1, Pure.Err, Conn>, Done{ConnH2{s, client}})

def conn.h2.start(s: Socket, r: H2.Client & HBytes.Bytes) -> IO(Result<&1, &1, Pure.Err, Conn>):
  (client, HBytes.Bytes{len, buf}) = r
  do IO<Result<&1, &1, Pure.Err, Conn>>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.send.words(s, len, buf)
    conn.h2.sent(client, sent)

def conn.tls.protocol(proto: String, s: Socket) -> IO(Result<&1, &1, Pure.Err, Conn>):
  match proto:
    case "h2":
      conn.h2.start(s, H2.client.start())
    case "http/1.1":
      IO.pure(Result<&1, &1, Pure.Err, Conn>, Done{Conn{True{}, s}})
    case "":
      IO.pure(Result<&1, &1, Pure.Err, Conn>, Done{Conn{True{}, s}})
    case other:
      do IO<Result<&1, &1, Pure.Err, Conn>>:
        Wire.tls.close(s)
        return Fail{Pure.ErrTls{71, "unsupported ALPN: " ++ other}}

def conn.tls.alpn(m: Socket & Result<&1, &1, U32 & String, String>) -> IO(Result<&1, &1, Pure.Err, Conn>):
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      do IO<Result<&1, &1, Pure.Err, Conn>>:
        Wire.tls.close(s)
        return Fail{Pure.err.or_late(code, Pure.ErrTls{code, why})}
    case Done{proto}:
      conn.tls.protocol(proto, s)

def conn.secure.store(offer: Bool, s: Socket, host: String, +ms: U32) ->
    IO(Result<&1, &1, Pure.Err, Conn>):
  match offer:
    case True{}:
      do IO<Result<&1, &1, Pure.Err, Conn>>:
        hs : Socket & Result<&1, &1, U32 & String, String> <-
          Wire.tls.connect.alpn(s, host, ms, "h2,http/1.1")
        conn.tls.alpn(hs)
    case False{}:
      do IO<Result<&1, &1, Pure.Err, Conn>>:
        hs : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect(s, host, ms)
        conn.tls(hs)

def conn.secure.file(offer: Bool, s: Socket, host: String, +ms: U32, +ca: String) ->
    IO(Result<&1, &1, Pure.Err, Conn>):
  match offer:
    case True{}:
      do IO<Result<&1, &1, Pure.Err, Conn>>:
        hs : Socket & Result<&1, &1, U32 & String, String> <-
          Wire.tls.connect.alpn.ca(s, host, ms, "h2,http/1.1", ca)
        conn.tls.alpn(hs)
    case False{}:
      do IO<Result<&1, &1, Pure.Err, Conn>>:
        hs : Socket & Result<&1, &1, U32 & String, Unit> <-
          Wire.tls.connect.ca(s, host, ms, ca)
        conn.tls(hs)

def conn.secure.no.cert(empty: Bool, offer: Bool, s: Socket, host: String, +ms: U32,
    +ca: String) -> IO(Result<&1, &1, Pure.Err, Conn>):
  match empty:
    case True{}:
      conn.secure.store(offer, s, host, ms)
    case False{}:
      conn.secure.file(offer, s, host, ms, ca)

def conn.secure.tls(cert: Maybe<&2, Pure.Cert>, s: Socket, host: String, +ms: U32,
    offer: Bool, +ca: String) -> IO(Result<&1, &1, Pure.Err, Conn>):
  match cert:
    case None{}:
      conn.secure.no.cert(String.is_empty(ca), offer, s, host, ms, ca)
    case Some{Pure.Cert{chain, key}}:
      do IO<Result<&1, &1, Pure.Err, Conn>>:
        hs : Socket & Result<&1, &1, U32 & String, Unit> <-
          Wire.tls.connect.cert(s, host, ms, chain, key)
        conn.tls(hs)

# A failed handshake is an error, never plaintext.
def conn.secure(+ms: U32, sni: String, s: Socket, tls: Bool,
    cert: Maybe<&2, Pure.Cert>, offer: Bool, +ca: String) -> IO(Result<&1, &1, Pure.Err, Conn>):
  match tls:
    case False{}:
      IO.pure(Result<&1, &1, Pure.Err, Conn>, Done{Conn{False{}, s}})
    case True{}:
      conn.secure.tls(cert, s, sni, ms, offer, ca)

def conn.made(+ms: U32, sni: String, tls: Bool, cert: Maybe<&2, Pure.Cert>,
    offer: Bool, +ca: String, r: Result<&1, &1, U32 & String, Socket>) ->
    IO(Result<&1, &1, Pure.Err, Conn>):
  match r:
    case Fail{(+code, why)}:
      IO.pure(Result<&1, &1, Pure.Err, Conn>, Fail{Pure.err.or_late(code, Pure.ErrConnect{code, why})})
    case Done{s}:
      conn.secure(ms, sni, s, tls, cert, offer, ca)

def conn.open(+tls: Bool, +ms: U32, sni: String, ip: String, port: U32) ->
    IO(Result<&1, &1, Pure.Err, Conn>):
  do IO<Result<&1, &1, Pure.Err, Conn>>:
    c : Result<&1, &1, U32 & String, Socket> <- Wire.connect(ip, port, ms)
    conn.made(ms, sni, tls, None{}, False{}, "", c)

# ponytail: addresses are tried in order, not raced; a broken first route can consume the step timeout.
type Dial is Type:
  Dial{port: U32, ms: U32, deadline: Nat, action: IO(Result<&1, &1, U32 & String, Socket>)}

def conn.dial.time(+ip: String, +port: U32, +deadline: Nat, now: Nat, expired: Bool) ->
  IO(Result<&1, &1, U32 & String, Socket>):
  match expired:
    case True{}:
      IO.pure(Result<&1, &1, U32 & String, Socket>, Fail{(60, "connect timeout")})
    case False{}:
      Wire.connect(ip, port, U32.from_nat(Nat.sub(deadline, now)))

def conn.dial.with(+ip: String, +port: U32, +ms: U32, +deadline: Nat, +now: Nat, unlimited: Bool) ->
  IO(Result<&1, &1, U32 & String, Socket>):
  match unlimited:
    case True{}:
      Wire.connect(ip, port, 0)
    case False{}:
      conn.dial.time(ip, port, deadline, now, Nat.is_le(deadline, now))

def conn.dial.try(+ip: String, +port: U32, +ms: U32, +deadline: Nat) ->
  IO(Result<&1, &1, U32 & String, Socket>):
  do IO<Result<&1, &1, U32 & String, Socket>>:
    now : Nat <- IO.now()
    conn.dial.with(ip, port, ms, deadline, now, U32.is_zero(ms))

def conn.dial.after(r: Result<&1, &1, U32 & String, Socket>, ip: String, +port: U32, +ms: U32, +deadline: Nat) ->
  IO(Result<&1, &1, U32 & String, Socket>):
  match r:
    case Done{s}:
      IO.pure(Result<&1, &1, U32 & String, Socket>, Done{s})
    case Fail{e}:
      conn.dial.try(ip, port, ms, deadline)

def conn.dial.more(prev: IO(Result<&1, &1, U32 & String, Socket>), ip: String, +port: U32, +ms: U32, +deadline: Nat) ->
  IO(Result<&1, &1, U32 & String, Socket>):
  do IO<Result<&1, &1, U32 & String, Socket>>:
    r : Result<&1, &1, U32 & String, Socket> <- prev
    conn.dial.after(r, ip, port, ms, deadline)

def conn.dial.fold(d: Dial, ip: String) -> Dial:
  Dial{+port, +ms, +deadline, action} = d
  Dial{port, ms, deadline, conn.dial.more(action, ip, port, ms, deadline)}

def conn.dial.run(d: Dial) -> IO(Result<&1, &1, U32 & String, Socket>):
  Dial{port, ms, deadline, action} = d
  action

def conn.dial.all(+port: U32, +ms: U32, +start: Nat, first: String, rest: List<&2, String>) ->
  IO(Result<&1, &1, U32 & String, Socket>):
  match rest:
    case Nil{}:
      Wire.connect(first, port, ms)
    case Con{ip, tail}:
      +deadline = Nat.add(start, U32.to_nat(ms))
      conn.dial.run(List.foldl(~&2, ~String, ~Dial, ~conn.dial.fold, Con{ip, tail},
        Dial{port, ms, deadline, Wire.connect(first, port, ms)}))

def conn.open.all(+tls: Bool, +ms: U32, +host: String, +port: U32,
    ips: List<&2, String>, cert: Maybe<&2, Pure.Cert>, offer: Bool, +ca: String) ->
    IO(Result<&1, &1, Pure.Err, Conn>):
  match ips:
    case Nil{}:
      IO.pure(Result<&1, &1, Pure.Err, Conn>, Fail{Pure.ErrDns{}})
    case Con{addr, rest}:
      do IO<Result<&1, &1, Pure.Err, Conn>>:
        start : Nat <- IO.now()
        r : Result<&1, &1, U32 & String, Socket> <- conn.dial.all(port, ms, start, addr, rest)
        conn.made(ms, host, tls, cert, offer, ca, r)

def proxy.env.lower(r: Result<&1, &1, U32 & String, String>, upper: String) ->
    IO(String):
  match r:
    case Done{value}:
      IO.pure(String, value)
    case Fail{e}:
      do IO<String>:
        got : Result<&1, &1, U32 & String, String> <- IO.get_env(upper)
        return Pure.proxy.env.value(got)

def proxy.env(lower: String, upper: String) -> IO(String):
  do IO<String>:
    got : Result<&1, &1, U32 & String, String> <- IO.get_env(lower)
    proxy.env.lower(got, upper)

def proxy.select(+scheme: String, +host: String, +port: U32) ->
    IO(Maybe<&2, Pure.Proxy>):
  +secure = String.eq(scheme, "https")
  do IO<Maybe<&2, Pure.Proxy>>:
    bypass : String <- proxy.env("no_proxy", "NO_PROXY")
    value : String <- proxy.env(Bool.pick(String, secure, "https_proxy", "http_proxy"),
      Bool.pick(String, secure, "HTTPS_PROXY", "HTTP_PROXY"))
    return Pure.proxy.choose(Pure.proxy.no_match(host, port, bypass), value)

def h2.header.values(+name: String, +mode: U32, vs: List<&2, String>) -> List<&2, Hpack.Field>:
  match vs:
    case Nil{}:
      Nil{}
    case Con{v, tail}:
      Hpack.Field{name, Pure.sanitize(v), mode} <> h2.header.values(name, mode, tail)

def h2.header.item(skip: Bool, +name: String, vs: List<&2, String>,
    tail: List<&2, Hpack.Field>) -> List<&2, Hpack.Field>:
  match skip:
    case True{}:
      tail
    case False{}:
      List.append(&2, Hpack.Field, h2.header.values(name, Pure.h2.header.mode(name), vs), tail)

def h2.header.items(xs: List<&2, Sigma<&2, &2, String, _ => List<&2, String>>>,
    +nominated: List<&2, String>) -> List<&2, Hpack.Field>:
  match xs:
    case Nil{}:
      Nil{}
    case (name, values) <> tail:
      +key = String.to_lower(name)
      h2.header.item(Bool.or(Pure.h2.header.skip(key), Pure.h2.header.has(nominated, key)),
        key, values, h2.header.items(tail, nominated))

def h2.request.fields(+method: String, target: String, authority: String,
    headers: Map<&2, List<&2, String>>) -> List<&2, Hpack.Field>:
  +xs = Map.to_list(&2, List<&2, String>, headers)
  List.append(&2, Hpack.Field,
    [Hpack.Field{":method", method, 0}, Hpack.Field{":scheme", "https", 0},
      Hpack.Field{":authority", authority, 0}, Hpack.Field{":path", target, 0}],
    h2.header.items(xs, Pure.h2.header.nominated(xs)))

def h2.response.status(xs: List<&2, Hpack.Field>) -> Maybe<&2, U32>:
  match xs:
    case Nil{}:
      None{}
    case Con{Hpack.Field{name, +value, mode}, tail}:
      match name:
        case ":status":
          Pure.h2.response.status.value(value, Nat.is_eq(String.length(value), 3n))
        case other:
          h2.response.status(tail)

def h2.response.headers(xs: List<&2, Hpack.Field>, acc: Map<&2, List<&2, String>>) ->
    Map<&2, List<&2, String>>:
  match xs:
    case Nil{}:
      acc
    case Con{Hpack.Field{name, value, mode}, tail}:
      match name:
        case SCon{Chr{58}, rest}:
          h2.response.headers(tail, acc)
        case other:
          h2.response.headers(tail, Pure.add(acc, String.to_lower(name), value))

def h2.response.final(interim: Bool, +status: U32, headers: List<&2, Hpack.Field>,
    body: HBytes.Bytes) -> Result<&1, &1, Pure.Err, Maybe<&1, Pure.Res>>:
  match interim:
    case True{}:
      Done{None{}}
    case False{}:
      HBytes.Bytes{len, buf} = body
      Done{Some{Pure.Res{status, h2.response.headers(headers, Pure.empty()), Bytes.Bytes{len, buf}}}}

def h2.response.valid(valid: Bool, +status: U32, headers: List<&2, Hpack.Field>,
    body: HBytes.Bytes) -> Result<&1, &1, Pure.Err, Maybe<&1, Pure.Res>>:
  match valid:
    case False{}:
      Fail{Pure.ErrBad{}}
    case True{}:
      h2.response.final(U32.is_lt(status, 200), status, headers, body)

def h2.response.parsed(m: Maybe<&2, U32>, headers: List<&2, Hpack.Field>,
    body: HBytes.Bytes) -> Result<&1, &1, Pure.Err, Maybe<&1, Pure.Res>>:
  match m:
    case None{}:
      Fail{Pure.ErrBad{}}
    case Some{+status}:
      h2.response.valid(Bool.and(U32.is_ge(status, 100), U32.is_lt(status, 600)),
        status, headers, body)

def h2.response(+fields: List<&2, Hpack.Field>, body: HBytes.Bytes) ->
    Result<&1, &1, Pure.Err, Maybe<&1, Pure.Res>>:
  h2.response.parsed(h2.response.status(fields), fields, body)


def h2.send.report(r: Socket & Result<&1, &1, U32 & String, Unit>) ->
    IO(Result<&1, &1, Pure.Err, Socket>):
  (s, sent) = r
  match sent:
    case Fail{(+code, why)}:
      do IO<Result<&1, &1, Pure.Err, Socket>>:
        Wire.tls.close(s)
        return Fail{Pure.err.or_late(code, Pure.ErrWrite{code, why})}
    case Done{unit}:
      IO.pure(Result<&1, &1, Pure.Err, Socket>, Done{s})

def h2.send.one(prev: Result<&1, &1, Pure.Err, Socket>, b: HBytes.Bytes) ->
    IO(Result<&1, &1, Pure.Err, Socket>):
  match prev:
    case Fail{e}:
      IO.pure(Result<&1, &1, Pure.Err, Socket>, Fail{e})
    case Done{s}:
      HBytes.Bytes{len, buf} = b
      do IO<Result<&1, &1, Pure.Err, Socket>>:
        sent : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.send.words(s, len, buf)
        h2.send.report(sent)

def h2.send.fold(prev: IO(Result<&1, &1, Pure.Err, Socket>), b: HBytes.Bytes) ->
    IO(Result<&1, &1, Pure.Err, Socket>):
  do IO<Result<&1, &1, Pure.Err, Socket>>:
    r : Result<&1, &1, Pure.Err, Socket> <- prev
    h2.send.one(r, b)

def h2.send(xs: List<&1, HBytes.Bytes>, s: Socket) -> IO(Result<&1, &1, Pure.Err, Socket>):
  List.foldl(~&1, ~HBytes.Bytes, ~IO(Result<&1, &1, Pure.Err, Socket>), ~h2.send.fold,
    xs, IO.pure(Result<&1, &1, Pure.Err, Socket>, Done{s}))

def h2.reader.fail(s: Socket, e: Pure.Err) ->
    IO(Result<&1, &1, Pure.Err, H2Reader & H2.ClientEvent>):
  do IO<Result<&1, &1, Pure.Err, H2Reader & H2.ClientEvent>>:
    Wire.tls.close(s)
    return Fail{e}

def h2.reader.sent(+id: U32, client: H2.Client, events: List<&1, H2.ClientEvent>,
    sent: Result<&1, &1, Pure.Err, Socket>) -> Result<&1, &1, Pure.Err, H2Reader>:
  match sent:
    case Fail{e}:
      Fail{e}
    case Done{s}:
      Done{H2Reader{s, client, id, events}}

def h2.reader.reply(s: Socket, +id: U32, reply: H2.Reply) ->
    IO(Result<&1, &1, Pure.Err, H2Reader>):
  match reply:
    case H2.Failed{error}:
      do IO<Result<&1, &1, Pure.Err, H2Reader>>:
        Wire.tls.close(s)
        return Fail{Pure.ErrBad{}}
    case H2.Advanced{client, writes, events}:
      do IO<Result<&1, &1, Pure.Err, H2Reader>>:
        sent : Result<&1, &1, Pure.Err, Socket> <- h2.send(writes, s)
        return h2.reader.sent(id, client, events, sent)

def h2.reader.released(s: Socket, +id: U32, events: List<&1, H2.ClientEvent>,
    reply: H2.Reply) -> IO(Result<&1, &1, Pure.Err, H2Reader>):
  match reply:
    case H2.Failed{error}:
      do IO<Result<&1, &1, Pure.Err, H2Reader>>:
        Wire.tls.close(s)
        return Fail{Pure.ErrBad{}}
    case H2.Advanced{client, writes, more}:
      do IO<Result<&1, &1, Pure.Err, H2Reader>>:
        sent : Result<&1, &1, Pure.Err, Socket> <- h2.send(writes, s)
        return h2.reader.sent(id, client, List.append(&1, H2.ClientEvent, events, more), sent)

def h2.reader.release(reader: H2Reader, +amount: U32) ->
    IO(Result<&1, &1, Pure.Err, H2Reader>):
  H2Reader{s, H2.Client{H2.Input{frames, discard, +pending}, streams, encoder, decoder, control},
    +id, events} = reader
  # Reset and GOAWAY can invalidate capacity in events already queued by receive.
  count = Bool.pick(U32, U32.is_zero(H2.client.credit.get(pending, id)), 0, amount)
  h2.reader.released(s, id, events, H2.client.release_capacity(
    H2.Client{H2.Input{frames, discard, pending}, streams, encoder, decoder, control}, id, count))

def h2.step(r: Result<&1, &1, Pure.Err, H2Reader>) -> H2Step:
  match r:
    case Fail{e}:
      H2Event{Fail{e}}
    case Done{reader}:
      H2Pending{reader}

def h2.reader.received(client: H2.Client, +id: U32,
    got: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) ->
    IO(Result<&1, &1, Pure.Err, H2Reader>):
  match got:
    case (s, Fail{(+code, why)}):
      do IO<Result<&1, &1, Pure.Err, H2Reader>>:
        Wire.tls.close(s)
        return Fail{Pure.err.or_late(code, Pure.ErrRead{code, why})}
    case (s, Done{(0, buf)}):
      do IO<Result<&1, &1, Pure.Err, H2Reader>>:
        Wire.tls.close(s)
        return Fail{Pure.ErrBad{}}
    case (s, Done{(len, buf)}):
      h2.reader.reply(s, id, H2.client.receive(client, HBytes.Bytes{len, buf}))

def h2.event.for(+want: U32, event: H2.ClientEvent) -> Bool & H2.ClientEvent:
  match event:
    case H2.Informational{+id, headers}:
      (U32.is_eq(id, want), H2.Informational{id, headers})
    case H2.Headers{+id, headers}:
      (U32.is_eq(id, want), H2.Headers{id, headers})
    case H2.Chunk{+id, bytes, capacity}:
      (U32.is_eq(id, want), H2.Chunk{id, bytes, capacity})
    case H2.Trailers{+id, headers}:
      (U32.is_eq(id, want), H2.Trailers{id, headers})
    case H2.Complete{+id}:
      (U32.is_eq(id, want), H2.Complete{id})
    case H2.Reset{+id, code}:
      (U32.is_eq(id, want), H2.Reset{id, code})
    case H2.Shutdown{last, code}:
      (True{}, H2.Shutdown{last, code})
    case H2.Pong{data}:
      (True{}, H2.Pong{data})

def h2.reader.selected(selected: Bool & H2.ClientEvent, reader: H2Reader) ->
    IO(Result<&1, &1, Pure.Err, H2Reader & H2.ClientEvent>):
  match selected:
    case (True{}, event):
      IO.pure(Result<&1, &1, Pure.Err, H2Reader & H2.ClientEvent>, Done{(reader, event)})
    case (False{}, event):
      H2Reader{s, client, id, events} = reader
      h2.reader.fail(s, Pure.ErrBad{})

def h2.reader.next(n: Nat, r: Result<&1, &1, Pure.Err, H2Reader>, +ms: U32) ->
    IO(Result<&1, &1, Pure.Err, H2Reader & H2.ClientEvent>):
  match n r:
    case _ Fail{e}:
      IO.pure(Result<&1, &1, Pure.Err, H2Reader & H2.ClientEvent>, Fail{e})
    case 0n Done{H2Reader{s, client, id, events}}:
      h2.reader.fail(s, Pure.ErrBad{})
    case 1n+p Done{H2Reader{s, client, +id, Nil{}}}:
      do IO<Result<&1, &1, Pure.Err, H2Reader & H2.ClientEvent>>:
        got : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <-
          Wire.tls.recv.words(s, 16384, ms)
        next : Result<&1, &1, Pure.Err, H2Reader> <- h2.reader.received(client, id, got)
        h2.reader.next(p, next, ms)
    case 1n+p Done{H2Reader{s, client, +id, event <> rest}}:
      h2.reader.selected(h2.event.for(id, event), H2Reader{s, client, id, rest})

def h2.reader.start(s: Socket, client: H2.Client, request: Pure.Send) ->
    IO(Result<&1, &1, Pure.Err, H2Reader>):
  H2.Client{input, streams, encoder, decoder, +control} = client
  H2.Control{+next, active, frame_max, initial, max_streams, send_window,
    recv_window, first, ack, continuation, goaway} = control
  Pure.Send{method, target, authority, headers, Bytes.Bytes{len, buf}} = request
  h2.reader.reply(s, next, H2.client.request(
    H2.Client{input, streams, encoder, decoder, control},
    h2.request.fields(method, target, authority, headers), HBytes.Bytes{len, buf}))


def h2.buffered.fail(reader: H2Reader, e: Pure.Err) -> IO(Result<&1, &1, Pure.Err, Conn & Pure.Res>):
  H2Reader{s, client, id, events} = reader
  do IO<Result<&1, &1, Pure.Err, Conn & Pure.Res>>:
    Wire.tls.close(s)
    return Fail{e}

def h2.buffered.done(res: Maybe<&1, Pure.Res>, reader: H2Reader, parts: List<&1, Bytes.Bytes>) ->
    IO(Result<&1, &1, Pure.Err, Conn & Pure.Res>):
  match res:
    case None{}:
      h2.buffered.fail(reader, Pure.ErrBad{})
    case Some{Pure.Res{status, headers, body}}:
      H2Reader{s, client, id, events} = reader
      IO.pure(Result<&1, &1, Pure.Err, Conn & Pure.Res>,
        Done{(ConnH2{s, client}, Pure.Res{status, headers, Pure.rb.body(parts)})})

def h2.buffered.head(fields: List<&2, Hpack.Field>) -> Maybe<&1, Pure.Res>:
  Pure.h2.buffered.head.result(h2.response(fields, HBytes.new(0)))

def h2.buffered.loop(n: Nat, +ms: U32, over: Bool, step: H2Step,
    res: Maybe<&1, Pure.Res>, parts: List<&1, Bytes.Bytes>, +used: U32) ->
    IO(Result<&1, &1, Pure.Err, Conn & Pure.Res>):
  match n over step:
    case _ _ H2Event{Fail{e}}:
      IO.pure(Result<&1, &1, Pure.Err, Conn & Pure.Res>, Fail{e})
    case 0n _ H2Pending{reader}:
      h2.buffered.fail(reader, Pure.ErrBad{})
    case 0n _ H2Event{Done{(reader, event)}}:
      h2.buffered.fail(reader, Pure.ErrBad{})
    case _ True{} H2Pending{reader}:
      h2.buffered.fail(reader, Pure.ErrBad{})
    case _ True{} H2Event{Done{(reader, event)}}:
      h2.buffered.fail(reader, Pure.ErrBad{})
    case 1n+p False{} H2Pending{reader}:
      do IO<Result<&1, &1, Pure.Err, Conn & Pure.Res>>:
        next : Result<&1, &1, Pure.Err, H2Reader & H2.ClientEvent> <-
          h2.reader.next(65536n, Done{reader}, ms)
        h2.buffered.loop(p, ms, False{}, H2Event{next}, res, parts, used)
    case 1n+p False{} H2Event{Done{(reader, event)}}:
      match event:
        case H2.Headers{id, fields}:
          h2.buffered.loop(p, ms, False{}, H2Pending{reader},
            h2.buffered.head(fields), parts, used)
        case H2.Chunk{id, HBytes.Bytes{+len, buf}, capacity}:
          +total = (used + len : U32)
          do IO<Result<&1, &1, Pure.Err, Conn & Pure.Res>>:
            released : Result<&1, &1, Pure.Err, H2Reader> <- h2.reader.release(reader, capacity)
            h2.buffered.loop(p, ms, Pure.fetch.over(total), h2.step(released),
              res, Bytes.Bytes{len, buf} <> parts, total)
        case H2.Complete{id}:
          h2.buffered.done(res, reader, parts)
        case H2.Reset{id, code}:
          h2.buffered.fail(reader, Pure.ErrBad{})
        case other:
          h2.buffered.loop(p, ms, False{}, H2Pending{reader}, res, parts, used)

def h2.buffered.start(start: Result<&1, &1, Pure.Err, H2Reader>, +ms: U32) ->
    IO(Result<&1, &1, Pure.Err, Conn & Pure.Res>):
  match start:
    case Fail{e}:
      IO.pure(Result<&1, &1, Pure.Err, Conn & Pure.Res>, Fail{e})
    case Done{reader}:
      h2.buffered.loop(Nat.mul(4n, Nat.add(Pure.fetch.max(), 65536n)), ms,
        False{}, H2Pending{reader}, None{}, Nil{}, 0)

def h2.exchange(s: Socket, client: H2.Client, +ms: U32, request: Pure.Send) ->
    IO(Result<&1, &1, Pure.Err, Conn & Pure.Res>):
  do IO<Result<&1, &1, Pure.Err, Conn & Pure.Res>>:
    start : Result<&1, &1, Pure.Err, H2Reader> <- h2.reader.start(s, client, request)
    h2.buffered.start(start, ms)

def proxy.connect.fail(s: Socket, e: Pure.Err) -> IO(Result<&1, &1, Pure.Err, Conn>):
  do IO<Result<&1, &1, Pure.Err, Conn>>:
    io.close(False{}, s)
    return Fail{e}

def proxy.connect.extra(m: Maybe<&2, String>, s: Socket, +ms: U32,
    sni: String, cert: Maybe<&2, Pure.Cert>, +ca: String) -> IO(Result<&1, &1, Pure.Err, Conn>):
  match m:
    case None{}:
      proxy.connect.fail(s, Pure.ErrBad{})
    case Some{rest}:
      match rest:
        case SNil{}:
          conn.secure(ms, sni, s, True{}, cert, True{}, ca)
        case other:
          proxy.connect.fail(s, Pure.ErrBad{})

def proxy.connect.status(ok: Bool, +status: U32, raw: String, s: Socket,
    +ms: U32, sni: String, cert: Maybe<&2, Pure.Cert>, +ca: String) ->
    IO(Result<&1, &1, Pure.Err, Conn>):
  match ok:
    case False{}:
      proxy.connect.fail(s, Pure.ErrConnect{status, "proxy CONNECT refused"})
    case True{}:
      proxy.connect.extra(Pure.after(raw, True{}), s, ms, sni, cert, ca)

def proxy.connect.finish(res: Pure.Res, raw: String, s: Socket, +ms: U32,
    sni: String, cert: Maybe<&2, Pure.Cert>, +ca: String) -> IO(Result<&1, &1, Pure.Err, Conn>):
  Pure.Res{+status, headers, body} = res
  proxy.connect.status(Bool.and(U32.is_ge(status, 200), U32.is_lt(status, 300)),
    status, raw, s, ms, sni, cert, ca)

def proxy.connect.loop(n: Nat, step: Pure.TunnelStep, +ms: U32, +sni: String,
    +cert: Maybe<&2, Pure.Cert>, +ca: String) -> IO(Result<&1, &1, Pure.Err, Conn>):
  match n:
    case 0n:
      match step:
        case Pure.TunnelRead{s, raw}:
          proxy.connect.fail(s, Pure.ErrBad{})
        case Pure.TunnelHead{s, raw, result}:
          proxy.connect.fail(s, Pure.ErrBad{})
        case Pure.TunnelGot{raw, answer}:
          (s, result) = answer
          proxy.connect.fail(s, Pure.ErrBad{})
    case 1n+p:
      match step:
        case Pure.TunnelRead{s, +raw}:
          proxy.connect.loop(p, Pure.TunnelHead{s, raw,
            Pure.proxy.connect.frame(raw, Nat.is_gt(String.length(raw), 65536n))},
            ms, sni, cert, ca)
        case Pure.TunnelHead{s, raw, result}:
          match result:
            case Pure.FrameBad{}:
              proxy.connect.fail(s, Pure.ErrBad{})
            case Pure.FrameMore{}:
              do IO<Result<&1, &1, Pure.Err, Conn>>:
                answer : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <-
                  io.recv.words(False{}, s, 4096, ms)
                proxy.connect.loop(p, Pure.TunnelGot{raw, answer}, ms, sni, cert, ca)
            case Pure.FrameDone{res}:
              proxy.connect.finish(res, raw, s, ms, sni, cert, ca)
        case Pure.TunnelGot{raw, answer}:
          match answer:
            case (s, Fail{(+code, why)}):
              proxy.connect.fail(s, Pure.err.or_late(code, Pure.ErrRead{code, why}))
            case (s, Done{(+len, buf)}):
              proxy.connect.loop(p,
                Pure.proxy.connect.chunk(U32.is_zero(len), s, raw, len, buf),
                ms, sni, cert, ca)

def proxy.connect.sent(r: Socket & Result<&1, &1, U32 & String, Unit>,
    +ms: U32, sni: String, cert: Maybe<&2, Pure.Cert>, +ca: String) ->
    IO(Result<&1, &1, Pure.Err, Conn>):
  (s, sent) = r
  match sent:
    case Fail{(+code, why)}:
      proxy.connect.fail(s, Pure.err.or_late(code, Pure.ErrWrite{code, why}))
    case Done{unit}:
      proxy.connect.loop(Nat.mul(3n, 65536n), Pure.TunnelRead{s, ""}, ms, sni, cert, ca)

def proxy.connect(s: Socket, +ms: U32, sni: String, authority: String,
    authorization: String, cert: Maybe<&2, Pure.Cert>, +ca: String) ->
    IO(Result<&1, &1, Pure.Err, Conn>):
  do IO<Result<&1, &1, Pure.Err, Conn>>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <-
      io.send.bytes(False{}, s, Bytes.from_string(Pure.proxy.connect.header(authority, authorization)))
    proxy.connect.sent(sent, ms, sni, cert, ca)

def proxy.route.tls(tls: Bool, s: Socket, +ms: U32, sni: String,
    authority: String, authorization: String, cert: Maybe<&2, Pure.Cert>, +ca: String) ->
    IO(Result<&1, &1, Pure.Err, Conn>):
  match tls:
    case False{}:
      IO.pure(Result<&1, &1, Pure.Err, Conn>, Done{Conn{False{}, s}})
    case True{}:
      proxy.connect(s, ms, sni, authority, authorization, cert, ca)

def proxy.route.connected(tls: Bool, +ms: U32, sni: String, authority: String,
    authorization: String, cert: Maybe<&2, Pure.Cert>, +ca: String,
    r: Result<&1, &1, Pure.Err, Conn>) -> IO(Result<&1, &1, Pure.Err, Conn>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Pure.Err, Conn>, Fail{e})
    case Done{c}:
      match c:
        case Conn{plain, s}:
          proxy.route.tls(tls, s, ms, sni, authority, authorization, cert, ca)
        case ConnH2{s, client}:
          do IO<Result<&1, &1, Pure.Err, Conn>>:
            Wire.tls.close(s)
            return Fail{Pure.ErrBad{}}

def proxy.route.open(+ms: U32, +tls: Bool, +host: String, +port: U32,
    +sni: String, +authority: String, +authorization: String,
    cert: Maybe<&2, Pure.Cert>, +ca: String) -> IO(Result<&1, &1, Pure.Err, Conn>):
  do IO<Result<&1, &1, Pure.Err, Conn>>:
    ips : List<&2, String> <- Dns.resolve.all(host)
    conn : Result<&1, &1, Pure.Err, Conn> <-
      conn.open.all(False{}, ms, host, port, ips, None{}, False{}, "")
    proxy.route.connected(tls, ms, sni, authority, authorization, cert, ca, conn)

# offer: send the h2 ALPN offer on a direct TLS connection.
def route.open(+ms: U32, offer: Bool, route: Pure.Route) -> IO(Result<&1, &1, Pure.Err, Conn>):
  match route:
    case Pure.RouteDirect{tls, +host, port, cert, ca}:
      do IO<Result<&1, &1, Pure.Err, Conn>>:
        ips : List<&2, String> <- Dns.resolve.all(host)
        conn.open.all(tls, ms, host, port, ips, cert, offer, ca)
    case Pure.RouteProxy{tls, host, port, sni, authority, authorization, cert, ca}:
      proxy.route.open(ms, tls, host, port, sni, authority, authorization, cert, ca)

def conn.ex.h1(+tls: Bool, s: Socket, +ms: U32, request: Pure.Send) -> IO(Pure.Out):
  Pure.Send{+method, target, authority, headers, body} = request
  exchange.go(tls, ms, False{}, String.eq(method, "HEAD"), s,
    Pure.encode_req.on(method, target, authority, headers, body, False{}))

# A socket with bytes past the response is out of step with the server, so it is closed.
def pool.keep.s(p: Pool, +key: String, +tls: Bool, res: Pure.Res, s: Socket, clean: Bool) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  match clean:
    case True{}:
      do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res>>:
        p2 : Pool <- pool.give(p, key, Conn{tls, s})
        return (p2, Done{res})
    case False{}:
      do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res>>:
        io.close(tls, s)
        return (p, Done{res})

def pool.keep.m(p: Pool, +key: String, +tls: Bool, res: Pure.Res, +clean: Bool, sock: Maybe<&1, Socket>) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  match sock:
    case None{}:
      IO.pure(Pool & Result<&1, &1, Pure.Err, Pure.Res>, (p, Done{res}))
    case Some{s}:
      pool.keep.s(p, key, tls, res, s, clean)

def pool.keep(p: Pool, +key: String, +tls: Bool, res: Pure.Res, sock: Maybe<&1, Socket>, rest: Bytes.Bytes) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  Bytes.Bytes{+len, buf} = rest
  pool.keep.m(p, key, tls, res, U32.is_zero(len), sock)

def pool.after(p: Pool, +key: String, +tls: Bool, o: Pure.Out) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  match o:
    case Pure.OutFail{e, none}:
      IO.pure(Pool & Result<&1, &1, Pure.Err, Pure.Res>, (p, Fail{e}))
    case Pure.OutDone{res, sock, rest}:
      pool.keep(p, key, tls, res, sock, rest)

def pool.h2.reusable(c: Conn) -> Bool & Conn:
  match c:
    case Conn{tls, s}:
      (True{}, Conn{tls, s})
    case ConnH2{s, H2.Client{input, streams, encoder, decoder, +control}}:
      H2.Control{next, active, frame_max, initial, max_streams, send_window,
        recv_window, first, ack, continuation, +goaway} = control
      (Maybe.is_none(&2, U32, goaway),
        ConnH2{s, H2.Client{input, streams, encoder, decoder, control}})

type Took is Type:
  TookNone{}
  TookRaw{c: Conn}
  TookSeen{quiet: Bool, c: Conn}

def took.of(pm: Pool & Maybe<&1, Conn>) -> Pool & Took:
  (p, m) = pm
  match m:
    case None{}:
      (p, TookNone{})
    case Some{c}:
      (p, TookRaw{c})

def took.seen(+tls: Bool, r: Socket & Bool) -> Took:
  (s, quiet) = r
  TookSeen{quiet, Conn{tls, s}}

# A live session goes back to the peek; a session with GOAWAY is closed.
def h2.idle.kept(state: Bool & Conn) -> Took:
  (live, c) = state
  match live:
    case True{}:
      TookRaw{c}
    case False{}:
      TookSeen{False{}, c}

def h2.idle.sent(client: H2.Client, sent: Result<&1, &1, Pure.Err, Socket>) -> Took:
  match sent:
    case Fail{e}:
      TookNone{}
    case Done{s}:
      h2.idle.kept(pool.h2.reusable(ConnH2{s, client}))

def h2.idle.reply(s: Socket, reply: H2.Reply) -> IO(Took):
  match reply:
    case H2.Failed{error}:
      IO.pure(Took, TookSeen{False{}, Conn{True{}, s}})
    case H2.Advanced{client, writes, events}:
      do IO<Took>:
        sent : Result<&1, &1, Pure.Err, Socket> <- h2.send(writes, s)
        return h2.idle.sent(client, sent)

def h2.idle.read(client: H2.Client,
    got: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Took):
  match got:
    case (s, Fail{e}):
      IO.pure(Took, TookSeen{False{}, ConnH2{s, client}})
    case (s, Done{(0, buf)}):
      IO.pure(Took, TookSeen{False{}, ConnH2{s, client}})
    case (s, Done{(+len, buf)}):
      h2.idle.reply(s, H2.client.receive(client, HBytes.Bytes{len, buf}))

# Waiting bytes may be PING, SETTINGS, or GOAWAY frames, so the client reads them; EOF fails the read.
def h2.idle.peek(client: H2.Client, r: Socket & Bool) -> IO(Took):
  (s, quiet) = r
  match quiet:
    case True{}:
      IO.pure(Took, TookSeen{True{}, ConnH2{s, client}})
    case False{}:
      do IO<Took>:
        got : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <-
          Wire.tls.recv.words(s, 16384, 100)
        h2.idle.read(client, got)

def conn.idle(c: Conn) -> IO(Took):
  match c:
    case Conn{+tls, s}:
      do IO<Took>:
        r : Socket & Bool <- Wire.idle(s)
        return took.seen(tls, r)
    case ConnH2{s, client}:
      do IO<Took>:
        r : Socket & Bool <- Wire.idle(s)
        h2.idle.peek(client, r)

# Each idle socket takes two steps: the peek, then the close and the next take. Each read of HTTP/2 frames takes one more.
def pool.take.go(n: Nat, +key: String, pt: Pool & Took) -> IO(Pool & Maybe<&1, Conn>):
  match n pt:
    case _ Tuple{p, TookNone{}}:
      IO.pure(Pool & Maybe<&1, Conn>, (p, None{}))
    case _ Tuple{p, TookSeen{True{}, c}}:
      IO.pure(Pool & Maybe<&1, Conn>, (p, Some{c}))
    case 0n Tuple{p, TookRaw{c}}:
      do IO<Pool & Maybe<&1, Conn>>:
        conn.close(c)
        return (p, None{})
    case 0n Tuple{p, TookSeen{False{}, c}}:
      do IO<Pool & Maybe<&1, Conn>>:
        conn.close(c)
        return (p, None{})
    case 1n+k Tuple{p, TookRaw{c}}:
      do IO<Pool & Maybe<&1, Conn>>:
        t : Took <- conn.idle(c)
        pool.take.go(k, key, (p, t))
    case 1n+k Tuple{p, TookSeen{False{}, c}}:
      do IO<Pool & Maybe<&1, Conn>>:
        conn.close(c)
        pool.take.go(k, key, took.of(pool.take(p, key)))

# pool.take, but an idle connection that the peer closed, or an HTTP/1.1 socket with bytes waiting, is closed, and the next one is tried.
def pool.take.live(p: Pool, +key: String) -> IO(Pool & Maybe<&1, Conn>):
  Pool{+cap, idle} = p
  pool.take.go((2n * U32.to_nat(cap) + 2n : Nat), key, took.of(pool.take(Pool{cap, idle}, key)))

def pool.h2.keep(p: Pool, +key: String, res: Pure.Res, state: Bool & Conn) ->
    IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  (reusable, c) = state
  match reusable:
    case True{}:
      do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res>>:
        next : Pool <- pool.give(p, key, c)
        return (next, Done{res})
    case False{}:
      do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res>>:
        conn.close(c)
        return (p, Done{res})

def pool.h2.result(p: Pool, +key: String, r: Result<&1, &1, Pure.Err, Conn & Pure.Res>) ->
    IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  match r:
    case Fail{e}:
      IO.pure(Pool & Result<&1, &1, Pure.Err, Pure.Res>, (p, Fail{e}))
    case Done{(c, res)}:
      pool.h2.keep(p, key, res, pool.h2.reusable(c))

def pool.h2.ex(p: Pool, +key: String, +ms: U32, request: Pure.Send,
    s: Socket, client: H2.Client) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res>>:
    r : Result<&1, &1, Pure.Err, Conn & Pure.Res> <- h2.exchange(s, client, ms, request)
    pool.h2.result(p, key, r)

def pool.fresh.conn(p: Pool, +key: String, +ms: U32, request: Pure.Send,
    r: Result<&1, &1, Pure.Err, Conn>) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  match r:
    case Fail{e}:
      IO.pure(Pool & Result<&1, &1, Pure.Err, Pure.Res>, (p, Fail{e}))
    case Done{c}:
      match c:
        case Conn{+tls, s}:
          do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res>>:
            o : Pure.Out <- conn.ex.h1(tls, s, ms, request)
            pool.after(p, key, tls, o)
        case ConnH2{s, client}:
          pool.h2.ex(p, key, ms, request, s, client)

def pool.fresh(p: Pool, +key: String, +ms: U32, request: Pure.Send, route: Pure.Route) ->
    IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res>>:
    c : Result<&1, &1, Pure.Err, Conn> <- route.open(ms, True{}, route)
    pool.fresh.conn(p, key, ms, request, c)

# A reused socket the server already closed fails before any response byte.
def pool.stale(p: Pool, +key: String, +ms: U32, request: Pure.Send,
    e: Pure.Err, again: Bool, route: Pure.Route) ->
    IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  match again:
    case True{}:
      pool.fresh(p, key, ms, request, route)
    case False{}:
      IO.pure(Pool & Result<&1, &1, Pure.Err, Pure.Res>, (p, Fail{e}))

def pool.reused(p: Pool, +key: String, +tls: Bool, +ms: U32, +idem: Bool,
    spare: Pure.Send, o: Pure.Out, route: Pure.Route) ->
    IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  match o:
    case Pure.OutFail{e, +none}:
      pool.stale(p, key, ms, spare, e, Pure.pool.retry(none, idem), route)
    case Pure.OutDone{res, sock, rest}:
      pool.keep(p, key, tls, res, sock, rest)

# Copy only the reused HTTP/1.1 request body, for a stale-socket retry.
def pool.idle.h1.bodies(p: Pool, +key: String, +tls: Bool, +ms: U32, +idem: Bool,
    s: Socket, +method: String, +target: String, +authority: String,
    +headers: Map<&2, List<&2, String>>, r: Bytes.Bytes & Bytes.Bytes,
    route: Pure.Route) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  (wire, spare) = r
  do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res>>:
    o : Pure.Out <- conn.ex.h1(tls, s, ms, Pure.Send{method, target, authority, headers, wire})
    pool.reused(p, key, tls, ms, idem,
      Pure.Send{method, target, authority, headers, spare}, o, route)

def pool.idle.h1(p: Pool, +key: String, +tls: Bool, +ms: U32, +idem: Bool,
    s: Socket, request: Pure.Send, route: Pure.Route) ->
    IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  Pure.Send{+method, +target, +authority, +headers, body} = request
  pool.idle.h1.bodies(p, key, tls, ms, idem, s, method, target,
    authority, headers, Bytes.slice(body, 0, 4294967295), route)

def pool.idle.reuse(p: Pool, +key: String, +ms: U32, +idem: Bool,
    c: Conn, request: Pure.Send, route: Pure.Route) ->
    IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  match c:
    case Conn{tls, s}:
      pool.idle.h1(p, key, tls, ms, idem, s, request, route)
    case ConnH2{s, client}:
      pool.h2.ex(p, key, ms, request, s, client)

def pool.idle(taken: Pool & Maybe<&1, Conn>, +key: String, +ms: U32,
    +idem: Bool, request: Pure.Send, route: Pure.Route) ->
    IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  (p, m) = taken
  match m:
    case None{}:
      pool.fresh(p, key, ms, request, route)
    case Some{c}:
      pool.idle.reuse(p, key, ms, idem, c, request, route)

def pool.origin.route(p: Pool, +method: String, +ms: U32, r: String & Pure.Send & Pure.Route) ->
    IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  (+key, request, route) = r
  do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res>>:
    taken : Pool & Maybe<&1, Conn> <- pool.take.live(p, key)
    pool.idle(taken, key, ms, Pure.pool.idempotent(method), request, route)

def pool.origin.choice(p: Pool, +method: String, ms: U32,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, hf: String,
    scheme: String, host: String, port: U32, target: String,
    cert: Maybe<&2, Pure.Cert>, +ca: String, choice: Maybe<&2, Pure.Proxy>) ->
    IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  match choice:
    case None{}:
      IO.pure(Pool & Result<&1, &1, Pure.Err, Pure.Res>, (p, Fail{Pure.ErrUrl{}}))
    case Some{proxy}:
      pool.origin.route(p, method, ms, Pure.origin.route(method, headers, body, hf,
        scheme, host, port, target, cert, ca, proxy))

def pool.origin(p: Pool, method: String, ms: U32,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, hf: String,
    a: Url.Abs, known: Bool, cert: Maybe<&2, Pure.Cert>, +ca: String,
    choice: Maybe<&2, Pure.Proxy>) ->
    IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  Url.Abs{scheme, host, port, target} = a
  match known:
    case False{}:
      IO.pure(Pool & Result<&1, &1, Pure.Err, Pure.Res>, (p, Fail{Pure.ErrUrl{}}))
    case True{}:
      pool.origin.choice(p, method, ms, headers, body, hf, scheme, host,
        port, target, cert, ca, choice)

def pool.one.back(h: Pure.Hop, pr: Pool & Result<&1, &1, Pure.Err, Pure.Res>) -> Pool & Result<&1, &1, Pure.Err, Pure.Res> & Pure.Hop:
  (p, r) = pr
  (p, r, h)

# sent is headers plus any jar cookies; the hop keeps headers, so cookies never pile up across hops.
def pool.one.of(p: Pool, +method: String, +url: Url.Abs,
    headers: Map<&2, List<&2, String>>, sent: Map<&2, List<&2, String>>,
    +ms: U32, r: Bytes.Bytes & Bytes.Bytes, cert: Maybe<&2, Pure.Cert>, +ca: String) ->
    IO(Pool & Result<&1, &1, Pure.Err, Pure.Res> & Pure.Hop):
  Url.Abs{+scheme, +host, +port, target} = url
  (body, wire) = r
  do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res> & Pure.Hop>:
    choice : Maybe<&2, Pure.Proxy> <- proxy.select(scheme, host, port)
    pr : Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      pool.origin(p, method, ms, sent, wire, Url.host_field(url),
        url, Pure.pool.scheme.ok(url), cert, ca, choice)
    return pool.one.back(Pure.Hop{method, url, headers, body}, pr)

# One request, on an idle socket to its origin when the pool has one. The hop comes back for the redirect.
def pool.one(p: Pool, h: Pure.Hop, +ms: U32, cert: Maybe<&2, Pure.Cert>, +ca: String, jar: Maybe<&2, Pure.Jar>) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res> & Pure.Hop):
  Pure.Hop{+method, +url, +headers, body} = h
  pool.one.of(p, method, url, headers, Pure.jar.opt.apply(jar, url, headers), ms, Bytes.slice(body, 0, 4294967295), cert, ca)

type Hops is Type:
  Hops{p: Pool, next: Pure.Next, cert: Maybe<&2, Pure.Cert>, jar: Maybe<&2, Pure.Jar>, ca: String}

def pool.next.move(p: Pool, jar: Maybe<&2, Pure.Jar>, nt: Pure.Next & Maybe<&2, Pure.Cert> & String) -> Hops:
  (n, cert, ca) = nt
  Hops{p, n, cert, jar, ca}

def pool.next.of(+mode: Pure.Mode, left: Nat, cert: Maybe<&2, Pure.Cert>, +ca: String, p: Pool, +url: Url.Abs, h: Pure.Hop, r: Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Pure.Res>) -> Hops:
  (jar, m) = r
  pool.next.move(p, jar, Pure.next.trust(Pure.redirect.origin(url), cert, ca, Pure.fetch.policy(mode, left, h, m)))

# The jar takes the response's Set-Cookie fields first, redirect or not.
def pool.next(+mode: Pure.Mode, left: Nat, cert: Maybe<&2, Pure.Cert>, +ca: String, jar: Maybe<&2, Pure.Jar>, x: Pool & Result<&1, &1, Pure.Err, Pure.Res> & Pure.Hop) -> Hops:
  (p, m, h) = x
  Pure.Hop{method, +url, headers, body} = h
  pool.next.of(mode, left, cert, ca, p, url, Pure.Hop{method, url, headers, body}, Pure.jar.opt.store(jar, url, m))

def pool.hops.one(+mode: Pure.Mode, +ms: U32, +cert: Maybe<&2, Pure.Cert>, +ca: String, +jar: Maybe<&2, Pure.Jar>, p: Pool, h: Pure.Hop, left: Nat) -> IO(Hops):
  do IO<Hops>:
    x : Pool & Result<&1, &1, Pure.Err, Pure.Res> & Pure.Hop <- pool.one(p, h, ms, cert, ca, jar)
    return pool.next(mode, left, cert, ca, jar, x)

# NGo.left is how many redirects may follow this request. 20 is WHATWG's limit.
# The jar, when there is one, gives cookies to every hop and takes them from every response.
@unsafe
def pool.hops(+mode: Pure.Mode, +ms: U32, st: Hops) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res> & Maybe<&2, Pure.Jar>):
  Hops{p, n, cert, cj, ca} = st
  match n:
    case Pure.NDone{m}:
      IO.pure(Pool & Result<&1, &1, Pure.Err, Pure.Res> & Maybe<&2, Pure.Jar>, (p, m, cj))
    case Pure.NStop{}:
      IO.pure(Pool & Result<&1, &1, Pure.Err, Pure.Res> & Maybe<&2, Pure.Jar>, (p, Fail{Pure.ErrRedirect{}}, cj))
    case Pure.NGo{+left, h}:
      do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res> & Maybe<&2, Pure.Jar>>:
        next : Hops <- pool.hops.one(mode, ms, cert, ca, cj, p, h, left)
        pool.hops(mode, ms, next)

# Content-Encoding (RFC 9110 §8.4): each value, trimmed and lowercased, in the order applied.
def ce.eff(~eff: U32 -> Bytes.Bytes -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>), b: Bytes.Bytes) -> IO(Maybe<&1, Bytes.Bytes>):
  do IO<Maybe<&1, Bytes.Bytes>>:
    r : Result<&1, &1, U32 & String, Bytes.Bytes> <- eff(16777216, b)
    return Pure.ce.words(r)

def ce.io.deflate(on: Bool, b: Bytes.Bytes) -> IO(Maybe<&1, Bytes.Bytes>):
  match on:
    case True{}:
      IO.pure(Maybe<&1, Bytes.Bytes>, Pure.ce.dec(Pure.ce.deflate(b)))
    case False{}:
      IO.pure(Maybe<&1, Bytes.Bytes>, Some{b})

def ce.io.zstd(on: Bool, +c: String, b: Bytes.Bytes) -> IO(Maybe<&1, Bytes.Bytes>):
  match on:
    case True{}:
      ce.eff(~ZNative.zstd, b)
    case False{}:
      ce.io.deflate(String.eq(c, "deflate"), b)

def ce.io.br(on: Bool, +c: String, b: Bytes.Bytes) -> IO(Maybe<&1, Bytes.Bytes>):
  match on:
    case True{}:
      ce.eff(~ZNative.brotli, b)
    case False{}:
      ce.io.zstd(String.eq(c, "zstd"), c, b)

# One known coding undone: gzip, x-gzip, br, zstd, deflate, or identity.
def ce.io.gz(on: Bool, +c: String, b: Bytes.Bytes) -> IO(Maybe<&1, Bytes.Bytes>):
  match on:
    case True{}:
      ce.eff(~ZNative.libz.inflate, b)
    case False{}:
      ce.io.br(String.eq(c, "br"), c, b)

def ce.io.go(cs: List<&2, String>, m: Maybe<&1, Bytes.Bytes>) -> IO(Maybe<&1, Bytes.Bytes>):
  match cs:
    case Nil{}:
      match m:
        case None{}:
          IO.pure(Maybe<&1, Bytes.Bytes>, None{})
        case Some{b}:
          IO.pure(Maybe<&1, Bytes.Bytes>, Some{b})
    case Con{+c, t}:
      match m:
        case None{}:
          IO.pure(Maybe<&1, Bytes.Bytes>, None{})
        case Some{b}:
          do IO<Maybe<&1, Bytes.Bytes>>:
            n : Maybe<&1, Bytes.Bytes> <- ce.io.gz(Bool.or(String.eq(c, "gzip"), String.eq(c, "x-gzip")), c, b)
            ce.io.go(t, n)

def decoded.io.run(known: Bool, +status: U32, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, cs: List<&2, String>) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  match known:
    case True{}:
      do IO<Result<&1, &1, Pure.Err, Pure.Res>>:
        m : Maybe<&1, Bytes.Bytes> <- ce.io.go(cs, Some{body})
        return Pure.decoded.io.pick(m, status, headers)
    case False{}:
      IO.pure(Result<&1, &1, Pure.Err, Pure.Res>, Done{Pure.Res{status, headers, body}})

def decoded.io.go(empty: Bool, +enc: String, +status: U32, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  match empty:
    case True{}:
      IO.pure(Result<&1, &1, Pure.Err, Pure.Res>, Done{Pure.Res{status, headers, body}})
    case False{}:
      +cs = List.reverse(&2, String, Pure.ce.split(Pure.fields(headers, "content-encoding")))
      decoded.io.run(Pure.ce.known(cs, Con{"identity", Con{"x-gzip", Pure.ce.split(Con{enc, Nil{}})}}), status, headers, body, cs)

# decoded through the C libraries, for the codings in enc. A body with any other coding stays as sent.
def decoded.io(+enc: String, res: Pure.Res) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  Pure.Res{+status, +headers, body} = res
  Bytes.Bytes{+len, buf} = body
  decoded.io.go(U32.is_zero(len), enc, status, headers, Bytes.Bytes{len, buf})

# An effect on empty input fails with ENOENT only when its library does not load.
def codings.has(~eff: U32 -> Bytes.Bytes -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>), b: Bytes.Bytes) -> IO(Bool):
  do IO<Bool>:
    r : Result<&1, &1, U32 & String, Bytes.Bytes> <- eff(0, b)
    return Pure.codings.ok(r)

def codings() -> IO(String):
  do IO<String>:
    b : Bool <- codings.has(~ZNative.brotli, Bytes.new(0))
    z : Bool <- codings.has(~ZNative.zstd, Bytes.new(0))
    return Pure.codings.add(z, Pure.codings.add(b, "gzip, deflate", "br"), "zstd")

# The final response of a fetch, after redirects.
def fetch.final(+enc: String, r: Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  match r:
    case Done{res}:
      decoded.io(enc, res)
    case Fail{e}:
      IO.pure(Result<&1, &1, Pure.Err, Pure.Res>, Fail{e})

def pool.final(+enc: String, pr: Pool & Result<&1, &1, Pure.Err, Pure.Res> & Maybe<&2, Pure.Jar>) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  (p, r, jar) = pr
  do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res>>:
    d : Result<&1, &1, Pure.Err, Pure.Res> <- fetch.final(enc, r)
    return (p, d)

def pool.how.enc(+enc: String, p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ms: U32, mode: Pure.Mode, cert: Maybe<&2, Pure.Cert>, +ca: String) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res>>:
    pr : Pool & Result<&1, &1, Pure.Err, Pure.Res> & Maybe<&2, Pure.Jar> <- pool.hops(mode, ms, Hops{p, Pure.fetch.start(method, headers, body, Url.absolute(url), enc), cert, None{}, ca})
    pool.final(enc, pr)

def pool.how.cert(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ms: U32, mode: Pure.Mode, cert: Maybe<&2, Pure.Cert>) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res>>:
    enc : String <- codings()
    pool.how.enc(enc, p, method, url, headers, body, ms, mode, cert, "")

# pool.how(p, "GET", "https://example.com/x?y=1", headers, body, ms, mode) follows redirects
# on p's idle sockets. Fail is a bad URL, a failed lookup, connect, handshake, send, read,
# a malformed response, more than 20 redirects, or a step past ms. Bodies are bytes.
def pool.how(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ms: U32, mode: Pure.Mode) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  pool.how.cert(p, method, url, headers, body, ms, mode, None{})

def pool.fetch.with(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ms: U32) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  pool.how(p, method, url, headers, body, ms, Pure.ModeFollow{})

def pool.fetch(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  pool.fetch.with(p, method, url, headers, body, 30000)

def pool.fetch.cert.with(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, chain: String, key: String, ms: U32) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  pool.how.cert(p, method, url, headers, body, ms, Pure.ModeFollow{}, Some{Pure.Cert{chain, key}})

def pool.fetch.cert(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, chain: String, key: String) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  pool.fetch.cert.with(p, method, url, headers, body, chain, key, 30000)

def pool.fetch.ca.with(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ca: String, ms: U32) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  do IO<Pool & Result<&1, &1, Pure.Err, Pure.Res>>:
    enc : String <- codings()
    pool.how.enc(enc, p, method, url, headers, body, ms, Pure.ModeFollow{}, None{}, ca)

def pool.fetch.ca(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ca: String) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  pool.fetch.ca.with(p, method, url, headers, body, ca, 30000)

# One request for fetch.all: the arguments of fetch, as a record.
def fetch.all.job(p: Pool, f: Pure.Fetch) -> IO(Pool & Result<&1, &1, Pure.Err, Pure.Res>):
  Pure.Fetch{method, url, headers, body} = f
  pool.fetch(p, method, url, headers, body)

def fetch.all.pools(n: Nat) -> List<Pool>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      pool.new() <> fetch.all.pools(p)

def fetch.all.close(ps: List<Pool>) -> IO(Unit):
  match ps:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case p <> rest:
      do IO<Unit>:
        pool.close(p)
        fetch.all.close(rest)

def fetch.all.done(r: List<Pool> & List<Result<&1, &1, Pure.Err, Pure.Res>>) -> IO(List<Result<&1, &1, Pure.Err, Pure.Res>>):
  (ps, rs) = r
  do IO<List<Result<&1, &1, Pure.Err, Pure.Res>>>:
    fetch.all.close(ps)
    return rs

# No requests start no workers, since Conc.pool needs at least one.
def fetch.all.go(xs: List<Pure.Fetch>, +workers: Nat) -> IO(List<Result<&1, &1, Pure.Err, Pure.Res>>):
  match xs:
    case Nil{}:
      IO.pure(List<Result<&1, &1, Pure.Err, Pure.Res>>, Nil{})
    case x <> rest:
      do IO<List<Result<&1, &1, Pure.Err, Pure.Res>>>:
        r : List<Pool> & List<Result<&1, &1, Pure.Err, Pure.Res>> <-
          Conc.pool(~Pool, ~Pure.Fetch, ~Result<&1, &1, Pure.Err, Pure.Res>, ~fetch.all.job, fetch.all.pools(workers), x <> rest)
        fetch.all.done(r)

def fetch.all.of(+n: U32, nx: Nat & List<Pure.Fetch>) -> IO(List<Result<&1, &1, Pure.Err, Pure.Res>>):
  (+len, xs) = nx
  fetch.all.go(xs, Nat.min(len, Nat.max(1n, U32.to_nat(n))))

# Each request as fetch would make it, on at most n workers (0 counts as 1, and
# never more workers than requests). Each worker owns its own Pool, so an idle
# socket is reused only by the worker that opened it; every pool is closed at the
# end. Results come back in the order of reqs.
def fetch.all(reqs: List<Pure.Fetch>, +n: U32) -> IO(List<Result<&1, &1, Pure.Err, Pure.Res>>):
  fetch.all.of(n, Conc.count(Pure.Fetch, reqs))

# The hops always hand the jar back; j is only the type's fallback.
def pool.jar.final(+enc: String, j: Pure.Jar, pr: Pool & Result<&1, &1, Pure.Err, Pure.Res> & Maybe<&2, Pure.Jar>) -> IO(Pool & Pure.Jar & Result<&1, &1, Pure.Err, Pure.Res>):
  (p, r, jar) = pr
  do IO<Pool & Pure.Jar & Result<&1, &1, Pure.Err, Pure.Res>>:
    d : Result<&1, &1, Pure.Err, Pure.Res> <- fetch.final(enc, r)
    return (p, Maybe.default(&2, Pure.Jar, jar, j), d)

def pool.jar.enc(+enc: String, p: Pool, +j: Pure.Jar, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Pool & Pure.Jar & Result<&1, &1, Pure.Err, Pure.Res>):
  do IO<Pool & Pure.Jar & Result<&1, &1, Pure.Err, Pure.Res>>:
    pr : Pool & Result<&1, &1, Pure.Err, Pure.Res> & Maybe<&2, Pure.Jar> <- pool.hops(Pure.ModeFollow{}, 30000, Hops{p, Pure.fetch.start(method, headers, body, Url.absolute(url), enc), None{}, Some{j}, ""})
    pool.jar.final(enc, j, pr)

# pool.fetch with a cookie jar (RFC 6265bis). Before every hop, redirects included, the jar's
# cookies for that URL join the request's cookie field; after every response, redirects included,
# its Set-Cookie fields go into the jar. The jar's clock is the caller's: advance it with jar.at.
def pool.fetch.jar(p: Pool, j: Pure.Jar, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Pool & Pure.Jar & Result<&1, &1, Pure.Err, Pure.Res>):
  do IO<Pool & Pure.Jar & Result<&1, &1, Pure.Err, Pure.Res>>:
    enc : String <- codings()
    pool.jar.enc(enc, p, j, method, url, headers, body)
def fetch.end(pr: Pool & Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  (p, r) = pr
  do IO<Result<&1, &1, Pure.Err, Pure.Res>>:
    pool.close(p)
    return r

# fetch is pool.how on a fresh pool that closes afterwards.
def fetch.how(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ms: U32, mode: Pure.Mode) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  do IO<Result<&1, &1, Pure.Err, Pure.Res>>:
    pr : Pool & Result<&1, &1, Pure.Err, Pure.Res> <- pool.how(pool.new(), method, url, headers, body, ms, mode)
    fetch.end(pr)

def fetch.with(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ms: U32) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  fetch.how(method, url, headers, body, ms, Pure.ModeFollow{})

def fetch.cert.with(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, chain: String, key: String, ms: U32) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  do IO<Result<&1, &1, Pure.Err, Pure.Res>>:
    pr : Pool & Result<&1, &1, Pure.Err, Pure.Res> <- pool.fetch.cert.with(pool.new(), method, url, headers, body, chain, key, ms)
    fetch.end(pr)

def fetch.cert(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, chain: String, key: String) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  fetch.cert.with(method, url, headers, body, chain, key, 30000)

def fetch.ca.with(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ca: String, ms: U32) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  do IO<Result<&1, &1, Pure.Err, Pure.Res>>:
    pr : Pool & Result<&1, &1, Pure.Err, Pure.Res> <- pool.fetch.ca.with(pool.new(), method, url, headers, body, ca, ms)
    fetch.end(pr)

def fetch.ca(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ca: String) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  fetch.ca.with(method, url, headers, body, ca, 30000)

# fetch.with and a 30 s step timeout.
def fetch(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  fetch.with(method, url, headers, body, 30000)

def get(url: String) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  fetch("GET", url, Pure.empty(), Bytes.new(0))

# POST v as compact JSON, with content-type: application/json.
def post.json(url: String, v: Json.Val) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  fetch("POST", url, Pure.set(Pure.empty(), "content-type", "application/json"), Json.encode.bytes(v))

# Base URLs: resolve(base, ref) is ref against the absolute http(s) URL base (RFC 3986 §5.2),
# written back as a URL for fetch. None when base is not absolute or ref has another scheme.
def retry.sleep(+v: String, n: Nat) -> IO(Unit):
  do IO<Unit>:
    now : Time.Instant <- clock.now()
    rnd : Result<&1, &1, U32 & String, U32> <- IO.random_u32()
    IO.sleep(Pure.retry.delay(v, now, n, Pure.retry.jitter(rnd)))

def retry.one(+idem: Bool, +method: String, +url: String, +headers: Map<&2, List<&2, String>>,
    r: Bytes.Bytes & Bytes.Bytes) -> IO(Bytes.Bytes & Result<&1, &1, Pure.Err, Pure.Res> & Maybe<&2, String>):
  (body, spare) = r
  do IO<Bytes.Bytes & Result<&1, &1, Pure.Err, Pure.Res> & Maybe<&2, String>>:
    got : Result<&1, &1, Pure.Err, Pure.Res> <- fetch(method, url, headers, spare)
    return Pure.retry.kept(body, Pure.retry.judge(idem, got))

# left: retries still allowed. n: the retry to wait for next, 0 first.
def retry.go(left: Nat, +n: Nat, +idem: Bool, +method: String, +url: String,
    +headers: Map<&2, List<&2, String>>,
    t: Bytes.Bytes & Result<&1, &1, Pure.Err, Pure.Res> & Maybe<&2, String>) -> IO(Result<&1, &1, Pure.Err, Pure.Res>):
  match left:
    case 0n:
      (body, r, m) = t
      IO.pure(Result<&1, &1, Pure.Err, Pure.Res>, r)
    case 1n+p:
      (body, r, m) = t
      match m:
        case None{}:
          IO.pure(Result<&1, &1, Pure.Err, Pure.Res>, r)
        case Some{v}:
          do IO<Result<&1, &1, Pure.Err, Pure.Res>>:
            retry.sleep(v, n)
            tried : Bytes.Bytes & Result<&1, &1, Pure.Err, Pure.Res> & Maybe<&2, String> <-
              retry.one(idem, method, url, headers, Bytes.slice(body, 0, 4294967295))
            retry.go(p, 1n+n, idem, method, url, headers, tried)

# fetch.retry(n, method, url, headers, body) is fetch, tried again up to n times while an
# idempotent method (GET, HEAD, OPTIONS, TRACE, PUT, DELETE) gets a connect error, a timeout,
# or 408, 429, 500, 502, 503, or 504. POST, PATCH and other methods get one try. It waits
# Retry-After (seconds or HTTP-date, at most 30 s) when given, else the backoff. When retries
# run out, the last response or error comes back as it was.
def retry.start(enabled: Bool, n: U32, +method: String, +url: String,
    +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Result<&1, &1, Pure.Err, Pure.Res>):
  match enabled:
    case False{}:
      fetch(method, url, headers, body)
    case True{}:
      do IO<Result<&1, &1, Pure.Err, Pure.Res>>:
        first : Bytes.Bytes & Result<&1, &1, Pure.Err, Pure.Res> & Maybe<&2, String> <-
          retry.one(True{}, method, url, headers, Bytes.slice(body, 0, 4294967295))
        retry.go(U32.to_nat(n), 0n, True{}, method, url, headers, first)

def fetch.retry(+n: U32, +method: String, +url: String,
    +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Result<&1, &1, Pure.Err, Pure.Res>):
  retry.start(Bool.and(U32.is_ne(n, 0), Pure.pool.idempotent(method)),
    n, method, url, headers, body)

# Streaming (a body read or sent in pieces). A decoded stream owns its decoders.
# What the next read returns: read more, a raw piece, a decoded piece, the end, or an error.
type StreamWire is Type:
  StreamH1{s: Socket}
  StreamH2{reader: H2Reader, capacity: U32}
  StreamDead{}

# back: the pool key, while the connection can take another request after this body.
type Stream is Type:
  Stream{tls: Bool, s: StreamWire, ms: U32, res: Pure.Res, rb: Pure.Rb, out: Pure.Po, decs: List<&1, ZNative.Decoder>, back: Maybe<&2, String>}

def stream.mk(+tls: Bool, s: StreamWire, +ms: U32, res: Pure.Res, decs: List<&1, ZNative.Decoder>, back: Maybe<&2, String>, x: Pure.Pc & Bool) -> Stream:
  (pc, extra) = x
  Pure.Pc{rb, out} = pc
  Stream{tls, s, ms, res, rb, out, decs, Bool.pick(Maybe<&2, String>, extra, None{}, back)}

def stream.got.piece(+tls: Bool, s: StreamWire, +ms: U32, res: Pure.Res, decs: List<&1, ZNative.Decoder>, back: Maybe<&2, String>, +rb: Pure.Rb, p: U32 & Array<U32>) -> Stream:
  (+len, buf) = p
  stream.mk(tls, s, ms, res, decs, back, Bool.pick(Pure.Pc & Bool, U32.is_zero(len), (Pure.pc.eof(rb), False{}), Pure.stream.pc(rb, Bytes.Bytes{len, buf})))

def stream.got(+tls: Bool, +ms: U32, res: Pure.Res, decs: List<&1, ZNative.Decoder>, back: Maybe<&2, String>, +rb: Pure.Rb, m: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Stream:
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      Stream{tls, StreamH1{s}, ms, res, Pure.RbDone{}, Pure.PoBad{Pure.err.or_late(code, Pure.ErrRead{code, why})}, decs, back}
    case Done{p}:
      stream.got.piece(tls, StreamH1{s}, ms, res, decs, back, rb, p)

type Fed is Type:
  Fed{decs: List<&1, ZNative.Decoder>, body: Result<&1, &1, Pure.Err, Bytes.Bytes>}

def stream.feed.received(done: List<&1, ZNative.Decoder>, m: ZNative.Decoder & Result<&1, &1, U32 & String, Bytes.Bytes>) -> Fed:
  (d, r) = m
  match r:
    case Fail{e}:
      Fed{d <> done, Fail{Pure.ErrBad{}}}
    case Done{b}:
      Fed{d <> done, Done{b}}

def stream.feed.step(st: Fed, d: ZNative.Decoder) -> IO(Fed):
  Fed{done, body} = st
  match body:
    case Fail{e}:
      IO.pure(Fed, Fed{d <> done, Fail{e}})
    case Done{b}:
      do IO<Fed>:
        m : ZNative.Decoder & Result<&1, &1, U32 & String, Bytes.Bytes> <- ZNative.dec.push(d, 16777216, b)
        return stream.feed.received(done, m)

def stream.feed.one(prev: IO(Fed), d: ZNative.Decoder) -> IO(Fed):
  do IO<Fed>:
    st : Fed <- prev
    stream.feed.step(st, d)

def stream.feed.reverse(st: Fed) -> Fed:
  Fed{done, body} = st
  Fed{List.reverse(&1, ZNative.Decoder, done), body}

def stream.feed.all(decs: List<&1, ZNative.Decoder>, b: Bytes.Bytes) -> IO(Fed):
  do IO<Fed>:
    st : Fed <- List.foldl(~&1, ~ZNative.Decoder, ~IO(Fed), ~stream.feed.one, decs,
      IO.pure(Fed, Fed{Nil{}, Done{b}}))
    return stream.feed.reverse(st)

def stream.feed.got(+tls: Bool, s: StreamWire, +ms: U32, res: Pure.Res, +rb: Pure.Rb, back: Maybe<&2, String>, st: Fed) -> Stream:
  Fed{decs, body} = st
  match body:
    case Fail{e}:
      Stream{tls, s, ms, res, rb, Pure.PoBad{e}, decs, back}
    case Done{b}:
      Bytes.Bytes{+len, buf} = b
      Stream{tls, s, ms, res, rb, Pure.stream.ready(U32.is_zero(len), rb, Bytes.Bytes{len, buf}), decs, back}

def stream.feed.st(st: Stream, b: Bytes.Bytes) -> IO(Stream):
  Stream{+tls, s, +ms, res, +rb, out, decs, back} = st
  match decs:
    case Nil{}:
      IO.pure(Stream, Stream{tls, s, ms, res, rb, Pure.PoReady{b}, Nil{}, back})
    case Con{d, rest}:
      do IO<Stream>:
        fed : Fed <- stream.feed.all(Con{d, rest}, b)
        return stream.feed.got(tls, s, ms, res, rb, back, fed)

def stream.finish(decs: List<&1, ZNative.Decoder>) -> IO(Bool):
  match decs:
    case Nil{}:
      IO.pure(Bool, True{})
    case Con{d, rest}:
      do IO<Bool>:
        r : Result<&1, &1, U32 & String, Unit> <- ZNative.dec.finish(d)
        tail : Bool <- stream.finish(rest)
        return Bool.and(Pure.stream.finish.ok(r), tail)

def stream.h2.event(+ms: U32, res: Pure.Res, decs: List<&1, ZNative.Decoder>,
    back: Maybe<&2, String>, got: Result<&1, &1, Pure.Err, H2Reader & H2.ClientEvent>) -> Stream:
  match got:
    case Fail{e}:
      Stream{True{}, StreamDead{}, ms, res, Pure.RbDone{}, Pure.PoBad{e}, decs, None{}}
    case Done{(reader, event)}:
      match event:
        case H2.Chunk{id, HBytes.Bytes{+len, buf}, capacity}:
          Stream{True{}, StreamH2{reader, capacity}, ms, res, Pure.RbClose{},
            Pure.pc.po(True{}, U32.is_zero(len), Bytes.Bytes{len, buf}), decs, back}
        case H2.Complete{id}:
          Stream{True{}, StreamH2{reader, 0}, ms, res, Pure.RbDone{}, Pure.PoEnd{}, decs, back}
        case H2.Reset{id, code}:
          Stream{True{}, StreamH2{reader, 0}, ms, res, Pure.RbDone{}, Pure.PoBad{Pure.ErrBad{}}, decs, back}
        case H2.Shutdown{last, code}:
          Stream{True{}, StreamH2{reader, 0}, ms, res, Pure.RbClose{}, Pure.PoNone{}, decs, back}
        case other:
          Stream{True{}, StreamH2{reader, 0}, ms, res, Pure.RbClose{}, Pure.PoNone{}, decs, back}

def stream.recv(+tls: Bool, wire: StreamWire, +ms: U32, res: Pure.Res, +rb: Pure.Rb,
    decs: List<&1, ZNative.Decoder>, back: Maybe<&2, String>) -> IO(Stream):
  match wire:
    case StreamH1{s}:
      do IO<Stream>:
        got : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <-
          io.recv.words(tls, s, 65536, ms)
        return stream.got(tls, ms, res, decs, back, rb, got)
    case StreamH2{reader, capacity}:
      do IO<Stream>:
        released : Result<&1, &1, Pure.Err, H2Reader> <- h2.reader.release(reader, capacity)
        got : Result<&1, &1, Pure.Err, H2Reader & H2.ClientEvent> <-
          h2.reader.next(65536n, released, ms)
        return stream.h2.event(ms, res, decs, back, got)
    case StreamDead{}:
      IO.pure(Stream, Stream{tls, StreamDead{}, ms, res, Pure.RbDone{}, Pure.PoBad{Pure.ErrBad{}}, decs, None{}})

def stream.wire.close(+tls: Bool, wire: StreamWire) -> IO(Unit):
  match wire:
    case StreamH1{s}:
      io.close(tls, s)
    case StreamH2{H2Reader{s, client, id, events}, capacity}:
      Wire.tls.close(s)
    case StreamDead{}:
      IO.pure(Unit, Unit{})

def stream.h2.pool.keep(state: Bool & Conn, p: Pool, +key: String) -> IO(Pool):
  (live, c) = state
  match live:
    case True{}:
      pool.give(p, key, c)
    case False{}:
      do IO<Pool>:
        conn.close(c)
        return p

def stream.h2.give.result(p: Pool, +key: String, r: Result<&1, &1, Pure.Err, H2Reader>) -> IO(Pool):
  match r:
    case Fail{e}:
      IO.pure(Pool, p)
    case Done{H2Reader{s, client, id, events}}:
      stream.h2.pool.keep(pool.h2.reusable(ConnH2{s, client}), p, key)

def stream.h2.release(active: Bool, p: Pool, +key: String, s: Socket,
    client: H2.Client, +id: U32) -> IO(Pool):
  match active:
    case False{}:
      do IO<Pool>:
        next : Result<&1, &1, Pure.Err, H2Reader> <-
          h2.reader.reply(s, id, H2.client.credit.release_all(client, id))
        stream.h2.give.result(p, key, next)
    case True{}:
      do IO<Pool>:
        next : Result<&1, &1, Pure.Err, H2Reader> <- h2.reader.reply(s, id, H2.client.cancel(client, id))
        stream.h2.give.result(p, key, next)

def stream.wire.give(whole: Bool, p: Pool, +key: String, +tls: Bool, wire: StreamWire) -> IO(Pool):
  match whole wire:
    case True{} StreamH1{s}:
      pool.give(p, key, Conn{tls, s})
    case False{} StreamH1{s}:
      do IO<Pool>:
        io.close(tls, s)
        return p
    case _ StreamH2{H2Reader{s, H2.Client{input, streams, encoder, decoder, +control}, id, events}, capacity}:
      H2.Control{next, +active, frame_max, initial, max_streams, send_window,
        recv_window, first, ack, continuation, goaway} = control
      stream.h2.release(U32.is_ne(active, 0), p, key, s,
        H2.Client{input, streams, encoder, decoder, control}, id)
    case _ StreamDead{}:
      IO.pure(Pool, p)

def stream.ended(good: Bool, +tls: Bool, s: StreamWire, +ms: U32, res: Pure.Res, +rb: Pure.Rb, back: Maybe<&2, String>) ->
  Stream & Result<&1, &1, Pure.Err, Maybe<&1, Bytes.Bytes>>:
  match good:
    case True{}:
      (Stream{tls, s, ms, res, rb, Pure.PoEnd{}, Nil{}, back}, Done{None{}})
    case False{}:
      (Stream{tls, s, ms, res, rb, Pure.PoBad{Pure.ErrBad{}}, Nil{}, back}, Fail{Pure.ErrBad{}})

# The next piece of the body; None at the end. A piece is never empty.
@unsafe
def stream.read(st: Stream) -> IO(Stream & Result<&1, &1, Pure.Err, Maybe<&1, Bytes.Bytes>>):
  Stream{+tls, s, +ms, res, +rb, out, decs, back} = st
  match out:
    case Pure.PoPiece{b}:
      do IO<Stream & Result<&1, &1, Pure.Err, Maybe<&1, Bytes.Bytes>>>:
        next : Stream <- stream.feed.st(Stream{tls, s, ms, res, rb, Pure.PoNone{}, decs, back}, b)
        stream.read(next)
    case Pure.PoReady{b}:
      IO.pure(Stream & Result<&1, &1, Pure.Err, Maybe<&1, Bytes.Bytes>>,
        (Stream{tls, s, ms, res, rb, Pure.stream.after(rb), decs, back}, Done{Some{b}}))
    case Pure.PoEnd{}:
      do IO<Stream & Result<&1, &1, Pure.Err, Maybe<&1, Bytes.Bytes>>>:
        good : Bool <- stream.finish(decs)
        return stream.ended(good, tls, s, ms, res, rb, back)
    case Pure.PoBad{+e}:
      IO.pure(Stream & Result<&1, &1, Pure.Err, Maybe<&1, Bytes.Bytes>>,
        (Stream{tls, s, ms, res, rb, Pure.PoBad{e}, decs, back}, Fail{e}))
    case Pure.PoNone{}:
      do IO<Stream & Result<&1, &1, Pure.Err, Maybe<&1, Bytes.Bytes>>>:
        next : Stream <- stream.recv(tls, s, ms, res, rb, decs, back)
        stream.read(next)

# Status and headers. Its body is empty: read the body with stream.read.
def stream.res(st: Stream) -> Stream & Pure.Res:
  Stream{tls, s, ms, res, rb, out, decs, back} = st
  Pure.Res{+status, +headers, body} = res
  (Stream{tls, s, ms, Pure.Res{status, headers, body}, rb, out, decs, back}, Pure.Res{status, headers, Bytes.new(0)})

def stream.close(st: Stream) -> IO(Unit):
  Stream{tls, s, ms, res, rb, out, decs, back} = st
  do IO<Unit>:
    good : Bool <- stream.finish(decs)
    stream.wire.close(tls, s)

def stream.give(whole: Bool, back: Maybe<&2, String>, p: Pool, +tls: Bool, s: StreamWire) -> IO(Pool):
  match back:
    case Some{key}:
      stream.wire.give(whole, p, key, tls, s)
    case None{}:
      do IO<Pool>:
        stream.wire.close(tls, s)
        return p

# stream.close, but a body read to its end and decoded cleanly gives its connection to the pool.
def pool.stream.close(p: Pool, st: Stream) -> IO(Pool):
  Stream{+tls, s, ms, res, +rb, out, decs, back} = st
  do IO<Pool>:
    good : Bool <- stream.finish(decs)
    stream.give(Bool.and(good, Bool.and(Pure.stream.po.end(out), Pure.stream.rb.done(rb))), back, p, tls, s)

# Head read state: still scanning, cut short or bad, or the head with the bytes after it.
# none: no response byte arrived, so a reused socket may be stale.
def fetch.fail.of(r: Result<&1, &1, Pure.Err, Pure.Res>) -> Result<&1, &1, Pure.Err, Stream>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{res}:
      Fail{Pure.ErrBad{}}

# The connection can take another request only when the server did not say close and the body does not end at close.
@unsafe
def stream.head(+tls: Bool, +ms: U32, +head: Bool, back: Maybe<&2, String>, st: Socket & Pure.Sh) -> IO(Bool & Result<&1, &1, Pure.Err, Stream>):
  (s, sh) = st
  match sh:
    case Pure.ShMore{buf, +k}:
      do IO<Bool & Result<&1, &1, Pure.Err, Stream>>:
        m : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- io.recv.words(tls, s, 65536, ms)
        stream.head(tls, ms, head, back, Pure.sh.next(head, buf, k, m))
    case Pure.ShBad{err, +none}:
      do IO<Bool & Result<&1, &1, Pure.Err, Stream>>:
        r : Result<&1, &1, Pure.Err, Pure.Res> <- fetch.bad(tls, s, err)
        return (none, fetch.fail.of(r))
    case Pure.ShRes{res, +rb, rest}:
      Pure.Res{+status, +headers, body} = res
      IO.pure(Bool & Result<&1, &1, Pure.Err, Stream>, (False{}, Done{stream.mk(tls, StreamH1{s}, ms, Pure.Res{status, headers, body}, Nil{},
        Pure.stream.back(back, rb, headers), Pure.stream.pc(rb, rest))}))

def stream.sent(+tls: Bool, +ms: U32, +head: Bool, back: Maybe<&2, String>, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Bool & Result<&1, &1, Pure.Err, Stream>):
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      do IO<Bool & Result<&1, &1, Pure.Err, Stream>>:
        io.close(tls, s)
        return (True{}, Fail{Pure.err.or_late(code, Pure.ErrWrite{code, why})})
    case Done{u}:
      stream.head(tls, ms, head, back, (s, Pure.ShMore{Bytes.new(0), 0}))

def stream.h2.head.done(res: Maybe<&1, Pure.Res>, +ms: U32, back: Maybe<&2, String>,
    reader: H2Reader) -> IO(Bool & Result<&1, &1, Pure.Err, Stream>):
  match res:
    case None{}:
      H2Reader{s, client, id, events} = reader
      do IO<Bool & Result<&1, &1, Pure.Err, Stream>>:
        Wire.tls.close(s)
        return (False{}, Fail{Pure.ErrBad{}})
    case Some{res}:
      IO.pure(Bool & Result<&1, &1, Pure.Err, Stream>,
        (False{}, Done{Stream{True{}, StreamH2{reader, 0}, ms, res, Pure.RbClose{}, Pure.PoNone{}, Nil{}, back}}))

def stream.h2.head(n: Nat, +ms: U32, +back: Maybe<&2, String>, step: H2Step) ->
    IO(Bool & Result<&1, &1, Pure.Err, Stream>):
  match n step:
    case _ H2Event{Fail{e}}:
      IO.pure(Bool & Result<&1, &1, Pure.Err, Stream>, (False{}, Fail{e}))
    case 0n H2Pending{reader}:
      stream.h2.head.done(None{}, ms, back, reader)
    case 0n H2Event{Done{(reader, event)}}:
      stream.h2.head.done(None{}, ms, back, reader)
    case 1n+p H2Pending{reader}:
      do IO<Bool & Result<&1, &1, Pure.Err, Stream>>:
        got : Result<&1, &1, Pure.Err, H2Reader & H2.ClientEvent> <-
          h2.reader.next(65536n, Done{reader}, ms)
        stream.h2.head(p, ms, back, H2Event{got})
    case 1n+p H2Event{Done{(reader, event)}}:
      match event:
        case H2.Headers{id, fields}:
          stream.h2.head.done(h2.buffered.head(fields), ms, back, reader)
        case H2.Informational{id, fields}:
          stream.h2.head(p, ms, back, H2Pending{reader})
        case H2.Pong{data}:
          stream.h2.head(p, ms, back, H2Pending{reader})
        case H2.Shutdown{last, code}:
          stream.h2.head(p, ms, back, H2Pending{reader})
        case other:
          stream.h2.head.done(None{}, ms, back, reader)

def stream.h2.start(+ms: U32, back: Maybe<&2, String>,
    r: Result<&1, &1, Pure.Err, H2Reader>) -> IO(Bool & Result<&1, &1, Pure.Err, Stream>):
  match r:
    case Fail{e}:
      IO.pure(Bool & Result<&1, &1, Pure.Err, Stream>, (False{}, Fail{e}))
    case Done{reader}:
      stream.h2.head(131072n, ms, back, H2Pending{reader})

# The bool is true when the open failed before any response byte.
def stream.conn(r: Result<&1, &1, Pure.Err, Conn>, +ms: U32, +head: Bool, back: Maybe<&2, String>, request: Pure.Send) -> IO(Bool & Result<&1, &1, Pure.Err, Stream>):
  match r:
    case Fail{e}:
      IO.pure(Bool & Result<&1, &1, Pure.Err, Stream>, (False{}, Fail{e}))
    case Done{c}:
      match c:
        case Conn{+tls, s}:
          Pure.Send{method, target, authority, headers, body} = request
          do IO<Bool & Result<&1, &1, Pure.Err, Stream>>:
            sent : Socket & Result<&1, &1, U32 & String, Unit> <-
              io.send.bytes(tls, s, Pure.encode_req.on(method, target, authority, headers, body, False{}))
            stream.sent(tls, ms, head, back, sent)
        case ConnH2{s, client}:
          do IO<Bool & Result<&1, &1, Pure.Err, Stream>>:
            started : Result<&1, &1, Pure.Err, H2Reader> <- h2.reader.start(s, client, request)
            stream.h2.start(ms, back, started)

def stream.opened(x: Bool & Result<&1, &1, Pure.Err, Stream>) -> Result<&1, &1, Pure.Err, Stream>:
  (none, r) = x
  r

# A fresh TLS stream offers HTTP/2, with HTTP/1.1 as the fallback.
def stream.fresh(+ms: U32, +head: Bool, back: Maybe<&2, String>, route: Pure.Route, request: Pure.Send) -> IO(Result<&1, &1, Pure.Err, Stream>):
  do IO<Result<&1, &1, Pure.Err, Stream>>:
    c : Result<&1, &1, Pure.Err, Conn> <- route.open(ms, True{}, route)
    x : Bool & Result<&1, &1, Pure.Err, Stream> <- stream.conn(c, ms, head, back, request)
    return stream.opened(x)

def stream.stale(again: Bool, p: Pool, +ms: U32, +head: Bool, +key: String, route: Pure.Route, spare: Pure.Send, e: Pure.Err) ->
    IO(Pool & Result<&1, &1, Pure.Err, Stream>):
  match again:
    case True{}:
      do IO<Pool & Result<&1, &1, Pure.Err, Stream>>:
        got : Result<&1, &1, Pure.Err, Stream> <- stream.fresh(ms, head, Some{key}, route, spare)
        return (p, got)
    case False{}:
      IO.pure(Pool & Result<&1, &1, Pure.Err, Stream>, (p, Fail{e}))

def stream.reused(p: Pool, +ms: U32, +head: Bool, +idem: Bool, +key: String, route: Pure.Route, spare: Pure.Send,
    x: Bool & Result<&1, &1, Pure.Err, Stream>) -> IO(Pool & Result<&1, &1, Pure.Err, Stream>):
  (+none, r) = x
  match r:
    case Done{st}:
      IO.pure(Pool & Result<&1, &1, Pure.Err, Stream>, (p, Done{st}))
    case Fail{e}:
      stream.stale(Pure.pool.retry(none, idem), p, ms, head, key, route, spare, e)

def stream.idle.h1(p: Pool, +ms: U32, +head: Bool, +idem: Bool, +key: String, route: Pure.Route,
    +method: String, +target: String, +authority: String, +headers: Map<&2, List<&2, String>>,
    bodies: Bytes.Bytes & Bytes.Bytes, c: Conn) -> IO(Pool & Result<&1, &1, Pure.Err, Stream>):
  (body, spare) = bodies
  do IO<Pool & Result<&1, &1, Pure.Err, Stream>>:
    x : Bool & Result<&1, &1, Pure.Err, Stream> <-
      stream.conn(Done{c}, ms, head, Some{key}, Pure.Send{method, target, authority, headers, body})
    stream.reused(p, ms, head, idem, key, route, Pure.Send{method, target, authority, headers, spare}, x)

def stream.idle(p: Pool, +ms: U32, +head: Bool, +idem: Bool, +key: String, route: Pure.Route,
    c: Conn, request: Pure.Send) -> IO(Pool & Result<&1, &1, Pure.Err, Stream>):
  match c:
    case Conn{tls, s}:
      Pure.Send{+method, +target, +authority, +headers, body} = request
      stream.idle.h1(p, ms, head, idem, key, route, method, target, authority, headers,
        Bytes.slice(body, 0, 4294967295), Conn{tls, s})
    case ConnH2{s, client}:
      do IO<Pool & Result<&1, &1, Pure.Err, Stream>>:
        x : Bool & Result<&1, &1, Pure.Err, Stream> <-
          stream.conn(Done{ConnH2{s, client}}, ms, head, Some{key}, request)
        return (p, stream.opened(x))

# Copy the request only for a reused socket, for a stale-socket retry.
def stream.take(taken: Pool & Maybe<&1, Conn>, +ms: U32, +head: Bool, +idem: Bool, +key: String, route: Pure.Route,
    wire: Pure.Send) -> IO(Pool & Result<&1, &1, Pure.Err, Stream>):
  (p, m) = taken
  match m:
    case None{}:
      do IO<Pool & Result<&1, &1, Pure.Err, Stream>>:
        got : Result<&1, &1, Pure.Err, Stream> <- stream.fresh(ms, head, Some{key}, route, wire)
        return (p, got)
    case Some{c}:
      stream.idle(p, ms, head, idem, key, route, c, wire)

# An idle session from the pool, or a new connection with ALPN.
def stream.route(p: Pool, +ms: U32, r: String & Pure.Send & Pure.Route) -> IO(Pool & Result<&1, &1, Pure.Err, Stream>):
  (+key, request, route) = r
  Pure.Send{+method, target, authority, headers, body} = request
  do IO<Pool & Result<&1, &1, Pure.Err, Stream>>:
    taken : Pool & Maybe<&1, Conn> <- pool.take.live(p, key)
    stream.take(taken, ms, String.eq(method, "HEAD"), Pure.pool.idempotent(method), key, route,
      Pure.Send{method, target, authority, headers, body})

def stream.origin.choice(p: Pool, +method: String, +ms: U32,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, hf: String,
    scheme: String, host: String, port: U32, target: String,
    cert: Maybe<&2, Pure.Cert>, +ca: String, choice: Maybe<&2, Pure.Proxy>) ->
    IO(Pool & Result<&1, &1, Pure.Err, Stream>):
  match choice:
    case None{}:
      IO.pure(Pool & Result<&1, &1, Pure.Err, Stream>, (p, Fail{Pure.ErrUrl{}}))
    case Some{proxy}:
      stream.route(p, ms, Pure.origin.route(method, headers, body, hf, scheme, host,
        port, target, cert, ca, proxy))

# cert and ca: the client identity and trusted CA file for this origin.
def stream.origin(p: Pool, +method: String, +ms: U32, headers: Map<&2, List<&2, String>>,
    body: Bytes.Bytes, hf: String, a: Url.Abs, known: Bool,
    cert: Maybe<&2, Pure.Cert>, +ca: String, choice: Maybe<&2, Pure.Proxy>) ->
    IO(Pool & Result<&1, &1, Pure.Err, Stream>):
  Url.Abs{scheme, host, port, target} = a
  match known:
    case False{}:
      IO.pure(Pool & Result<&1, &1, Pure.Err, Stream>, (p, Fail{Pure.ErrUrl{}}))
    case True{}:
      stream.origin.choice(p, method, ms, headers, body, hf, scheme, host, port,
        target, cert, ca, choice)

def stream.one.back(h: Pure.Hop, pr: Pool & Result<&1, &1, Pure.Err, Stream>) -> Pool & Pure.Hop & Result<&1, &1, Pure.Err, Stream>:
  (p, r) = pr
  (p, h, r)

# sent is headers plus any jar cookies; the hop keeps headers, so cookies never pile up across hops.
def stream.one.of(p: Pool, +method: String, +url: Url.Abs, headers: Map<&2, List<&2, String>>, sent: Map<&2, List<&2, String>>,
    +ms: U32, r: Bytes.Bytes & Bytes.Bytes, cert: Maybe<&2, Pure.Cert>, +ca: String) -> IO(Pool & Pure.Hop & Result<&1, &1, Pure.Err, Stream>):
  Url.Abs{+scheme, +host, +port, target} = url
  (body, wire) = r
  do IO<Pool & Pure.Hop & Result<&1, &1, Pure.Err, Stream>>:
    choice : Maybe<&2, Pure.Proxy> <- proxy.select(scheme, host, port)
    got : Pool & Result<&1, &1, Pure.Err, Stream> <-
      stream.origin(p, method, ms, sent, wire, Url.host_field(url), url,
        Pure.pool.scheme.ok(url), cert, ca, choice)
    return stream.one.back(Pure.Hop{method, url, headers, body}, got)

# One request, on an idle socket to its origin when the pool has one. The hop comes back for the redirect.
def stream.one(p: Pool, h: Pure.Hop, +ms: U32, cert: Maybe<&2, Pure.Cert>, +ca: String, jar: Maybe<&2, Pure.Jar>) -> IO(Pool & Pure.Hop & Result<&1, &1, Pure.Err, Stream>):
  Pure.Hop{+method, +url, +headers, body} = h
  stream.one.of(p, method, url, headers, Pure.jar.opt.apply(jar, url, headers), ms, Bytes.slice(body, 0, 4294967295), cert, ca)

# Go: the next request. Drop: close this stream, then go on. Done: the answer.
type Sn is Type:
  SnGo{left: Nat, hop: Pure.Hop}
  SnDrop{st: Stream, next: Pure.Next}
  SnDone{r: Result<&1, &1, Pure.Err, Stream>}

def sn.of(n: Pure.Next) -> Sn:
  match n:
    case Pure.NGo{l, h}:
      SnGo{l, h}
    case Pure.NStop{}:
      SnDone{Fail{Pure.ErrRedirect{}}}
    case Pure.NDone{m}:
      match m:
        case Fail{e}:
          SnDone{Fail{e}}
        case Done{r}:
          SnDone{Fail{Pure.ErrBad{}}}

def stream.decide.done(st: Stream, m: Result<&1, &1, Pure.Err, Pure.Res>) -> Sn:
  match m:
    case Fail{e}:
      SnDrop{st, Pure.NDone{Fail{e}}}
    case Done{r}:
      SnDone{Done{st}}

def stream.decide.n(st: Stream, n: Pure.Next) -> Sn:
  match n:
    case Pure.NDone{m}:
      stream.decide.done(st, m)
    case Pure.NGo{l, h}:
      SnDrop{st, Pure.NGo{l, h}}
    case Pure.NStop{}:
      SnDrop{st, Pure.NStop{}}

# The redirect loop's state for a stream: what to do next, the client identity, the jar, and the CA file.
type StreamHops is Type:
  StreamHops{next: Sn, cert: Maybe<&2, Pure.Cert>, jar: Maybe<&2, Pure.Jar>, ca: String}

def stream.decide.trust(st: Stream, jar: Maybe<&2, Pure.Jar>, nt: Pure.Next & Maybe<&2, Pure.Cert> & String) -> StreamHops:
  (n, cert, ca) = nt
  StreamHops{stream.decide.n(st, n), cert, jar, ca}

def stream.decide.jar(+mode: Pure.Mode, left: Nat, cert: Maybe<&2, Pure.Cert>, +ca: String, st: Stream, +old: String, hop: Pure.Hop,
    r: Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Pure.Res>) -> StreamHops:
  (jar, m) = r
  stream.decide.trust(st, jar, Pure.next.trust(old, cert, ca, Pure.fetch.policy(mode, left, hop, m)))

# The jar takes the response's Set-Cookie fields first, redirect or not.
def stream.decide.of(+mode: Pure.Mode, left: Nat, cert: Maybe<&2, Pure.Cert>, +ca: String, jar: Maybe<&2, Pure.Jar>, hop: Pure.Hop, sr: Stream & Pure.Res) -> StreamHops:
  Pure.Hop{method, +url, headers, body} = hop
  (st, res) = sr
  stream.decide.jar(mode, left, cert, ca, st, Pure.redirect.origin(url), Pure.Hop{method, url, headers, body}, Pure.jar.opt.store(jar, url, Done{res}))

def stream.decide(+mode: Pure.Mode, left: Nat, cert: Maybe<&2, Pure.Cert>, +ca: String, jar: Maybe<&2, Pure.Jar>, x: Pure.Hop & Result<&1, &1, Pure.Err, Stream>) -> StreamHops:
  (hop, r) = x
  match r:
    case Fail{e}:
      StreamHops{SnDone{Fail{e}}, cert, jar, ca}
    case Done{st}:
      stream.decide.of(mode, left, cert, ca, jar, hop, stream.res(st))

def stream.step(+mode: Pure.Mode, left: Nat, cert: Maybe<&2, Pure.Cert>, +ca: String, jar: Maybe<&2, Pure.Jar>,
    x: Pool & Pure.Hop & Result<&1, &1, Pure.Err, Stream>) -> Pool & StreamHops:
  (p, hop, r) = x
  (p, stream.decide(mode, left, cert, ca, jar, (hop, r)))

# mode says what a redirect does, as in pool.hops. A dropped redirect gives its connection to the pool
# when its body has ended. The pool and the jar come back beside the stream.
@unsafe
def stream.hops(+mode: Pure.Mode, +ms: U32, x: Pool & StreamHops) -> IO(Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>):
  (p, hs) = x
  StreamHops{sn, +cert, +jar, +ca} = hs
  match sn:
    case SnDone{r}:
      IO.pure(Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>, (p, jar, r))
    case SnGo{left, hop}:
      do IO<Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>>:
        y : Pool & Pure.Hop & Result<&1, &1, Pure.Err, Stream> <- stream.one(p, hop, ms, cert, ca, jar)
        stream.hops(mode, ms, stream.step(mode, left, cert, ca, jar, y))
    case SnDrop{st, next}:
      do IO<Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>>:
        q : Pool <- pool.stream.close(p, st)
        stream.hops(mode, ms, (q, StreamHops{sn.of(next), cert, jar, ca}))

type Opened is Type:
  Opened{decs: List<&1, ZNative.Decoder>, bad: Bool}

def stream.open.got(st: Opened, r: Result<&1, &1, U32 & String, ZNative.Decoder>) -> Opened:
  Opened{decs, bad} = st
  match r:
    case Fail{e}:
      Opened{decs, True{}}
    case Done{d}:
      Opened{d <> decs, bad}

def stream.open.add(st: Opened, m: IO(Result<&1, &1, U32 & String, ZNative.Decoder>)) -> IO(Opened):
  do IO<Opened>:
    r : Result<&1, &1, U32 & String, ZNative.Decoder> <- m
    return stream.open.got(st, r)

def stream.open.zstd(zstd: Bool, st: Opened) -> IO(Opened):
  match zstd:
    case True{}:
      stream.open.add(st, ZNative.zstd.new())
    case False{}:
      IO.pure(Opened, st)

def stream.open.br(br: Bool, +c: String, st: Opened) -> IO(Opened):
  match br:
    case True{}:
      stream.open.add(st, ZNative.brotli.new())
    case False{}:
      stream.open.zstd(String.eq(c, "zstd"), st)

def stream.open.gz(gz: Bool, +c: String, st: Opened) -> IO(Opened):
  match gz:
    case True{}:
      stream.open.add(st, ZNative.inflate.new())
    case False{}:
      stream.open.br(String.eq(c, "br"), c, st)

def stream.open.step(+c: String, st: Opened) -> IO(Opened):
  Opened{decs, bad} = st
  match bad:
    case True{}:
      IO.pure(Opened, Opened{decs, True{}})
    case False{}:
      stream.open.gz(Bool.or(String.eq(c, "gzip"), Bool.or(String.eq(c, "x-gzip"), String.eq(c, "deflate"))),
        c, Opened{decs, False{}})

def stream.open.one(prev: IO(Opened), c: String) -> IO(Opened):
  do IO<Opened>:
    st : Opened <- prev
    stream.open.step(c, st)

def stream.open.all(cs: List<&2, String>) -> IO(Opened):
  List.foldl(~&2, ~String, ~IO(Opened), ~stream.open.one, cs, IO.pure(Opened, Opened{Nil{}, False{}}))

def stream.put.decs(st: Stream, decs: List<&1, ZNative.Decoder>) -> Stream:
  Stream{tls, s, ms, res, rb, out, old, back} = st
  Stream{tls, s, ms, res, rb, out, decs, back}

def stream.init.opened(st: Stream, opened: Opened) -> IO(Result<&1, &1, Pure.Err, Stream>):
  Opened{decs, bad} = opened
  match bad:
    case True{}:
      do IO<Result<&1, &1, Pure.Err, Stream>>:
        stream.close(stream.put.decs(st, decs))
        return Fail{Pure.ErrBad{}}
    case False{}:
      IO.pure(Result<&1, &1, Pure.Err, Stream>, Done{stream.put.decs(st, List.reverse(&1, ZNative.Decoder, decs))})

def stream.init.known(known: Bool, st: Stream, cs: List<&2, String>) -> IO(Result<&1, &1, Pure.Err, Stream>):
  match known:
    case False{}:
      IO.pure(Result<&1, &1, Pure.Err, Stream>, Done{st})
    case True{}:
      do IO<Result<&1, &1, Pure.Err, Stream>>:
        opened : Opened <- stream.open.all(cs)
        stream.init.opened(st, opened)

def stream.init.st(+enc: String, st: Stream) -> IO(Result<&1, &1, Pure.Err, Stream>):
  Stream{tls, s, ms, res, rb, out, decs, back} = st
  Pure.Res{+status, +headers, body} = res
  +cs = List.reverse(&2, String, Pure.ce.split(Pure.fields(headers, "content-encoding")))
  stream.init.known(Pure.ce.known(cs, Con{"identity", Con{"x-gzip", Pure.ce.split(Con{enc, Nil{}})}}),
    Stream{tls, s, ms, Pure.Res{status, headers, body}, rb, out, decs, back}, cs)

def stream.init(+enc: String, r: Result<&1, &1, Pure.Err, Stream>) -> IO(Result<&1, &1, Pure.Err, Stream>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Pure.Err, Stream>, Fail{e})
    case Done{st}:
      stream.init.st(enc, st)

def stream.init.pool(+enc: String, x: Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>) -> IO(Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>):
  (p, jar, r) = x
  do IO<Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>>:
    s : Result<&1, &1, Pure.Err, Stream> <- stream.init(enc, r)
    return (p, jar, s)

def stream.start(method: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, u: Maybe<&2, Url.Abs>) -> Sn:
  match u:
    case None{}:
      SnDone{Fail{Pure.ErrUrl{}}}
    case Some{a}:
      SnGo{20n, Pure.Hop{method, a, Pure.req.put(Map.to_list(&2, List<&2, String>, headers), Pure.empty()), body}}

def stream.only(x: Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>) -> Result<&1, &1, Pure.Err, Stream>:
  (jar, r) = x
  r

def pool.stream.only(x: Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>) -> Pool & Result<&1, &1, Pure.Err, Stream>:
  (p, jar, r) = x
  (p, r)

# A one-off pool ends with the open; it closes any idle socket a redirect gave back.
def stream.unpooled(x: Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>) -> IO(Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>):
  (p, jar, r) = x
  do IO<Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>>:
    pool.close(p)
    return (jar, r)

# open.raw.how on a pool: each hop takes an idle socket to its origin when the pool has one.
def pool.open.raw.how(p: Pool, mode: Pure.Mode, cert: Maybe<&2, Pure.Cert>, ca: String, jar: Maybe<&2, Pure.Jar>, method: String, url: String,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, +ms: U32) -> IO(Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>):
  stream.hops(mode, ms, (p, StreamHops{stream.start(method, headers, body, Url.absolute(url)), cert, jar, ca}))

# A raw stream with every choice of fetch: mode for redirects, cert and ca for the first origin and each
# same-origin hop ("" trusts the default store), and a jar that gives cookies to every hop and takes them
# from every response. The jar comes back beside the stream. Body bytes and headers remain as sent.
def open.raw.how(mode: Pure.Mode, cert: Maybe<&2, Pure.Cert>, ca: String, jar: Maybe<&2, Pure.Jar>, method: String, url: String,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, +ms: U32) -> IO(Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>):
  do IO<Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>>:
    x : Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream> <- pool.open.raw.how(pool.new(), mode, cert, ca, jar, method, url, headers, body, ms)
    stream.unpooled(x)

# Open a raw stream. It follows redirects, with no client certificate and no jar.
def open.raw.with(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, +ms: U32) -> IO(Result<&1, &1, Pure.Err, Stream>):
  do IO<Result<&1, &1, Pure.Err, Stream>>:
    x : Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream> <- open.raw.how(Pure.ModeFollow{}, None{}, "", None{}, method, url, headers, body, ms)
    return stream.only(x)

def open.raw(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Result<&1, &1, Pure.Err, Stream>):
  open.raw.with(method, url, headers, body, 30000)

def pool.open.how.enc(+enc: String, p: Pool, mode: Pure.Mode, cert: Maybe<&2, Pure.Cert>, ca: String, jar: Maybe<&2, Pure.Jar>, method: String, url: String,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, +ms: U32) -> IO(Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>):
  do IO<Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>>:
    x : Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream> <-
      stream.hops(mode, ms, (p, StreamHops{stream.start(method, Pure.accept.enc(headers, enc), body, Url.absolute(url)), cert, jar, ca}))
    stream.init.pool(enc, x)

# open.how on a pool. Give a stream back with pool.stream.close.
def pool.open.how(p: Pool, mode: Pure.Mode, cert: Maybe<&2, Pure.Cert>, ca: String, jar: Maybe<&2, Pure.Jar>, method: String, url: String,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, +ms: U32) -> IO(Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>):
  do IO<Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>>:
    enc : String <- codings()
    pool.open.how.enc(enc, p, mode, cert, ca, jar, method, url, headers, body, ms)

def pool.open.with(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, +ms: U32) -> IO(Pool & Result<&1, &1, Pure.Err, Stream>):
  do IO<Pool & Result<&1, &1, Pure.Err, Stream>>:
    x : Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream> <- pool.open.how(p, Pure.ModeFollow{}, None{}, "", None{}, method, url, headers, body, ms)
    return pool.stream.only(x)

# open on a pool: an idle socket to the origin when the pool has one, else a new one.
def pool.open(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Pool & Result<&1, &1, Pure.Err, Stream>):
  pool.open.with(p, method, url, headers, body, 30000)

def open.how.enc(+enc: String, mode: Pure.Mode, cert: Maybe<&2, Pure.Cert>, ca: String, jar: Maybe<&2, Pure.Jar>, method: String, url: String,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, +ms: U32) -> IO(Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>):
  do IO<Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>>:
    x : Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream> <- pool.open.how.enc(enc, pool.new(), mode, cert, ca, jar, method, url, headers, body, ms)
    stream.unpooled(x)

# open.raw.how, then each body piece decoded by Content-Encoding (see codings). Unknown codings stay raw.
def open.how(mode: Pure.Mode, cert: Maybe<&2, Pure.Cert>, ca: String, jar: Maybe<&2, Pure.Jar>, method: String, url: String,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, +ms: U32) -> IO(Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>):
  do IO<Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream>>:
    enc : String <- codings()
    open.how.enc(enc, mode, cert, ca, jar, method, url, headers, body, ms)

# Follow redirects, then decode each body piece by Content-Encoding. No client certificate and no jar.
def open.with(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, +ms: U32) -> IO(Result<&1, &1, Pure.Err, Stream>):
  do IO<Result<&1, &1, Pure.Err, Stream>>:
    x : Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Stream> <- open.how(Pure.ModeFollow{}, None{}, "", None{}, method, url, headers, body, ms)
    return stream.only(x)

def open(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Result<&1, &1, Pure.Err, Stream>):
  open.with(method, url, headers, body, 30000)

# Upload: the request body sent in chunks (RFC 9112 §7.1). err: the first failed write.
def up.conn(r: Result<&1, &1, Pure.Err, Conn>, +ms: U32, +head: Bool, wire: String) -> IO(Result<&1, &1, Pure.Err, Pure.Up>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Pure.Err, Pure.Up>, Fail{e})
    case Done{c}:
      match c:
        case Conn{+tls, s}:
          do IO<Result<&1, &1, Pure.Err, Pure.Up>>:
            sent : Socket & Result<&1, &1, U32 & String, Unit> <- io.send.bytes(tls, s, Bytes.from_string(wire))
            return Done{Pure.up.sent(tls, ms, head, sent)}
        case ConnH2{s, client}:
          do IO<Result<&1, &1, Pure.Err, Pure.Up>>:
            Wire.tls.close(s)
            return Fail{Pure.ErrBad{}}

def up.route(+ms: U32, r: String & Pure.Send & Pure.Route) -> IO(Result<&1, &1, Pure.Err, Pure.Up>):
  (key, request, route) = r
  Pure.Send{+method, +target, +authority, +headers, body} = request
  do IO<Result<&1, &1, Pure.Err, Pure.Up>>:
    c : Result<&1, &1, Pure.Err, Conn> <- route.open(ms, False{}, route)
    up.conn(c, ms, String.eq(method, "HEAD"), Pure.up.head(method, target, authority, headers))

def up.origin.choice(+method: String, +ms: U32,
    headers: Map<&2, List<&2, String>>, hf: String,
    scheme: String, host: String, port: U32, target: String,
    cert: Maybe<&2, Pure.Cert>, +ca: String, choice: Maybe<&2, Pure.Proxy>) ->
    IO(Result<&1, &1, Pure.Err, Pure.Up>):
  match choice:
    case None{}:
      IO.pure(Result<&1, &1, Pure.Err, Pure.Up>, Fail{Pure.ErrUrl{}})
    case Some{proxy}:
      up.route(ms, Pure.origin.route(method, headers, Bytes.new(0), hf, scheme, host,
        port, target, cert, ca, proxy))

def up.origin(+method: String, +ms: U32, headers: Map<&2, List<&2, String>>,
    hf: String, a: Url.Abs, known: Bool, cert: Maybe<&2, Pure.Cert>, +ca: String) ->
    IO(Result<&1, &1, Pure.Err, Pure.Up>):
  Url.Abs{+scheme, +host, +port, target} = a
  match known:
    case False{}:
      IO.pure(Result<&1, &1, Pure.Err, Pure.Up>, Fail{Pure.ErrUrl{}})
    case True{}:
      do IO<Result<&1, &1, Pure.Err, Pure.Up>>:
        choice : Maybe<&2, Pure.Proxy> <- proxy.select(scheme, host, port)
        up.origin.choice(method, ms, headers, hf, scheme, host, port, target,
          cert, ca, choice)

def up.url(+method: String, +ms: U32, headers: Map<&2, List<&2, String>>,
    u: Maybe<&2, Url.Abs>, cert: Maybe<&2, Pure.Cert>, +ca: String) ->
    IO(Result<&1, &1, Pure.Err, Pure.Up>):
  match u:
    case None{}:
      IO.pure(Result<&1, &1, Pure.Err, Pure.Up>, Fail{Pure.ErrUrl{}})
    case Some{+a}:
      up.origin(method, ms, headers, Url.host_field(a), a, Pure.pool.scheme.ok(a), cert, ca)

# cert and ca as in open.how. A streamed body cannot be replayed, so redirects are not followed.
def upload.how(cert: Maybe<&2, Pure.Cert>, +ca: String, +method: String, url: String,
    headers: Map<&2, List<&2, String>>, +ms: U32) -> IO(Result<&1, &1, Pure.Err, Pure.Up>):
  up.url(method, ms, headers, Url.absolute(url), cert, ca)

def upload.with(+method: String, url: String, headers: Map<&2, List<&2, String>>, +ms: U32) -> IO(Result<&1, &1, Pure.Err, Pure.Up>):
  upload.how(None{}, "", method, url, headers, ms)

def upload(+method: String, url: String, headers: Map<&2, List<&2, String>>) -> IO(Result<&1, &1, Pure.Err, Pure.Up>):
  upload.with(method, url, headers, 30000)

def up.put(+tls: Bool, s: Socket, +ms: U32, +head: Bool, +len: U32, piece: Bytes.Bytes, skip: Bool) -> IO(Pure.Up & Result<&2, &2, Pure.Err, Unit>):
  match skip:
    case True{}:
      IO.pure(Pure.Up & Result<&2, &2, Pure.Err, Unit>, (Pure.Up{tls, s, ms, head, None{}}, Done{Unit{}}))
    case False{}:
      do IO<Pure.Up & Result<&2, &2, Pure.Err, Unit>>:
        sent : Socket & Result<&1, &1, U32 & String, Unit> <- io.send.bytes(tls, s, Bytes.concat(Con{Bytes.from_string(Pure.hex(len) ++ "\r\n"), Con{piece, Con{Bytes.from_string("\r\n"), Nil{}}}}))
        return Pure.up.wrote(tls, ms, head, sent)

def up.chunk(+tls: Bool, s: Socket, +ms: U32, +head: Bool, piece: Bytes.Bytes) -> IO(Pure.Up & Result<&2, &2, Pure.Err, Unit>):
  Bytes.Bytes{+len, buf} = piece
  up.put(tls, s, ms, head, len, Bytes.Bytes{len, buf}, U32.is_zero(len))

# One chunk. An empty piece sends nothing, since an empty chunk would end the body.
def upload.write(up: Pure.Up, piece: Bytes.Bytes) -> IO(Pure.Up & Result<&2, &2, Pure.Err, Unit>):
  Pure.Up{+tls, s, +ms, +head, err} = up
  match err:
    case Some{+e}:
      IO.pure(Pure.Up & Result<&2, &2, Pure.Err, Unit>, (Pure.Up{tls, s, ms, head, Some{e}}, Fail{e}))
    case None{}:
      up.chunk(tls, s, ms, head, piece)

# Ends the body and returns the response as a stream.
def upload.finish(up: Pure.Up) -> IO(Result<&1, &1, Pure.Err, Stream>):
  Pure.Up{+tls, s, +ms, +head, err} = up
  match err:
    case Some{e}:
      do IO<Result<&1, &1, Pure.Err, Stream>>:
        io.close(tls, s)
        return Fail{e}
    case None{}:
      do IO<Result<&1, &1, Pure.Err, Stream>>:
        sent : Socket & Result<&1, &1, U32 & String, Unit> <- io.send.bytes(tls, s, Bytes.from_string("0\r\n\r\n"))
        x : Bool & Result<&1, &1, Pure.Err, Stream> <- stream.sent(tls, ms, head, None{}, sent)
        return stream.opened(x)

def limits.validate.ok(valid: Bool) -> IO(Unit):
  match valid:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 22, "request cap plus 65536-byte recv overshoot and 3-byte packed rounding must fit U32")

def limits.validate(+max: Nat) -> IO(Unit):
  limits.validate.ok(Nat.is_gt(max, 0n) && Nat.is_le(max, U32.to_nat(Pure.limits.representable())))

def bounded.send.ready(expired: Bool, s: Socket, b: Bytes.Bytes, ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match expired:
    case True{}:
      IO.pure(Socket & Result<&1, &1, U32 & String, Unit>, (s, Fail{(60, "write deadline expired")}))
    case False{}:
      Bytes.Bytes{len, words} = b
      do IO<Socket & Result<&1, &1, U32 & String, Unit>>:
        sent : Socket & (U32 & Result<&1, &1, U32 & String, Unit>) <- Wire.send.words.deadline(s, len, words, ms)
        return Pure.bounded.sent(sent)

def bounded.send(s: Socket, b: Bytes.Bytes, until: Time.Duration) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  do IO<Socket & Result<&1, &1, U32 & String, Unit>>:
    now : Time.Duration <- clock.mono()
    +ms : U32 = Pure.phase.remaining(until, now)
    bounded.send.ready(U32.is_zero(ms), s, b, ms)

def reply.drain(n: Nat, alive: Bool, +until: Time.Duration, st: Socket & Bool) -> IO(Unit):
  match n:
    case 0n:
      (s, more) = st
      Socket.close(s)
    case 1n+p:
      match alive:
        case False{}:
          (s, more) = st
          Socket.close(s)
        case True{}:
          (s, more) = st
          match more:
            case False{}:
              Socket.close(s)
            case True{}:
              do IO<Unit>:
                got : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Wire.recv.words(s, 65536, 50)
                now : Time.Duration <- clock.mono()
                reply.drain(p, Cmp.is_lt(Time.Duration.cmp(now, until)), until, Pure.reply.drain.of(got))

def reply.sent.close(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (s, r) = m
  match r:
    case Fail{e}:
      Socket.close(s)
    case Done{u}:
      do IO<Unit>:
        now : Time.Duration <- clock.mono()
        reply.drain(U32.to_nat(512), True{}, Time.Duration.add(now, Time.Duration.of_ms(2500)), (s, True{}))

def reply.sent.observe(observer: Completion.Receipt, status: U32,
  sent: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (socket, result) = sent
  match result:
    case Fail{(code, message)}:
      do IO<Unit>:
        Socket.close(socket)
        Completion.report(observer, status, Completion.WriteFailed{code, message})
    case Done{unit}:
      do IO<Unit>:
        reply.sent.close((socket, Done{unit}))
        Completion.report(observer, status, Completion.HostAccepted{})


def reply_fail(observer: Completion.Receipt, s: Socket, +status: U32, ms: U32) -> IO(Unit):
  do IO<Unit>:
    now : Time.Duration <- clock.mono()
    sent : Socket & Result<&1, &1, U32 & String, Unit> <-
      bounded.send(s, Pure.encode(Pure.reply.fail.bytes(status)), Time.Duration.add(now, Time.Duration.of_ms(ms)))
    reply.sent.observe(observer, status, sent)


# The head is parsed once, when it is whole. Body pieces are kept as they come and joined once.
def talk.after(settings: Pure.Limits, keep: Bool, rest: Bytes.Bytes, m: Socket & Result<&1, &1, U32 & String, Unit>) -> (Socket & Pure.Turn) & Completion.Outcome:
  (s, r) = m
  match r:
    case Fail{(code, message)}:
      ((s, Pure.TurnClose{}), Completion.WriteFailed{code, message})
    case Done{u}:
      (Pure.talk.after.keep(keep, settings, rest, s), Completion.HostAccepted{})

def talk.send(+settings: Pure.Limits, s: Socket, rest: Bytes.Bytes, +headers: Map<&2, List<&2, String>>, v11: Bool, +head: Bool, res: Pure.Res) -> IO((Socket & Pure.Turn) & Completion.Outcome):
  Pure.Limits{max, cap, hm, bm, im, wm} = settings
  Pure.Res{+status, +rh, body} = res
  +keep = Pure.serve.keep(headers, v11, status, rh)
  do IO<(Socket & Pure.Turn) & Completion.Outcome>:
    now : Time.Duration <- clock.mono()
    sent : Socket & Result<&1, &1, U32 & String, Unit> <-
      bounded.send(s, Pure.reply.bytes(Pure.Res{status, rh, body}, head, Bool.not(keep)), Time.Duration.add(now, Time.Duration.of_ms(wm)))
    return talk.after(settings, keep, rest, sent)

def talk.completed.connection(outcome: Completion.Outcome, next: Socket & Pure.Turn) -> IO(Maybe<&1, Socket & Pure.Turn>):
  match outcome:
    case Completion.HostAccepted{}:
      (socket, turn) = next
      IO.pure(Maybe<&1, Socket & Pure.Turn>, Some{(socket, turn)})
    case Completion.WriteFailed{code, message}:
      (socket, turn) = next
      do IO<Maybe<&1, Socket & Pure.Turn>>:
        Socket.close(socket)
        return None{}
    case Completion.IncompleteResponse{}:
      (socket, turn) = next
      do IO<Maybe<&1, Socket & Pure.Turn>>:
        Socket.close(socket)
        return None{}

def talk.completed(observer: Completion.Receipt, receipt: Completion.Receipt, +status: U32,
  sent: (Socket & Pure.Turn) & Completion.Outcome) -> IO(Maybe<&1, Socket & Pure.Turn>):
  (next, outcome) = sent
  +observed = {outcome : Completion.Outcome}
  do IO<Maybe<&1, Socket & Pure.Turn>>:
    remaining : Maybe<&1, Socket & Pure.Turn> <- talk.completed.connection(observed, next)
    Completion.report(observer, status, observed)
    Completion.report(receipt, status, observed)
    return remaining

def talk.respond(observer: Completion.Receipt, +settings: Pure.Limits, s: Socket, rest: Bytes.Bytes,
  headers: Map<&2, List<&2, String>>, v11: Bool, head: Bool, reply: Reply) -> IO(Maybe<&1, Socket & Pure.Turn>):
  Reply{Pure.Res{+status, rh, body}, receipt} = reply
  do IO<Maybe<&1, Socket & Pure.Turn>>:
    sent : (Socket & Pure.Turn) & Completion.Outcome <- talk.send(settings, s, rest, headers, v11, head, Pure.Res{status, rh, body})
    talk.completed(observer, receipt, status, sent)

def talk.cont(cont: Bool, s: Socket, ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match cont:
    case False{}:
      IO.pure(Socket & Result<&1, &1, U32 & String, Unit>, (s, Done{Unit{}}))
    case True{}:
      do IO<Socket & Result<&1, &1, U32 & String, Unit>>:
        now : Time.Duration <- clock.mono()
        bounded.send(s, Bytes.from_string("HTTP/1.1 100 Continue\r\n\r\n"), Time.Duration.add(now, Time.Duration.of_ms(ms)))

def talk.read.running(held: Bool, inbox: Chan(Admission.Command)) -> IO(Bool):
  match held:
    case True{}: IO.pure(Bool, True{})
    case False{}: Admission.running(inbox)

@unsafe
def talk.read.loop(+inbox: Chan(Admission.Command), +held: Bool, +settings: Pure.Limits,
  step: Pure.ReadStep) -> IO((Socket & Pure.Turn) & Pure.Phase):
  match step:
    case Pure.ReadChecking{s, sv, phase}:
      do IO<(Socket & Pure.Turn) & Pure.Phase>:
        running : Bool <- talk.read.running(held, inbox)
        talk.read.loop(inbox, held, settings, Pure.ReadAllowed{running, s, sv, phase})
    case Pure.ReadAllowed{running, s, sv, +phase}:
      match running:
        case False{}:
          IO.pure((Socket & Pure.Turn) & Pure.Phase, ((s, Pure.TurnClose{}), phase))
        case True{}:
          Pure.Phase{kind, until} = phase
          do IO<(Socket & Pure.Turn) & Pure.Phase>:
            now : Time.Duration <- clock.mono()
            +ms : U32 = Pure.phase.remaining(until, now)
            talk.read.loop(inbox, held, settings,
              Pure.ReadBudget{Bool.pick(U32, held, ms, U32.min(ms, 50)), s, sv, phase})
    case Pure.ReadBudget{ms, s, sv, +phase}:
      match ms:
        case 0:
          IO.pure((Socket & Pure.Turn) & Pure.Phase, ((s, Pure.phase.expired(phase)), phase))
        case _:
          do IO<(Socket & Pure.Turn) & Pure.Phase>:
            got : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Wire.recv.words(s, 65536, ms)
            now : Time.Duration <- clock.mono()
            talk.read.loop(inbox, held, settings, Pure.ReadReceived{sv, phase, now, got})
    case Pure.ReadReceived{sv, +phase, +now, got}:
      Pure.Phase{kind, until} = phase
      (s, result) = got
      match result:
        case Fail{(+code, message)}:
          talk.read.loop(inbox, held, settings,
            Pure.ReadFailed{Pure.err.late(code) && Cmp.is_lt(Time.Duration.cmp(now, until)), s, sv, phase, now, (code, message)})
        case Done{packed}:
          IO.pure((Socket & Pure.Turn) & Pure.Phase,
            Pure.talk.received.late(Bool.not(Cmp.is_lt(Time.Duration.cmp(now, until))), settings, phase, now, sv, (s, Done{packed})))
    case Pure.ReadFailed{retry, s, sv, +phase, +now, error}:
      match retry:
        case True{}:
          talk.read.loop(inbox, held, settings, Pure.ReadChecking{s, sv, phase})
        case False{}:
          Pure.Phase{kind, until} = phase
          IO.pure((Socket & Pure.Turn) & Pure.Phase,
            Pure.talk.received.late(Bool.not(Cmp.is_lt(Time.Duration.cmp(now, until))), settings, phase, now, sv, (s, Fail{error})))

def talk.read(+inbox: Chan(Admission.Command), held: Bool, +settings: Pure.Limits, sv: Pure.Sv, phase: Pure.Phase, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO((Socket & Pure.Turn) & Pure.Phase):
  (s, r) = m
  match r:
    case Fail{(code, message)}:
      IO.pure((Socket & Pure.Turn) & Pure.Phase, ((s, Pure.TurnInputFailed{Pure.SendContinue{}, code, message}), phase))
    case Done{u}:
      talk.read.loop(inbox, held, settings, Pure.ReadChecking{s, sv, phase})

def talk.recv.selected(+inbox: Chan(Admission.Command), held: Bool, +settings: Pure.Limits, s: Socket, cont: Bool, selected: Pure.Phase & Pure.Sv) -> IO((Socket & Pure.Turn) & Pure.Phase):
  Pure.Limits{max, cap, hm, bm, im, wm} = settings
  (phase, state) = selected
  do IO<(Socket & Pure.Turn) & Pure.Phase>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- talk.cont(cont, s, wm)
    talk.read(inbox, held, settings, state, phase, sent)

def talk.recv(+inbox: Chan(Admission.Command), held: Bool, +settings: Pure.Limits, s: Socket, sv: Pure.Sv, cont: Bool, previous: Maybe<&2, Pure.Phase>) -> IO((Socket & Pure.Turn) & Pure.Phase):
  do IO<(Socket & Pure.Turn) & Pure.Phase>:
    now : Time.Duration <- clock.mono()
    talk.recv.selected(inbox, held, settings, s, cont, Pure.phase.select(settings, sv, now, previous))

def admission.done(+inbox: Chan(Admission.Command), operation: IO(Unit)) -> IO(Unit):
  do IO<Unit>:
    operation
    Admission.give(inbox, 0)

def admission.reject(observer: Completion.Receipt, s: Socket, head: Bool, ms: U32) -> IO(Unit):
  do IO<Unit>:
    now : Time.Duration <- clock.mono()
    sent : Socket & Result<&1, &1, U32 & String, Unit> <-
      bounded.send(s, Pure.reply.bytes(Pure.reply.fail.bytes(503), head, True{}), Time.Duration.add(now, Time.Duration.of_ms(ms)))
    reply.sent.observe(observer, 503, sent)

def admission.request(
  ~C: Data, ~h: C -> Pure.Req -> IO(Reply), ~observe: C -> U32 -> Completion.Outcome -> IO(Unit),
  admitted: Bool, +inbox: Chan(Admission.Command), +context: C, +settings: Pure.Limits, s: Socket, req: Pure.Req, rest: Bytes.Bytes, v11: Bool
) -> IO(Maybe<&1, Socket & Pure.Turn>):
  match admitted:
    case False{}:
      Pure.Limits{max, cap, hm, bm, im, wm} = settings
      do IO<Maybe<&1, Socket & Pure.Turn>>:
        admission.reject(Completion.Observed{status => outcome => observe(context, status, outcome)}, s, Pure.admission.head(req), wm)
        return None{}
    case True{}:
      Pure.Req{+method, path, +headers, body} = req
      do IO<Maybe<&1, Socket & Pure.Turn>>:
        res : Reply <- h(context, Pure.Req{method, path, headers, body})
        next : Maybe<&1, Socket & Pure.Turn> <- talk.respond(Completion.Observed{status => outcome => observe(context, status, outcome)}, settings, s, rest, headers, v11, String.eq(method, "HEAD"), res)
        Admission.give(inbox, 1)
        return next


@unsafe
def talk(~C: Data, ~h: C -> Pure.Req -> IO(Reply), ~observe: C -> U32 -> Completion.Outcome -> IO(Unit), +context: C, +settings: Pure.Limits, +inbox: Chan(Admission.Command), st: Maybe<&1, Pure.Serving>) -> IO(Unit):
  Pure.Limits{max, cap, hm, bm, im, wm} = settings
  match st:
    case None{}:
      IO.pure(Unit, Unit{})
    case Some{Pure.Serving{(s, t), phase}}:
      match t:
        case Pure.TurnMore{sv, cont}:
          do IO<Unit>:
            received : (Socket & Pure.Turn) & Pure.Phase <- talk.recv(inbox, False{}, settings, s, sv, cont, phase)
            talk(~C, ~h, ~observe, context, settings, inbox, Some{Pure.talk.state(received)})
        case Pure.TurnReq{req, rest, v11}:
          do IO<Unit>:
            admitted : Bool <- Admission.take(inbox, 1)
            next : Maybe<&1, Socket & Pure.Turn> <- admission.request(~C, ~h, ~observe, admitted, inbox, context, settings, s, req, rest, v11)
            talk(~C, ~h, ~observe, context, settings, inbox, Pure.serve.write.state(next))
        case Pure.TurnFail{status}:
          reply_fail(Completion.Observed{status => outcome => observe(context, status, outcome)}, s, status, wm)
        case Pure.TurnClose{}:
          Socket.close(s)
        case Pure.TurnInputFailed{operation, code, message}:
          Socket.close(s)

def conn.admitted(~h: Pure.Req -> IO(Reply), ~observe: U32 -> Completion.Outcome -> IO(Unit), admitted: Bool, +settings: Pure.Limits, +inbox: Chan(Admission.Command), l: Listener, s: Socket) -> IO(Listener):
  match admitted:
    case False{}:
      do IO<Listener>:
        Socket.close(s)
        return l
    case True{}:
      do IO<Listener>:
        IO.spawn(Unit, admission.done(inbox, talk(~Unit, ~(context => req => h(req)), ~(context => status => outcome => observe(status, outcome)), Unit{}, settings, inbox,
          Some{Pure.Serving{(s, Pure.TurnMore{Pure.sv.none(), False{}}), None{}}})))
        return l

def conn(~h: Pure.Req -> IO(Reply), ~observe: U32 -> Completion.Outcome -> IO(Unit), +settings: Pure.Limits, +inbox: Chan(Admission.Command), m: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (l, r) = m
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    admitted : Bool <- Admission.take(inbox, 0)
    conn.admitted(~h, ~observe, admitted, settings, inbox, l, s)

# Finite positive settings, not zero/unlimited sentinels.
type Server<-C: Data> is Type:
  Server{listener: Listener, context: C, config: Pure.ServerConfig, admission: Chan(Admission.Command), drained: Chan(Admission.Counts)}

def server.opened(~C: Data, ~O: Type, owner: O, listener: Listener, context: C,
  config: Pure.ServerConfig, opened: Chan(Admission.Command) & Chan(Admission.Counts)) -> IO(O & Result<&2, &1, Pure.StartupError, Server<C>>):
  (inbox, drained) = opened
  IO.pure(O & Result<&2, &1, Pure.StartupError, Server<C>>, (owner, Done{Server{listener, context, config, inbox, drained}}))

def server.started(~C: Data, ~O: Type, context: C, owner: O, +config: Pure.ServerConfig, result: Result<&1, &1, U32 & String, Listener>) -> IO(O & Result<&2, &1, Pure.StartupError, Server<C>>):
  Pure.ServerConfig{host, port, body, headers, connections, requests, buffered, hm, bm, im, wm} = config
  match result:
    case Fail{error}:
      (code, message) = error
      IO.pure(O & Result<&2, &1, Pure.StartupError, Server<C>>, (owner, Fail{Pure.BindError{code, message}}))
    case Done{listener}:
      do IO<O & Result<&2, &1, Pure.StartupError, Server<C>>>:
        opened : Chan(Admission.Command) & Chan(Admission.Counts) <- Admission.open.owner(Admission.Caps{connections, requests, buffered})
        server.opened(~C, ~O, owner, listener, context, config, opened)

def server.bound(~C: Data, ~O: Type, context: C, owner: O, config: Pure.ServerConfig,
  result: Result<&1, &1, U32 & String, Listener & U32>) -> IO(O & Result<&2, &1, Pure.StartupError, Server<C>>):
  Pure.ServerConfig{host, requested, body, headers, connections, requests, buffered, hm, bm, im, wm} = config
  match result:
    case Fail{error}:
      server.started(~C, ~O, context, owner,
        Pure.ServerConfig{host, requested, body, headers, connections, requests, buffered, hm, bm, im, wm}, Fail{error})
    case Done{(listener, port)}:
      server.started(~C, ~O, context, owner,
        Pure.ServerConfig{host, port, body, headers, connections, requests, buffered, hm, bm, im, wm}, Done{listener})

def server.start.valid(~C: Data, ~O: Type, valid: Bool, context: C, owner: O, +config: Pure.ServerConfig) -> IO(O & Result<&2, &1, Pure.StartupError, Server<C>>):
  match valid:
    case False{}:
      IO.pure(O & Result<&2, &1, Pure.StartupError, Server<C>>, (owner, Fail{Pure.InvalidConfig{}}))
    case True{}:
      Pure.ServerConfig{host, port, body, headers, connections, requests, buffered, header_ms, body_ms, idle_ms, write_ms} = config
      do IO<O & Result<&2, &1, Pure.StartupError, Server<C>>>:
        result : Result<&1, &1, U32 & String, Listener & U32> <- Wire.listen(host, port)
        server.bound(~C, ~O, context, owner, config, result)

# Done is the readiness signal: Wire.listen has installed an accepting socket.
# Both branches return the preopened application owner unchanged.
def server.start(~C: Data, ~O: Type, context: C, owner: O, +config: Pure.ServerConfig) -> IO(O & Result<&2, &1, Pure.StartupError, Server<C>>):
  server.start.valid(~C, ~O, Pure.server.config.valid(config), context, owner, config)

# Observe the actual bound port without releasing the listener.
def server.port(~C: Data, server: Server<C>) -> Server<C> & U32:
  Server{listener, context, config, inbox, drained} = server
  Pure.ServerConfig{host, +port, body, headers, connections, requests, buffered, hm, bm, im, wm} = config
  (Server{listener, context, Pure.ServerConfig{host, port, body, headers, connections, requests, buffered, hm, bm, im, wm}, inbox, drained}, port)


# Copyable read-only observations remain usable while server.run owns the listener.
type ServerStats is Data:
  ServerStats{inbox: Chan(Admission.Command)}

def server.observer(~C: Data, server: Server<C>) -> Server<C> & ServerStats:
  Server{listener, context, config, +inbox, drained} = server
  (Server{listener, context, config, inbox, drained}, ServerStats{inbox})

def server.counts(counts: Maybe<&2, Admission.Counts>) -> Maybe<&2, Pure.ServerCounts>:
  match counts:
    case None{}:
      None{}
    case Some{Admission.Counts{c, a, b, ch, ah, bh, cr, ar, br}}:
      Some{Pure.ServerCounts{c, a, b, ch, ah, bh, cr, ar, br}}

# None means accounting has closed after the listener and its retained operations.
# This is not a drain result or a per-response write outcome.
def server.stats(observer: ServerStats) -> IO(Maybe<&2, Pure.ServerCounts>):
  ServerStats{inbox} = observer
  do IO<Maybe<&2, Pure.ServerCounts>>:
    counts : Maybe<&2, Admission.Counts> <- Admission.snapshot(inbox)
    return server.counts(counts)

type ServerControl is Data:
  ServerControl{inbox: Chan(Admission.Command)}

# Stop linearizes in Admission. It requests quiescence, never attests drain.
def server.control(~C: Data, server: Server<C>) -> Server<C> & ServerControl:
  Server{listener, context, config, +inbox, drained} = server
  (Server{listener, context, config, inbox, drained}, ServerControl{inbox})

def server.stop(control: ServerControl) -> IO(Bool):
  ServerControl{inbox} = control
  Admission.quiesce(inbox)

def server.final.counts(counts: Admission.Counts) -> Pure.ServerCounts:
  Admission.Counts{c, a, b, ch, ah, bh, cr, ar, br} = counts
  Pure.ServerCounts{c, a, b, ch, ah, bh, cr, ar, br}

# Only the listener owner closes it, after the current accept really returns.
# Joining the controller waits for every real operation, including callbacks.
def server.close(~C: Data, server: Server<C>) -> IO(Pure.ServerCounts):
  Server{listener, context, config, +inbox, drained} = server
  do IO<Pure.ServerCounts>:
    requested : Bool <- Admission.quiesce(inbox)
    Listener.close(listener)
    Admission.close(inbox)
    counts : Admission.Counts <- IO.join(Admission.Counts, drained)
    return server.final.counts(counts)

def server.finish(~C: Data, stopped: Bool, error: U32 & String, server: Server<C>) -> IO(Pure.ServerExit):
  do IO<Pure.ServerExit>:
    counts : Pure.ServerCounts <- server.close(~C, server)
    return Pure.server.finished(stopped, error, counts)

def server.admitted(~C: Data, ~operation: C -> Pure.Limits -> Chan(Admission.Command) -> Socket -> IO(Unit), admitted: Bool, +context: C, +config: Pure.ServerConfig, +inbox: Chan(Admission.Command), drained: Chan(Admission.Counts), listener: Listener, socket: Socket) -> IO(Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>):
  match admitted:
    case False{}:
      do IO<Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>>:
        Socket.close(socket)
        return (Server{listener, context, config, inbox, drained}, Fail{(11, "transport capacity exhausted")})
    case True{}:
      do IO<Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>>:
        finished : Chan(Unit) <- IO.fork(Unit, admission.done(inbox, operation(context, Pure.limits.config(config), inbox, socket)))
        return (Server{listener, context, config, inbox, drained}, Done{finished})

def server.accepted(~C: Data, ~operation: C -> Pure.Limits -> Chan(Admission.Command) -> Socket -> IO(Unit), +context: C, +config: Pure.ServerConfig, +inbox: Chan(Admission.Command), drained: Chan(Admission.Counts), result: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>):
  (listener, got) = result
  match got:
    case Fail{error}:
      IO.pure(Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>, (Server{listener, context, config, inbox, drained}, Fail{error}))
    case Done{socket}:
      do IO<Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>>:
        admitted : Bool <- Admission.take(inbox, 0)
        server.admitted(~C, ~operation, admitted, context, config, inbox, drained, listener, socket)

# One accepting step, so the caller retains explicit listener ownership.
type AcceptStep<-C: Data> is Type:
  AcceptChecking{server: Server<C>}
  AcceptAllowed{running: Bool, server: Server<C>}
  AcceptReceived{result: Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>}
  AcceptFailed{retry: Bool, server: Server<C>, error: U32 & String}

@unsafe
def server.accept.loop(~C: Data, ~operation: C -> Pure.Limits -> Chan(Admission.Command) -> Socket -> IO(Unit),
  step: AcceptStep<C>) -> IO(Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>):
  match step:
    case AcceptChecking{server}:
      Server{listener, context, config, +inbox, drained} = server
      do IO<Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>>:
        running : Bool <- Admission.running(inbox)
        server.accept.loop(~C, ~operation, AcceptAllowed{running, Server{listener, context, config, inbox, drained}})
    case AcceptAllowed{running, server}:
      match running:
        case False{}:
          IO.pure(Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>, (server, Fail{(0, "server stopped")}))
        case True{}:
          Server{listener, context, config, inbox, drained} = server
          do IO<Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>>:
            result : Listener & Result<&1, &1, U32 & String, Socket> <- Wire.accept.deadline(listener, 50)
            accepted : Server<C> & Result<&1, &1, U32 & String, Chan(Unit)> <-
              server.accepted(~C, ~operation, context, config, inbox, drained, result)
            server.accept.loop(~C, ~operation, AcceptReceived{accepted})
    case AcceptReceived{accepted}:
      (server, result) = accepted
      match result:
        case Fail{(+code, message)}:
          server.accept.loop(~C, ~operation, AcceptFailed{Pure.err.late(code), server, (code, message)})
        case Done{finished}:
          IO.pure(Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>, (server, Done{finished}))
    case AcceptFailed{retry, server, error}:
      match retry:
        case True{}: server.accept.loop(~C, ~operation, AcceptChecking{server})
        case False{}: IO.pure(Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>, (server, Fail{error}))

def server.accept.operation(~C: Data, ~operation: C -> Pure.Limits -> Chan(Admission.Command) -> Socket -> IO(Unit),
  server: Server<C>) -> IO(Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>):
  server.accept.loop(~C, ~operation, AcceptChecking{server})

def server.accept(~C: Data, ~h: C -> Pure.Req -> IO(Reply), ~observe: C -> U32 -> Completion.Outcome -> IO(Unit), server: Server<C>) -> IO(Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>):
  server.accept.operation(~C,
    ~(context => settings => inbox => socket => talk(~C, ~h, ~observe, context, settings, inbox,
      Some{Pure.Serving{(socket, Pure.TurnMore{Pure.sv.none(), False{}}), None{}}})), server)

type ServerLoop<-C: Data> is Type:
  ServerListening{server: Server<C>}
  ServerAccepted{result: Server<C> & Result<&1, &1, U32 & String, Chan(Unit)>}
  ServerFailed{retry: Bool, server: Server<C>, error: U32 & String}

@unsafe
def server.run.loop(~C: Data, ~operation: C -> Pure.Limits -> Chan(Admission.Command) -> Socket -> IO(Unit), step: ServerLoop<C>) -> IO(Pure.ServerExit):
  match step:
    case ServerListening{server}:
      do IO<Pure.ServerExit>:
        result : Server<C> & Result<&1, &1, U32 & String, Chan(Unit)> <- server.accept.operation(~C, ~operation, server)
        server.run.loop(~C, ~operation, ServerAccepted{result})
    case ServerAccepted{accepted}:
      (server, result) = accepted
      match result:
        case Fail{+error}:
          server.run.loop(~C, ~operation, ServerFailed{Pure.error.capacity(error), server, error})
        case Done{finished}:
          do IO<Pure.ServerExit>:
            Chan.close(Unit, finished)
            server.run.loop(~C, ~operation, ServerListening{server})
    case ServerFailed{retry, server, +error}:
      match retry:
        case True{}:
          server.run.loop(~C, ~operation, ServerListening{server})
        case False{}:
          server.finish(~C, Pure.error.stopped(error), error, server)

def server.run(~C: Data, ~h: C -> Pure.Req -> IO(Reply), ~observe: C -> U32 -> Completion.Outcome -> IO(Unit), server: Server<C>) -> IO(Pure.ServerExit):
  server.run.loop(~C,
    ~(context => settings => inbox => socket => talk(~C, ~h, ~observe, context, settings, inbox,
      Some{Pure.Serving{(socket, Pure.TurnMore{Pure.sv.none(), False{}}), None{}}})), ServerListening{server})

# Convenience wrappers use the same owner and observe its actual exit/drain.
def server.exited(result: Pure.ServerExit) -> IO(Unit):
  match result:
    case Pure.ServerStopped{counts}: IO.pure(Unit, Unit{})
    case Pure.ServerAcceptFailed{code, message, counts}: IO.die(Unit, code, message)

def server.start.failed(error: Pure.StartupError) -> IO(Unit):
  match error:
    case Pure.InvalidConfig{}: IO.die(Unit, 22, "invalid server configuration")
    case Pure.BindError{code, message}: IO.die(Unit, code, message)

def serve.config.result(result: Result<&2, &2, Pure.StartupError, Unit>) -> IO(Unit):
  match result:
    case Fail{error}: server.start.failed(error)
    case Done{unit}: IO.pure(Unit, unit)

def serve.stream.nonempty(~S: Type, ~piece: S -> Bytes.Bytes -> IO(S & Bool), empty: Bool, state: S, b: Bytes.Bytes) -> IO(S & Bool):
  match empty:
    case True{}:
      IO.pure(S & Bool, (state, False{}))
    case False{}:
      piece(state, b)

# The piece callback returns True to discard the rest of this request body.
def serve.stream.one(~S: Type, ~piece: S -> Bytes.Bytes -> IO(S & Bool), drop: Bool, state: S, b: Bytes.Bytes) -> IO(S & Bool):
  match drop:
    case True{}:
      IO.pure(S & Bool, (state, True{}))
    case False{}:
      Bytes.Bytes{+len, buf} = b
      serve.stream.nonempty(~S, ~piece, U32.is_eq(len, 0), state, Bytes.Bytes{len, buf})

def serve.stream.parts(~S: Type, ~piece: S -> Bytes.Bytes -> IO(S & Bool), xs: List<&1, Bytes.Bytes>, st: S & Bool) -> IO(S & Bool):
  match xs:
    case Nil{}:
      IO.pure(S & Bool, st)
    case Con{b, rest}:
      (state, drop) = st
      do IO<S & Bool>:
        next : S & Bool <- serve.stream.one(~S, ~piece, drop, state, b)
        serve.stream.parts(~S, ~piece, rest, next)

def serve.stream.feed(~S: Type, ~start: Pure.Req -> IO(S), ~piece: S -> Bytes.Bytes -> IO(S & Bool), req: Pure.Req, m: Maybe<&1, S & Bool>, parts: List<&1, Bytes.Bytes>) -> IO(S & Bool):
  match m:
    case None{}:
      do IO<S & Bool>:
        state : S <- start(req)
        serve.stream.parts(~S, ~piece, parts, (state, False{}))
    case Some{st}:
      serve.stream.parts(~S, ~piece, parts, st)

def serve.stream.respond(~S: Type, ~finish: S -> IO(Reply), ~observe: U32 -> Completion.Outcome -> IO(Unit), +settings: Pure.Limits, s: Socket, rest: Bytes.Bytes, +headers: Map<&2, List<&2, String>>, v11: Bool, +method: String, st: S & Bool) -> IO(Maybe<&1, Socket & Pure.Turn>):
  (state, dropped) = st
  do IO<Maybe<&1, Socket & Pure.Turn>>:
    res : Reply <- finish(state)
    talk.respond(Completion.Observed{status => outcome => observe(status, outcome)}, settings, s, rest, headers, v11, String.eq(method, "HEAD"), res)

def admission.give.held(held: Bool, inbox: Chan(Admission.Command)) -> IO(Unit):
  match held:
    case False{}:
      IO.pure(Unit, Unit{})
    case True{}:
      Admission.give(inbox, 1)

def admission.stream.take(needed: Bool, inbox: Chan(Admission.Command)) -> IO(Bool):
  match needed:
    case False{}:
      IO.pure(Bool, True{})
    case True{}:
      Admission.take(inbox, 1)

def serve.stream.abort(~S: Type, ~abort: S -> Pure.StreamAbort -> IO(Unit),
  reason: Pure.StreamAbort, state: Maybe<&1, S & Bool>) -> IO(Unit):
  match state:
    case None{}: IO.pure(Unit, Unit{})
    case Some{pair}:
      (value, dropped) = pair
      abort(value, reason)

# One recursive state machine keeps template callbacks out of mutual recursion.
@unsafe
def serve.stream.talk(
  ~S: Type, ~start: Pure.Req -> IO(S), ~piece: S -> Bytes.Bytes -> IO(S & Bool),
  ~finish: S -> IO(Reply), ~abort: S -> Pure.StreamAbort -> IO(Unit), ~observe: U32 -> Completion.Outcome -> IO(Unit), +settings: Pure.Limits, +inbox: Chan(Admission.Command), step: Pure.StreamServing<S>
) -> IO(Unit):
  Pure.Limits{max, cap, hm, bm, im, wm} = settings
  match step:
    case Pure.StreamDone{}:
      IO.pure(Unit, Unit{})
    case Pure.StreamCheck{held, connection, state}:
      Pure.Serving{(socket, turn), phase} = connection
      serve.stream.talk(~S, ~start, ~piece, ~finish, ~abort, ~observe, settings, inbox,
        Pure.serve.stream.ready(~S, held, socket, phase, state, Pure.admission.ready(turn)))
    case Pure.StreamReady{+held, +ready, connection, state}:
      do IO<Unit>:
        admitted : Bool <- admission.stream.take(Bool.not(held) && ready, inbox)
        serve.stream.talk(~S, ~start, ~piece, ~finish, ~abort, ~observe, settings, inbox,
          Pure.StreamChecked{held || ready, admitted, connection, state})
    case Pure.StreamChecked{+held, admitted, connection, m}:
      match admitted:
        case False{}:
          Pure.Serving{(socket, turn), phase} = connection
          do IO<Unit>:
            serve.stream.abort(~S, ~abort, Pure.StreamFailed{503}, m)
            admission.reject(Completion.Observed{status => outcome => observe(status, outcome)}, socket, Pure.admission.turn.head(turn), wm)
        case True{}:
          Pure.Serving{(s, t), phase} = connection
          match t:
            case Pure.TurnClose{}:
              do IO<Unit>:
                Socket.close(s)
                serve.stream.abort(~S, ~abort, Pure.StreamClosed{}, m)
                admission.give.held(held, inbox)
            case Pure.TurnInputFailed{operation, code, message}:
              do IO<Unit>:
                Socket.close(s)
                serve.stream.abort(~S, ~abort, Pure.StreamInputFailed{operation, code, message}, m)
                admission.give.held(held, inbox)
            case Pure.TurnFail{+status}:
              do IO<Unit>:
                serve.stream.abort(~S, ~abort, Pure.StreamFailed{status}, m)
                reply_fail(Completion.Observed{status => outcome => observe(status, outcome)}, s, status, wm)
                admission.give.held(held, inbox)
            case Pure.TurnReq{req, rest, v11}:
              Pure.Req{+method, path, +headers, body} = req
              do IO<Unit>:
                next : S & Bool <- serve.stream.feed(~S, ~start, ~piece,
                  Pure.Req{method, path, headers, Bytes.new(0)}, m, [body])
                after : Maybe<&1, Socket & Pure.Turn> <- serve.stream.respond(~S, ~finish, ~observe, settings, s, rest, headers, v11, method, next)
                Admission.give(inbox, 1)
                serve.stream.talk(~S, ~start, ~piece, ~finish, ~abort, ~observe, settings, inbox,
                  Pure.serve.stream.after(~S, after))
            case Pure.TurnMore{sv, cont}:
              match sv:
                case Pure.SvHead{buf}:
                  do IO<Unit>:
                    received : (Socket & Pure.Turn) & Pure.Phase <- talk.recv(inbox, held, settings, s, Pure.SvHead{buf}, cont, phase)
                    serve.stream.talk(~S, ~start, ~piece, ~finish, ~abort, ~observe, settings, inbox,
                      Pure.StreamCheck{held, Pure.talk.state(received), m})
                case Pure.SvLen{req, +v11, +left, parts}:
                  Pure.Req{+method, +path, +headers, body} = req
                  do IO<Unit>:
                    now : Time.Duration <- clock.mono()
                    reading : Pure.Phase = Pure.phase.body(phase, settings, now)
                    next : S & Bool <- serve.stream.feed(~S, ~start, ~piece,
                      Pure.Req{method, path, headers, body}, m, List.reverse(&1, Bytes.Bytes, parts))
                    received : (Socket & Pure.Turn) & Pure.Phase <- talk.recv(inbox, held, settings, s,
                      Pure.SvLen{Pure.Req{method, path, headers, Bytes.new(0)}, v11, left, Nil{}}, cont, Some{reading})
                    serve.stream.talk(~S, ~start, ~piece, ~finish, ~abort, ~observe, settings, inbox,
                      Pure.StreamCheck{held, Pure.talk.state(received), Some{next}})
                case Pure.SvChunk{req, +v11, +n, st, parts}:
                  Pure.Req{+method, +path, +headers, body} = req
                  do IO<Unit>:
                    now : Time.Duration <- clock.mono()
                    reading : Pure.Phase = Pure.phase.body(phase, settings, now)
                    next : S & Bool <- serve.stream.feed(~S, ~start, ~piece,
                      Pure.Req{method, path, headers, body}, m, List.reverse(&1, Bytes.Bytes, parts))
                    received : (Socket & Pure.Turn) & Pure.Phase <- talk.recv(inbox, held, settings, s,
                      Pure.SvChunk{Pure.Req{method, path, headers, Bytes.new(0)}, v11, n, st, Nil{}}, cont, Some{reading})
                    serve.stream.talk(~S, ~start, ~piece, ~finish, ~abort, ~observe, settings, inbox,
                      Pure.StreamCheck{held, Pure.talk.state(received), Some{next}})


def server.stream.run(
  ~S: Type, ~start: Pure.Req -> IO(S), ~piece: S -> Bytes.Bytes -> IO(S & Bool),
  ~finish: S -> IO(Reply), ~abort: S -> Pure.StreamAbort -> IO(Unit), ~observe: U32 -> Completion.Outcome -> IO(Unit), server: Server<Unit>
) -> IO(Pure.ServerExit):
  server.run.loop(~Unit,
    ~(context => settings => inbox => socket =>
      serve.stream.talk(~S, ~start, ~piece, ~finish, ~abort, ~observe, settings, inbox,
        Pure.StreamCheck{False{}, Pure.Serving{(socket, Pure.TurnMore{Pure.sv.none(), False{}}), None{}}, None{}})),
    ServerListening{server})

def serve.stream.started(
  ~S: Type, ~start: Pure.Req -> IO(S), ~piece: S -> Bytes.Bytes -> IO(S & Bool), ~finish: S -> IO(Reply), ~abort: S -> Pure.StreamAbort -> IO(Unit), ~observe: U32 -> Completion.Outcome -> IO(Unit),
  result: Unit & Result<&2, &1, Pure.StartupError, Server<Unit>>
) -> IO(Result<&2, &2, Pure.StartupError, Unit>):
  (owner, got) = result
  match got:
    case Fail{error}:
      IO.pure(Result<&2, &2, Pure.StartupError, Unit>, Fail{error})
    case Done{server}:
      do IO<Result<&2, &2, Pure.StartupError, Unit>>:
        exited : Pure.ServerExit <- server.stream.run(~S, ~start, ~piece, ~finish, ~abort, ~observe, server)
        server.exited(exited)
        return Done{Unit{}}

def serve.stream.config(
  ~S: Type, ~start: Pure.Req -> IO(S), ~piece: S -> Bytes.Bytes -> IO(S & Bool), ~finish: S -> IO(Reply), ~abort: S -> Pure.StreamAbort -> IO(Unit), ~observe: U32 -> Completion.Outcome -> IO(Unit),
  config: Pure.ServerConfig
) -> IO(Result<&2, &2, Pure.StartupError, Unit>):
  do IO<Result<&2, &2, Pure.StartupError, Unit>>:
    started : Unit & Result<&2, &1, Pure.StartupError, Server<Unit>> <- server.start(~Unit, ~Unit, Unit{}, Unit{}, config)
    serve.stream.started(~S, ~start, ~piece, ~finish, ~abort, ~observe, started)

type Writer is Type:
  Writer{s: Maybe<&1, Socket>, mode: Pure.WriterMode, until: Time.Duration, outcome: Completion.Outcome}

type WriteHead<-S: Type> is Type:
  WriteHead{status: U32, headers: Map<&2, List<&2, String>>, length: Maybe<&2, U32>, state: S, receipt: Completion.Receipt}

def writer.sent(+mode: Pure.WriterMode, +until: Time.Duration, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Writer):
  (s, r) = m
  match r:
    case Fail{(code, message)}:
      do IO<Writer>:
        Socket.close(s)
        return Writer{None{}, mode, until, Completion.WriteFailed{code, message}}
    case Done{u}:
      IO.pure(Writer, Writer{Some{s}, mode, until, Completion.HostAccepted{}})

def writer.raw(w: Writer, b: Bytes.Bytes) -> IO(Writer):
  Writer{socket, +mode, +until, outcome} = w
  match socket:
    case None{}:
      IO.pure(Writer, Writer{None{}, mode, until, outcome})
    case Some{s}:
      do IO<Writer>:
        sent : Socket & Result<&1, &1, U32 & String, Unit> <- bounded.send(s, b, until)
        writer.sent(mode, until, sent)

def writer.chunk(s: Socket, b: Bytes.Bytes, +len: U32, until: Time.Duration) -> IO(Writer):
  do IO<Writer>:
    head : Writer <- writer.raw(Writer{Some{s}, Pure.WriteChunk{}, until, Completion.HostAccepted{}}, Bytes.from_string(Pure.hex(len) ++ "\r\n"))
    data : Writer <- writer.raw(head, b)
    writer.raw(data, Bytes.from_string("\r\n"))

def writer.known(ok: Bool, s: Socket, +left: U32, len: U32, b: Bytes.Bytes, +until: Time.Duration) -> IO(Writer):
  match ok:
    case False{}:
      do IO<Writer>:
        Socket.close(s)
        return Writer{None{}, Pure.WriteKnown{left}, until, Completion.IncompleteResponse{}}
    case True{}:
      writer.raw(Writer{Some{s}, Pure.WriteKnown{(left - len : U32)}, until, Completion.HostAccepted{}}, b)

def writer.chunk.go(empty: Bool, s: Socket, b: Bytes.Bytes, len: U32, until: Time.Duration) -> IO(Writer):
  match empty:
    case True{}:
      IO.pure(Writer, Writer{Some{s}, Pure.WriteChunk{}, until, Completion.HostAccepted{}})
    case False{}:
      writer.chunk(s, b, len, until)

def writer.write.mode(s: Socket, mode: Pure.WriterMode, b: Bytes.Bytes, until: Time.Duration) -> IO(Writer):
  match mode:
    case Pure.WriteNone{}:
      IO.pure(Writer, Writer{Some{s}, Pure.WriteNone{}, until, Completion.HostAccepted{}})
    case Pure.WriteKnown{+left}:
      Bytes.Bytes{+len, buf} = b
      writer.known(U32.is_le(len, left), s, left, len, Bytes.Bytes{len, buf}, until)
    case Pure.WriteChunk{}:
      Bytes.Bytes{+len, buf} = b
      writer.chunk.go(U32.is_zero(len), s, Bytes.Bytes{len, buf}, len, until)

def writer.write(w: Writer, b: Bytes.Bytes) -> IO(Writer):
  Writer{socket, mode, until, outcome} = w
  match socket:
    case None{}:
      IO.pure(Writer, Writer{None{}, mode, until, outcome})
    case Some{s}:
      writer.write.mode(s, mode, b, until)

def writer.result(w: Writer) -> Maybe<&1, Socket> & Completion.Outcome:
  Writer{socket, mode, until, outcome} = w
  (socket, outcome)

def writer.finish.known(complete: Bool, s: Socket) -> IO(Maybe<&1, Socket> & Completion.Outcome):
  match complete:
    case True{}:
      IO.pure(Maybe<&1, Socket> & Completion.Outcome, (Some{s}, Completion.HostAccepted{}))
    case False{}:
      do IO<Maybe<&1, Socket> & Completion.Outcome>:
        Socket.close(s)
        return (None{}, Completion.IncompleteResponse{})

def writer.finish.mode(s: Socket, mode: Pure.WriterMode, until: Time.Duration) -> IO(Maybe<&1, Socket> & Completion.Outcome):
  match mode:
    case Pure.WriteNone{}:
      IO.pure(Maybe<&1, Socket> & Completion.Outcome, (Some{s}, Completion.HostAccepted{}))
    case Pure.WriteKnown{left}:
      writer.finish.known(U32.is_zero(left), s)
    case Pure.WriteChunk{}:
      do IO<Maybe<&1, Socket> & Completion.Outcome>:
        end : Writer <- writer.raw(Writer{Some{s}, Pure.WriteChunk{}, until, Completion.HostAccepted{}}, Bytes.from_string("0\r\n\r\n"))
        return writer.result(end)

def writer.finish(w: Writer) -> IO(Maybe<&1, Socket> & Completion.Outcome):
  Writer{socket, mode, until, outcome} = w
  match socket:
    case None{}:
      IO.pure(Maybe<&1, Socket> & Completion.Outcome, (None{}, outcome))
    case Some{s}:
      writer.finish.mode(s, mode, until)

def serve.write.completed(observer: Completion.Receipt, receipt: Completion.Receipt, +status: U32,
  settings: Pure.Limits, keep: Bool, rest: Bytes.Bytes, result: Maybe<&1, Socket> & Completion.Outcome) -> IO(Maybe<&1, Socket & Pure.Turn>):
  (socket, outcome) = result
  +observed = {outcome : Completion.Outcome}
  do IO<Maybe<&1, Socket & Pure.Turn>>:
    Completion.report(observer, status, observed)
    Completion.report(receipt, status, observed)
    return Pure.serve.write.after(settings, keep, rest, socket)

def serve.write.returned(observer: Completion.Receipt, status: U32, settings: Pure.Limits, keep: Bool,
  rest: Bytes.Bytes, result: Writer & Completion.Receipt) -> IO(Maybe<&1, Socket & Pure.Turn>):
  (writer, receipt) = result
  do IO<Maybe<&1, Socket & Pure.Turn>>:
    done : Maybe<&1, Socket> & Completion.Outcome <- writer.finish(writer)
    serve.write.completed(observer, receipt, status, settings, keep, rest, done)

def serve.write.finish(observer: Completion.Receipt, receipt: Completion.Receipt, status: U32,
  settings: Pure.Limits, keep: Bool, rest: Bytes.Bytes, w: Writer) -> IO(Maybe<&1, Socket & Pure.Turn>):
  serve.write.returned(observer, status, settings, keep, rest, (w, receipt))

def serve.write.body(~S: Type, ~write: S -> Writer -> Completion.Receipt -> IO(Writer & Completion.Receipt), ~dispose: S -> IO(Unit),
  observer: Completion.Receipt, receipt: Completion.Receipt, status: U32, settings: Pure.Limits,
  keep: Bool, rest: Bytes.Bytes, state: S, s: Socket, mode: Pure.WriterMode, suppress: Bool, until: Time.Duration) -> IO(Maybe<&1, Socket & Pure.Turn>):
  match suppress:
    case True{}:
      do IO<Maybe<&1, Socket & Pure.Turn>>:
        dispose(state)
        serve.write.finish(observer, receipt, status, settings, keep, rest, Writer{Some{s}, Pure.WriteNone{}, until, Completion.HostAccepted{}})
    case False{}:
      do IO<Maybe<&1, Socket & Pure.Turn>>:
        result : Writer & Completion.Receipt <- write(state, Writer{Some{s}, mode, until, Completion.HostAccepted{}}, receipt)
        serve.write.returned(observer, status, settings, keep, rest, result)

def serve.write.open(~S: Type, ~write: S -> Writer -> Completion.Receipt -> IO(Writer & Completion.Receipt), ~dispose: S -> IO(Unit),
  observer: Completion.Receipt, receipt: Completion.Receipt, +status: U32, settings: Pure.Limits,
  keep: Bool, rest: Bytes.Bytes, state: S, mode: Pure.WriterMode, suppress: Bool, until: Time.Duration,
  m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Maybe<&1, Socket & Pure.Turn>):
  (s, r) = m
  match r:
    case Fail{(code, message)}:
      +failure = {Completion.WriteFailed{code, message} : Completion.Outcome}
      do IO<Maybe<&1, Socket & Pure.Turn>>:
        Socket.close(s)
        dispose(state)
        Completion.report(observer, status, failure)
        Completion.report(receipt, status, failure)
        return None{}
    case Done{u}:
      serve.write.body(~S, ~write, ~dispose, observer, receipt, status, settings, keep, rest, state, s, mode, suppress, until)

def serve.write.send.plan(
  ~S: Type, ~write: S -> Writer -> Completion.Receipt -> IO(Writer & Completion.Receipt), ~dispose: S -> IO(Unit),
  observer: Completion.Receipt, receipt: Completion.Receipt, +settings: Pure.Limits, s: Socket, rest: Bytes.Bytes,
  +keep: Bool, +head: Bool, +status: U32, state: S, plan: Pure.WriterMode & Map<&2, List<&2, String>>
) -> IO(Maybe<&1, Socket & Pure.Turn>):
  Pure.Limits{max, cap, hm, bm, im, wm} = settings
  (mode, headers) = plan
  sent_headers = Pure.writer.connection(keep, headers)
  do IO<Maybe<&1, Socket & Pure.Turn>>:
    now : Time.Duration <- clock.mono()
    +until : Time.Duration = Time.Duration.add(now, Time.Duration.of_ms(wm))
    sent : Socket & Result<&1, &1, U32 & String, Unit> <-
      bounded.send(s, Bytes.from_string(Pure.response(status, sent_headers, "")), until)
    serve.write.open(~S, ~write, ~dispose, observer, receipt, status, settings, keep, rest, state, mode,
      Pure.frame.nobody(status, head), until, sent)

def serve.write.send(
  ~S: Type, ~write: S -> Writer -> Completion.Receipt -> IO(Writer & Completion.Receipt), ~dispose: S -> IO(Unit), observer: Completion.Receipt, settings: Pure.Limits, s: Socket, rest: Bytes.Bytes,
  +headers: Map<&2, List<&2, String>>, v11: Bool, +head: Bool, out: WriteHead<S>
) -> IO(Maybe<&1, Socket & Pure.Turn>):
  WriteHead{+status, rh, length, state, receipt} = out
  +normalized = Pure.writer.headers(Map.to_list(&2, List<&2, String>, rh), Pure.empty())
  +keep = Pure.serve.keep(headers, v11, status, normalized)
  serve.write.send.plan(~S, ~write, ~dispose, observer, receipt, settings, s, rest, keep, head, status, state,
    Pure.writer.plan(Pure.frame.nobody(status, False{}), normalized, length))

def admission.write(
  ~S: Type, ~start: Pure.Req -> IO(WriteHead<S>), ~write: S -> Writer -> Completion.Receipt -> IO(Writer & Completion.Receipt), ~dispose: S -> IO(Unit), ~observe: U32 -> Completion.Outcome -> IO(Unit),
  admitted: Bool, +inbox: Chan(Admission.Command), +settings: Pure.Limits,
  s: Socket, req: Pure.Req, rest: Bytes.Bytes, v11: Bool
) -> IO(Maybe<&1, Socket & Pure.Turn>):
  match admitted:
    case False{}:
      Pure.Limits{max, cap, hm, bm, im, wm} = settings
      do IO<Maybe<&1, Socket & Pure.Turn>>:
        admission.reject(Completion.Observed{status => outcome => observe(status, outcome)}, s, Pure.admission.head(req), wm)
        return None{}
    case True{}:
      Pure.Req{+method, path, +headers, body} = req
      do IO<Maybe<&1, Socket & Pure.Turn>>:
        out : WriteHead<S> <- start(Pure.Req{method, path, headers, body})
        after : Maybe<&1, Socket & Pure.Turn> <- serve.write.send(~S, ~write, ~dispose, Completion.Observed{status => outcome => observe(status, outcome)}, settings, s, rest, headers, v11, String.eq(method, "HEAD"), out)
        Admission.give(inbox, 1)
        return after

@unsafe
def serve.write.talk(
  ~S: Type, ~start: Pure.Req -> IO(WriteHead<S>), ~write: S -> Writer -> Completion.Receipt -> IO(Writer & Completion.Receipt), ~dispose: S -> IO(Unit), ~observe: U32 -> Completion.Outcome -> IO(Unit),
  +settings: Pure.Limits, +inbox: Chan(Admission.Command), st: Maybe<&1, Pure.Serving>
) -> IO(Unit):
  Pure.Limits{max, cap, hm, bm, im, wm} = settings
  match st:
    case None{}:
      IO.pure(Unit, Unit{})
    case Some{Pure.Serving{(s, t), phase}}:
      match t:
        case Pure.TurnMore{sv, cont}:
          do IO<Unit>:
            received : (Socket & Pure.Turn) & Pure.Phase <- talk.recv(inbox, False{}, settings, s, sv, cont, phase)
            serve.write.talk(~S, ~start, ~write, ~dispose, ~observe, settings, inbox, Some{Pure.talk.state(received)})
        case Pure.TurnReq{req, rest, v11}:
          do IO<Unit>:
            admitted : Bool <- Admission.take(inbox, 1)
            after : Maybe<&1, Socket & Pure.Turn> <- admission.write(~S, ~start, ~write, ~dispose, ~observe, admitted, inbox, settings, s, req, rest, v11)
            serve.write.talk(~S, ~start, ~write, ~dispose, ~observe, settings, inbox, Pure.serve.write.state(after))
        case Pure.TurnFail{status}:
          reply_fail(Completion.Observed{status => outcome => observe(status, outcome)}, s, status, wm)
        case Pure.TurnClose{}:
          Socket.close(s)
        case Pure.TurnInputFailed{operation, code, message}:
          Socket.close(s)

def server.write.run(
  ~S: Type, ~start: Pure.Req -> IO(WriteHead<S>),
  ~write: S -> Writer -> Completion.Receipt -> IO(Writer & Completion.Receipt),
  ~dispose: S -> IO(Unit),
  ~observe: U32 -> Completion.Outcome -> IO(Unit), server: Server<Unit>
) -> IO(Pure.ServerExit):
  server.run.loop(~Unit,
    ~(context => settings => inbox => socket =>
      serve.write.talk(~S, ~start, ~write, ~dispose, ~observe, settings, inbox,
        Some{Pure.Serving{(socket, Pure.TurnMore{Pure.sv.none(), False{}}), None{}}})),
    ServerListening{server})

def serve.write.started(
  ~S: Type, ~start: Pure.Req -> IO(WriteHead<S>), ~write: S -> Writer -> Completion.Receipt -> IO(Writer & Completion.Receipt), ~dispose: S -> IO(Unit), ~observe: U32 -> Completion.Outcome -> IO(Unit),
  result: Unit & Result<&2, &1, Pure.StartupError, Server<Unit>>
) -> IO(Result<&2, &2, Pure.StartupError, Unit>):
  (owner, got) = result
  match got:
    case Fail{error}:
      IO.pure(Result<&2, &2, Pure.StartupError, Unit>, Fail{error})
    case Done{server}:
      do IO<Result<&2, &2, Pure.StartupError, Unit>>:
        exited : Pure.ServerExit <- server.write.run(~S, ~start, ~write, ~dispose, ~observe, server)
        server.exited(exited)
        return Done{Unit{}}

def serve.write.config(
  ~S: Type, ~start: Pure.Req -> IO(WriteHead<S>), ~write: S -> Writer -> Completion.Receipt -> IO(Writer & Completion.Receipt), ~dispose: S -> IO(Unit), ~observe: U32 -> Completion.Outcome -> IO(Unit), config: Pure.ServerConfig
) -> IO(Result<&2, &2, Pure.StartupError, Unit>):
  do IO<Result<&2, &2, Pure.StartupError, Unit>>:
    started : Unit & Result<&2, &1, Pure.StartupError, Server<Unit>> <- server.start(~Unit, ~Unit, Unit{}, Unit{}, config)
    serve.write.started(~S, ~start, ~write, ~dispose, ~observe, started)

def serve.started(~h: Pure.Req -> IO(Reply), ~observe: U32 -> Completion.Outcome -> IO(Unit),
  started: Unit & Result<&2, &1, Pure.StartupError, Server<Unit>>) -> IO(Unit):
  (owner, result) = started
  match result:
    case Fail{error}: server.start.failed(error)
    case Done{server}:
      do IO<Unit>:
        exited : Pure.ServerExit <- server.run(~Unit, ~(context => req => h(req)),
          ~(context => status => outcome => observe(status, outcome)), server)
        server.exited(exited)

def serve.on.with(~h: Pure.Req -> IO(Reply), ~observe: U32 -> Completion.Outcome -> IO(Unit), host: String, +port: U32, +max: Nat) -> IO(Unit):
  do IO<Unit>:
    limits.validate(max)
    started : Unit & Result<&2, &1, Pure.StartupError, Server<Unit>> <-
      server.start(~Unit, ~Unit, Unit{}, Unit{}, Pure.server.config.with(host, port, max))
    serve.started(~h, ~observe, started)

def serve.on(~h: Pure.Req -> IO(Reply), ~observe: U32 -> Completion.Outcome -> IO(Unit), host: String, +port: U32) -> IO(Unit):
  serve.on.with(~h, ~observe, host, port, Pure.serve.max())

def serve.with(~h: Pure.Req -> IO(Reply), ~observe: U32 -> Completion.Outcome -> IO(Unit), +port: U32, +max: Nat) -> IO(Unit):
  serve.on.with(~h, ~observe, "0.0.0.0", port, max)

def serve(~h: Pure.Req -> IO(Reply), ~observe: U32 -> Completion.Outcome -> IO(Unit), +port: U32) -> IO(Unit):
  serve.with(~h, ~observe, port, Pure.serve.max())

def serve.stream.on.with(
  ~S: Type, ~start: Pure.Req -> IO(S), ~piece: S -> Bytes.Bytes -> IO(S & Bool),
  ~finish: S -> IO(Reply), ~abort: S -> Pure.StreamAbort -> IO(Unit), ~observe: U32 -> Completion.Outcome -> IO(Unit), host: String, +port: U32, +max: Nat
) -> IO(Unit):
  do IO<Unit>:
    limits.validate(max)
    result : Result<&2, &2, Pure.StartupError, Unit> <-
      serve.stream.config(~S, ~start, ~piece, ~finish, ~abort, ~observe, Pure.server.config.with(host, port, max))
    serve.config.result(result)

def serve.stream.with(
  ~S: Type, ~start: Pure.Req -> IO(S), ~piece: S -> Bytes.Bytes -> IO(S & Bool),
  ~finish: S -> IO(Reply), ~abort: S -> Pure.StreamAbort -> IO(Unit), ~observe: U32 -> Completion.Outcome -> IO(Unit), +port: U32, +max: Nat
) -> IO(Unit):
  serve.stream.on.with(~S, ~start, ~piece, ~finish, ~abort, ~observe, "0.0.0.0", port, max)

def serve.write.on.with(
  ~S: Type, ~start: Pure.Req -> IO(WriteHead<S>), ~write: S -> Writer -> Completion.Receipt -> IO(Writer & Completion.Receipt), ~dispose: S -> IO(Unit), ~observe: U32 -> Completion.Outcome -> IO(Unit),
  host: String, +port: U32, +max: Nat
) -> IO(Unit):
  do IO<Unit>:
    limits.validate(max)
    result : Result<&2, &2, Pure.StartupError, Unit> <-
      serve.write.config(~S, ~start, ~write, ~dispose, ~observe, Pure.server.config.with(host, port, max))
    serve.config.result(result)

def serve.write.with(
  ~S: Type, ~start: Pure.Req -> IO(WriteHead<S>), ~write: S -> Writer -> Completion.Receipt -> IO(Writer & Completion.Receipt), ~dispose: S -> IO(Unit), ~observe: U32 -> Completion.Outcome -> IO(Unit),
  +port: U32, +max: Nat
) -> IO(Unit):
  serve.write.on.with(~S, ~start, ~write, ~dispose, ~observe, "0.0.0.0", port, max)
