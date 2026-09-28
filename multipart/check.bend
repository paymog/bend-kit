import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import ./multipart.bend as Mp

# The laws run in the checker. This runs encode and decode on the native runtime: a binary
# body with every octet, fed in every two-way split and in chunks of several sizes.

def ok(ok: Bool, +name: String, +got: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, name ++ " gave " ++ got)

# Octets 0..255, then CR LF "--" runs that are not the delimiter.
def octets.go(n: Nat, a: Array<U32>, +i: U32) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      octets.go(p, Bytes.poke(a, i, i), (i + 1 : U32))

def binary() -> Bytes.Bytes:
  Bytes.append(Bytes.Bytes{256, octets.go(256n, Bytes.alloc(256), 0)}, Bytes.from_string("\r\n--\r\n--bend\r\n-\r"))

def opt(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      "-"
    case Some{s}:
      s

def part.show(p: Mp.Part) -> String:
  Mp.Part{n, f, c, b} = p
  n ++ "|" ++ opt(f) ++ "|" ++ opt(c) ++ "|" ++ Bytes.to_hex(b) ++ ";"

def parts.show(ps: List<&1, Mp.Part>) -> String:
  match ps:
    case Nil{}:
      SNil{}
    case Con{p, t}:
      part.show(p) ++ parts.show(t)

def shown(r: Result<&1, &1, String, List<&1, Mp.Part>>) -> String:
  match r:
    case Fail{e}:
      "!" ++ e
    case Done{ps}:
      parts.show(ps)

def form() -> List<&1, Mp.Part>:
  [Mp.Part{"title", None{}, None{}, Bytes.from_string("hello")}, Mp.Part{"blob", Some{"b\"in.bin"}, Some{"application/octet-stream"}, binary()}, Mp.Part{"empty", None{}, None{}, Bytes.new(0)}]

def want() -> String:
  shown(Done{form()})

# s in chunks of n octets.
def chunks.go(f: Nat, s: String, +n: Nat, acc: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  match f:
    case 0n:
      List.reverse(&1, Bytes.Bytes, acc)
    case 1n+p:
      match s:
        case SNil{}:
          List.reverse(&1, Bytes.Bytes, acc)
        case SCon{+h, +t}:
          chunks.go(p, String.drop(SCon{h, t}, n), n, Con{Bytes.from_string(String.take(SCon{h, t}, n)), acc})

def chunks(b: Bytes.Bytes, +n: U32) -> List<&1, Bytes.Bytes>:
  +s = Bytes.to_string(b)
  chunks.go(String.length(s), s, U32.to_nat(n), Nil{})

def split.two(r: Bytes.Bytes & Bytes.Bytes, +i: U32) -> List<&1, Bytes.Bytes>:
  (b, h) = r
  [h, Bytes.snd(Bytes.slice(b, i, 4294967295))]

# Every split point i in [i, len]; ok counts the matches.
def splits.go(f: Nat, +body: String, +i: U32, +good: U32) -> U32:
  match f:
    case 0n:
      good
    case 1n+p:
      +same = String.eq(shown(Mp.decode.chunks("XyZ", split.two(Bytes.slice(Bytes.from_string(body), 0, i), i))), want())
      splits.go(p, body, (i + 1 : U32), (good + Bool.to_u32(same) : U32))

def sizes(sz: List<&2, U32>, +s: String) -> IO(Unit):
  match sz:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{+n, t}:
      +got = shown(Mp.decode.chunks("XyZ", chunks(Bytes.from_string(s), n)))
      do IO<Unit>:
        ok(String.eq(got, want()), "chunks of " ++ U32.show(n), got)
        sizes(t, s)

def encoded(r: Result<&1, &1, String, Bytes.Bytes>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "encode failed: " ++ e)
    case Done{body}:
      +s = Bytes.to_string(body)
      +n = Bytes.count(s, 0)
      +good = splits.go(U32.to_nat((n + 1 : U32)), s, 0, 0)
      do IO<Unit>:
        ok(String.eq(shown(Mp.decode("XyZ", Bytes.from_string(s))), want()), "roundtrip binary", shown(Mp.decode("XyZ", Bytes.from_string(s))))
        ok(U32.is_eq(good, (n + 1 : U32)), "every two-way split", U32.show(good) ++ " of " ++ U32.show((n + 1 : U32)))
        sizes([1, 2, 3, 5, 7, 13, 64, 4096], s)

def formed(r: Result<&1, &1, U32 & String, String & Bytes.Bytes>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "form failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{(+ct, body)}:
      ok(String.eq(shown(Mp.decode.chunks(Maybe.default(&2, String, Mp.boundary.get(ct), ""), chunks(body, 100))), want()), "form with random boundary", ct)

def randoms(a: Result<&1, &1, U32 & String, String>, b: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match a:
    case Fail{e}:
      IO.die(Unit, 1, "boundary failed")
    case Done{+x}:
      match b:
        case Fail{e}:
          IO.die(Unit, 1, "boundary failed")
        case Done{+y}:
          do IO<Unit>:
            ok(Bool.and(Mp.boundary.ok(x), U32.is_eq(Bytes.count(x, 0), 41)), "boundary is 41 bchars", x)
            ok(Bool.not(String.eq(x, y)), "boundaries differ", y)

def main() -> IO(Unit):
  do IO<Unit>:
    encoded(Mp.encode("XyZ", form()))
    a : Result<&1, &1, U32 & String, String> <- Mp.boundary.new()
    b : Result<&1, &1, U32 & String, String> <- Mp.boundary.new()
    randoms(a, b)
    r : Result<&1, &1, U32 & String, String & Bytes.Bytes> <- Mp.form(form())
    formed(r)
