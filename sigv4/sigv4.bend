# AWS Signature V4 signing and S3 object storage over Hairpin. Source: https://github.com/paymog/bend-kit/tree/main/sigv4
import Base
import bend-kit-crypto@0.2.2.2/crypto.bend as Crypto
import bend-kit-hairpin@0.19.1.0/hairpin.bend as Hairpin
import bend-kit-hairpin@0.19.1.0/pure.bend as HairpinPure
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import bend-kit-http@0.45.1.0/http.bend as Http
import bend-kit-http@0.45.1.0/pure.bend as HttpPure
import bend-kit-time@0.3.0.5/pure.bend as Time
import bend-kit-url@0.4.1.0/url.bend as Url
import bend-kit-encoding@0.5.0.3/encoding.bend as Enc
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import ./pure.bend as Pure
import ./xml.bend as Xml

# Text (path, query, header values) is a String of code points; non-ASCII is sent as UTF-8.
# S3 decodes and re-encodes wire escapes once; other services encode an escaped wire path twice.
# SigV4 encoding keeps only A-Z a-z 0-9 - _ . ~ and uses uppercase %XX.
# date is the x-amz-date form, YYYYMMDDTHHMMSSZ. token is "" for long-term keys.
type Credentials is Data:
  Credentials{access: String, secret: String, token: String}

# Code points to UTF-8 octets, one Char per octet. acc is reversed.
def utf8.c3(three: Bool, +c: U32, acc: String) -> String:
  Pure.utf8.c3(three, c, acc)

def utf8.c2(two: Bool, +c: U32, acc: String) -> String:
  Pure.utf8.c2(two, c, acc)

def utf8.c1(one: Bool, +c: U32, acc: String) -> String:
  Pure.utf8.c1(one, c, acc)

def utf8.go(s: String, acc: String) -> String:
  Pure.utf8.go(s, acc)

def utf8(s: String) -> String:
  Pure.utf8(s)

# SigV4 URI encoding of text: UTF-8, then every octet but the unreserved ones as %XX. slash keeps '/'.
def encode(s: String, slash: Bool) -> String:
  Pure.encode(s, slash)

def dec.of(m: Maybe<&2, String>, +raw: String) -> String:
  Pure.dec.of(m, raw)

# A wire component, re-encoded. A malformed escape stays literal, so its '%' is encoded.
def norm(s: String) -> String:
  Pure.norm(s)

def norms(xs: List<&2, String>) -> List<&2, String>:
  Pure.norms(xs)

# Non-S3 services encode the wire path a second time; '%' becomes '%25'.
def wire.segs(xs: List<&2, String>) -> List<&2, String>:
  Pure.wire.segs(xs)

# Canonical URI (RFC 3986 §5.2.4 for services other than s3): "" and "." segments drop, ".." pops.
def dots.seg(skip: Bool, up: Bool, +seg: String, st: List<&2, String>) -> List<&2, String>:
  Pure.dots.seg(skip, up, seg, st)

def dots(xs: List<&2, String>, st: List<&2, String>) -> List<&2, String>:
  Pure.dots(xs, st)

def uri.slash(empty: Bool, trail: Bool, +body: String) -> String:
  Pure.uri.slash(empty, trail, body)

def uri.dots(+path: String) -> String:
  Pure.uri.dots(path)

# S3 signs the path as sent: each segment re-encoded, nothing removed.
def uri.s3(empty: Bool, +path: String) -> String:
  Pure.uri.s3(empty, path)

def uri.if(s3: Bool, +path: String) -> String:
  Pure.uri.if(s3, path)

def uri(+service: String, +path: String) -> String:
  Pure.uri(service, path)

# Canonical query: split on '&', each "k=v" (a bare "k" is "k="), re-encoded, sorted by key then value.
def pair(xs: List<&2, String>) -> Sigma<&2, &2, String, _ => String>:
  Pure.pair(xs)

def pairs.if(empty: Bool, +h: String, rest: List<&2, Sigma<&2, &2, String, _ => String>>) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  Pure.pairs.if(empty, h, rest)

def pairs(xs: List<&2, String>) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  Pure.pairs(xs)

def pair.le.of(c: Cmp, av: String, bv: String) -> Bool:
  Pure.pair.le.of(c, av, bv)

def pair.le(a: Sigma<&2, &2, String, _ => String>, b: Sigma<&2, &2, String, _ => String>) -> Bool:
  Pure.pair.le(a, b)

def pairs.show(xs: List<&2, Sigma<&2, &2, String, _ => String>>) -> List<&2, String>:
  Pure.pairs.show(xs)

def query(q: String) -> String:
  Pure.query(q)

# Canonical headers: lowercase names, trimmed values with space runs squashed, sorted by name,
# and a repeated name's values joined by ',' in the order given.
def squash.if(space: Bool, sp: Bool, +c: U32, rest: String) -> String:
  Pure.squash.if(space, sp, c, rest)

