# SCRAM-SHA-256 (RFC 5802, RFC 7677) client for PostgreSQL SASL authentication, without channel binding.
import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import bend-kit-crypto@0.1.1.0/crypto.bend as Crypto

# Messages and keys are byte strings, one Char per octet. The password is its octets
# (UTF-8), used as is: no SASLprep, which is the same as libpq for ASCII passwords.
#   (st, msg) : First & String <- first(user)          -> SASLInitialResponse
#   (fin, msg) : Final & String <- respond(st, sf, pw)  -> SASLResponse
#   verify(fin, server_final)                           -> Done{Unit{}} or Fail
# Errors: 22 for a malformed server message, 13 for a server error or a wrong server
# signature, else the crypto effect's errno.

def mechanism() -> String:
  "SCRAM-SHA-256"

# bare: client-first-message-bare. nonce: the client nonce.
type First is Data:
  First{bare: String, nonce: String}

# sig: the ServerSignature the server-final-message must carry.
type Final is Data:
  Final{sig: String}

# nonce: the combined nonce. salt: decoded octets. iters: at least 1.
type Parsed is Data:
  Parsed{nonce: String, salt: String, iters: U32}

# saslname (RFC 5802 §5.1): '=' as "=3D", ',' as "=2C".
def saslname.of(+c: U32, +rest: String) -> String:
  Bool.pick(String, U32.is_eq(c, 61), "=3D" ++ rest, Bool.pick(String, U32.is_eq(c, 44), "=2C" ++ rest, SCon{Chr{c}, rest}))

def saslname(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, t}:
      saslname.of(c, saslname(t))

# The client-first-message for a nonce: gs2 header "n,," (no channel binding), then the bare part.
def first.with(+user: String, +nonce: String) -> First & String:
  +bare = "n=" ++ saslname(user) ++ ",r=" ++ nonce
  (First{bare, nonce}, "n,," ++ bare)

