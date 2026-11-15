import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-json@0.7.0.0/json.bend as Json
import ./migrate.bend as M
import ./LAWS.bend as Laws

# Result lemmas
# -------------

def fail_done.motive(r: Result<&1, &1, M.Error, M.V1>) -> Type:
  match r:
    case Fail{e}:
      Unit
    case Done{x}:
      Empty

def fail_done(-e: M.Error, -s: M.V1, h: {Fail{e} == Done{s} : Result<&1, &1, M.Error, M.V1>}) -> Empty:
  %h : fail_done.motive(_)
  Unit{}

# The v1 record inside a successful downgrade.
def unwrap(r: Result<&1, &1, M.Error, M.V1>) -> M.V1:
  match r:
    case Fail{e}:
      M.V1{0, Bytes.new(0), 0, False{}}
    case Done{x}:
      x

# Business fields
# ---------------

def Laws.up1_terms(r):
  match r:
    case M.V1{i, p, c, a}:
      {==}

def Laws.up2_terms(r):
  match r:
    case M.V2{i, p, c, pe, s, n}:
      {==}

def Laws.down3_terms(r):
  match r:
    case M.V3{i, p, c, pe, s}:
      {==}

def Laws.upgrade_terms(r):
  match r:
    case M.R1{M.V1{i, p, c, a}}:
      {==}
    case M.R2{M.V2{i, p, c, pe, s, n}}:
      {==}
    case M.R3{M.V3{i, p, c, pe, s}}:
      {==}

# Reversible: v1 and v2
# ---------------------

def Laws.down_up1(r):
  match r:
    case M.V1{i, p, c, True{}}:
      {==}
    case M.V1{i, p, c, False{}}:
      {==}

def Laws.up_down2(r, s, h):
  match r:
    case M.V2{i, p, c, M.Yearly{}, st, n}:
      Empty.absurd({M.V1.up(s) == M.V2{i, p, c, M.Yearly{}, st, n} : M.V2}, fail_done(M.NotInV1{M.KPeriod{}}, s, h))
    case M.V2{i, p, c, M.Monthly{}, M.Paused{}, n}:
      Empty.absurd({M.V1.up(s) == M.V2{i, p, c, M.Monthly{}, M.Paused{}, n} : M.V2}, fail_done(M.NotInV1{M.KStatus{}}, s, h))
    case M.V2{i, p, c, M.Monthly{}, M.Active{}, Some{b}}:
      Empty.absurd({M.V1.up(s) == M.V2{i, p, c, M.Monthly{}, M.Active{}, Some{b}} : M.V2}, fail_done(M.NotInV1{M.KNote{}}, s, h))
    case M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, Some{b}}:
      Empty.absurd({M.V1.up(s) == M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, Some{b}} : M.V2}, fail_done(M.NotInV1{M.KNote{}}, s, h))
    case M.V2{i, p, c, M.Monthly{}, M.Active{}, None{}}:
      %h : {M.V1.up(unwrap(_)) == M.V2{i, p, c, M.Monthly{}, M.Active{}, None{}} : M.V2}
      {==}
    case M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, None{}}:
      %h : {M.V1.up(unwrap(_)) == M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, None{}} : M.V2}
      {==}

def Laws.down2_terms(r, s, h):
  match r:
    case M.V2{i, p, c, M.Yearly{}, st, n}:
      Empty.absurd({M.V1.terms(s) == M.V2.terms(M.V2{i, p, c, M.Yearly{}, st, n}) : M.Terms}, fail_done(M.NotInV1{M.KPeriod{}}, s, h))
    case M.V2{i, p, c, M.Monthly{}, M.Paused{}, n}:
      Empty.absurd({M.V1.terms(s) == M.V2.terms(M.V2{i, p, c, M.Monthly{}, M.Paused{}, n}) : M.Terms}, fail_done(M.NotInV1{M.KStatus{}}, s, h))
    case M.V2{i, p, c, M.Monthly{}, M.Active{}, Some{b}}:
      Empty.absurd({M.V1.terms(s) == M.V2.terms(M.V2{i, p, c, M.Monthly{}, M.Active{}, Some{b}}) : M.Terms}, fail_done(M.NotInV1{M.KNote{}}, s, h))
    case M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, Some{b}}:
      Empty.absurd({M.V1.terms(s) == M.V2.terms(M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, Some{b}}) : M.Terms}, fail_done(M.NotInV1{M.KNote{}}, s, h))
    case M.V2{i, p, c, M.Monthly{}, M.Active{}, None{}}:
      %h : {M.V1.terms(unwrap(_)) == M.V2.terms(M.V2{i, p, c, M.Monthly{}, M.Active{}, None{}}) : M.Terms}
      {==}
    case M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, None{}}:
      %h : {M.V1.terms(unwrap(_)) == M.V2.terms(M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, None{}}) : M.Terms}
      {==}

