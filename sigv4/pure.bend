import Base
import bend-kit-url@0.4.1.0/url.bend as Url
import bend-kit-collections@0.1.6.0/order.bend as Order

# Code points to UTF-8 octets, one Char per octet. acc is reversed.
def utf8.c3(three: Bool, +c: U32, acc: String) -> String:
  match three:
    case True{}:
      SCon{Chr{(128 + c % 64 : U32)}, SCon{Chr{(128 + c / 64 % 64 : U32)}, SCon{Chr{(224 + c / 4096 : U32)}, acc}}}
    case False{}:
      SCon{Chr{(128 + c % 64 : U32)}, SCon{Chr{(128 + c / 64 % 64 : U32)}, SCon{Chr{(128 + c / 4096 % 64 : U32)}, SCon{Chr{(240 + c / 262144 : U32)}, acc}}}}

def utf8.c2(two: Bool, +c: U32, acc: String) -> String:
  match two:
    case True{}:
      SCon{Chr{(128 + c % 64 : U32)}, SCon{Chr{(192 + c / 64 : U32)}, acc}}
    case False{}:
      utf8.c3(U32.is_lt(c, 65536), c, acc)

def utf8.c1(one: Bool, +c: U32, acc: String) -> String:
  match one:
    case True{}:
      SCon{Chr{c}, acc}
    case False{}:
      utf8.c2(U32.is_lt(c, 2048), c, acc)

