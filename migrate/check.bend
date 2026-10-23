# Old subscription records, read through the real decode and migration chain by a billing consumer.
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import bend-kit-json@0.6.1.1/json.bend as Json
import ./migrate.bend as M

def ok(good: Bool, +name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad " ++ name)

def Error.show(e: M.Error) -> String:
  match e:
    case M.Malformed{}:
      "malformed"
    case M.Unsupported{v}:
      "unsupported version " ++ U32.show(v)
    case M.Missing{f}:
      "missing " ++ f
    case M.Unknown{f}:
      "unknown field " ++ f
    case M.Duplicate{f}:
      "duplicate field " ++ f
    case M.BadField{f}:
      "bad field " ++ f
    case M.Invalid{f}:
      "invalid " ++ f
    case M.NotInV1{f}:
      "v1 cannot hold " ++ f

# The current consumer: what billing does with a v3 record.
def action(s: M.Status, +c: U32, pe: M.Period) -> String:
  match s:
    case M.Active{}:
      "bill " ++ U32.show(c) ++ " cents " ++ M.Period.name(pe)
    case M.Paused{}:
      "hold"
    case M.Cancelled{}:
      "stop"

def bill(r: M.V3) -> String:
  M.V3{i, p, c, pe, s} = r
  "#" ++ U32.show(i) ++ " " ++ p ++ ": " ++ action(s, c, pe)

def lost(n: String) -> String:
  match n:
    case SNil{}:
      ""
    case SCon{h, t}:
      "; dropped note: " ++ SCon{h, t}

def billed(p: M.V3 & M.Dropped) -> String:
  (r, M.Dropped{n}) = p
  bill(r) ++ lost(n)

def read(r: Result<&2, &2, M.Error, M.Record>) -> String:
  match r:
    case Fail{e}:
      "error: " ++ Error.show(e)
    case Done{x}:
      billed(M.Record.upgrade(x))

# Decodes UTF-8 JSON text, upgrades it to v3, and bills it.
def expect(+json: String, +want: String) -> IO(Unit):
  +got = read(M.decode(Json.utf8(json)))
  ok(String.eq(got, want), json ++ " -> " ++ got)

def text(b: Bytes.Bytes) -> String:
  Bytes.to_string(b)

# Encodes, decodes, and encodes again; both encodings must match.
def again(r: Result<&2, &2, M.Error, M.Record>, +first: String) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "bad round trip " ++ first ++ ": " ++ Error.show(e))
    case Done{x}:
      ok(String.eq(text(M.encode(x)), first), "round trip " ++ first)

def roundtrip(+r: M.Record) -> IO(Unit):
  +first = text(M.encode(r))
  again(M.decode(Bytes.from_string(first)), first)

def down1(r: Result<&2, &2, M.Error, M.V1>) -> String:
  match r:
    case Fail{e}:
      "error: " ++ Error.show(e)
    case Done{x}:
      text(M.encode(M.R1{x}))

def downgrade(r: Result<&2, &2, M.Error, M.V1>, +want: String) -> IO(Unit):
  +got = down1(r)
  ok(String.eq(got, want), "downgrade " ++ got)

def main() -> IO(Unit):
  do IO<Unit>:
    # Supported versions, through the chain to the current consumer.
    expect("{\"version\":1,\"id\":7,\"plan\":\"pro\",\"monthly_cents\":1200,\"active\":true}", "#7 pro: bill 1200 cents monthly")
    expect("{\"active\":false,\"monthly_cents\":1200,\"plan\":\"pro\",\"id\":8,\"version\":1}", "#8 pro: stop")
    expect("{\"version\":2,\"id\":9,\"plan\":\"team\",\"cents\":99000,\"period\":\"yearly\",\"status\":\"paused\",\"note\":\"paused for audit\"}", "#9 team: hold; dropped note: paused for audit")
    expect("{\"version\":2,\"id\":10,\"plan\":\"basic\",\"cents\":500,\"status\":\"active\"}", "#10 basic: bill 500 cents monthly")
    expect("{\"version\":2,\"id\":11,\"plan\":\"équipe\",\"cents\":4000,\"period\":\"yearly\",\"status\":\"active\",\"note\":\"\"}", "#11 équipe: bill 4000 cents yearly")
    expect("{\"version\":3,\"id\":12,\"plan\":\"pro\",\"cents\":12000,\"period\":\"yearly\",\"status\":\"cancelled\"}", "#12 pro: stop")
    # Malformed input.
    expect("{\"version\":1,", "error: malformed")
    expect("[1]", "error: malformed")
    expect("{\"version\":1,\"id\":7,\"plan\":\"pro\",\"monthly_cents\":1200,\"active\":true,\"x\":{}}", "error: malformed")
    expect("{\"id\":7}", "error: missing version")
    expect("{\"version\":\"1\"}", "error: bad field version")
    expect("{\"version\":1,\"id\":7,\"plan\":\"pro\",\"monthly_cents\":1200}", "error: missing active")
    expect("{\"version\":1,\"id\":7,\"plan\":\"pro\",\"monthly_cents\":1200,\"active\":true,\"cents\":1200}", "error: unknown field cents")
    expect("{\"version\":3,\"id\":7,\"plan\":\"pro\",\"cents\":1,\"period\":\"monthly\",\"status\":\"active\",\"note\":\"x\"}", "error: unknown field note")
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
    roundtrip(M.R1{M.V1{7, "pro", 1200, True{}}})
    roundtrip(M.R2{M.V2{9, "team", 99000, M.Yearly{}, M.Paused{}, "paused for audit"}})
    roundtrip(M.R3{M.V3{12, "pro", 12000, M.Yearly{}, M.Cancelled{}}})
    # Downgrades for an old writer: v3 to v2 to v1 when v1 can hold it.
    downgrade(M.V2.down(M.V3.down(M.V3{12, "pro", 1200, M.Monthly{}, M.Active{}})), "{\"version\":1,\"id\":12,\"plan\":\"pro\",\"monthly_cents\":1200,\"active\":true}")
    downgrade(M.V2.down(M.V3.down(M.V3{12, "pro", 12000, M.Yearly{}, M.Active{}})), "error: v1 cannot hold period")
    downgrade(M.V2.down(M.V2{9, "team", 900, M.Monthly{}, M.Paused{}, ""}), "error: v1 cannot hold status")
    downgrade(M.V2.down(M.V2{9, "team", 900, M.Monthly{}, M.Active{}, "vip"}), "error: v1 cannot hold note")
