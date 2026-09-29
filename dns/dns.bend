# DNS codec and host lookup. Source: https://github.com/paymog/bend-kit/tree/main/dns
import Base
import bend-kit-wire@0.4.3.0/wire.bend as Wire
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

# query, answer, and resolve.pure are pure; PROOF.bend covers them, not effs/.
# resolve.all uses the OS resolver (IPv4 and IPv6); resolve keeps the first address.
#   import bend-kit-dns@0.5.0.0/dns.bend as Dns

# Query
# -----

def label.ok(+l: String) -> Bool:
  +n = String.length(l)
  Bool.and(Nat.is_lt(0n, n), Nat.is_le(n, 63n))

def label.ascii(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{c}, t}:
      Bool.and(U32.is_lt(c, 128), label.ascii(t))

def labels.ok(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+l, t}:
      Bool.and(Bool.and(label.ok(l), label.ascii(l)), labels.ok(t))

# QNAME's length without its final zero octet.
def labels.len(xs: List<&2, String>, +n: U32) -> U32:
  match xs:
    case Nil{}:
      n
    case Con{+l, t}:
      labels.len(t, (n + 1 + U32.from_nat(String.length(l)) : U32))

def label.put(s: String, b: Bytes.Bytes, +i: U32) -> Bytes.Bytes:
  match s:
    case SNil{}:
      b
    case SCon{Chr{c}, t}:
      label.put(t, Bytes.set(b, i, c), (i + 1 : U32))

# Each label as its length octet, then its octets. The zero octet that ends QNAME is already there.
def labels.put(xs: List<&2, String>, b: Bytes.Bytes, +i: U32) -> Bytes.Bytes:
  match xs:
    case Nil{}:
      b
    case Con{+l, t}:
      +n = U32.from_nat(String.length(l))
      labels.put(t, label.put(l, Bytes.set(b, i, n), (i + 1 : U32)), (i + 1 + n : U32))

def query.if(+id: U32, +xs: List<&2, String>, ok: Bool) -> Maybe<&1, Bytes.Bytes>:
  match ok:
    case False{}:
      None{}
    case True{}:
      # header: id, RD, QDCOUNT 1; question: QNAME, QTYPE A, QCLASS IN. Other fields stay zero.
      +n = (labels.len(xs, 0) + 17 : U32)
      Some{Bytes.set.u16be(Bytes.set.u16be(labels.put(xs, Bytes.set.u16be(Bytes.set.u16be(Bytes.set.u16be(Bytes.new(n), 0, id), 2, 256), 4, 1), 12), (n - 4 : U32), 1), (n - 2 : U32), 1)}

def query.labels(+id: U32, +xs: List<&2, String>) -> Maybe<&1, Bytes.Bytes>:
  query.if(id, xs, labels.ok(xs))

def strip_dot.if(+s: String, dot: Bool) -> String:
  match dot:
    case True{}:
      String.reverse(String.drop(String.reverse(s), 1n))
    case False{}:
      s

def strip_dot(+s: String) -> String:
  strip_dot.if(s, String.ends_with(s, "."))

# RFC 1035 §4.1: a standard query for the A record of name.
def query(id: U32, name: String) -> Maybe<&1, Bytes.Bytes>:
  query.labels(id, String.split(strip_dot(name), '.'))

# Answer
# ------

# One step through a name: go on at the next label, or stop with the offset past the name.
type Step is Data:
  Go{at: U32}
  Stop{end: Maybe<&2, U32>}

# §4.1.4: l, the octet at i, is 0 at the end, 192..255 for a two-octet pointer, 64..191 reserved.
def name.step.of(+i: U32, +l: U32) -> Step:
  Bool.pick(Step, U32.is_eq(l, 0), Stop{Some{(i + 1 : U32)}}, Bool.pick(Step, U32.is_le(192, l), Stop{Some{(i + 2 : U32)}}, Bool.pick(Step, U32.is_le(64, l), Stop{None{}}, Go{(i + 1 + l : U32)})))