def utf8.go(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{Chr{+c}, t}:
      utf8.go(t, utf8.c1(U32.is_lt(c, 128), c, acc))

def utf8(s: String) -> String:
  utf8.go(s, SNil{})

# SigV4 URI encoding of text: UTF-8, then every octet but the unreserved ones as %XX. slash keeps '/'.
def encode(s: String, slash: Bool) -> String:
  match slash:
    case True{}:
      Url.pct.encode_path(utf8(s))
    case False{}:
      Url.pct.encode_q(utf8(s))

def dec.of(m: Maybe<&2, String>, +raw: String) -> String:
  match m:
    case None{}:
      raw
    case Some{d}:
      d

# A wire component, re-encoded. A malformed escape stays literal, so its '%' is encoded.
def norm(s: String) -> String:
  +o = utf8(s)
  Url.pct.encode_q(dec.of(Url.pct.decode(o), o))

def norms(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{norm(h), norms(t)}

# Non-S3 services encode the wire path a second time; '%' becomes '%25'.
def wire.segs(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{Url.pct.encode_q(utf8(h)), wire.segs(t)}

# Canonical URI (RFC 3986 §5.2.4 for services other than s3): "" and "." segments drop, ".." pops.
def dots.seg(skip: Bool, up: Bool, +seg: String, st: List<&2, String>) -> List<&2, String>:
  match skip up:
    case True{} _:
      st
    case False{} True{}:
      List.drop(&2, String, st, 1n)
    case False{} False{}:
      Con{seg, st}

def dots(xs: List<&2, String>, st: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      List.reverse(&2, String, st)
    case Con{+h, t}:
      dots(t, dots.seg(Bool.or(String.is_empty(h), String.eq(h, ".")), String.eq(h, ".."), h, st))

def uri.slash(empty: Bool, trail: Bool, +body: String) -> String:
  match empty trail:
    case True{} _:
      "/"
    case False{} True{}:
      "/" ++ body ++ "/"
    case False{} False{}:
      "/" ++ body

def uri.dots(+path: String) -> String:
  +body = String.join(wire.segs(dots(String.split(path, '/'), Nil{})), "/")
  +trail = Bool.or(String.ends_with(path, "/"), Bool.or(String.ends_with(path, "/."), String.ends_with(path, "/..")))
  uri.slash(String.is_empty(body), trail, body)

# S3 signs the path as sent: each segment re-encoded, nothing removed.
def uri.s3(empty: Bool, +path: String) -> String:
  match empty:
    case True{}:
      "/"
    case False{}:
      String.join(norms(String.split(path, '/')), "/")

def uri.if(s3: Bool, +path: String) -> String:
  match s3:
    case True{}:
      uri.s3(String.is_empty(path), path)
    case False{}:
      uri.dots(path)

def uri(+service: String, +path: String) -> String:
  uri.if(String.eq(service, "s3"), path)

# Canonical query: split on '&', each "k=v" (a bare "k" is "k="), re-encoded, sorted by key then value.
def pair(xs: List<&2, String>) -> Sigma<&2, &2, String, _ => String>:
  match xs:
    case Nil{}:
      ("", "")
    case Con{k, t}:
      (norm(k), norm(String.join(t, "=")))

def pairs.if(empty: Bool, +h: String, rest: List<&2, Sigma<&2, &2, String, _ => String>>) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  match empty:
    case True{}:
      rest
    case False{}:
      Con{pair(String.split(h, '=')), rest}

def pairs(xs: List<&2, String>) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      pairs.if(String.is_empty(h), h, pairs(t))

def pair.le.of(c: Cmp, av: String, bv: String) -> Bool:
  match c:
    case LT{}:
      True{}
    case GT{}:
      False{}
    case EQ{}:
      String.is_le(av, bv)

def pair.le(a: Sigma<&2, &2, String, _ => String>, b: Sigma<&2, &2, String, _ => String>) -> Bool:
  (ak, av) = a
  (bk, bv) = b
  pair.le.of(Order.string(ak, bk), av, bv)

def pairs.show(xs: List<&2, Sigma<&2, &2, String, _ => String>>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{(k, v), t}:
      Con{k ++ "=" ++ v, pairs.show(t)}

def query(q: String) -> String:
  String.join(pairs.show(List.sort(~Sigma<&2, &2, String, _ => String>, ~pair.le, pairs(String.split(q, '&')))), "&")

# Canonical headers: lowercase names, trimmed values with space runs squashed, sorted by name,
# and a repeated name's values joined by ',' in the order given.
def squash.if(space: Bool, sp: Bool, +c: U32, rest: String) -> String:
  match space sp:
    case True{} True{}:
      rest
    case _ _:
      SCon{Chr{c}, rest}

def squash(s: String, sp: Bool) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, t}:
      squash.if(U32.is_eq(c, 32), sp, c, squash(t, U32.is_eq(c, 32)))

def hdrs.low(xs: List<&2, Sigma<&2, &2, String, _ => String>>) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{(n, v), t}:
      Con{(String.to_lower(n), squash(String.trim(v), False{})), hdrs.low(t)}

def name.le(a: Sigma<&2, &2, String, _ => String>, b: Sigma<&2, &2, String, _ => String>) -> Bool:
  (an, av) = a
  (bn, bv) = b
  String.is_le(an, bn)

def grp.if(same: Bool, +n: String, +v: String, +pn: String, +pv: String, rest: List<&2, Sigma<&2, &2, String, _ => String>>) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  match same:
    case True{}:
      Con{(pn, pv ++ "," ++ v), rest}
    case False{}:
      Con{(n, v), Con{(pn, pv), rest}}

def grp.add(acc: List<&2, Sigma<&2, &2, String, _ => String>>, +n: String, +v: String) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  match acc:
    case Nil{}:
      [(n, v)]
    case Con{(+pn, +pv), rest}:
      grp.if(String.eq(pn, n), n, v, pn, pv, rest)

def grp(xs: List<&2, Sigma<&2, &2, String, _ => String>>, acc: List<&2, Sigma<&2, &2, String, _ => String>>) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  match xs:
    case Nil{}:
      List.reverse(&2, Sigma<&2, &2, String, _ => String>, acc)
    case Con{(+n, +v), t}:
      grp(t, grp.add(acc, n, v))

def headers(hs: List<&2, Sigma<&2, &2, String, _ => String>>) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  grp(List.sort(~Sigma<&2, &2, String, _ => String>, ~name.le, hdrs.low(hs)), Nil{})

def names(xs: List<&2, Sigma<&2, &2, String, _ => String>>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{(n, v), t}:
      Con{n, names(t)}

def lines(xs: List<&2, Sigma<&2, &2, String, _ => String>>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{(n, v), t}:
      n ++ ":" ++ v ++ "\n" ++ lines(t)

# The SignedHeaders value for headers hs.
def signed(hs: List<&2, Sigma<&2, &2, String, _ => String>>) -> String:
  String.join(names(headers(hs)), ";")

# The canonical request. hs must hold every header to sign, host included. phash is the
# payload's lowercase hex SHA-256, or "UNSIGNED-PAYLOAD".
def canonical(+service: String, +method: String, +path: String, +q: String, +hs: List<&2, Sigma<&2, &2, String, _ => String>>, +phash: String) -> String:
  +h = headers(hs)
  method ++ "\n" ++ uri(service, path) ++ "\n" ++ query(q) ++ "\n" ++ lines(h) ++ "\n" ++ String.join(names(h), ";") ++ "\n" ++ phash

def scope(+date: String, +region: String, +service: String) -> String:
  String.take(date, 8n) ++ "/" ++ region ++ "/" ++ service ++ "/aws4_request"

# The string to sign, from the hex SHA-256 of the canonical request.
def to_sign(+date: String, +scope: String, +hash: String) -> String:
  "AWS4-HMAC-SHA256\n" ++ date ++ "\n" ++ scope ++ "\n" ++ hash

def header(+access: String, +scope: String, +signed: String, +sig: String) -> String:
  "AWS4-HMAC-SHA256 Credential=" ++ access ++ "/" ++ scope ++ ", SignedHeaders=" ++ signed ++ ", Signature=" ++ sig

def token.q(empty: Bool, +token: String) -> String:
  match empty:
    case True{}:
      ""
    case False{}:
      "&X-Amz-Security-Token=" ++ encode(token, False{})

# The query a presigned request adds to q, before X-Amz-Signature.
def presign.query(+access: String, +token: String, +scope: String, +date: String, +expires: U32, +q: String) -> String:
  query(q ++ "&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=" ++ encode(access ++ "/" ++ scope, False{}) ++ "&X-Amz-Date=" ++ date ++ "&X-Amz-Expires=" ++ U32.show(expires) ++ token.q(String.is_empty(token), token) ++ "&X-Amz-SignedHeaders=host")
