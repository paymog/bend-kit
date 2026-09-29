import Base
import ./crypto.bend as C
import ../bytes/bytes.bend as Bytes

def from.hex.of(m: Maybe<&1, Bytes.Bytes>) -> Bytes.Bytes:
  match m:
    case None{}:
      Bytes.from_string("")
    case Some{b}:
      b

def from.hex(s: String) -> Bytes.Bytes:
  from.hex.of(Bytes.from_hex(s))

# NIST GCM AES-256 zero-key vector and RFC 8439 section 2.8.2.
def aes.key() -> Bytes.Bytes:
  from.hex(String.repeat("00", 32n))

def aes.nonce() -> Bytes.Bytes:
  from.hex(String.repeat("00", 12n))

def chacha.key() -> Bytes.Bytes:
  from.hex("808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f")

def chacha.nonce() -> Bytes.Bytes:
  from.hex("070000004041424344454647")

def chacha.aad() -> Bytes.Bytes:
  from.hex("50515253c0c1c2c3c4c5c6c7")

def chacha.plain() -> Bytes.Bytes:
  Bytes.from_string("Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.")

def chacha.sealed() -> Bytes.Bytes:
  from.hex("d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc3ff4def08e4b7a9de576d26586cec64b61161ae10b594f09e26a7e902ecbd0600691")