def squash(s: String, sp: Bool) -> String:
  Pure.squash(s, sp)

def hdrs.low(xs: List<&2, Sigma<&2, &2, String, _ => String>>) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  Pure.hdrs.low(xs)

def name.le(a: Sigma<&2, &2, String, _ => String>, b: Sigma<&2, &2, String, _ => String>) -> Bool:
  Pure.name.le(a, b)

def grp.if(same: Bool, +n: String, +v: String, +pn: String, +pv: String, rest: List<&2, Sigma<&2, &2, String, _ => String>>) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  Pure.grp.if(same, n, v, pn, pv, rest)

def grp.add(acc: List<&2, Sigma<&2, &2, String, _ => String>>, +n: String, +v: String) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  Pure.grp.add(acc, n, v)

def grp(xs: List<&2, Sigma<&2, &2, String, _ => String>>, acc: List<&2, Sigma<&2, &2, String, _ => String>>) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  Pure.grp(xs, acc)

def headers(hs: List<&2, Sigma<&2, &2, String, _ => String>>) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  Pure.headers(hs)

def names(xs: List<&2, Sigma<&2, &2, String, _ => String>>) -> List<&2, String>:
  Pure.names(xs)

def lines(xs: List<&2, Sigma<&2, &2, String, _ => String>>) -> String:
  Pure.lines(xs)

# The SignedHeaders value for headers hs.
def signed(hs: List<&2, Sigma<&2, &2, String, _ => String>>) -> String:
  Pure.signed(hs)

# The canonical request. hs must hold every header to sign, host included. phash is the
# payload's lowercase hex SHA-256, or "UNSIGNED-PAYLOAD".
def canonical(+service: String, +method: String, +path: String, +q: String, +hs: List<&2, Sigma<&2, &2, String, _ => String>>, +phash: String) -> String:
  Pure.canonical(service, method, path, q, hs, phash)

def scope(+date: String, +region: String, +service: String) -> String:
  Pure.scope(date, region, service)

# The string to sign, from the hex SHA-256 of the canonical request.
def to_sign(+date: String, +scope: String, +hash: String) -> String:
  Pure.to_sign(date, scope, hash)

def header(+access: String, +scope: String, +signed: String, +sig: String) -> String:
  Pure.header(access, scope, signed, sig)

# Crypto. Errors are the crypto effect's (errno, why).