def name.step(+i: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & Step:
  (b, m) = r
  match m:
    case None{}:
      (b, Stop{None{}})
    case Some{l}:
      (b, name.step.of(i, l))

def name.walk(fuel: Nat, r: Bytes.Bytes & Step) -> Bytes.Bytes & Maybe<&2, U32>:
  match fuel:
    case 0n:
      (b, s) = r
      (b, None{})
    case 1n+f:
      (b, s) = r
      match s:
        case Stop{end}:
          (b, end)
        case Go{+at}:
          name.walk(f, name.step(at, Bytes.get(b, at)))

# The offset past the name at i. §2.3.4: a name is at most 255 octets, so 128 steps are enough.
def name.skip(b: Bytes.Bytes, +i: U32) -> Bytes.Bytes & Maybe<&2, U32>:
  name.walk(128n, name.step(i, Bytes.get(b, i)))

type RR is Data:
  RRBad{}
  RRA{ip: String}
  RRSkip{at: U32}

def dotted(+ip: U32) -> String:
  U32.show(U32.shrn(ip, 24n)) ++ "." ++ U32.show(Bytes.b8(U32.shrn(ip, 16n))) ++ "." ++ U32.show(Bytes.b8(U32.shrn(ip, 8n))) ++ "." ++ U32.show(Bytes.b8(ip))

def rr.a(r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & RR:
  (b, m) = r
  match m:
    case None{}:
      (b, RRBad{})
    case Some{ip}:
      (b, RRA{dotted(ip)})

# RDATA at i holds len octets. A skipped record past the end fails at the next read.
def rr.data(a: Bool, b: Bytes.Bytes, +i: U32, +len: U32) -> Bytes.Bytes & RR:
  match a:
    case True{}:
      rr.a(Bytes.get.u32be(b, i))
    case False{}:
      (b, RRSkip{(i + len : U32)})

def rr.len(+o: U32, +ty: U32, +cl: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & RR:
  (b, m) = r
  match m:
    case None{}:
      (b, RRBad{})
    case Some{+len}:
      rr.data(Bool.and(Bool.and(U32.is_eq(ty, 1), U32.is_eq(cl, 1)), U32.is_eq(len, 4)), b, (o + 10 : U32), len)

def rr.cl(+o: U32, +ty: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & RR:
  (b, m) = r
  match m:
    case None{}:
      (b, RRBad{})
    case Some{cl}:
      rr.len(o, ty, cl, Bytes.get.u16be(b, (o + 8 : U32)))

def rr.ty(+o: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & RR:
  (b, m) = r
  match m:
    case None{}:
      (b, RRBad{})
    case Some{ty}:
      rr.cl(o, ty, Bytes.get.u16be(b, (o + 2 : U32)))

def rr.name(r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & RR:
  (b, m) = r
  match m:
    case None{}:
      (b, RRBad{})
    case Some{+o}:
      rr.ty(o, Bytes.get.u16be(b, o))

# §4.1.3: NAME, TYPE, CLASS, TTL, RDLENGTH, RDATA.
def rr(b: Bytes.Bytes, +i: U32) -> Bytes.Bytes & RR:
  rr.name(name.skip(b, i))

# fuel = records left. The first A record wins; CNAMEs before it are skipped.
def answers.scan(fuel: Nat, r: Bytes.Bytes & RR) -> Maybe<&2, String>:
  match fuel:
    case 0n:
      None{}
    case 1n+f:
      (b, x) = r
      match x:
        case RRBad{}:
          None{}
        case RRA{ip}:
          Some{ip}
        case RRSkip{+at}:
          answers.scan(f, rr(b, at))

# QTYPE and QCLASS follow the name.
def question.end(r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & Maybe<&2, U32>:
  (b, m) = r
  match m:
    case None{}:
      (b, None{})
    case Some{e}:
      (b, Some{(e + 4 : U32)})

def questions(fuel: Nat, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & Maybe<&2, U32>:
  match fuel:
    case 0n:
      (b, m) = r
      (b, m)
    case 1n+f:
      (b, m) = r
      match m:
        case None{}:
          (b, None{})
        case Some{+at}:
          questions(f, question.end(name.skip(b, at)))

def body.go(+an: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&2, String>:
  (b, m) = r
  match m:
    case None{}:
      None{}
    case Some{+at}:
      answers.scan(U32.to_nat(an), rr(b, at))

# The 12-octet header ends with NSCOUNT and ARCOUNT; the questions follow.
def body.an(+qd: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&2, String>:
  (b, m) = r
  match m:
    case None{}:
      None{}
    case Some{an}:
      body.go(an, questions(U32.to_nat(qd), (b, Some{12})))

def body.qd(r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&2, String>:
  (b, m) = r
  match m:
    case None{}:
      None{}
    case Some{qd}:
      body.an(qd, Bytes.get.u16be(b, 6))

# §4.1.1: QR set, opcode QUERY, not truncated, RCODE 0.
def flags.ok(+f: U32) -> Bool:
  Bool.and(Bool.and(U32.is_eq(U32.and(f, 32768), 32768), U32.is_eq(U32.and(f, 30720), 0)), Bool.and(U32.is_eq(U32.and(f, 512), 0), U32.is_eq(U32.and(f, 15), 0)))

def head.flags.if(ok: Bool, b: Bytes.Bytes) -> Maybe<&2, String>:
  match ok:
    case False{}:
      None{}
    case True{}:
      body.qd(Bytes.get.u16be(b, 4))

def head.flags(r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&2, String>:
  (b, m) = r
  match m:
    case None{}:
      None{}
    case Some{f}:
      head.flags.if(flags.ok(f), b)

def head.id.if(ok: Bool, b: Bytes.Bytes) -> Maybe<&2, String>:
  match ok:
    case False{}:
      None{}
    case True{}:
      head.flags(Bytes.get.u16be(b, 2))

def head.id(+id: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&2, String>:
  (b, m) = r
  match m:
    case None{}:
      None{}
    case Some{got}:
      head.id.if(U32.is_eq(id, got), b)

# The IPv4 address the response gives for the query with this id.
def answer(id: U32, msg: Bytes.Bytes) -> Maybe<&2, String>:
  head.id(id, Bytes.get.u16be(msg, 0))

# resolv.conf
# -----------

def nameservers.add(+line: String, rest: List<&2, String>, hit: Bool) -> List<&2, String>:
  match hit:
    case False{}:
      rest
    case True{}:
      Con{String.trim(String.drop(line, 10n)), rest}

def nameservers.go(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+line, t}:
      nameservers.add(line, nameservers.go(t), String.starts_with(line, "nameserver"))

# Every nameserver line, in file order.
def nameservers(conf: String) -> List<&2, String>:
  nameservers.go(String.lines(conf))

def nameserver.first(xs: List<&2, String>) -> Maybe<&2, String>:
  match xs:
    case Nil{}:
      None{}
    case Con{n, t}:
      Some{n}

# The first nameserver line of a resolv.conf.
def nameserver(conf: String) -> Maybe<&2, String>:
  nameserver.first(nameservers(conf))

# Resolve
# -------

def none() -> IO(Maybe<&2, String>):
  IO.pure(Maybe<&2, String>, None{})

def list.append(xs: List<&2, String>, ys: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      ys
    case Con{+h, t}:
      h <> list.append(t, ys)

def list.one(+x: String) -> List<&2, String>:
  x <> Nil{}

def list.any(+xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{+_, +_}:
      True{}

def list.first(xs: List<&2, String>) -> Maybe<&2, String>:
  match xs:
    case Nil{}:
      None{}
    case Con{+h, t}:
      Some{h}

def ipv4.go(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.or(U32.is_eq(c, 46), Bool.and(U32.is_le(48, c), U32.is_le(c, 57))), ipv4.go(t))

# Digits and dots; TCP.connect rejects anything else that is not an address.
def ipv4(+s: String) -> Bool:
  Bool.and(Bool.not(String.is_empty(s)), ipv4.go(s))

def ipv6.ch(+c: U32) -> Bool:
  Bool.or(
    Bool.and(U32.is_le(48, c), U32.is_le(c, 57)),
    Bool.or(
      Bool.and(U32.is_le(97, c), U32.is_le(c, 102)),
      Bool.and(U32.is_le(65, c), U32.is_le(c, 70))))

def ipv6.go(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.or(U32.is_eq(c, 58), ipv6.ch(c)), ipv6.go(t))

def ipv6.has(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, t}:
      Bool.or(U32.is_eq(c, 58), ipv6.has(t))

# Bracket-free IPv6 text; connect validates the address.
def ipv6(+s: String) -> Bool:
  Bool.and(Bool.and(Bool.not(String.is_empty(s)), ipv6.has(s)), ipv6.go(s))

def ip(+s: String) -> Bool:
  Bool.or(ipv4(s), ipv6(s))

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
  try.pure(s, Bool.pick(Try, Bool.and(String.eq(h, ns), U32.is_eq(p, 53)), Got{answer(id, Bytes.Bytes{n, w})}, Again{}))

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
  try.send(s, ns, id, query(id, name))

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
    resolve.list(name, nameservers(conf.text(r)))

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


def hosts.on_line(+name: String, ns: List<&2, String>) -> Bool:
  match ns:
    case Nil{}:
      False{}
    case Con{+n, t}:
      Bool.or(String.eq(String.to_lower(n), name), hosts.on_line(name, t))

def hosts.line.all(+name: String, xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+addr, ns}:
      Bool.pick(List<&2, String>, Bool.and(ip(addr), hosts.on_line(name, ns)), list.one(addr), Nil{})

def hosts.sp(+c: U32, tab: Bool) -> U32:
  match tab:
    case True{}:
      32
    case False{}:
      c

def hosts.flat(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, t}:
      SCon{Chr{hosts.sp(c, U32.is_eq(c, 9))}, hosts.flat(t)}

def hosts.scan.all(xs: List<&2, String>, +name: String, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      acc
    case Con{+line, t}:
      hosts.scan.all(t, name,
        list.append(acc, hosts.line.all(name, String.split(hosts.flat(line), ' '))))

# Every address for name in an /etc/hosts file. The name is already lowercase.
def hosts.all(+name: String, text: String) -> List<&2, String>:
  hosts.scan.all(String.lines(text), name, Nil{})

# First address for name in an /etc/hosts file. The name is already lowercase.
def hosts(+name: String, text: String) -> Maybe<&2, String>:
  list.first(hosts.all(name, text))

def lookup.split(+s: String) -> List<&2, String>:
  List.filter(~String, ~(n => Bool.not(String.is_empty(n))), String.split(s, Chr{0}))

# OS resolver: every address, NUL-separated in getaddrinfo order.
def lookup.all(host: String) -> IO(Result<&1, &1, U32 & String, String>):
  import "./effs/dns.c"
  import "./effs/dns.js"

# Literals and localhost without the OS (for laws and fast paths).
def resolve.literal.all(+host: String) -> List<&2, String>:
  Bool.pick(List<&2, String>, ip(host), list.one(host),
    Bool.pick(List<&2, String>, String.eq(host, "localhost"),
      ["::1", "127.0.0.1"], Nil{}))

def resolve.literal(+host: String) -> Maybe<&2, String>:
  list.first(resolve.literal.all(host))

def resolve.all.got(r: Result<&1, &1, U32 & String, String>) -> IO(List<&2, String>):
  match r:
    case Fail{e}:
      IO.pure(List<&2, String>, Nil{})
    case Done{s}:
      IO.pure(List<&2, String>, lookup.split(s))

def resolve.all.os(+name: String) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    r : Result<&1, &1, U32 & String, String> <- lookup.all(name)
    resolve.all.got(r)

def resolve.all.dns.one(m: Maybe<&2, String>) -> IO(List<&2, String>):
  match m:
    case Some{ip}:
      IO.pure(List<&2, String>, list.one(ip))
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
      resolve.all.from(name, hosts.all(name, s))

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
  resolve.all.pick(host, resolve.literal.all(host))

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
  resolve.all.pure.pick(host, resolve.literal.all(host))

def resolve.pure(+host: String) -> IO(Maybe<&2, String>):
  do IO<Maybe<&2, String>>:
    xs : List<&2, String> <- resolve.all.pure(host)
    return list.first(xs)

# First address from resolve.all (getaddrinfo order when the OS resolves).
def resolve(+host: String) -> IO(Maybe<&2, String>):
  do IO<Maybe<&2, String>>:
    xs : List<&2, String> <- resolve.all(host)
    return list.first(xs)
