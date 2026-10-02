import Base
import ./router.bend as R
import ./target.bend as T

def require(ok: Bool, label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, label)

def groups(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> t:
      U32.show(h) ++ "/" ++ groups(t)

def choice(c: R.Choice<U32>) -> String:
  match c:
    case R.NotFound{}:
      "404"
    case R.MethodMissing{gs, allow}:
      "405:" ++ groups(gs) ++ ":" ++ allow
    case R.Options{gs, allow}:
      "204:" ++ groups(gs) ++ ":" ++ allow
    case R.Found{id, params, gs, method, pattern}:
      "hit:" ++ U32.show(id) ++ ":" ++ groups(gs) ++ ":" ++ method ++ ":" ++ pattern

def result(r: Result<&2, &2, R.Error, R.Resolved<U32>>) -> String:
  match r:
    case Fail{e}:
      "400"
    case Done{R.Resolved{target, c}}:
      choice(c)

def check(+table: R.Table<U32>, +method: String, +target: String, expected: String) -> IO(Unit):
  require(String.eq(result(R.resolve(~U32, table, method, target)), expected), method ++ " " ++ target)

def ready(r: Result<&2, &2, R.Error, R.Table<U32>>) -> IO(R.Table<U32>):
  match r:
    case Fail{e}:
      IO.die(R.Table<U32>, 1, "valid registration rejected")
    case Done{table}:
      IO.pure(R.Table<U32>, table)

def error(r: Result<&2, &2, R.Error, R.Table<U32>>) -> String:
  match r:
    case Done{table}:
      "accepted"
    case Fail{R.InvalidPattern{p}}:
      "pattern"
    case Fail{R.InvalidMethod{m}}:
      "method"
    case Fail{R.Duplicate{m, p}}:
      "duplicate"
    case Fail{R.GroupConflict{p}}:
      "groups"
    case Fail{R.BadTarget{}}:
      "target"

def registration(entries: List<&2, R.Entry<U32>>, expected: String) -> IO(Unit):
  require(String.eq(error(R.prepare(~U32, entries)), expected), "registration error kind")

def value(r: Map<&2, String> & String) -> String:
  (m, v) = r
  v

def captured(r: Result<&2, &2, R.Error, R.Resolved<U32>>, key: String) -> String:
  match r:
    case Done{R.Resolved{target, R.Found{id, params, gs, method, pattern}}}:
      value(Map.get(String, "absent", params, key))
    case _:
      "not found"

def queries(xs: List<&2, T.Query>) -> String:
  match xs:
    case Nil{}:
      ""
    case T.Query{k, v} <> t:
      "[" ++ k ++ "=" ++ v ++ "]" ++ queries(t)

def authority(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      "none"
    case Some{host}:
      host

def parsed(m: Maybe<&2, T.Target>) -> String:
  match m:
    case None{}:
      "bad"
    case Some{T.Target{ss, q, host, star}}:
      String.join(ss, "|") ++ ":" ++ queries(q) ++ ":" ++ authority(host)

def target(+raw: String, expected: String) -> IO(Unit):
  require(String.eq(parsed(T.parse(raw, "GET")), expected), "target " ++ raw)

def hidden(xs: List<&2, R.Hidden>) -> String:
  match xs:
    case Nil{}:
      ""
    case R.Hidden{p, methods} <> t:
      p ++ "=" ++ methods ++ ";" ++ hidden(t)

def description.next(here: Bool, hs: List<&2, R.Hidden>, later: Unit -> String) -> String:
  match here:
    case True{}:
      hidden(hs)
    case False{}:
      later(Unit{})

def description(xs: List<&2, R.Description>) -> String:
  match xs:
    case Nil{}:
      "absent"
    case R.Description{m, p, gs, hs} <> t:
      description.next(String.eq(p, "/users/me"), hs, u => description(t))

def fixture() -> List<&2, R.Entry<U32>>:
  [R.Entry{"POST", "/users/:id", 1, [7]}, R.Entry{"GET", "/users/me", 2, [8]},
   R.Entry{"GET", "/", 3, []}, R.Entry{"GET", "/users/", 4, [7]},
   R.Entry{"HEAD", "/users/me", 5, [8]}, R.Entry{"OPTIONS", "/explicit", 6, [9]},
   R.Entry{"GET", "/users/:name", 7, [7]}, R.Entry{"GET", "/café", 8, []},
   R.Entry{"GET", "/:first/b", 9, [1]}, R.Entry{"GET", "/a/:second", 10, [2]}]

def exercise(+table: R.Table<U32>) -> IO(Unit):
  do IO<Unit>:
    check(table, "POST", "/users/me", "405:8/:GET, HEAD, OPTIONS")
    check(table, "GET", "/users/me", "hit:2:8/:GET:/users/me")
    check(table, "HEAD", "/users/me", "hit:5:8/:HEAD:/users/me")
    check(table, "OPTIONS", "/users/me", "204:8/:GET, HEAD, OPTIONS")
    check(table, "GET", "/users/7", "hit:7:7/:GET:/users/:name")
    check(table, "HEAD", "/users/7", "hit:7:7/:GET:/users/:name")
    check(table, "POST", "/users/7", "hit:1:7/:POST:/users/:id")
    check(table, "DELETE", "/users/7", "405:7/:GET, HEAD, OPTIONS, POST")
    check(table, "OPTIONS", "/users/7", "204:7/:GET, HEAD, OPTIONS, POST")
    check(table, "OPTIONS", "/missing", "404")
    check(table, "OPTIONS", "/explicit", "hit:6:9/:OPTIONS:/explicit")
    check(table, "GET", "/", "hit:3::GET:/")
    check(table, "GET", "/users/", "hit:4:7/:GET:/users/")
    check(table, "GET", "//users/7", "404")
    check(table, "GET", "/users//7", "404")
    check(table, "GET", "/users/7/", "404")
    check(table, "GET", "/USERS/me", "404")
    check(table, "GET", "/a/b", "hit:10:2/:GET:/a/:second")
    check(table, "GET", "/caf%C3%A9?tag=a&tag=b", "hit:8::GET:/café")
    check(table, "GET", "https://example.test/users/me", "hit:2:8/:GET:/users/me")
    check(table, "GET", "http://example.test", "hit:3::GET:/")
    check(table, "GET", "*", "400")
    check(table, "OPTIONS", "*", "204::GET, HEAD, OPTIONS, POST")
    require(String.eq(captured(R.resolve(~U32, table, "POST", "/users/%252F"), "id"), "%2F"), "parameter decoded twice")
    require(String.eq(captured(R.resolve(~U32, table, "GET", "/users/a+b"), "name"), "a+b"), "path plus changed")
    require(String.eq(captured(R.resolve(~U32, table, "GET", "/a/b"), "second"), "b"), "method-specific names lost")
    require(String.eq(description(R.describe(~U32, table)), "/users/:id=POST;"), "hidden method description")

def invalids(xs: List<&2, String>, +table: R.Table<U32>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case h <> t:
      do IO<Unit>:
        check(table, "GET", h, "400")
        invalids(t, table)

def patterns(xs: List<&2, String>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case h <> t:
      do IO<Unit>:
        registration([R.Entry{"GET", h, 0, []}], "pattern")
        patterns(t)

def absent(route: Maybe<&2, Map<&2, String>>) -> Bool:
  match route:
    case None{}:
      True{}
    case Some{params}:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    require(absent(R.route("OPTIONS", "OPTIONS", "/", "*")), "asterisk target matched root pattern")
    +empty : R.Table<U32> <- ready(R.prepare(~U32, []))
    check(empty, "GET", "/", "404")
    check(empty, "OPTIONS", "*", "204::OPTIONS")
    +methods : R.Table<U32> <- ready(R.prepare(~U32, [R.Entry{"HEAD", "/head", 4, []}, R.Entry{"get", "/lower", 5, []}]))
    check(methods, "HEAD", "/head", "hit:4::HEAD:/head")
    check(methods, "GET", "/head", "405::HEAD, OPTIONS")
    check(methods, "GET", "/lower", "405::OPTIONS, get")
    check(methods, "get", "/lower", "hit:5::get:/lower")
    +cross : R.Table<U32> <- ready(R.prepare(~U32, [R.Entry{"GET", "/x/:first/fixed", 6, []}, R.Entry{"POST", "/x/static/:second", 7, []}]))
    check(cross, "GET", "/x/static/fixed", "405::OPTIONS, POST")
    a : R.Table<U32> <- ready(R.prepare(~U32, fixture()))
    b : R.Table<U32> <- ready(R.prepare(~U32, List.reverse(&2, R.Entry<U32>, fixture())))
    +table : R.Table<U32> = a
    exercise(table)
    exercise(b)
    invalids(["/x%", "/x%0", "/x%GG", "/x%00", "/x%2f", "/x%C0%AF", "/x%ED%A0%80", "/x%F4%90%80%80", "/x%E2%82", "/x#y", "/x y", "/x\u{80}", "/x\u{7F}", "/?x=%00", "/?x=%FF", "http:///x", "not-a-target"], table)
    patterns(["", "users", "//users", "/users//", "/:id/:id", "/:", "/:9id", "/:a-b", "/x\0"])
    registration([R.Entry{"GET", "/users/:id", 1, []}, R.Entry{"GET", "/users/:name", 2, []}], "duplicate")
    registration([R.Entry{"GET", "/x", 1, [1]}, R.Entry{"POST", "/x", 2, [2]}], "groups")
    registration([R.Entry{"bad method", "/x", 1, []}], "method")
    target("/caf%C3%A9?tag=a&tag=b&flag&flag=&=x&&q=a+b&plus=%2B", "café:[tag=a][tag=b][flag=][flag=][=x][q=a b][plus=+]:none")
    target("custom+v1://example.test?x=1", ":[x=1]:example.test")
    target("/%F0%9F%98%80", "😀::none")
    target("/a/../b/", "a|..|b|::none")
    target("/%EF%BF%BD", "�::none")
    IO.print("prepared router: PASS")