def Laws.down2_domain(r):
  match r:
    case M.V2{i, p, c, M.Yearly{}, st, n}:
      {==}
    case M.V2{i, p, c, M.Monthly{}, M.Paused{}, n}:
      {==}
    case M.V2{i, p, c, M.Monthly{}, M.Active{}, Some{b}}:
      {==}
    case M.V2{i, p, c, M.Monthly{}, M.Active{}, None{}}:
      {==}
    case M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, Some{b}}:
      {==}
    case M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, None{}}:
      {==}

# Validity
# --------

def Laws.upgrade_valid(r, h):
  match r:
    case M.R1{M.V1{i, Bytes.Bytes{len, buf}, c, a}}:
      h
    case M.R2{M.V2{i, Bytes.Bytes{len, buf}, c, pe, s, n}}:
      h
    case M.R3{M.V3{i, Bytes.Bytes{len, buf}, c, pe, s}}:
      h

def check_if_ok(m: Maybe<&2, M.Key>, -x: M.Record, e: {M.Record.valid(x) == M.none(m) : Bool}) -> {Laws.decoded_ok(M.Record.check.if(m, x)) == True{} : Bool}:
  match m:
    case None{}:
      e
    case Some{k}:
      {==}

def check_ok(r: M.Record) -> {Laws.decoded_ok(M.Record.check(r)) == True{} : Bool}:
  match r:
    case M.R1{M.V1{+i, Bytes.Bytes{+len, buf}, +c, +a}}:
      check_if_ok(M.Terms.problem(len, c), M.R1{M.V1{i, Bytes.Bytes{len, buf}, c, a}}, {==})
    case M.R2{M.V2{+i, Bytes.Bytes{+len, buf}, +c, +pe, +s, n}}:
      check_if_ok(M.Terms.problem(len, c), M.R2{M.V2{i, Bytes.Bytes{len, buf}, c, pe, s, n}}, {==})
    case M.R3{M.V3{+i, Bytes.Bytes{+len, buf}, +c, +pe, +s}}:
      check_if_ok(M.Terms.problem(len, c), M.R3{M.V3{i, Bytes.Bytes{len, buf}, c, pe, s}}, {==})

def bind_ok(x: Result<&1, &1, M.Error, M.Record>) -> {Laws.decoded_ok(Result.bind(&1, &1, M.Error, M.Record, M.Record, x, M.Record.check)) == True{} : Bool}:
  match x:
    case Fail{e}:
      {==}
    case Done{r}:
      check_ok(r)

def Laws.decode_val_valid(v):
  bind_ok(M.decode.shape(v))

def parsed_ok(m: Maybe<&1, Json.Val>) -> {Laws.decoded_ok(M.decode.parsed(m)) == True{} : Bool}:
  match m:
    case None{}:
      {==}
    case Some{v}:
      Laws.decode_val_valid(v)

def Laws.decode_valid(b):
  parsed_ok(Json.parse.strict.bytes(b, 1))

# Chains
# ------

def Laws.chain_v1(r):
  match r:
    case M.V1{i, p, c, a}:
      {==}

def Laws.chain_v2(r):
  {==}

def Laws.chain_v3(r):
  {==}

# Lossy: v2 to v3
# ---------------

def Laws.up2_restore(r):
  match r:
    case M.V2{i, p, c, pe, s, n}:
      {==}

