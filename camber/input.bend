# Checked typed inputs; bodies are consumed once, without caching or decompression.
import Base
import bend-kit-http@0.32.0.0/http.bend as Http
import bend-kit-router@0.2.0.0/target.bend as Target
import bend-kit-json@0.5.1.0/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import bend-kit-url@0.4.1.0/url.bend as Url
import ./response.bend as Response

# Expected HTTP status, not an exception; the dispatch executor maps it once.
def checked(~I: Type, value: Maybe<&1, I>) -> Result<&2, &1, U32, I>:
  match value:
    case None{}: Fail{400}
    case Some{input}: Done{input}

def decimal.step(ok: Bool, +acc: U32, digit: U32, next: U32 -> Maybe<&2, U32>) -> Maybe<&2, U32>:
  match ok:
    case False{}: None{}
    case True{}: next((acc * 10 + digit : U32))

def decimal.go(text: String, +acc: U32) -> Maybe<&2, U32>:
  match text:
    case SNil{}: Some{acc}
    case SCon{Chr{+c}, rest}:
      +digit = (c - 48 : U32)
      decimal.step(U32.is_ge(c, 48) && U32.is_le(c, 57) && (U32.is_lt(acc, 429496729) || (U32.is_eq(acc, 429496729) && U32.is_le(digit, 5))), acc, digit, n => decimal.go(rest, n))

# Nonempty ASCII decimal only; arithmetic happens only after the overflow guard.
def u32(text: String) -> Maybe<&2, U32>:
  match text:
    case SNil{}: None{}
    case SCon{c, rest}: decimal.go(SCon{c, rest}, 0)

def scalar.convert(~I: Data, value: Maybe<&2, I>) -> Result<&2, &1, U32, I>:
  match value:
    case None{}: Fail{400}
    case Some{input}: Done{input}

def path.value(~I: Data, ~convert: String -> Maybe<&2, I>, pair: Map<&2, String> & String) -> Result<&2, &1, U32, I>:
  (params, value) = pair
  scalar.convert(~I, convert(value))

def path.present(~I: Data, ~convert: String -> Maybe<&2, I>, present: Bool, params: Map<&2, String>, key: String) -> Result<&2, &1, U32, I>:
  match present:
    case False{}: Fail{400}
    case True{}:
      path.value(~I, ~convert, Map.get(String, "", params, key))

def path.found(~I: Data, ~convert: String -> Maybe<&2, I>, key: String, pair: Map<&2, String> & Bool) -> Result<&2, &1, U32, I>:
  (params, present) = pair
  path.present(~I, ~convert, present, params, key)

def path(~I: Data, ~convert: String -> Maybe<&2, I>, params: Map<&2, String>, +key: String) -> Result<&2, &1, U32, I>:
  path.found(~I, ~convert, key, Map.has(&2, String, params, key))


def query.keep(same: Bool, value: String, rest: List<&2, String>) -> List<&2, String>:
  match same:
    case True{}: value <> rest
    case False{}: rest
def query.values(xs: List<&2, Target.Query>, +key: String) -> List<&2, String>:
  match xs:
    case Nil{}: Nil{}
    case Target.Query{+name, value} <> rest:
      query.keep(String.eq(name, key), value, query.values(rest, key))


def scalar.values(~I: Data, ~convert: String -> Maybe<&2, I>, values: List<&2, String>) -> Result<&2, &1, U32, I>:
  match values:
    case value <> Nil{}: scalar.convert(~I, convert(value))
    case _: Fail{400}

def query.scalar(~I: Data, ~convert: String -> Maybe<&2, I>, query: List<&2, Target.Query>, key: String) -> Result<&2, &1, U32, I>:
  scalar.values(~I, ~convert, query.values(query, key))

def list.values(~I: Data, ~convert: String -> Maybe<&2, I>, values: List<&2, String>) -> Result<&2, &1, U32, List<&2, I>>:
  match values:
    case Nil{}: Done{Nil{}}
    case value <> rest:
      do Result<&2, &1, U32, List<&2, I>>:
        head : I <- scalar.convert(~I, convert(value))
        tail : List<&2, I> <- list.values(~I, ~convert, rest)
        return head <> tail