def seal(alg: String, k: Bytes.Bytes, n: Bytes.Bytes, a: Bytes.Bytes, p: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{kn, kw} = k
  Bytes.Bytes{nn, nw} = n
  Bytes.Bytes{an, aw} = a
  Bytes.Bytes{pn, pw} = p
  C.aead.seal.words(alg, kn, kw, nn, nw, an, aw, pn, pw)

def open(alg: String, k: Bytes.Bytes, n: Bytes.Bytes, a: Bytes.Bytes, c: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{kn, kw} = k
  Bytes.Bytes{nn, nw} = n
  Bytes.Bytes{an, aw} = a
  Bytes.Bytes{cn, cw} = c
  C.aead.open.words(alg, kn, kw, nn, nw, an, aw, cn, cw)

def verified(ok: Bool, name: String, got: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, name ++ " gave " ++ got)

def rejected(ok: Bool, name: String, code: U32, why: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, name ++ " failed with " ++ U32.show(code) ++ " " ++ why)

def matches(+name: String, +want: String, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{(code, why)}:
      IO.die(Unit, 1, name ++ " failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{(len, words)}:
      +got = Bytes.to_hex(Bytes.Bytes{len, words})
      verified(String.eq(got, want), name, got)

def rejects(+name: String, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      rejected(U32.is_eq(code, 22), name, code, why)
    case Done{(len, words)}:
      IO.die(Unit, 1, name ++ " released unauthenticated data")

def run() -> IO(Unit):
  do IO<Unit>:
    a : Result<&1, &1, U32 & String, U32 & Array<U32>> <- seal("AES-256-GCM", aes.key(), aes.nonce(), Bytes.from_string(""), from.hex(String.repeat("00", 16n)))
    matches("NIST AES-256-GCM", "cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919", a)
    b : Result<&1, &1, U32 & String, U32 & Array<U32>> <- open("AES-256-GCM", aes.key(), aes.nonce(), Bytes.from_string(""), from.hex("cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919"))
    matches("NIST AES-256-GCM open", String.repeat("00", 16n), b)
    empty : Result<&1, &1, U32 & String, U32 & Array<U32>> <- seal("AES-256-GCM", aes.key(), aes.nonce(), Bytes.from_string(""), Bytes.from_string(""))
    matches("AES empty plaintext", "530f8afbc74536b9a963b4f1c4cb738b", empty)
    empty_open : Result<&1, &1, U32 & String, U32 & Array<U32>> <- open("AES-256-GCM", aes.key(), aes.nonce(), Bytes.from_string(""), from.hex("530f8afbc74536b9a963b4f1c4cb738b"))
    matches("AES empty open", "", empty_open)
    empty_bad : Result<&1, &1, U32 & String, U32 & Array<U32>> <- open("AES-256-GCM", aes.key(), aes.nonce(), Bytes.from_string(""), from.hex("530f8afbc74536b9a963b4f1c4cb738a"))
    rejects("AES empty tag changed", empty_bad)
    c : Result<&1, &1, U32 & String, U32 & Array<U32>> <- seal("CHACHA20-POLY1305", chacha.key(), chacha.nonce(), chacha.aad(), chacha.plain())
    matches("RFC 8439 seal", Bytes.to_hex(chacha.sealed()), c)
    d : Result<&1, &1, U32 & String, U32 & Array<U32>> <- open("CHACHA20-POLY1305", chacha.key(), chacha.nonce(), chacha.aad(), chacha.sealed())
    matches("RFC 8439 open", Bytes.to_hex(chacha.plain()), d)
    e : Result<&1, &1, U32 & String, U32 & Array<U32>> <- open("AES-256-GCM", aes.key(), aes.nonce(), Bytes.from_string(""), from.hex("cfa7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919"))
    rejects("AES ciphertext changed", e)
    f : Result<&1, &1, U32 & String, U32 & Array<U32>> <- open("AES-256-GCM", aes.key(), aes.nonce(), Bytes.from_string(""), from.hex("cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab918"))
    rejects("AES tag changed", f)
    g : Result<&1, &1, U32 & String, U32 & Array<U32>> <- open("AES-256-GCM", aes.key(), from.hex("010000000000000000000000"), Bytes.from_string(""), from.hex("cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919"))
    rejects("AES nonce changed", g)
    h : Result<&1, &1, U32 & String, U32 & Array<U32>> <- open("CHACHA20-POLY1305", chacha.key(), chacha.nonce(), chacha.aad(), from.hex("d21a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc3ff4def08e4b7a9de576d26586cec64b61161ae10b594f09e26a7e902ecbd0600691"))
    rejects("RFC ciphertext changed", h)
    i : Result<&1, &1, U32 & String, U32 & Array<U32>> <- open("CHACHA20-POLY1305", chacha.key(), chacha.nonce(), chacha.aad(), from.hex("d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc3ff4def08e4b7a9de576d26586cec64b61161ae10b594f09e26a7e902ecbd0600690"))
    rejects("RFC tag changed", i)
    j : Result<&1, &1, U32 & String, U32 & Array<U32>> <- open("CHACHA20-POLY1305", chacha.key(), from.hex("070000004041424344454646"), chacha.aad(), chacha.sealed())
    rejects("RFC nonce changed", j)
    k : Result<&1, &1, U32 & String, U32 & Array<U32>> <- open("CHACHA20-POLY1305", chacha.key(), chacha.nonce(), from.hex("50515253c0c1c2c3c4c5c6c6"), chacha.sealed())
    rejects("RFC AAD changed", k)
    l : Result<&1, &1, U32 & String, U32 & Array<U32>> <- open("AES-256-GCM", aes.key(), aes.nonce(), Bytes.from_string(""), Bytes.from_string("short"))
    rejects("short tag", l)
    m : Result<&1, &1, U32 & String, U32 & Array<U32>> <- seal("AES-256-GCM", Bytes.from_string("short"), aes.nonce(), Bytes.from_string(""), Bytes.from_string(""))
    rejects("short key", m)
    n : Result<&1, &1, U32 & String, U32 & Array<U32>> <- seal("AES-256-GCM", aes.key(), Bytes.from_string("short"), Bytes.from_string(""), Bytes.from_string(""))
    rejects("short nonce", n)
    o : Result<&1, &1, U32 & String, U32 & Array<U32>> <- seal("AES-128-GCM", aes.key(), aes.nonce(), Bytes.from_string(""), Bytes.from_string(""))
    rejects("unknown algorithm", o)
    malformed : Result<&1, &1, U32 & String, U32 & Array<U32>> <- seal("AES-256-GCM", Bytes.Bytes{32, Array.new(U32, 2n, 0)}, aes.nonce(), Bytes.from_string(""), Bytes.from_string(""))
    rejects("key words shorter than length", malformed)
    oversized : Result<&1, &1, U32 & String, U32 & Array<U32>> <- C.aead.seal.words("AES-256-GCM", 32, Array.new(U32, 3n, 0), 12, Array.new(U32, 2n, 0), 0, Array.new(U32, 0n, 0), 2147483648, Array.new(U32, 0n, 0))
    rejects("data exceeds EVP int limit", oversized)

def main() -> IO(Unit):
  run()