def hex.of(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, U32 & String, String>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{(len, buf)}:
      Done{Bytes.to_hex(Bytes.Bytes{len, buf})}

# Hex SHA-256 of a byte string.
def sha.words(b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{+len, buf} = b
  Crypto.sha256.words(len, buf)

def sha(+s: String) -> IO(Result<&1, &1, U32 & String, String>):
  do IO<Result<&1, &1, U32 & String, String>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- sha.words(Bytes.from_string(s))
    return hex.of(r)

def mac.words(+kn: U32, kb: Array<U32>, d: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{+dn, db} = d
  Crypto.hmac.words("SHA256", kn, kb, dn, db)

def words(b: Bytes.Bytes) -> Result<&1, &1, U32 & String, U32 & Array<U32>>:
  Bytes.Bytes{+len, buf} = b
  Done{(len, buf)}

# HMAC-SHA256 of msg under the key k holds, or k's failure.
def mac(k: Result<&1, &1, U32 & String, U32 & Array<U32>>, +msg: String) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  match k:
    case Fail{e}:
      IO.pure(Result<&1, &1, U32 & String, U32 & Array<U32>>, Fail{e})
    case Done{(kn, kb)}:
      mac.words(kn, kb, Bytes.from_string(msg))

# The signing key: HMAC(HMAC(HMAC(HMAC("AWS4" + secret, day), region), service), "aws4_request").
def key(+secret: String, +day: String, +region: String, +service: String) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  do IO<Result<&1, &1, U32 & String, U32 & Array<U32>>>:
    k1 : Result<&1, &1, U32 & String, U32 & Array<U32>> <- mac(words(Bytes.from_string("AWS4" ++ secret)), day)
    k2 : Result<&1, &1, U32 & String, U32 & Array<U32>> <- mac(k1, region)
    k3 : Result<&1, &1, U32 & String, U32 & Array<U32>> <- mac(k2, service)
    mac(k3, "aws4_request")

def signature.of(h: Result<&1, &1, U32 & String, String>, +secret: String, +date: String, +region: String, +service: String) -> IO(Result<&1, &1, U32 & String, String>):
  match h:
    case Fail{e}:
      IO.pure(Result<&1, &1, U32 & String, String>, Fail{e})
    case Done{+hash}:
      do IO<Result<&1, &1, U32 & String, String>>:
        k : Result<&1, &1, U32 & String, U32 & Array<U32>> <- key(secret, String.take(date, 8n), region, service)
        s : Result<&1, &1, U32 & String, U32 & Array<U32>> <- mac(k, to_sign(date, scope(date, region, service), hash))
        return hex.of(s)

# The hex signature of a canonical request.
def signature(+secret: String, +date: String, +region: String, +service: String, +creq: String) -> IO(Result<&1, &1, U32 & String, String>):
  do IO<Result<&1, &1, U32 & String, String>>:
    h : Result<&1, &1, U32 & String, String> <- sha(creq)
    signature.of(h, secret, date, region, service)

def header.of(r: Result<&1, &1, U32 & String, String>, +access: String, +scope: String, +signed: String) -> Result<&1, &1, U32 & String, String>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{sig}:
      Done{header(access, scope, signed, sig)}

# The Authorization header over exactly the headers hs: the general form, for any header set.
# hs must include host and x-amz-date, and x-amz-security-token for temporary credentials;
# creds.token is not added here (authorize.hash adds it). Send every header in hs.
def sign(creds: Credentials, +region: String, +service: String, +date: String, +method: String, +path: String, +q: String, +hs: List<&2, Sigma<&2, &2, String, _ => String>>, +phash: String) -> IO(Result<&1, &1, U32 & String, String>):
  Credentials{+access, +secret, token} = creds
  do IO<Result<&1, &1, U32 & String, String>>:
    s : Result<&1, &1, U32 & String, String> <- signature(secret, date, region, service, canonical(service, method, path, q, hs, phash))
    return header.of(s, access, scope(date, region, service), signed(hs))

def token.hdr(empty: Bool, +token: String) -> List<&2, Sigma<&2, &2, String, _ => String>>:
  match empty:
    case True{}:
      Nil{}
    case False{}:
      [("x-amz-security-token", token)]

# The Authorization header over host;x-amz-content-sha256;x-amz-date, plus x-amz-security-token
# when creds has a token. Send those headers with these values. phash: the payload's hex
# SHA-256, or "UNSIGNED-PAYLOAD".
def authorize.hash(creds: Credentials, +region: String, +service: String, +date: String, +method: String, +path: String, +q: String, +host: String, +phash: String) -> IO(Result<&1, &1, U32 & String, String>):
  Credentials{+access, +secret, +token} = creds
  sign(Credentials{access, secret, token}, region, service, date, method, path, q, Con{("host", host), Con{("x-amz-content-sha256", phash), Con{("x-amz-date", date), token.hdr(String.is_empty(token), token)}}}, phash)

def authorize.pair(r: Result<&1, &1, U32 & String, String>, +phash: String) -> Result<&1, &1, U32 & String, String & String>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{a}:
      Done{(a, phash)}

def authorize.of(h: Result<&1, &1, U32 & String, String>, creds: Credentials, +region: String, +service: String, +date: String, +method: String, +path: String, +q: String, +host: String) -> IO(Result<&1, &1, U32 & String, String & String>):
  match h:
    case Fail{e}:
      IO.pure(Result<&1, &1, U32 & String, String & String>, Fail{e})
    case Done{+phash}:
      do IO<Result<&1, &1, U32 & String, String & String>>:
        a : Result<&1, &1, U32 & String, String> <- authorize.hash(creds, region, service, date, method, path, q, host, phash)
        return authorize.pair(a, phash)

# authorize.hash over the payload's SHA-256. Done{(authorization, x-amz-content-sha256)}.
def authorize(creds: Credentials, +region: String, +service: String, +date: String, +method: String, +path: String, +q: String, +host: String, payload: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, String & String>):
  do IO<Result<&1, &1, U32 & String, String & String>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- sha.words(payload)
    authorize.of(hex.of(r), creds, region, service, date, method, path, q, host)

def token.q(empty: Bool, +token: String) -> String:
  Pure.token.q(empty, token)

# The query a presigned request adds to q, before X-Amz-Signature.
def presign.query(+access: String, +token: String, +scope: String, +date: String, +expires: U32, +q: String) -> String:
  Pure.presign.query(access, token, scope, date, expires, q)

def presign.of(r: Result<&1, &1, U32 & String, String>, +cq: String) -> Result<&1, &1, U32 & String, String>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{sig}:
      Done{cq ++ "&X-Amz-Signature=" ++ sig}

def presign.go(+creds: Credentials, +region: String, +service: String, +date: String, +method: String, +path: String, +q: String, +host: String, +expires: U32) -> IO(Result<&1, &1, U32 & String, String>):
  Credentials{+access, +secret, +token} = creds
  +cq = presign.query(access, token, scope(date, region, service), date, expires, q)
  do IO<Result<&1, &1, U32 & String, String>>:
    s : Result<&1, &1, U32 & String, String> <- signature(secret, date, region, service, canonical(service, method, path, cq, [("host", host)], "UNSIGNED-PAYLOAD"))
    return presign.of(s, cq)

def presign.if(ok: Bool, +creds: Credentials, +region: String, +service: String, +date: String, +method: String, +path: String, +q: String, +host: String, +expires: U32) -> IO(Result<&1, &1, U32 & String, String>):
  match ok:
    case True{}:
      presign.go(creds, region, service, date, method, path, q, host, expires)
    case False{}:
      IO.pure(Result<&1, &1, U32 & String, String>, Fail{(22, "sigv4: expires must be 1 to 604800 seconds")})

# A presigned URL's query, signing host only over UNSIGNED-PAYLOAD, valid for expires seconds,
# 1 to 604800 (else Fail EINVAL). Request https://{host}{path}?{result} with no auth headers.
def presign(+creds: Credentials, +region: String, +service: String, +date: String, +method: String, +path: String, +q: String, +host: String, +expires: U32) -> IO(Result<&1, &1, U32 & String, String>):
  presign.if(Bool.and(U32.is_lt(0, expires), U32.is_le(expires, 604800)), creds, region, service, date, method, path, q, host, expires)

# ---- S3

# Path: {endpoint}/{bucket}/{key}. Virtual: {bucket}.{endpoint host}/{key}.
type Style is Data:
  Path{}
  Virtual{}

# endpoint: scheme://host[:port], as https://s3.us-east-1.amazonaws.com or http://127.0.0.1:9000. Its path is ignored.
type Config is Data:
  Config{endpoint: String, region: String, style: Style, creds: Credentials}

type Client is Type:
  Client{cfg: Config, http: Hairpin.Client}

# ErrNet: no response. ErrSign: the signer failed. ErrConfig: a bad endpoint or a missing setting.
# ErrS3: any status outside 2xx, redirects included, with S3's error Code and Message ("" when there is no
# error body, as for HEAD). ErrXml: a 2xx body that is not the XML asked for, with its text.
type Err is Data:
  ErrNet{e: Hairpin.Err}
  ErrSign{code: U32, why: String}
  ErrConfig{why: String}
  ErrS3{status: U32, code: String, message: String}
  ErrXml{body: String}

# etag keeps S3's quotes. modified is S3's ISO 8601 text.
type Object is Data:
  Object{key: String, size: Nat, etag: String, modified: String}

# next: the continuation token when S3 cut the listing off.
type Page is Data:
  Page{objects: List<&2, Object>, prefixes: List<&2, String>, next: Maybe<&2, String>}

# From a HEAD: Content-Length, ETag, Content-Type, and Last-Modified.
type Meta is Data:
  Meta{size: Nat, etag: String, mime: String, modified: String}

# ---- config

# Redirects come back as ErrS3: a signed request must not follow one.
def new(cfg: Config) -> Client:
  Client{cfg, Hairpin.redirect(Hairpin.new(), HttpPure.ModeManual{})}

def close(c: Client) -> IO(Unit):
  Client{cfg, http} = c
  Hairpin.close(http)

# Up to n more tries after a connect error, a timeout, or 408, 429, 500, 502, 503, or 504. The signature stays valid for 15 minutes.
def retry(c: Client, n: U32) -> Client:
  Client{cfg, http} = c
  Client{cfg, Hairpin.retry(http, n)}

def timeout(c: Client, ms: U32) -> Client:
  Client{cfg, http} = c
  Client{cfg, Hairpin.timeout(http, ms)}

# AWS itself: https://s3.{region}.amazonaws.com, virtual-hosted.
def aws(+region: String, creds: Credentials) -> Config:
  Config{"https://s3." ++ region ++ ".amazonaws.com", region, Virtual{}, creds}

def env(r: Result<&1, &1, U32 & String, String>) -> String:
  match r:
    case Fail{e}:
      ""
    case Done{s}:
      s

def or(+a: String, b: String) -> String:
  Bool.pick(String, String.is_empty(a), b, a)

def from_env.cfg(custom: Bool, +region: String, endpoint: String, creds: Credentials) -> Config:
  match custom:
    case True{}:
      Config{endpoint, region, Path{}, creds}
    case False{}:
      aws(region, creds)

def from_env.if(missing: Bool, access: String, secret: String, token: String, region: String, +endpoint: String) ->
    Result<&1, &1, Err, Config>:
  match missing:
    case True{}:
      Fail{ErrConfig{"AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set"}}
    case False{}:
      Done{from_env.cfg(Bool.not(String.is_empty(endpoint)), region, endpoint, Credentials{access, secret, token})}

def from_env.of(+access: String, +secret: String, token: String, region: String, endpoint: String) -> Result<&1, &1, Err, Config>:
  from_env.if(Bool.or(String.is_empty(access), String.is_empty(secret)), access, secret, token, region, endpoint)

# AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN; AWS_REGION, else AWS_DEFAULT_REGION, else us-east-1;
# AWS_ENDPOINT_URL_S3, else AWS_ENDPOINT_URL. A custom endpoint is path-style, as MinIO wants; AWS is virtual-hosted.
def from_env() -> IO(Result<&1, &1, Err, Config>):
  do IO<Result<&1, &1, Err, Config>>:
    a : Result<&1, &1, U32 & String, String> <- IO.get_env("AWS_ACCESS_KEY_ID")
    s : Result<&1, &1, U32 & String, String> <- IO.get_env("AWS_SECRET_ACCESS_KEY")
    t : Result<&1, &1, U32 & String, String> <- IO.get_env("AWS_SESSION_TOKEN")
    r : Result<&1, &1, U32 & String, String> <- IO.get_env("AWS_REGION")
    dr : Result<&1, &1, U32 & String, String> <- IO.get_env("AWS_DEFAULT_REGION")
    e3 : Result<&1, &1, U32 & String, String> <- IO.get_env("AWS_ENDPOINT_URL_S3")
    e : Result<&1, &1, U32 & String, String> <- IO.get_env("AWS_ENDPOINT_URL")
    return from_env.of(env(a), env(s), env(t), or(env(r), or(env(dr), "us-east-1")), or(env(e3), env(e)))

# ---- XML

def xml(s: String) -> Maybe<&2, List<&2, Xml.Leaf>>:
  Xml.xml(s)

def fault.of(+status: U32, cm: String & String) -> Err:
  (code, msg) = cm
  ErrS3{status, code, msg}

def fault(+status: U32, m: Maybe<&2, List<&2, Xml.Leaf>>) -> Err:
  fault.of(status, Xml.fault(m))

def ok(+s: U32) -> Bool:
  Bool.and(U32.is_le(200, s), U32.is_lt(s, 300))

def judge.res(good: Bool, +status: U32, h: Map<&2, List<&2, String>>, b: Bytes.Bytes) -> Result<&1, &1, Err, HttpPure.Res>:
  match good:
    case True{}:
      Done{HttpPure.Res{status, h, b}}
    case False{}:
      Fail{fault(status, xml(Enc.utf8.decode(b)))}

def judge(r: Result<&1, &1, Hairpin.Err, HttpPure.Res>) -> Result<&1, &1, Err, HttpPure.Res>:
  match r:
    case Fail{e}:
      Fail{ErrNet{e}}
    case Done{res}:
      HttpPure.Res{+status, h, b} = res
      judge.res(ok(status), status, h, b)

# ---- requests

def stamp.of(m: Maybe<&2, Time.DateTime>) -> String:
  match m:
    case None{}:
      ""
    case Some{Time.DateTime{Time.Date{y, mo, d}, h, mi, s, n}}:
      String.concat([Time.pad(y, 4n), Time.pad(mo, 2n), Time.pad(d, 2n), "T", Time.pad(h, 2n), Time.pad(mi, 2n), Time.pad(s, 2n), "Z"])

# Now as YYYYMMDDTHHMMSSZ. "" only outside years 0 to 9999, which S3 then refuses.
def stamp() -> IO(String):
  do IO<String>:
    now : Time.Instant <- Http.clock.now()
    return stamp.of(Time.DateTime.of_instant(now))

# origin: scheme://host field. host: the Host field, as Http sends it. path: the wire path.
type Where is Data:
  Where{origin: String, host: String, path: String}

# "" for the bucket itself.
def seg(+key: String) -> String:
  Bool.pick(String, String.is_empty(key), "", "/" ++ encode(key, True{}))

def loc.at(style: Style, +bucket: String, +key: String, a: Url.Abs) -> Where:
  match style:
    case Path{}:
      Url.Abs{+scheme, host, port, t} = a
      +field = Url.host_field(Url.Abs{scheme, host, port, "/"})
      Where{scheme ++ "://" ++ field, field, "/" ++ bucket ++ seg(key)}
    case Virtual{}:
      Url.Abs{+scheme, host, port, t} = a
      +field = Url.host_field(Url.Abs{scheme, bucket ++ "." ++ host, port, "/"})
      Where{scheme ++ "://" ++ field, field, or(seg(key), "/")}

def loc(style: Style, +bucket: String, +key: String, m: Maybe<&2, Url.Abs>) -> Maybe<&2, Where>:
  match m:
    case None{}:
      None{}
    case Some{a}:
      Some{loc.at(style, bucket, key, a)}

def token(c: Credentials) -> String:
  Credentials{a, s, t} = c
  t

def with.token(+token: String, +h: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  Bool.pick(Map<&2, List<&2, String>>, String.is_empty(token), h, HttpPure.set(h, "x-amz-security-token", token))

# extra, and the headers the signature covers. Host is Http's own, from the same URL.
def request.signed(extra: Map<&2, List<&2, String>>, date: String, +token: String, got: String & String) -> Map<&2, List<&2, String>>:
  (auth, hash) = got
  with.token(token, HttpPure.set(HttpPure.set(HttpPure.set(HttpPure.set(extra, "x-amz-date", date), "x-amz-content-sha256", hash), "authorization", auth), "accept-encoding", "identity"))

def url(origin: String, path: String, +query: String) -> String:
  origin ++ path ++ Bool.pick(String, String.is_empty(query), "", "?" ++ query)

def call.done(cfg: Config, x: Hairpin.Client & Result<&1, &1, Hairpin.Err, HttpPure.Res>) -> Client & Result<&1, &1, Err, HttpPure.Res>:
  (h, r) = x
  (Client{cfg, h}, judge(r))

# Hairpin's request with the codings "identity": Http then leaves a stored Content-Encoding (gzip, br, ..) as sent,
# so GET returns the object's bytes and HEAD's size matches. ponytail: Http still undoes x-gzip, which S3 rarely stores.
def send.budget(+method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes,
    y: Hairpin.Client & Retry.Budget) -> IO(Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, HttpPure.Res>):
  (h, b) = y
  Hairpin.request.as(~HairpinPure.judge, h, b, HttpPure.pool.idempotent(method), "identity", method, url, headers, body)

def send(c: Hairpin.Client, +method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Hairpin.Client & Result<&1, &1, Hairpin.Err, HttpPure.Res>):
  do IO<Hairpin.Client & Result<&1, &1, Hairpin.Err, HttpPure.Res>>:
    y : Hairpin.Client & Retry.Budget <- Hairpin.budget(c)
    x : Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, HttpPure.Res> <- send.budget(method, url, headers, body, y)
    return Hairpin.request.drop(x)

def call.send(s: Result<&1, &1, U32 & String, String & String>, cfg: Config, http: Hairpin.Client, +method: String, url: String,
    extra: Map<&2, List<&2, String>>, date: String, token: String, body: Bytes.Bytes) -> IO(Client & Result<&1, &1, Err, HttpPure.Res>):
  match s:
    case Fail{e}:
      (code, why) = e
      IO.pure(Client & Result<&1, &1, Err, HttpPure.Res>, (Client{cfg, http}, Fail{ErrSign{code, why}}))
    case Done{got}:
      do IO<Client & Result<&1, &1, Err, HttpPure.Res>>:
        x : Hairpin.Client & Result<&1, &1, Hairpin.Err, HttpPure.Res> <- send(http, method, url, request.signed(extra, date, token, got), body)
        return call.done(cfg, x)

# The signer hashes one copy of the body; the other goes on the wire.
def call.sign(got: Where, +endpoint: String, +region: String, +style: Style, +creds: Credentials,
    http: Hairpin.Client, +method: String, +query: String, extra: Map<&2, List<&2, String>>, +date: String,
    b: Bytes.Bytes & Bytes.Bytes) -> IO(Client & Result<&1, &1, Err, HttpPure.Res>):
  Where{origin, host, +path} = got
  (keep, copy) = b
  do IO<Client & Result<&1, &1, Err, HttpPure.Res>>:
    s : Result<&1, &1, U32 & String, String & String> <- authorize(creds, region, "s3", date, method, path, query, host, copy)
    call.send(s, Config{endpoint, region, style, creds}, http, method, url(origin, path, query), extra, date, token(creds), keep)

def call.at(w: Maybe<&2, Where>, +endpoint: String, +region: String, +style: Style, +creds: Credentials,
    http: Hairpin.Client, +method: String, +query: String, extra: Map<&2, List<&2, String>>, +date: String, body: Bytes.Bytes) ->
    IO(Client & Result<&1, &1, Err, HttpPure.Res>):
  match w:
    case None{}:
      IO.pure(Client & Result<&1, &1, Err, HttpPure.Res>, (Client{Config{endpoint, region, style, creds}, http}, Fail{ErrConfig{"bad endpoint: " ++ endpoint}}))
    case Some{got}:
      call.sign(got, endpoint, region, style, creds, http, method, query, extra, date, Bytes.slice(body, 0, 4294967295))

# Object calls require a bucket and a key. ListObjectsV2 targets the bucket with list-type=2.
# The absolute URL bypasses base resolution, so '.' and '..' in object keys survive.
def call.run(c: Client, +method: String, +bucket: String, +key: String, +query: String, extra: Map<&2, List<&2, String>>,
    body: Bytes.Bytes) -> IO(Client & Result<&1, &1, Err, HttpPure.Res>):
  Client{cfg, http} = c
  Config{+endpoint, +region, +style, +creds} = cfg
  do IO<Client & Result<&1, &1, Err, HttpPure.Res>>:
    date : String <- stamp()
    call.at(loc(style, bucket, key, Url.absolute(endpoint)), endpoint, region, style, creds, http, method, query, extra, date, body)

def call.guard(bad: Bool, c: Client, +method: String, +bucket: String, +key: String, +query: String,
    extra: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Client & Result<&1, &1, Err, HttpPure.Res>):
  match bad:
    case True{}:
      IO.pure(Client & Result<&1, &1, Err, HttpPure.Res>, (c, Fail{ErrConfig{"bucket and object key must not be empty"}}))
    case False{}:
      call.run(c, method, bucket, key, query, extra, body)

def call(c: Client, +method: String, +bucket: String, +key: String, +query: String, extra: Map<&2, List<&2, String>>,
    body: Bytes.Bytes) -> IO(Client & Result<&1, &1, Err, HttpPure.Res>):
  call.guard(Bool.or(String.is_empty(bucket), Bool.and(String.is_empty(key), String.is_empty(query))),
    c, method, bucket, key, query, extra, body)

# ---- operations

def etag.of(r: Result<&1, &1, Err, HttpPure.Res>) -> Result<&1, &1, Err, String>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{res}:
      HttpPure.Res{s, +h, b} = res
      Done{HttpPure.header(h, "etag")}

def put.done(x: Client & Result<&1, &1, Err, HttpPure.Res>) -> Client & Result<&1, &1, Err, String>:
  (c, r) = x
  (c, etag.of(r))

# PutObject. mime: Content-Type, "" for none. The ETag comes back.
def put(c: Client, bucket: String, key: String, +mime: String, body: Bytes.Bytes) -> IO(Client & Result<&1, &1, Err, String>):
  +h = Bool.pick(Map<&2, List<&2, String>>, String.is_empty(mime), HttpPure.empty(), HttpPure.set(HttpPure.empty(), "content-type", mime))
  do IO<Client & Result<&1, &1, Err, String>>:
    x : Client & Result<&1, &1, Err, HttpPure.Res> <- call(c, "PUT", bucket, key, "", h, body)
    return put.done(x)

def xgzip.values(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{v, t}:
      Bool.or(String.eq(String.to_lower(String.trim(v)), "x-gzip"), xgzip.values(t))

def xgzip.fields(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{v, t}:
      Bool.or(xgzip.values(String.split(v, ',')), xgzip.fields(t))

def body.encoding(gzip: Bool, b: Bytes.Bytes) -> Result<&1, &1, Err, Bytes.Bytes>:
  match gzip:
    case True{}:
      Fail{ErrConfig{"Hairpin decodes x-gzip objects; their stored bytes are unavailable"}}
    case False{}:
      Done{b}

def body.of(r: Result<&1, &1, Err, HttpPure.Res>) -> Result<&1, &1, Err, Bytes.Bytes>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{res}:
      HttpPure.Res{s, h, b} = res
      body.encoding(xgzip.fields(HttpPure.fields(h, "content-encoding")), b)

def get.done(x: Client & Result<&1, &1, Err, HttpPure.Res>) -> Client & Result<&1, &1, Err, Bytes.Bytes>:
  (c, r) = x
  (c, body.of(r))

# GetObject: the object's bytes. A missing key is ErrS3{404, "NoSuchKey", ..}.
# ponytail: Hairpin decodes x-gzip; reject it rather than return bytes that differ from the stored object.
def get(c: Client, bucket: String, key: String) -> IO(Client & Result<&1, &1, Err, Bytes.Bytes>):
  do IO<Client & Result<&1, &1, Err, Bytes.Bytes>>:
    x : Client & Result<&1, &1, Err, HttpPure.Res> <- call(c, "GET", bucket, key, "", HttpPure.empty(), Bytes.new(0))
    return get.done(x)

def nat(s: String) -> Nat:
  Maybe.default(&2, Nat, Nat.read(s), 0n)

def meta.of(r: Result<&1, &1, Err, HttpPure.Res>) -> Result<&1, &1, Err, Meta>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{res}:
      HttpPure.Res{s, +h, b} = res
      Done{Meta{nat(HttpPure.header(h, "content-length")), HttpPure.header(h, "etag"), HttpPure.header(h, "content-type"), HttpPure.header(h, "last-modified")}}

def head.done(x: Client & Result<&1, &1, Err, HttpPure.Res>) -> Client & Result<&1, &1, Err, Meta>:
  (c, r) = x
  (c, meta.of(r))

# HeadObject. A missing key is ErrS3{404, "", ""}: HEAD has no error body.
def head(c: Client, bucket: String, key: String) -> IO(Client & Result<&1, &1, Err, Meta>):
  do IO<Client & Result<&1, &1, Err, Meta>>:
    x : Client & Result<&1, &1, Err, HttpPure.Res> <- call(c, "HEAD", bucket, key, "", HttpPure.empty(), Bytes.new(0))
    return head.done(x)

def unit.of(r: Result<&1, &1, Err, HttpPure.Res>) -> Result<&1, &1, Err, Unit>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{res}:
      Done{Unit{}}

def delete.done(x: Client & Result<&1, &1, Err, HttpPure.Res>) -> Client & Result<&1, &1, Err, Unit>:
  (c, r) = x
  (c, unit.of(r))

# DeleteObject. S3 answers 204 for a key that was never there too.
def delete(c: Client, bucket: String, key: String) -> IO(Client & Result<&1, &1, Err, Unit>):
  do IO<Client & Result<&1, &1, Err, Unit>>:
    x : Client & Result<&1, &1, Err, HttpPure.Res> <- call(c, "DELETE", bucket, key, "", HttpPure.empty(), Bytes.new(0))
    return delete.done(x)

# ---- ListObjectsV2

def object(key: String, size: Nat, etag: String, modified: String) -> Object:
  Object{key, size, etag, modified}

def page.result(m: Maybe<&2, Xml.Page<Object>>, s: String) -> Result<&1, &1, Err, Page>:
  match m:
    case None{}:
      Fail{ErrXml{s}}
    case Some{Xml.Page{objects, prefixes, next}}:
      Done{Page{objects, prefixes, next}}

def page.doc(+s: String, m: Maybe<&2, List<&2, Xml.Leaf>>) -> Result<&1, &1, Err, Page>:
  page.result(Xml.page(~Object, ~object, m), s)

def page.of(r: Result<&1, &1, Err, HttpPure.Res>) -> Result<&1, &1, Err, Page>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{res}:
      HttpPure.Res{s, h, b} = res
      +text = Enc.utf8.decode(b)
      page.doc(text, xml(text))

def list.done(x: Client & Result<&1, &1, Err, HttpPure.Res>) -> Client & Result<&1, &1, Err, Page>:
  (c, r) = x
  (c, page.of(r))

def q.kv(k: String, +v: String) -> String:
  k ++ "=" ++ encode(v, False{})

def q.opt(k: String, +v: String, +rest: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, String.is_empty(v), rest, Con{q.kv(k, v), rest})

def q.token(t: Maybe<&2, String>, rest: List<&2, String>) -> List<&2, String>:
  match t:
    case None{}:
      rest
    case Some{v}:
      Con{q.kv("continuation-token", v), rest}

def q.max(+n: U32) -> List<&2, String>:
  Bool.pick(List<&2, String>, U32.is_eq(n, 0), Nil{}, ["max-keys=" ++ U32.show(n)])

# In the signer's order: continuation-token, delimiter, list-type, max-keys, prefix.
def list.query(prefix: String, delim: String, +max: U32, t: Maybe<&2, String>) -> String:
  String.join(q.token(t, q.opt("delimiter", delim, Con{"list-type=2", List.append(&2, String, q.max(max), q.opt("prefix", prefix, Nil{}))})), "&")

# One page of ListObjectsV2. prefix, delim: "" for none. max: keys per page, 0 for S3's 1000. token: a page's next.
def list(c: Client, +bucket: String, prefix: String, delim: String, +max: U32, token: Maybe<&2, String>) ->
    IO(Client & Result<&1, &1, Err, Page>):
  do IO<Client & Result<&1, &1, Err, Page>>:
    x : Client & Result<&1, &1, Err, HttpPure.Res> <- call(c, "GET", bucket, "", list.query(prefix, delim, max, token), HttpPure.empty(), Bytes.new(0))
    return list.done(x)

def all.merge(objs: List<&2, Object>, pre: List<&2, String>, r: Result<&1, &1, Err, Page>) -> Result<&1, &1, Err, Page>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{Page{os, ps, next}}:
      Done{Page{List.append(&2, Object, objs, os), List.append(&2, String, pre, ps), next}}

# f: pages left. When they run out, next holds the token to go on from.
def all.go(f: Nat, +bucket: String, +prefix: String, +delim: String, +max: U32, objs: List<&2, Object>, pre: List<&2, String>,
    x: Client & Result<&1, &1, Err, Page>) -> IO(Client & Result<&1, &1, Err, Page>):
  match f:
    case 0n:
      (c, r) = x
      IO.pure(Client & Result<&1, &1, Err, Page>, (c, all.merge(objs, pre, r)))
    case 1n+g:
      (c, r) = x
      match r:
        case Fail{e}:
          IO.pure(Client & Result<&1, &1, Err, Page>, (c, Fail{e}))
        case Done{Page{os, ps, next}}:
          match next:
            case None{}:
              IO.pure(Client & Result<&1, &1, Err, Page>, (c, Done{Page{List.append(&2, Object, objs, os), List.append(&2, String, pre, ps), None{}}}))
            case Some{tok}:
              do IO<Client & Result<&1, &1, Err, Page>>:
                y : Client & Result<&1, &1, Err, Page> <- list(c, bucket, prefix, delim, max, Some{tok})
                all.go(g, bucket, prefix, delim, max, List.append(&2, Object, objs, os), List.append(&2, String, pre, ps), y)

# Every page, following NextContinuationToken, up to 100000 pages.
def list.all(c: Client, +bucket: String, +prefix: String, +delim: String, +max: U32) -> IO(Client & Result<&1, &1, Err, Page>):
  do IO<Client & Result<&1, &1, Err, Page>>:
    x : Client & Result<&1, &1, Err, Page> <- list(c, bucket, prefix, delim, max, None{})
    all.go(U32.to_nat(100000), bucket, prefix, delim, max, Nil{}, Nil{}, x)