def Laws.up2_dropped(r):
  match r:
    case M.V2{i, p, c, pe, s, n}:
      {==}

def Laws.up2_forgets_note(i, p, c, pe, s, n, m):
  {==}

def Laws.up_down3(r):
  match r:
    case M.V3{i, p, c, pe, s}:
      {==}

# Names
# -----

def Laws.key_roundtrip(k):
  match k:
    case M.KVersion{}:
      {==}
    case M.KId{}:
      {==}
    case M.KPlan{}:
      {==}
    case M.KMonthlyCents{}:
      {==}
    case M.KActive{}:
      {==}
    case M.KCents{}:
      {==}
    case M.KPeriod{}:
      {==}
    case M.KStatus{}:
      {==}
    case M.KNote{}:
      {==}

def Laws.period_roundtrip(p):
  match p:
    case M.Monthly{}:
      {==}
    case M.Yearly{}:
      {==}

def Laws.status_roundtrip(s):
  match s:
    case M.Active{}:
      {==}
    case M.Paused{}:
      {==}
    case M.Cancelled{}:
      {==}

# Wire round trip
# ---------------

def v1_fin(~digits: @n: U32 -> {M.u32.read(M.u32.text(n)) == Some{n} : Maybe<&2, U32>}, +i: U32, -p: Bytes.Bytes, +c: U32, -a: Bool) -> {M.V1.finish(M.u32.read(M.u32.text(i)), p, M.u32.read(M.u32.text(c)), a) == Done{M.R1{M.V1{i, p, c, a}}} : Result<&1, &1, M.Error, M.Record>}:
  %Equal.sym(Maybe<&2, U32>, M.u32.read(M.u32.text(i)), Some{i}, digits(i)) : {M.V1.finish(_, p, M.u32.read(M.u32.text(c)), a) == Done{M.R1{M.V1{i, p, c, a}}} : Result<&1, &1, M.Error, M.Record>}
  %Equal.sym(Maybe<&2, U32>, M.u32.read(M.u32.text(c)), Some{c}, digits(c)) : {M.V1.finish(Some{i}, p, _, a) == Done{M.R1{M.V1{i, p, c, a}}} : Result<&1, &1, M.Error, M.Record>}
  {==}

def v2_fin(~digits: @n: U32 -> {M.u32.read(M.u32.text(n)) == Some{n} : Maybe<&2, U32>}, +i: U32, -p: Bytes.Bytes, +c: U32, -pe: M.Period, -s: M.Status, -n: Maybe<&1, Bytes.Bytes>) -> {M.V2.finish(M.u32.read(M.u32.text(i)), p, M.u32.read(M.u32.text(c)), pe, s, n) == Done{M.R2{M.V2{i, p, c, pe, s, n}}} : Result<&1, &1, M.Error, M.Record>}:
  %Equal.sym(Maybe<&2, U32>, M.u32.read(M.u32.text(i)), Some{i}, digits(i)) : {M.V2.finish(_, p, M.u32.read(M.u32.text(c)), pe, s, n) == Done{M.R2{M.V2{i, p, c, pe, s, n}}} : Result<&1, &1, M.Error, M.Record>}
  %Equal.sym(Maybe<&2, U32>, M.u32.read(M.u32.text(c)), Some{c}, digits(c)) : {M.V2.finish(Some{i}, p, _, pe, s, n) == Done{M.R2{M.V2{i, p, c, pe, s, n}}} : Result<&1, &1, M.Error, M.Record>}
  {==}

def v3_fin(~digits: @n: U32 -> {M.u32.read(M.u32.text(n)) == Some{n} : Maybe<&2, U32>}, +i: U32, -p: Bytes.Bytes, +c: U32, -pe: M.Period, -s: M.Status) -> {M.V3.finish(M.u32.read(M.u32.text(i)), p, M.u32.read(M.u32.text(c)), pe, s) == Done{M.R3{M.V3{i, p, c, pe, s}}} : Result<&1, &1, M.Error, M.Record>}:
  %Equal.sym(Maybe<&2, U32>, M.u32.read(M.u32.text(i)), Some{i}, digits(i)) : {M.V3.finish(_, p, M.u32.read(M.u32.text(c)), pe, s) == Done{M.R3{M.V3{i, p, c, pe, s}}} : Result<&1, &1, M.Error, M.Record>}
  %Equal.sym(Maybe<&2, U32>, M.u32.read(M.u32.text(c)), Some{c}, digits(c)) : {M.V3.finish(Some{i}, p, _, pe, s) == Done{M.R3{M.V3{i, p, c, pe, s}}} : Result<&1, &1, M.Error, M.Record>}
  {==}