def query.list(~I: Data, ~convert: String -> Maybe<&2, I>, query: List<&2, Target.Query>, key: String) -> Result<&2, &1, U32, List<&2, I>>:
  list.values(~I, ~convert, query.values(query, key))

# Reuse Target's RFC 3629 state machine directly over the owned packed array.
def utf8.step(pair: Array<U32> & U32, state: Target.Utf) -> Array<U32> & Maybe<&2, Target.Utf>:
  (bytes, byte) = pair
  Target.Utf{+need, lo, hi, cp, out} = state
  (bytes, Target.utf.step(U32.is_eq(need, 0), byte, need, lo, hi, cp, out))

def utf8.go(fuel: Nat, pair: Array<U32> & Maybe<&2, Target.Utf>, +index: U32) -> Array<U32> & Maybe<&2, String>:
  match fuel:
    case 0n:
      (bytes, state) = pair
      (bytes, Target.utf.finish(state))
    case 1n+rest:
      (bytes, state) = pair
      match state:
        case None{}: (bytes, None{})
        case Some{state}: utf8.go(rest, utf8.step(Bytes.peek(bytes, index), state), (index + 1 : U32))

def utf8.borrowed(len: U32, pair: Array<U32> & Maybe<&2, String>) -> Http.Body & Maybe<&2, String>:
  (buffer, text) = pair
  (Bytes.Bytes{len, buffer}, text)

def utf8.borrow(bytes: Http.Body) -> Http.Body & Maybe<&2, String>:
  Bytes.Bytes{+len, buffer} = bytes
  utf8.borrowed(len, utf8.go(U32.to_nat(len), (buffer, Some{Target.Utf{0, 128, 191, 0, ""}}), 0))

def utf8.text(pair: Http.Body & Maybe<&2, String>) -> Maybe<&2, String>:
  (bytes, text) = pair
  text

def utf8(bytes: Http.Body) -> Maybe<&2, String>:
  utf8.text(utf8.borrow(bytes))

# Split only unquoted semicolons, retaining quoted parameter syntax for checks.
def media.part(split: Bool, +c: U32, +quoted: Bool, +escaped: Bool, acc: String, parts: List<&2, String>) -> Bool & Bool & String & List<&2, String>:
  match split:
    case True{}: (False{}, False{}, "", String.reverse(acc) <> parts)
    case False{}:
      (Bool.pick(Bool, U32.is_eq(c, 34) && Bool.not(escaped), Bool.not(quoted), quoted), quoted && U32.is_eq(c, 92) && Bool.not(escaped), SCon{Chr{c}, acc}, parts)

def media.end(invalid: Bool, acc: String, parts: List<&2, String>) -> List<&2, String>:
  match invalid:
    case True{}: ["invalid"]
    case False{}: List.reverse(&2, String, String.reverse(acc) <> parts)

def media.parts(text: String, state: Bool & Bool & String & List<&2, String>) -> List<&2, String>:
  match text:
    case SNil{}:
      (quoted, escaped, acc, parts) = state
      media.end(quoted || escaped, acc, parts)
    case SCon{Chr{+c}, rest}:
      (+quoted, escaped, acc, parts) = state
      media.parts(rest, media.part(U32.is_eq(c, 59) && Bool.not(quoted), c, quoted, escaped, acc, parts))

# Compare the decoded quoted-string charset without allocating a second value.
def media.charset.quoted(text: String, expected: String, escaped: Bool) -> Bool:
  match text:
    case SNil{}: False{}
    case SCon{Chr{+c}, rest}:
      match c:
        case 92:
          match expected:
            case SNil{}: False{}
            case SCon{Chr{want}, next}:
              match escaped:
                case True{}: False{}
                case False{}: media.charset.quoted(rest, SCon{Chr{want}, next}, True{})
        case _:
          match expected:
            case SNil{}: U32.is_eq(c, 34) && Bool.not(escaped) && String.eq(rest, "")
            case SCon{Chr{want}, next}: U32.is_eq(c, want) && media.charset.quoted(rest, next, False{})

def media.charset.start(quoted: Bool, c: U32, rest: String) -> Bool:
  match quoted:
    case True{}: media.charset.quoted(rest, "utf-8", False{})
    case False{}: String.eq(SCon{Chr{c}, rest}, "utf-8")

