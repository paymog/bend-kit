# Old subscription records, read through the real decode and migration chain by a billing consumer.
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-json@0.7.0.0/json.bend as Json
import bend-kit-encoding@0.5.0.0/encoding.bend as Encoding
import ./migrate.bend as M

def ok(good: Bool, +name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad " ++ name)

# Text for the terminal. The package itself stays in bytes.
def text(b: Bytes.Bytes) -> String:
  Encoding.utf8.decode(b)

def Key.show(k: M.Key) -> String:
  text(M.Key.bytes(k))

def Error.show(e: M.Error) -> String:
  match e:
    case M.Malformed{}:
      "malformed"
    case M.Unsupported{v}:
      "unsupported version " ++ U32.show(v)
    case M.Unknown{b}:
      "unknown field " ++ text(b)
    case M.Unexpected{k}:
      "unexpected field " ++ Key.show(k)
    case M.Missing{k}:
      "missing " ++ Key.show(k)
    case M.Duplicate{k}:
      "duplicate field " ++ Key.show(k)
    case M.BadField{k}:
      "bad field " ++ Key.show(k)
    case M.Invalid{k}:
      "invalid " ++ Key.show(k)
    case M.NotInV1{k}:
      "v1 cannot hold " ++ Key.show(k)

def Period.show(p: M.Period) -> String:
  text(M.Tag.bytes(M.Period.tag(p)))

# The current consumer: what billing does with a v3 record.
def action(s: M.Status, +c: U32, pe: M.Period) -> String:
  match s:
    case M.Active{}:
      "bill " ++ U32.show(c) ++ " cents " ++ Period.show(pe)
    case M.Paused{}:
      "hold"
    case M.Cancelled{}:
      "stop"

def bill(r: M.V3) -> String:
  M.V3{i, p, c, pe, s} = r
  "#" ++ U32.show(i) ++ " " ++ text(p) ++ ": " ++ action(s, c, pe)

def lost(n: Maybe<&1, Bytes.Bytes>) -> String:
  match n:
    case None{}:
      ""
    case Some{b}:
      "; dropped note: " ++ text(b)

def billed(p: M.V3 & M.Dropped) -> String:
  (r, M.Dropped{n}) = p
  bill(r) ++ lost(n)

def read(r: Result<&1, &1, M.Error, M.Record>) -> String:
  match r:
    case Fail{e}:
      "error: " ++ Error.show(e)
    case Done{x}:
      billed(M.Record.upgrade(x))

# Decodes UTF-8 JSON text, upgrades it to v3, and bills it.
def expect(+json: String, +want: String) -> IO(Unit):
  +got = read(M.decode(Json.utf8(json)))
  ok(String.eq(got, want), json ++ " -> " ++ got)

def octets(b: Bytes.Bytes) -> String:
  Bytes.to_string(b)

# Encodes, decodes, and encodes again; both encodings must match.
def again(r: Result<&1, &1, M.Error, M.Record>, +first: String) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "bad round trip " ++ first ++ ": " ++ Error.show(e))
    case Done{x}:
      ok(String.eq(octets(M.encode(x)), first), "round trip " ++ text(Bytes.from_string(first)))

def roundtrip(r: M.Record) -> IO(Unit):
  +first = octets(M.encode(r))
  again(M.decode(Bytes.from_string(first)), first)

def down1(r: Result<&1, &1, M.Error, M.V1>) -> String:
  match r:
    case Fail{e}:
      "error: " ++ Error.show(e)
    case Done{x}:
      octets(M.encode(M.R1{x}))

def downgrade(r: Result<&1, &1, M.Error, M.V1>, +want: String) -> IO(Unit):
  +got = down1(r)
  ok(String.eq(got, want), "downgrade " ++ got)

def number.got(m: Maybe<&2, U32>) -> String:
  match m:
    case Some{n}:
      U32.show(n)
    case None{}:
      "none"

# Reads digits as bytes.
def number(+digits: String, +want: String) -> IO(Unit):
  +got = number.got(M.u32.read(Bytes.from_string(digits)))
  ok(String.eq(got, want), "number " ++ digits ++ " -> " ++ got)

def same(m: Maybe<&2, U32>, +n: U32) -> Bool:
  match m:
    case Some{x}:
      U32.is_eq(x, n)
    case None{}:
      False{}

# Writes then reads every n in [lo, lo + count) and stops at the first that does not come back.
def numbers.go(f: Nat, +n: U32) -> Maybe<&2, U32>:
  match f:
    case 0n:
      None{}
    case 1n+p:
      Bool.pick(Maybe<&2, U32>, same(M.u32.read(M.u32.text(n)), n), numbers.go(p, (n + 1 : U32)), Some{n})

def numbers(+lo: U32, count: Nat) -> IO(Unit):
  +bad = number.got(numbers.go(count, lo))
  ok(String.eq(bad, "none"), "number round trip from " ++ U32.show(lo) ++ ": first failure " ++ bad)

def plan(+s: String) -> Bytes.Bytes:
  Json.utf8(s)

