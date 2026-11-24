# DNS host lookup. Source: https://github.com/paymog/bend-kit/tree/main/dns
import Base
import bend-kit-wire@0.4.8.1/wire.bend as Wire
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import ./pure.bend as Pure

# Resolve
# -------

def none() -> IO(Maybe<&2, String>):
  IO.pure(Maybe<&2, String>, None{})

# One attempt's outcome: try again, or this answer (None: no address).
type Try is Data:
  Again{}
  Got{ip: Maybe<&2, String>}

def try.pure(s: Socket, t: Try) -> IO(Socket & Try):
  IO.pure(Socket & Try, (s, t))

# A datagram from anyone but the nameserver's port 53 is ignored (retried).
def try.from(s: Socket, +ns: String, id: U32, hpd: String & U32 & (U32 & Array<U32>)) -> IO(Socket & Try):
  (h, +p, d) = hpd
  (n, w) = d
  try.pure(s, Bool.pick(Try, Bool.and(String.eq(h, ns), U32.is_eq(p, 53)), Got{Pure.answer(id, Bytes.Bytes{n, w})}, Again{}))

def try.back(ns: String, id: U32, m: Socket & Result<&1, &1, U32 & String, String & U32 & (U32 & Array<U32>)>) -> IO(Socket & Try):
  (s, r) = m
  match r:
    case Fail{e}:
      try.pure(s, Again{})
    case Done{hpd}:
      try.from(s, ns, id, hpd)

# §4.2.1 and resolv.conf defaults: 5 s per attempt.
def try.sent(ns: String, id: U32, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Socket & Try):
  (s, r) = m
  match r:
    case Fail{e}:
      try.pure(s, Again{})
    case Done{u}:
      do IO<Socket & Try>:
        back : Socket & Result<&1, &1, U32 & String, String & U32 & (U32 & Array<U32>)> <- Wire.recv_from.words(s, 512, 5000)
        try.back(ns, id, back)

# Bytes cannot be copied, so each attempt builds its own query. A name that query rejects ends the tries.
def try.send(s: Socket, +ns: String, id: U32, q: Maybe<&1, Bytes.Bytes>) -> IO(Socket & Try):
  match q:
    case None{}:
      try.pure(s, Got{None{}})
    case Some{Bytes.Bytes{n, w}}:
      do IO<Socket & Try>:
        sent : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send_to.words(s, ns, 53, n, w)
        try.sent(ns, id, sent)

def try.once(s: Socket, +ns: String, +id: U32, name: String) -> IO(Socket & Try):
  try.send(s, ns, id, Pure.query(id, name))

def try.close(s: Socket, r: Maybe<&2, String>) -> IO(Maybe<&2, String>):
  do IO<Maybe<&2, String>>:
    Socket.close(s)
    return r

def tries.end(st: Socket & Try) -> IO(Maybe<&2, String>):
  (s, t) = st
  match t:
    case Got{ip}:
      try.close(s, ip)
    case Again{}:
      try.close(s, None{})

# fuel: attempts left (resolv.conf's default is 2).
def tries(fuel: Nat, +ns: String, +id: U32, +name: String, st: Socket & Try) -> IO(Maybe<&2, String>):
  match fuel:
    case 0n:
      tries.end(st)
    case 1n+f:
      (s, t) = st
      match t:
        case Got{ip}:
          try.close(s, ip)
        case Again{}:
          do IO<Maybe<&2, String>>:
            next : Socket & Try <- try.once(s, ns, id, name)
            tries(f, ns, id, name, next)

def resolve.sock(ns: String, id: U32, name: String, r: Result<&1, &1, U32 & String, Socket>) -> IO(Maybe<&2, String>):
  match r:
    case Fail{e}:
      none()
    case Done{s}:
      tries(2n, ns, id, name, (s, Again{}))

# §7.3: a random id makes forged answers harder to land.
def resolve.id(name: String, ns: String, r: Result<&1, &1, U32 & String, U32>) -> IO(Maybe<&2, String>):
  match r:
    case Fail{e}:
      none()
    case Done{x}:
      do IO<Maybe<&2, String>>:
        u : Result<&1, &1, U32 & String, Socket> <- UDP.bind("0.0.0.0", 0)
        resolve.sock(ns, U32.and(x, 65535), name, u)

def resolve.ns(name: String, ns: Maybe<&2, String>) -> IO(Maybe<&2, String>):
  match ns:
    case None{}:
      none()
    case Some{n}:
      do IO<Maybe<&2, String>>:
        r : Result<&1, &1, U32 & String, U32> <- IO.random_u32()
        resolve.id(name, n, r)

# Ask one nameserver. Tests use this; resolve reads /etc/resolv.conf.
def resolve.at(+host: String, ns: String) -> IO(Maybe<&2, String>):
  resolve.ns(host, Some{ns})

def conf.text(r: Result<&1, &1, U32 & String, String>) -> String:
  match r:
    case Fail{e}:
      ""
    case Done{s}:
      s

# ponytail: 3 nameservers; a longer resolv.conf ignores the rest
def resolve.n3(+name: String, xs: List<&2, String>) -> IO(Maybe<&2, String>):
  match xs:
    case Nil{}:
      none()
    case Con{+ns, t}:
      resolve.at(name, ns)

def resolve.n2b(+name: String, rest: List<&2, String>, ip: Maybe<&2, String>) -> IO(Maybe<&2, String>):
  match ip:
    case Some{s}:
      IO.pure(Maybe<&2, String>, Some{s})
    case None{}:
      resolve.n3(name, rest)