def media.charset.value(value: String) -> Bool:
  match value:
    case SNil{}: False{}
    case SCon{Chr{+c}, rest}: media.charset.start(U32.is_eq(c, 34), c, rest)

def media.parameter(pair: String & String) -> Bool:
  (key, value) = pair
  +name = String.to_lower(Http.trim(key))
  +charset = String.to_lower(Http.trim(value))
  Bool.not(String.eq(name, "charset")) || media.charset.value(charset)

def media.charset(parts: List<&2, String>) -> Bool:
  match parts:
    case Nil{}: True{}
    case part <> rest: media.parameter(Url.take_to(part, 61)) && media.charset(rest)

def media.type(json: Bool, +name: String) -> Bool:
  match json:
    case True{}:
      String.eq(name, "application/json") || (String.starts_with(name, "application/") && String.ends_with(name, "+json") && Nat.is_gt(String.length(name), 17n) && Response.name(String.drop(name, 12n)))
    case False{}:
      String.starts_with(name, "text/") && Response.name(String.drop(name, 5n))

def media.content(json: Bool, parts: List<&2, String>) -> Bool:
  match parts:
    case Nil{}: False{}
    case name <> rest: media.type(json, String.to_lower(Http.trim(name))) && media.charset(rest)

def media.encoding(values: List<&2, String>) -> Bool:
  match values:
    case Nil{}: True{}
    case value <> rest: String.eq(value, "identity") && media.encoding(rest)

def media.headers(json: Bool, types: List<&2, String>, encodings: List<&2, String>) -> Bool:
  match types:
    case value <> Nil{}: media.content(json, media.parts(value, (False{}, False{}, "", Nil{}))) && media.encoding(Http.ce.split(encodings))
    case _: False{}

def media(json: Bool, +headers: Map<&2, List<&2, String>>) -> Bool:
  media.headers(json, Http.fields(headers, "content-type"), Http.fields(headers, "content-encoding"))

def raw(body: Http.Body) -> Result<&2, &1, U32, Http.Body>:
  Done{body}

def text.accepted(accepted: Bool, body: Http.Body) -> Result<&2, &1, U32, String>:
  match accepted:
    case False{}: Fail{415}
    case True{}: scalar.convert(~String, utf8(body))

def text(headers: Map<&2, List<&2, String>>, body: Http.Body) -> Result<&2, &1, U32, String>:
  text.accepted(media(False{}, headers), body)

# An explicit stack avoids mutually recursive tree walkers. Each decoded object
# has its own key set; escaped and literal spellings compare as the same text.
type Parent is Type:
  Object{key: Bytes.Bytes, rest: List<&1, Bytes.Bytes & Json.Val>, acc: List<&1, Bytes.Bytes & Json.Val>, seen: Set()}
  Array{rest: List<&1, Json.Val>, acc: List<&1, Json.Val>}

type Walk is Type:
  Value{value: Json.Val, parents: List<&1, Parent>}
  Fields{fields: List<&1, Bytes.Bytes & Json.Val>, acc: List<&1, Bytes.Bytes & Json.Val>, seen: Set(), parents: List<&1, Parent>}
  Items{values: List<&1, Json.Val>, acc: List<&1, Json.Val>, parents: List<&1, Parent>}
  Returned{value: Json.Val, parents: List<&1, Parent>}

def unique.field(repeated: Bool, key: Bytes.Bytes, value: Json.Val, rest: List<&1, Bytes.Bytes & Json.Val>, acc: List<&1, Bytes.Bytes & Json.Val>, seen: Set(), parents: List<&1, Parent>) -> Maybe<&1, Walk>:
  match repeated:
    case True{}: None{}
    case False{}: Some{Value{value, Object{key, rest, acc, seen} <> parents}}

def unique.seen(pair: Set() & Bool, name: String, key: Bytes.Bytes, value: Json.Val, rest: List<&1, Bytes.Bytes & Json.Val>, acc: List<&1, Bytes.Bytes & Json.Val>, parents: List<&1, Parent>) -> Maybe<&1, Walk>:
  (seen, repeated) = pair
  unique.field(repeated, key, value, rest, acc, Set.add(seen, name), parents)