def main() -> IO(Unit):
  do IO<Unit>:
    # Supported versions, through the chain to the current consumer.
    expect("{\"version\":1,\"id\":7,\"plan\":\"pro\",\"monthly_cents\":1200,\"active\":true}", "#7 pro: bill 1200 cents monthly")
    expect("{\"active\":false,\"monthly_cents\":1200,\"plan\":\"pro\",\"id\":8,\"version\":1}", "#8 pro: stop")
    expect("{\"version\":2,\"id\":9,\"plan\":\"team\",\"cents\":99000,\"period\":\"yearly\",\"status\":\"paused\",\"note\":\"paused for audit\"}", "#9 team: hold; dropped note: paused for audit")
    expect("{\"version\":2,\"id\":10,\"plan\":\"basic\",\"cents\":500,\"status\":\"active\"}", "#10 basic: bill 500 cents monthly")
    expect("{\"version\":2,\"id\":11,\"plan\":\"équipe\",\"cents\":4000,\"period\":\"yearly\",\"status\":\"active\",\"note\":\"\"}", "#11 équipe: bill 4000 cents yearly; dropped note: ")
    expect("{\"version\":3,\"id\":12,\"plan\":\"pro\",\"cents\":12000,\"period\":\"yearly\",\"status\":\"cancelled\"}", "#12 pro: stop")
    # Malformed input.
    expect("{\"version\":1,", "error: malformed")
    expect("[1]", "error: malformed")
    expect("{\"version\":1,\"id\":7,\"plan\":\"pro\",\"monthly_cents\":1200,\"active\":true,\"x\":{}}", "error: malformed")
    expect("{\"id\":7}", "error: missing version")
    expect("{\"version\":\"1\"}", "error: bad field version")
    expect("{\"version\":1,\"id\":7,\"plan\":\"pro\",\"monthly_cents\":1200}", "error: missing active")
    expect("{\"version\":1,\"id\":7,\"plan\":\"pro\",\"monthly_cents\":1200,\"active\":true,\"cents\":1200}", "error: unexpected field cents")
    expect("{\"version\":3,\"id\":7,\"plan\":\"pro\",\"cents\":1,\"period\":\"monthly\",\"status\":\"active\",\"note\":\"x\"}", "error: unexpected field note")
    expect("{\"version\":1,\"id\":7,\"plan\":\"pro\",\"monthly_cents\":1200,\"active\":true,\"colour\":\"red\"}", "error: unknown field colour")
    expect("{\"version\":1,\"id\":7,\"plan\":\"pro\",\"monthly_cents\":1200,\"active\":true,\"monthly_cents_x\":1}", "error: unknown field monthly_cents_x")
    expect("{\"version\":1,\"id\":7,\"id\":8,\"plan\":\"pro\",\"monthly_cents\":1200,\"active\":true}", "error: duplicate field id")
    expect("{\"version\":1,\"id\":-7,\"plan\":\"pro\",\"monthly_cents\":1200,\"active\":true}", "error: bad field id")
    expect("{\"version\":1,\"id\":7,\"plan\":\"pro\",\"monthly_cents\":12.5,\"active\":true}", "error: bad field monthly_cents")
    expect("{\"version\":1,\"id\":7,\"plan\":\"pro\",\"monthly_cents\":4294967296,\"active\":true}", "error: bad field monthly_cents")
    expect("{\"version\":2,\"id\":7,\"plan\":\"pro\",\"cents\":100,\"period\":\"weekly\",\"status\":\"active\"}", "error: bad field period")
    expect("{\"version\":2,\"id\":7,\"plan\":\"pro\",\"cents\":100,\"status\":\"trial\"}", "error: bad field status")
    # Business rules.
    expect("{\"version\":1,\"id\":7,\"plan\":\"\",\"monthly_cents\":1200,\"active\":true}", "error: invalid plan")
    expect("{\"version\":2,\"id\":7,\"plan\":\"pro\",\"cents\":0,\"status\":\"active\"}", "error: invalid cents")
    # Unsupported versions.
    expect("{\"version\":4,\"id\":7}", "error: unsupported version 4")
    expect("{\"version\":0}", "error: unsupported version 0")
    # Encode then decode gives the same record, in each version.
    roundtrip(M.R1{M.V1{7, plan("pro"), 1200, True{}}})
    roundtrip(M.R2{M.V2{9, plan("équipe"), 99000, M.Yearly{}, M.Paused{}, Some{plan("paused for audit")}}})
    roundtrip(M.R2{M.V2{10, plan("basic"), 4294967295, M.Monthly{}, M.Active{}, None{}}})
    roundtrip(M.R3{M.V3{0, plan("pro"), 12000, M.Yearly{}, M.Cancelled{}}})
    # Downgrades for an old writer: v3 to v2 to v1 when v1 can hold it.
    downgrade(M.V2.down(M.V3.down(M.V3{12, plan("pro"), 1200, M.Monthly{}, M.Active{}})), "{\"version\":1,\"id\":12,\"plan\":\"pro\",\"monthly_cents\":1200,\"active\":true}")
    downgrade(M.V2.down(M.V3.down(M.V3{12, plan("pro"), 12000, M.Yearly{}, M.Active{}})), "error: v1 cannot hold period")
    downgrade(M.V2.down(M.V2{9, plan("team"), 900, M.Monthly{}, M.Paused{}, None{}}), "error: v1 cannot hold status")
    downgrade(M.V2.down(M.V2{9, plan("team"), 900, M.Monthly{}, M.Active{}, Some{plan("")}}), "error: v1 cannot hold note")
    # The number codec: digits as bytes.
    number("0", "0")
    number("7", "7")
    number("4294967295", "4294967295")
    number("4294967296", "none")
    number("9999999999", "none")
    number("10000000000", "none")
    number("", "none")
    number("01", "none")
    number("12a", "none")
    number("-1", "none")
    numbers(0, 20000n)
    numbers(99990, 20n)
    numbers(999999990, 20n)
    numbers(4294957296, 10000n)