def resolve.n2(+name: String, xs: List<&2, String>) -> IO(Maybe<&2, String>):
  match xs:
    case Nil{}:
      none()
    case Con{+ns, t}:
      do IO<Maybe<&2, String>>:
        ip : Maybe<&2, String> <- resolve.at(name, ns)
        resolve.n2b(name, t, ip)

def resolve.n1b(+name: String, rest: List<&2, String>, ip: Maybe<&2, String>) -> IO(Maybe<&2, String>):
  match ip:
    case Some{s}:
      IO.pure(Maybe<&2, String>, Some{s})
    case None{}:
      resolve.n2(name, rest)

def resolve.list(+name: String, xs: List<&2, String>) -> IO(Maybe<&2, String>):
  match xs:
    case Nil{}:
      none()
    case Con{+ns, t}:
      do IO<Maybe<&2, String>>:
        ip : Maybe<&2, String> <- resolve.at(name, ns)
        resolve.n1b(name, t, ip)

def resolve.read(name: String, m: File & Result<&1, &1, U32 & String, String>) -> IO(Maybe<&2, String>):
  (f, r) = m
  do IO<Maybe<&2, String>>:
    File.close(f)
    resolve.list(name, Pure.nameservers(conf.text(r)))

def resolve.conf(name: String, r: Result<&1, &1, U32 & String, File>) -> IO(Maybe<&2, String>):
  match r:
    case Fail{e}:
      none()
    case Done{f}:
      do IO<Maybe<&2, String>>:
        m : File & Result<&1, &1, U32 & String, String> <- File.read(f, 65536)
        resolve.read(name, m)

def resolve.dns(name: String) -> IO(Maybe<&2, String>):
  do IO<Maybe<&2, String>>:
    f : Result<&1, &1, U32 & String, File> <- File.open("/etc/resolv.conf", "r")
    resolve.conf(name, f)

# OS resolver: every address, NUL-separated in getaddrinfo order.
def lookup.all(host: String) -> IO(Result<&1, &1, U32 & String, String>):
  import "./effs/dns.c"
  import "./effs/dns.js"

def resolve.all.got(r: Result<&1, &1, U32 & String, String>) -> IO(List<&2, String>):
  match r:
    case Fail{e}:
      IO.pure(List<&2, String>, Nil{})
    case Done{s}:
      IO.pure(List<&2, String>, Pure.lookup.split(s))

def resolve.all.os(+name: String) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    r : Result<&1, &1, U32 & String, String> <- lookup.all(name)
    resolve.all.got(r)

def resolve.all.dns.one(m: Maybe<&2, String>) -> IO(List<&2, String>):
  match m:
    case Some{ip}:
      IO.pure(List<&2, String>, Pure.list.one(ip))
    case None{}:
      IO.pure(List<&2, String>, Nil{})

# ponytail: UDP path still asks for A records only
def resolve.all.dns(+name: String) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    m : Maybe<&2, String> <- resolve.dns(name)
    resolve.all.dns.one(m)

def resolve.all.from(+name: String, +xs: List<&2, String>) -> IO(List<&2, String>):
  match xs:
    case Nil{}:
      resolve.all.dns(name)
    case Con{+_, +t}:
      IO.pure(List<&2, String>, xs)

def resolve.all.text(+name: String, r: Result<&1, &1, U32 & String, String>) -> IO(List<&2, String>):
  match r:
    case Fail{e}:
      resolve.all.dns(name)
    case Done{s}:
      resolve.all.from(name, Pure.hosts.all(name, s))

def resolve.all.opened(+name: String, m: File & Result<&1, &1, U32 & String, String>) -> IO(List<&2, String>):
  (f, r) = m
  do IO<List<&2, String>>:
    File.close(f)
    resolve.all.text(name, r)

def resolve.all.hosts(+name: String, r: Result<&1, &1, U32 & String, File>) -> IO(List<&2, String>):
  match r:
    case Fail{e}:
      resolve.all.dns(name)
    case Done{f}:
      do IO<List<&2, String>>:
        m : File & Result<&1, &1, U32 & String, String> <- File.read(f, 65536)
        resolve.all.opened(name, m)

def resolve.all.pick(+host: String, +xs: List<&2, String>) -> IO(List<&2, String>):
  match xs:
    case Nil{}:
      resolve.all.os(String.to_lower(host))
    case Con{+_, +t}:
      IO.pure(List<&2, String>, xs)

def resolve.all(+host: String) -> IO(List<&2, String>):
  resolve.all.pick(host, Pure.resolve.literal.all(host))

def resolve.all.ask(+name: String) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    f : Result<&1, &1, U32 & String, File> <- File.open("/etc/hosts", "r")
    resolve.all.hosts(name, f)

def resolve.all.pure.pick(+host: String, +xs: List<&2, String>) -> IO(List<&2, String>):
  match xs:
    case Nil{}:
      resolve.all.ask(String.to_lower(host))
    case Con{+_, +t}:
      IO.pure(List<&2, String>, xs)

def resolve.all.pure(+host: String) -> IO(List<&2, String>):
  resolve.all.pure.pick(host, Pure.resolve.literal.all(host))

def resolve.pure(+host: String) -> IO(Maybe<&2, String>):
  do IO<Maybe<&2, String>>:
    xs : List<&2, String> <- resolve.all.pure(host)
    return Pure.list.first(xs)

# First address from resolve.all (getaddrinfo order when the OS resolves).
def resolve(+host: String) -> IO(Maybe<&2, String>):
  do IO<Maybe<&2, String>>:
    xs : List<&2, String> <- resolve.all(host)
    return Pure.list.first(xs)