def v2_shape(~digits: @n: U32 -> {M.u32.read(M.u32.text(n)) == Some{n} : Maybe<&2, U32>}, +i: U32, -p: Bytes.Bytes, +c: U32, pe: M.Period, s: M.Status, n: Maybe<&1, Bytes.Bytes>) -> {M.decode.shape(M.V2.json(M.V2{i, p, c, pe, s, n})) == Done{M.R2{M.V2{i, p, c, pe, s, n}}} : Result<&1, &1, M.Error, M.Record>}:
  match pe s n:
    case M.Monthly{} M.Active{} None{}:
      v2_fin(~digits, i, p, c, M.Monthly{}, M.Active{}, None{})
    case M.Monthly{} M.Active{} Some{b}:
      v2_fin(~digits, i, p, c, M.Monthly{}, M.Active{}, Some{b})
    case M.Monthly{} M.Paused{} None{}:
      v2_fin(~digits, i, p, c, M.Monthly{}, M.Paused{}, None{})
    case M.Monthly{} M.Paused{} Some{b}:
      v2_fin(~digits, i, p, c, M.Monthly{}, M.Paused{}, Some{b})
    case M.Monthly{} M.Cancelled{} None{}:
      v2_fin(~digits, i, p, c, M.Monthly{}, M.Cancelled{}, None{})
    case M.Monthly{} M.Cancelled{} Some{b}:
      v2_fin(~digits, i, p, c, M.Monthly{}, M.Cancelled{}, Some{b})
    case M.Yearly{} M.Active{} None{}:
      v2_fin(~digits, i, p, c, M.Yearly{}, M.Active{}, None{})
    case M.Yearly{} M.Active{} Some{b}:
      v2_fin(~digits, i, p, c, M.Yearly{}, M.Active{}, Some{b})
    case M.Yearly{} M.Paused{} None{}:
      v2_fin(~digits, i, p, c, M.Yearly{}, M.Paused{}, None{})
    case M.Yearly{} M.Paused{} Some{b}:
      v2_fin(~digits, i, p, c, M.Yearly{}, M.Paused{}, Some{b})
    case M.Yearly{} M.Cancelled{} None{}:
      v2_fin(~digits, i, p, c, M.Yearly{}, M.Cancelled{}, None{})
    case M.Yearly{} M.Cancelled{} Some{b}:
      v2_fin(~digits, i, p, c, M.Yearly{}, M.Cancelled{}, Some{b})

def v3_shape(~digits: @n: U32 -> {M.u32.read(M.u32.text(n)) == Some{n} : Maybe<&2, U32>}, +i: U32, -p: Bytes.Bytes, +c: U32, pe: M.Period, s: M.Status) -> {M.decode.shape(M.V3.json(M.V3{i, p, c, pe, s})) == Done{M.R3{M.V3{i, p, c, pe, s}}} : Result<&1, &1, M.Error, M.Record>}:
  match pe s:
    case M.Monthly{} M.Active{}:
      v3_fin(~digits, i, p, c, M.Monthly{}, M.Active{})
    case M.Monthly{} M.Paused{}:
      v3_fin(~digits, i, p, c, M.Monthly{}, M.Paused{})
    case M.Monthly{} M.Cancelled{}:
      v3_fin(~digits, i, p, c, M.Monthly{}, M.Cancelled{})
    case M.Yearly{} M.Active{}:
      v3_fin(~digits, i, p, c, M.Yearly{}, M.Active{})
    case M.Yearly{} M.Paused{}:
      v3_fin(~digits, i, p, c, M.Yearly{}, M.Paused{})
    case M.Yearly{} M.Cancelled{}:
      v3_fin(~digits, i, p, c, M.Yearly{}, M.Cancelled{})

