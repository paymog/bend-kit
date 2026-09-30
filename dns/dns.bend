# DNS codec and host lookup. Source: https://github.com/paymog/bend-kit/tree/main/dns
import Base
import bend-kit-wire@0.4.3.0/wire.bend as Wire
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes

# query, answer, and resolve.pure are pure; PROOF.bend covers them, not effs/.
# resolve.all uses the OS resolver (IPv4 and IPv6); resolve keeps the first address.
#   import bend-kit-dns@0.6.0.0/dns.bend as Dns

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

# The query buffer is allocated to its exact size before writing.
def written(r: Bytes.Cursor & Bool) -> Bytes.Cursor:
  (c, ok) = r
  c

def label.put(s: String, c: Bytes.Cursor) -> Bytes.Cursor:
  match s:
    case SNil{}:
      c
    case SCon{Chr{v}, t}:
      label.put(t, written(Bytes.Cursor.put.u8(c, v)))

def labels.put(xs: List<&2, String>, c: Bytes.Cursor) -> Bytes.Cursor:
  match xs:
    case Nil{}:
      written(Bytes.Cursor.put.u8(c, 0))
    case Con{+l, t}:
      labels.put(t, label.put(l, written(Bytes.Cursor.put.u8(c, U32.from_nat(String.length(l))))))

def query.done(r: Bytes.Bytes & U32) -> Maybe<&1, Bytes.Bytes>:
  (b, pos) = r
  Some{b}

def query.if(+id: U32, +xs: List<&2, String>, ok: Bool) -> Maybe<&1, Bytes.Bytes>:
  match ok:
    case False{}:
      None{}
    case True{}:
      # header: id, RD, QDCOUNT 1; question: QNAME, QTYPE A, QCLASS IN.
      c = Bytes.Cursor.new(Bytes.new((labels.len(xs, 0) + 17 : U32)))
      c = written(Bytes.Cursor.put.u16be(c, id))
      c = written(Bytes.Cursor.put.u16be(c, 256))
      c = written(Bytes.Cursor.put.u16be(c, 1))
      c = written(Bytes.Cursor.skip(c, 6))
      c = labels.put(xs, c)
      c = written(Bytes.Cursor.put.u16be(c, 1))
      c = written(Bytes.Cursor.put.u16be(c, 1))
      query.done(Bytes.Cursor.finish(c))

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

# One step through a name: continue at the next label or stop after the name.
type Step is Data:
  Go{}
  Stop{ok: Bool}

def name.advance(stop: Bool, r: Bytes.Cursor & Bool) -> Bytes.Cursor & Step:
  (c, ok) = r
  match ok:
    case False{}:
      (c, Stop{False{}})
    case True{}:
      (c, Bool.pick(Step, stop, Stop{True{}}, Go{}))

# §4.1.4: zero terminates, 192..255 starts a pointer, 64..191 is reserved.
def name.label(ok: Bool, c: Bytes.Cursor, l: U32) -> Bytes.Cursor & Step:
  match ok:
    case False{}:
      (c, Stop{False{}})
    case True{}:
      name.advance(False{}, Bytes.Cursor.skip(c, l))

def name.pointer(pointer: Bool, +l: U32, c: Bytes.Cursor) -> Bytes.Cursor & Step:
  match pointer:
    case True{}:
      name.advance(True{}, Bytes.Cursor.skip(c, 1))
    case False{}:
      name.label(U32.is_lt(l, 64), c, l)

def name.step.of(+l: U32, c: Bytes.Cursor) -> Bytes.Cursor & Step:
  match l:
    case 0:
      (c, Stop{True{}})
    case _:
      name.pointer(U32.is_le(192, l), l, c)

def name.step(r: Bytes.Cursor & Maybe<&2, U32>) -> Bytes.Cursor & Step:
  (c, m) = r
  match m:
    case None{}:
      (c, Stop{False{}})
    case Some{l}:
      name.step.of(l, c)

def name.walk(fuel: Nat, r: Bytes.Cursor & Step) -> Bytes.Cursor & Bool:
  match fuel:
    case 0n:
      (c, s) = r
      (c, False{})
    case 1n+f:
      (c, s) = r
      match s:
        case Stop{ok}:
          (c, ok)
        case Go{}:
          name.walk(f, name.step(Bytes.Cursor.u8(c)))

# §2.3.4: a name is at most 255 octets, so retain the 128-step limit.
def name.skip(c: Bytes.Cursor) -> Bytes.Cursor & Bool:
  name.walk(128n, name.step(Bytes.Cursor.u8(c)))

type RR is Data:
  RRBad{}
  RRA{ip: String}
  RRSkip{}

def dotted(+ip: U32) -> String:
  U32.show(U32.shrn(ip, 24n)) ++ "." ++ U32.show(Bytes.b8(U32.shrn(ip, 16n))) ++ "." ++ U32.show(Bytes.b8(U32.shrn(ip, 8n))) ++ "." ++ U32.show(Bytes.b8(ip))

def rr.a(limit: Bytes.CursorLimit, r: Bytes.Cursor & Maybe<&2, U32>) -> Bytes.Cursor & RR:
  (c, m) = r
  match m:
    case None{}:
      (Bytes.Cursor.leave(c, limit), RRBad{})
    case Some{ip}:
      (Bytes.Cursor.leave(c, limit), RRA{dotted(ip)})

def rr.data.some(a: Bool, c: Bytes.Cursor, limit: Bytes.CursorLimit) -> Bytes.Cursor & RR:
  match a:
    case True{}:
      rr.a(limit, Bytes.Cursor.u32be(c))
    case False{}:
      (Bytes.Cursor.leave(c, limit), RRSkip{})

