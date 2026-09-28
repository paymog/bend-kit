# Hairpin: an HTTP client with a base URL, default headers, a pool, cookies, mTLS, redirects, and retries. Source: https://github.com/paymog/bend-kit/tree/main/hairpin
import Base
import bend-kit-http@0.23.0.1/http.bend as Http
import bend-kit-time@0.1.0.0/time.bend as Time
# By hash, as http imports them: bend-kit-url@0.4.1.0, -json@0.5.0.1, -bytes@0.3.0.0.
import 0x1f2d80f53f971b16c6de6a65cb1918ae/url.bend as Url
import 0x584fc27920487ceab242392391418d7f/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# base: "" for none. headers: lowercase names. ms: the step timeout. retries: extra tries for idempotent methods.
type Opts is Data:
  Opts{base: String, headers: Map<&2, List<&2, String>>, ms: U32, mode: Http.Mode, retries: U32, cert: Maybe<&2, Http.Cert>}

type Client is Type:
  Client{opts: Opts, pool: Http.Pool, jar: Maybe<&2, Http.Jar>}

# A pool of up to cap idle sockets per origin, no base, no default headers, 30 s steps, follow redirects, no retries.
def new.with(+cap: U32) -> Client:
  Client{Opts{"", Http.empty(), 30000, Http.ModeFollow{}, 0, None{}}, Http.pool.new.with(cap), None{}}

def new() -> Client:
  new.with(8)

def base(c: Client, url: String) -> Client:
  Client{Opts{b, h, ms, mode, n, cert}, p, j} = c
  Client{Opts{url, h, ms, mode, n, cert}, p, j}

# A default header. It replaces an earlier default of the same name; a request header of that name replaces it.
def header(c: Client, k: String, v: String) -> Client:
  Client{Opts{b, h, ms, mode, n, cert}, p, j} = c
  Client{Opts{b, Http.set(h, String.to_lower(k), v), ms, mode, n, cert}, p, j}

def timeout(c: Client, ms: U32) -> Client:
  Client{Opts{b, h, old, mode, n, cert}, p, j} = c
  Client{Opts{b, h, ms, mode, n, cert}, p, j}

def redirect(c: Client, mode: Http.Mode) -> Client:
  Client{Opts{b, h, ms, old, n, cert}, p, j} = c
  Client{Opts{b, h, ms, mode, n, cert}, p, j}

def retry(c: Client, n: U32) -> Client:
  Client{Opts{b, h, ms, mode, old, cert}, p, j} = c
  Client{Opts{b, h, ms, mode, n, cert}, p, j}

# Paths to a PEM client chain and its private key, presented to every HTTPS origin.
def cert(c: Client, chain: String, key: String) -> Client:
  Client{Opts{b, h, ms, mode, n, old}, p, j} = c
  Client{Opts{b, h, ms, mode, n, Some{Http.Cert{chain, key}}}, p, j}

# Every request stores and sends cookies through jar. Its clock moves to Time.now() before each try.
def jar(c: Client, jar: Http.Jar) -> Client:
  Client{o, p, old} = c
  Client{o, p, Some{jar}}

# The jar, if the client has one.
def jar.of(c: Client) -> Client & Maybe<&2, Http.Jar>:
  Client{o, p, +j} = c
  (Client{o, p, j}, j)

def close(c: Client) -> IO(Unit):
  Client{o, p, j} = c
  Http.pool.close(p)

def target.pick(none: Bool, b: String, ref: String) -> Maybe<&2, String>:
  match none:
    case True{}:
      Some{ref}
    case False{}:
      Http.resolve(b, ref)

# ref against the base (RFC 3986 §5.2); with no base, ref as given. None when the base is not absolute.
def target(+b: String, ref: String) -> Maybe<&2, String>:
  target.pick(String.is_empty(b), b, ref)

def target.abs(m: Maybe<&2, String>) -> Maybe<&2, Url.Abs>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      Url.absolute(s)