def first.of(+user: String, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, U32 & String, First & String>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{(len, buf)}:
      Done{first.with(user, Bytes.to_base64(Bytes.Bytes{len, buf}))}

# A fresh 18-octet nonce from the OS secure random source, base64 (24 printable chars, no ',').
def first(+user: String) -> IO(Result<&1, &1, U32 & String, First & String>):
  do IO<Result<&1, &1, U32 & String, First & String>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Crypto.random.words(18)
    return first.of(user, r)

# server-first-message (RFC 5802 §7): r=nonce,s=salt,i=iterations, then extensions, which are ignored.

# The value of attribute name, when s is name=value.
def attr(+name: U32, s: String) -> Maybe<&2, String>:
  match s:
    case SCon{Chr{+c}, SCon{'=', v}}:
      Bool.pick(Maybe<&2, String>, U32.is_eq(c, name), Some{v}, None{})
    case _:
      None{}

# printable (RFC 5802 §7): %x21-2B / %x2D-7E.
def printable(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.and(U32.is_le(33, c), U32.is_le(c, 126)), Bool.and(U32.is_ne(c, 44), printable(t)))

def digits(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.and(U32.is_le(48, c), U32.is_le(c, 57)), digits(t))

# The server nonce must be the client nonce plus at least one more printable char.
def nonce.ok(+client: String, +server: String) -> Bool:
  Bool.and(Bool.and(String.starts_with(server, client), Nat.is_lt(String.length(client), String.length(server))), printable(server))

def parse.iters(ok: Bool, m: Maybe<&2, U32>, +nonce: String, +salt: String) -> Result<&1, &1, U32 & String, Parsed>:
  match ok m:
    case True{} Some{+i}:
      Bool.pick(Result<&1, &1, U32 & String, Parsed>, U32.is_eq(i, 0), Fail{(22, "SCRAM iteration count is 0")}, Done{Parsed{nonce, salt, i}})
    case _ _:
      Fail{(22, "SCRAM iteration count is not a decimal U32")}

def parse.salt.of(empty: Bool, +nonce: String, +salt: String, +it: String) -> Result<&1, &1, U32 & String, Parsed>:
  match empty:
    case True{}:
      Fail{(22, "SCRAM salt is empty")}
    case False{}:
      parse.iters(Bool.and(Bool.not(String.is_empty(it)), digits(it)), U32.read(it), nonce, salt)

def parse.salt(m: Maybe<&1, Bytes.Bytes>, +nonce: String, +it: String) -> Result<&1, &1, U32 & String, Parsed>:
  match m:
    case None{}:
      Fail{(22, "SCRAM salt is not base64")}
    case Some{b}:
      +salt = Bytes.to_string(b)
      parse.salt.of(String.is_empty(salt), nonce, salt, it)

def parse.nonce(ok: Bool, +nonce: String, +salt: String, +it: String) -> Result<&1, &1, U32 & String, Parsed>:
  match ok:
    case False{}:
      Fail{(22, "SCRAM server nonce does not extend the client nonce")}
    case True{}:
      parse.salt(Bytes.from_base64(salt), nonce, it)

def parse.fields(+client: String, r: Maybe<&2, String>, s: Maybe<&2, String>, i: Maybe<&2, String>) -> Result<&1, &1, U32 & String, Parsed>:
  match r s i:
    case Some{+nonce} Some{+salt} Some{+it}:
      parse.nonce(nonce.ok(client, nonce), nonce, salt, it)
    case _ _ _:
      Fail{(22, "server-first-message is not r=,s=,i=")}

def parse.parts(+client: String, parts: List<&2, String>) -> Result<&1, &1, U32 & String, Parsed>:
  match parts:
    case Con{+r, Con{+s, Con{+i, rest}}}:
      parse.fields(client, attr(114, r), attr(115, s), attr(105, i))
    case _:
      Fail{(22, "server-first-message is not r=,s=,i=")}

# The server-first-message checked against the client nonce.
def parse(+client: String, +msg: String) -> Result<&1, &1, U32 & String, Parsed>:
  parse.parts(client, String.split(msg, ','))

# Crypto over byte strings.

def octets(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, U32 & String, String>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{(len, buf)}:
      Done{Bytes.to_string(Bytes.Bytes{len, buf})}

def hmac.of(k: Bytes.Bytes, d: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{kl, kw} = k
  Bytes.Bytes{dl, dw} = d
  Crypto.hmac.words("SHA256", kl, kw, dl, dw)

def hmac(+key: String, +data: String) -> IO(Result<&1, &1, U32 & String, String>):
  do IO<Result<&1, &1, U32 & String, String>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- hmac.of(Bytes.from_string(key), Bytes.from_string(data))
    return octets(r)

def sha.of(b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{len, buf} = b
  Crypto.sha256.words(len, buf)

def sha(+data: String) -> IO(Result<&1, &1, U32 & String, String>):
  do IO<Result<&1, &1, U32 & String, String>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- sha.of(Bytes.from_string(data))
    return octets(r)

def pbkdf2.of(p: Bytes.Bytes, s: Bytes.Bytes, +iters: U32) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{pl, pw} = p
  Bytes.Bytes{sl, sw} = s
  Crypto.pbkdf2.words("SHA256", pl, pw, sl, sw, iters, 32)

# SaltedPassword = Hi(pass, salt, iters) (RFC 5802 §2.2), which is PBKDF2 with HMAC-SHA-256.
def pbkdf2(+pass: String, +salt: String, +iters: U32) -> IO(Result<&1, &1, U32 & String, String>):
  do IO<Result<&1, &1, U32 & String, String>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- pbkdf2.of(Bytes.from_string(pass), Bytes.from_string(salt), iters)
    return octets(r)

def eq.of(a: Bytes.Bytes, b: Bytes.Bytes) -> IO(Bool):
  Bytes.Bytes{al, aw} = a
  Bytes.Bytes{bl, bw} = b
  Crypto.eq.ct.words(al, aw, bl, bw)

def xor(a: String, b: String) -> String:
  match a b:
    case SCon{Chr{+x}, at} SCon{Chr{+y}, bt}:
      SCon{Chr{(x .^. y : U32)}, xor(at, bt)}
    case _ _:
      SNil{}

# client-final-message (RFC 5802 §3, §7).

def step.of(r: Result<&1, &1, U32 & String, String>, k: String -> IO(Result<&1, &1, U32 & String, Final & String>)) -> IO(Result<&1, &1, U32 & String, Final & String>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, U32 & String, Final & String>, Fail{e})
    case Done{s}:
      k(s)

def step(m: IO(Result<&1, &1, U32 & String, String>), k: String -> IO(Result<&1, &1, U32 & String, Final & String>)) -> IO(Result<&1, &1, U32 & String, Final & String>):
  do IO<Result<&1, &1, U32 & String, Final & String>>:
    r : Result<&1, &1, U32 & String, String> <- m
    step.of(r, k)

# c=biws is base64 of the gs2 header "n,,". AuthMessage joins the three bare messages.
def respond.of(r: Result<&1, &1, U32 & String, Parsed>, +bare: String, +sf: String, +pass: String) -> IO(Result<&1, &1, U32 & String, Final & String>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, U32 & String, Final & String>, Fail{e})
    case Done{Parsed{+nonce, +salt, +iters}}:
      +fb = "c=biws,r=" ++ nonce
      +auth = bare ++ "," ++ sf ++ "," ++ fb
      step(pbkdf2(pass, salt, iters), +salted =>
        step(hmac(salted, "Client Key"), +ck =>
          step(sha(ck), +sk =>
            step(hmac(sk, auth), +cs =>
              step(hmac(salted, "Server Key"), +svk =>
                step(hmac(svk, auth), +ss =>
                  IO.pure(Result<&1, &1, U32 & String, Final & String>, Done{(Final{ss}, fb ++ ",p=" ++ Bytes.to_base64(Bytes.from_string(xor(ck, cs))))})))))))

# The client-final-message with ClientProof for the server-first-message sf and the password.
def respond(st: First, +sf: String, +pass: String) -> IO(Result<&1, &1, U32 & String, Final & String>):
  First{+bare, +client} = st
  respond.of(parse(client, sf), bare, sf, pass)

# server-final-message (RFC 5802 §7): v=signature or e=error, then extensions, which are ignored.

def final.sig(m: Maybe<&1, Bytes.Bytes>) -> Result<&1, &1, U32 & String, String>:
  match m:
    case None{}:
      Fail{(22, "SCRAM server signature is not base64")}
    case Some{b}:
      Done{Bytes.to_string(b)}

def final.attr(s: String) -> Result<&1, &1, U32 & String, String>:
  match s:
    case SCon{'v', SCon{'=', v}}:
      final.sig(Bytes.from_base64(v))
    case SCon{'e', SCon{'=', e}}:
      Fail{(13, "SCRAM server error: " ++ e)}
    case _:
      Fail{(22, "server-final-message is not v= or e=")}

def final.parts(parts: List<&2, String>) -> Result<&1, &1, U32 & String, String>:
  match parts:
    case Con{f, rest}:
      final.attr(f)
    case Nil{}:
      Fail{(22, "server-final-message is not v= or e=")}

def verify.ok(ok: Bool) -> Result<&1, &1, U32 & String, Unit>:
  match ok:
    case True{}:
      Done{Unit{}}
    case False{}:
      Fail{(13, "SCRAM server signature does not match")}

def verify.of(+sig: String, r: Result<&1, &1, U32 & String, String>) -> IO(Result<&1, &1, U32 & String, Unit>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, U32 & String, Unit>, Fail{e})
    case Done{+got}:
      do IO<Result<&1, &1, U32 & String, Unit>>:
        ok : Bool <- eq.of(Bytes.from_string(sig), Bytes.from_string(got))
        return verify.ok(ok)

# Done when the server-final-message proves the server knows the password, compared in constant time.
def verify(st: Final, +msg: String) -> IO(Result<&1, &1, U32 & String, Unit>):
  Final{+sig} = st
  verify.of(sig, final.parts(String.split(msg, ',')))
