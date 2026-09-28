# URL benchmark: parse and encode a fixed origin-form list, N rounds (see README.md).
import Base
import ../../time/time.bend as Time
import ../url.bend as Url

def rounds() -> Nat:
  10000n

def len(s: String, n: U32) -> U32:
  match s:
    case SNil{}:
      n
    case SCon{h, t}:
      len(t, (n + 1 : U32))

def fields(xs: List<&2, Sigma<&2, &2, String, _ => String>>, acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case (k, v) <> t:
      fields(t, (acc + len(k, 0) + len(v, 0) + 1 : U32))

def score(m: Maybe<&2, Url.Url>) -> U32:
  match m:
    case None{}:
      0
    case Some{u}:
      Url.Url{path, query} = u
      (len(path, 0) + fields(Map.to_list(&2, String, query), 0) : U32)

def chk.go(s: String, h: U32, n: U32) -> U32:
  match s:
    case SNil{}:
      (h + n : U32)
    case SCon{Chr{+c}, t}:
      chk.go(t, (h * 31 + c : U32), (n + 1 : U32))

def chk(+s: String) -> U32:
  chk.go(s, 0, 0)

def urls() -> List<&2, String>:
  [
    "/",
    "/health",
    "/users",
    "/users/42",
    "/users/42/posts",
    "/users/42/posts/99",
    "/api/v1/items?page=2&sort=name",
    "/x?a=1&b=2",
    "/a%20b",
    "/a%20b?q=hello%20world",
    "/orgs/paymog/repos/bend-kit/issues/74",
    "/search?q=hello+world&limit=10",
    "/file/name%2Fwith%2Fslashes",
    "/?empty=",
    "/path?u=%2Fenc%2Foded",
    "nope"
  ]

def parse.each(xs: List<&2, String>, acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{s, t}:
      parse.each(t, (acc + score(Url.parse(s)) : U32))

def parse.rounds(n: Nat, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      parse.rounds(p, parse.each(urls(), acc))

def enc.one(u: Url.Url, acc: U32) -> U32:
  (acc + chk(Url.encode(u)) : U32)

def enc.each(xs: List<&2, Url.Url>, acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{u, t}:
      enc.each(t, enc.one(u, acc))

def parsed.push(m: Maybe<&2, Url.Url>, acc: List<&2, Url.Url>) -> List<&2, Url.Url>:
  match m:
    case None{}:
      acc
    case Some{u}:
      u <> acc

def parsed.go(xs: List<&2, String>, acc: List<&2, Url.Url>) -> List<&2, Url.Url>:
  match xs:
    case Nil{}:
      acc
    case Con{s, t}:
      parsed.go(t, parsed.push(Url.parse(s), acc))

def parsed() -> List<&2, Url.Url>:
  parsed.go(urls(), [])

def enc.rounds(n: Nat, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      enc.rounds(p, enc.each(parsed(), acc))

def lap(+name: String, t0: Time.Duration, t1: Time.Duration, chk: U32) -> IO(Unit):
  IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(chk))

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    pchk : U32 = parse.rounds(rounds(), 0)
    t1 : Time.Duration <- Time.mono()
    lap("parse", t0, t1, pchk)
    t0 : Time.Duration <- Time.mono()
    echk : U32 = enc.rounds(rounds(), 0)
    t1 : Time.Duration <- Time.mono()
    lap("encode", t0, t1, echk)