def unique.key(text: Maybe<&2, String>, key: Bytes.Bytes, value: Json.Val, rest: List<&1, Bytes.Bytes & Json.Val>, acc: List<&1, Bytes.Bytes & Json.Val>, seen: Set(), parents: List<&1, Parent>) -> Maybe<&1, Walk>:
  match text:
    case None{}: None{}
    case Some{+name}:
      unique.seen(Set.has(seen, name), name, key, value, rest, acc, parents)

def unique.borrowed(pair: Http.Body & Maybe<&2, String>, value: Json.Val, rest: List<&1, Bytes.Bytes & Json.Val>, acc: List<&1, Bytes.Bytes & Json.Val>, seen: Set(), parents: List<&1, Parent>) -> Maybe<&1, Walk>:
  (key, text) = pair
  unique.key(text, key, value, rest, acc, seen, parents)

def unique.step(step: Walk) -> Maybe<&1, Walk>:
  match step:
    case Value{value, parents}:
      match value:
        case Json.Obj{fields}: Some{Fields{fields, Nil{}, Set.new(), parents}}
        case Json.Arr{values}: Some{Items{values, Nil{}, parents}}
        case Json.Null{}: Some{Returned{Json.Null{}, parents}}
        case Json.Flag{on}: Some{Returned{Json.Flag{on}, parents}}
        case Json.Num{number}: Some{Returned{Json.Num{number}, parents}}
        case Json.Str{text}: Some{Returned{Json.Str{text}, parents}}
    case Fields{fields, acc, seen, parents}:
      match fields:
        case Nil{}: Some{Returned{Json.Obj{List.reverse(&1, Bytes.Bytes & Json.Val, acc)}, parents}}
        case (key, value) <> rest:
          unique.borrowed(utf8.borrow(key), value, rest, acc, seen, parents)
    case Items{values, acc, parents}:
      match values:
        case Nil{}: Some{Returned{Json.Arr{List.reverse(&1, Json.Val, acc)}, parents}}
        case value <> rest: Some{Value{value, Array{rest, acc} <> parents}}
    case Returned{value, parents}:
      match parents:
        case Nil{}: Some{Returned{value, Nil{}}}
        case Object{key, rest, acc, seen} <> parents: Some{Fields{rest, (key, value) <> acc, seen, parents}}
        case Array{rest, acc} <> parents: Some{Items{rest, value <> acc, parents}}

def unique(fuel: Nat, step: Maybe<&1, Walk>) -> Maybe<&1, Json.Val>:
  match fuel:
    case 0n: None{}
    case 1n+rest:
      match step:
        case None{}: None{}
        case Some{Returned{value, Nil{}}}: Some{value}
        case Some{state}: unique(rest, unique.step(state))

def json.parsed(fuel: Nat, value: Maybe<&1, Json.Val>) -> Result<&2, &1, U32, Json.Val>:
  match value:
    case None{}: Fail{400}
    case Some{value}: checked(~Json.Val, unique(fuel, Some{Value{value, Nil{}}}))

def json.accepted(accepted: Bool, cap: U32, body: Http.Body) -> Result<&2, &1, U32, Json.Val>:
  match accepted:
    case False{}: Fail{415}
    case True{}:
      Bytes.Bytes{+len, buffer} = body
      json.parsed(Nat.add(Nat.mul(U32.to_nat(len), 4n), 8n), Json.parse.strict.bytes(Bytes.Bytes{len, buffer}, cap))

def json.with_depth(headers: Map<&2, List<&2, String>>, body: Http.Body, cap: U32) -> Result<&2, &1, U32, Json.Val>:
  json.accepted(media(True{}, headers), cap, body)

def json(headers: Map<&2, List<&2, String>>, body: Http.Body) -> Result<&2, &1, U32, Json.Val>:
  json.with_depth(headers, body, 64)

# Exact number text remains packed until this explicit checked conversion.
def number.u32(value: Json.Val) -> Result<&2, &1, U32, U32>:
  match value:
    case Json.Num{bytes}: scalar.convert(~U32, u32(Bytes.to_string(bytes)))
    case _: Fail{400}