# Bound RDATA in the original packed buffer, then resume after the entire region.
def rr.data(a: Bool, r: Bytes.Cursor & Maybe<&1, Bytes.CursorLimit>) -> Bytes.Cursor & RR:
  (c, m) = r
  match m:
    case None{}:
      (c, RRBad{})
    case Some{limit}:
      rr.data.some(a, c, limit)

def rr.len(+ty: U32, +cl: U32, r: Bytes.Cursor & Maybe<&2, U32>) -> Bytes.Cursor & RR:
  (c, m) = r
  match m:
    case None{}:
      (c, RRBad{})
    case Some{+len}:
      rr.data(Bool.and(Bool.and(U32.is_eq(ty, 1), U32.is_eq(cl, 1)), U32.is_eq(len, 4)), Bytes.Cursor.region(c, len))

def rr.ttl(+ty: U32, +cl: U32, r: Bytes.Cursor & Bool) -> Bytes.Cursor & RR:
  (c, ok) = r
  match ok:
    case False{}:
      (c, RRBad{})
    case True{}:
      rr.len(ty, cl, Bytes.Cursor.u16be(c))

def rr.cl(+ty: U32, r: Bytes.Cursor & Maybe<&2, U32>) -> Bytes.Cursor & RR:
  (c, m) = r
  match m:
    case None{}:
      (c, RRBad{})
    case Some{cl}:
      rr.ttl(ty, cl, Bytes.Cursor.skip(c, 4))

def rr.ty(r: Bytes.Cursor & Maybe<&2, U32>) -> Bytes.Cursor & RR:
  (c, m) = r
  match m:
    case None{}:
      (c, RRBad{})
    case Some{ty}:
      rr.cl(ty, Bytes.Cursor.u16be(c))

def rr.name(r: Bytes.Cursor & Bool) -> Bytes.Cursor & RR:
  (c, ok) = r
  match ok:
    case False{}:
      (c, RRBad{})
    case True{}:
      rr.ty(Bytes.Cursor.u16be(c))

# §4.1.3: NAME, TYPE, CLASS, TTL, RDLENGTH, RDATA.
def rr(c: Bytes.Cursor) -> Bytes.Cursor & RR:
  rr.name(name.skip(c))

# fuel = records left. The first A record wins; CNAMEs before it are skipped.
def answers.scan(fuel: Nat, r: Bytes.Cursor & RR) -> Maybe<&2, String>:
  match fuel:
    case 0n:
      None{}
    case 1n+f:
      (c, x) = r
      match x:
        case RRBad{}:
          None{}
        case RRA{ip}:
          Some{ip}
        case RRSkip{}:
          answers.scan(f, rr(c))

# QTYPE and QCLASS follow the name.
def question.end(r: Bytes.Cursor & Bool) -> Bytes.Cursor & Bool:
  (c, ok) = r
  match ok:
    case False{}:
      (c, False{})
    case True{}:
      Bytes.Cursor.skip(c, 4)

def questions(fuel: Nat, r: Bytes.Cursor & Bool) -> Bytes.Cursor & Bool:
  match fuel:
    case 0n:
      r
    case 1n+f:
      (c, ok) = r
      match ok:
        case False{}:
          (c, False{})
        case True{}:
          questions(f, question.end(name.skip(c)))

def body.go(+an: U32, r: Bytes.Cursor & Bool) -> Maybe<&2, String>:
  (c, ok) = r
  match ok:
    case False{}:
      None{}
    case True{}:
      answers.scan(U32.to_nat(an), rr(c))

# The header ends with NSCOUNT and ARCOUNT; questions follow.
def body.an(+qd: U32, r: Bytes.Cursor & Maybe<&2, U32>) -> Maybe<&2, String>:
  (c, m) = r
  match m:
    case None{}:
      None{}
    case Some{an}:
      body.go(an, questions(U32.to_nat(qd), Bytes.Cursor.skip(c, 4)))

def body.qd(r: Bytes.Cursor & Maybe<&2, U32>) -> Maybe<&2, String>:
  (c, m) = r
  match m:
    case None{}:
      None{}
    case Some{qd}:
      body.an(qd, Bytes.Cursor.u16be(c))

# §4.1.1: QR set, opcode QUERY, not truncated, RCODE 0.
def flags.ok(+f: U32) -> Bool:
  Bool.and(Bool.and(U32.is_eq(U32.and(f, 32768), 32768), U32.is_eq(U32.and(f, 30720), 0)), Bool.and(U32.is_eq(U32.and(f, 512), 0), U32.is_eq(U32.and(f, 15), 0)))

def head.flags.if(ok: Bool, c: Bytes.Cursor) -> Maybe<&2, String>:
  match ok:
    case False{}:
      None{}
    case True{}:
      body.qd(Bytes.Cursor.u16be(c))

def head.flags(r: Bytes.Cursor & Maybe<&2, U32>) -> Maybe<&2, String>:
  (c, m) = r
  match m:
    case None{}:
      None{}
    case Some{f}:
      head.flags.if(flags.ok(f), c)

def head.id.if(ok: Bool, c: Bytes.Cursor) -> Maybe<&2, String>:
  match ok:
    case False{}:
      None{}
    case True{}:
      head.flags(Bytes.Cursor.u16be(c))

def head.id(+id: U32, r: Bytes.Cursor & Maybe<&2, U32>) -> Maybe<&2, String>:
  (c, m) = r
  match m:
    case None{}:
      None{}
    case Some{got}:
      head.id.if(U32.is_eq(id, got), c)

# The IPv4 address the response gives for the query with this id.
def answer(id: U32, msg: Bytes.Bytes) -> Maybe<&2, String>:
  head.id(id, Bytes.Cursor.u16be(Bytes.Cursor.new(msg)))

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