# The defaults under the request headers, names lowercased; a request header replaces a default of its name.
# Host, Connection, Content-Length, and Transfer-Encoding are the client's own, so both sides drop them.
def merge(defaults: Map<&2, List<&2, String>>, headers: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  Http.req.put(Map.to_list(&2, List<&2, String>, headers), Http.req.put(Map.to_list(&2, List<&2, String>, defaults), Http.empty()))

def jar.now(j: Maybe<&2, Http.Jar>) -> IO(Maybe<&2, Http.Jar>):
  match j:
    case None{}:
      IO.pure(Maybe<&2, Http.Jar>, None{})
    case Some{jar}:
      do IO<Maybe<&2, Http.Jar>>:
        now : Time.Instant <- Time.now()
        return Some{Http.jar.at(jar, now)}

def once.final(+enc: String, x: Http.Pool & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, Http.Jar>) ->
    IO(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>):
  (p, r, j) = x
  do IO<Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>>:
    d : Result<&1, &1, Http.Err, Http.Res> <- Http.fetch.final(enc, r)
    return (p, j, d)

# One try: the redirect loop on the pool, with the jar and the certificate, then the body decoded.
def once(+ms: U32, +mode: Http.Mode, +cert: Maybe<&2, Http.Cert>, +enc: String, p: Http.Pool, j: Maybe<&2, Http.Jar>,
    +method: String, +u: Maybe<&2, Url.Abs>, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>):
  do IO<Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>>:
    now : Maybe<&2, Http.Jar> <- jar.now(j)
    x : Http.Pool & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, Http.Jar> <-
      Http.pool.hops(mode, ms, Http.Hops{p, Http.fetch.start(method, headers, body, u, enc), cert, now})
    once.final(enc, x)

def try.kept(p: Http.Pool, j: Maybe<&2, Http.Jar>, body: Bytes.Bytes,
    r: Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>) ->
    Http.Pool & Maybe<&2, Http.Jar> & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>:
  (res, again) = r
  (p, j, body, res, again)

def try.judged(+idem: Bool, body: Bytes.Bytes, x: Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>) ->
    Http.Pool & Maybe<&2, Http.Jar> & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>:
  (p, j, r) = x
  try.kept(p, j, body, Http.retry.judge(idem, r))

# One try of the spare copy. The body comes back for the next try, with Some{Retry-After} when another may help.
def try(+o: Opts, +enc: String, +idem: Bool, +method: String, +u: Maybe<&2, Url.Abs>, +headers: Map<&2, List<&2, String>>,
    p: Http.Pool, j: Maybe<&2, Http.Jar>, r: Bytes.Bytes & Bytes.Bytes) ->
    IO(Http.Pool & Maybe<&2, Http.Jar> & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>):
  Opts{b, h, +ms, +mode, n, +cert} = o
  (body, spare) = r
  do IO<Http.Pool & Maybe<&2, Http.Jar> & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>>:
    x : Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res> <- once(ms, mode, cert, enc, p, j, method, u, headers, spare)
    return try.judged(idem, body, x)

# left: retries still allowed. n: the retry to wait for next, 0 first. The wait is the fetch.retry policy.
def go(left: Nat, +n: Nat, +o: Opts, +enc: String, +idem: Bool, +method: String, +u: Maybe<&2, Url.Abs>,
    +headers: Map<&2, List<&2, String>>,
    t: Http.Pool & Maybe<&2, Http.Jar> & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>) ->
    IO(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>):
  match left:
    case 0n:
      (p, j, body, r, m) = t
      IO.pure(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>, (p, j, r))
    case 1n+rest:
      (p, j, body, r, m) = t
      match m:
        case None{}:
          IO.pure(Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>, (p, j, r))
        case Some{v}:
          do IO<Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>>:
            Http.retry.sleep(v, n)
            tried : Http.Pool & Maybe<&2, Http.Jar> & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String> <-
              try(o, enc, idem, method, u, headers, p, j, Bytes.slice(body, 0, 4294967295))
            go(rest, 1n+n, o, enc, idem, method, u, headers, tried)

def request.done(+o: Opts, x: Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res>) ->
    Client & Result<&1, &1, Http.Err, Http.Res>:
  (p, j, r) = x
  (Client{o, p, j}, r)

def request.go(+o: Opts, +retries: U32, +enc: String, p: Http.Pool, j: Maybe<&2, Http.Jar>, +method: String,
    +u: Maybe<&2, Url.Abs>, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Client & Result<&1, &1, Http.Err, Http.Res>):
  +idem = Http.pool.idempotent(method)
  do IO<Client & Result<&1, &1, Http.Err, Http.Res>>:
    first : Http.Pool & Maybe<&2, Http.Jar> & Bytes.Bytes & Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String> <-
      try(o, enc, idem, method, u, headers, p, j, Bytes.slice(body, 0, 4294967295))
    x : Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Res> <- go(U32.to_nat(retries), 0n, o, enc, idem, method, u, headers, first)
    return request.done(o, x)

# url resolves against the base; headers go over the defaults. Redirects follow the client's mode, at most 20.
# GET, HEAD, OPTIONS, TRACE, PUT, and DELETE retry after a connect error, a timeout, or 408, 429, 500, 502, 503,
# or 504, as Http.fetch.retry does, on the same pool. When retries run out, the last result comes back.
def request(c: Client, +method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Client & Result<&1, &1, Http.Err, Http.Res>):
  Client{+o, p, j} = c
  Opts{+b, +h, ms, mode, +n, cert} = o
  do IO<Client & Result<&1, &1, Http.Err, Http.Res>>:
    enc : String <- Http.codings()
    request.go(o, n, enc, p, j, method, target.abs(target(b, url)), merge(h, headers), body)

def get(c: Client, url: String) -> IO(Client & Result<&1, &1, Http.Err, Http.Res>):
  request(c, "GET", url, Http.empty(), Bytes.new(0))

# POST v as compact JSON, with content-type: application/json.
def post.json(c: Client, url: String, v: Json.Val) -> IO(Client & Result<&1, &1, Http.Err, Http.Res>):
  request(c, "POST", url, Http.set(Http.empty(), "content-type", "application/json"), Json.encode.bytes(v))