def Laws.shape_roundtrip(digits, r):
  match r:
    case M.R1{M.V1{i, p, c, a}}:
      v1_fin(~digits, i, p, c, a)
    case M.R2{M.V2{i, p, c, pe, s, n}}:
      v2_shape(~digits, i, p, c, pe, s, n)
    case M.R3{M.V3{i, p, c, pe, s}}:
      v3_shape(~digits, i, p, c, pe, s)

def true_motive(b: Bool) -> Type:
  match b:
    case True{}:
      Empty
    case False{}:
      Unit

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : true_motive(_)
  Unit{}

def check_if_done(m: Maybe<&2, M.Key>, -x: M.Record, e: {M.none(m) == True{} : Bool}) -> {M.Record.check.if(m, x) == Done{x} : Result<&1, &1, M.Error, M.Record>}:
  match m:
    case None{}:
      {==}
    case Some{k}:
      Empty.absurd({M.Record.check.if(Some{k}, x) == Done{x} : Result<&1, &1, M.Error, M.Record>}, false_true(e))

def Laws.val_roundtrip(digits, r, h):
  match r:
    case M.R1{M.V1{+i, Bytes.Bytes{+len, buf}, +c, +a}}:
      %Equal.sym(Result<&1, &1, M.Error, M.Record>, M.decode.shape(M.Record.json(M.R1{M.V1{i, Bytes.Bytes{len, buf}, c, a}})), Done{M.R1{M.V1{i, Bytes.Bytes{len, buf}, c, a}}}, Laws.shape_roundtrip(~digits, M.R1{M.V1{i, Bytes.Bytes{len, buf}, c, a}})) : {Result.bind(&1, &1, M.Error, M.Record, M.Record, _, M.Record.check) == Done{M.R1{M.V1{i, Bytes.Bytes{len, buf}, c, a}}} : Result<&1, &1, M.Error, M.Record>}
      check_if_done(M.Terms.problem(len, c), M.R1{M.V1{i, Bytes.Bytes{len, buf}, c, a}}, h)
    case M.R2{M.V2{+i, Bytes.Bytes{+len, buf}, +c, +pe, +s, n}}:
      %Equal.sym(Result<&1, &1, M.Error, M.Record>, M.decode.shape(M.Record.json(M.R2{M.V2{i, Bytes.Bytes{len, buf}, c, pe, s, n}})), Done{M.R2{M.V2{i, Bytes.Bytes{len, buf}, c, pe, s, n}}}, Laws.shape_roundtrip(~digits, M.R2{M.V2{i, Bytes.Bytes{len, buf}, c, pe, s, n}})) : {Result.bind(&1, &1, M.Error, M.Record, M.Record, _, M.Record.check) == Done{M.R2{M.V2{i, Bytes.Bytes{len, buf}, c, pe, s, n}}} : Result<&1, &1, M.Error, M.Record>}
      check_if_done(M.Terms.problem(len, c), M.R2{M.V2{i, Bytes.Bytes{len, buf}, c, pe, s, n}}, h)
    case M.R3{M.V3{+i, Bytes.Bytes{+len, buf}, +c, +pe, +s}}:
      %Equal.sym(Result<&1, &1, M.Error, M.Record>, M.decode.shape(M.Record.json(M.R3{M.V3{i, Bytes.Bytes{len, buf}, c, pe, s}})), Done{M.R3{M.V3{i, Bytes.Bytes{len, buf}, c, pe, s}}}, Laws.shape_roundtrip(~digits, M.R3{M.V3{i, Bytes.Bytes{len, buf}, c, pe, s}})) : {Result.bind(&1, &1, M.Error, M.Record, M.Record, _, M.Record.check) == Done{M.R3{M.V3{i, Bytes.Bytes{len, buf}, c, pe, s}}} : Result<&1, &1, M.Error, M.Record>}
      check_if_done(M.Terms.problem(len, c), M.R3{M.V3{i, Bytes.Bytes{len, buf}, c, pe, s}}, h)
