import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import bend-kit-json@0.6.1.1/json.bend as Json
import ./migrate.bend as M
import ./LAWS.bend as Laws

# Result lemmas
# -------------

def fail_done.motive(r: Result<&2, &2, M.Error, M.V1>) -> Type:
  match r:
    case Fail{e}:
      Unit
    case Done{x}:
      Empty

def fail_done(e: M.Error, s: M.V1, h: {Fail{e} == Done{s} : Result<&2, &2, M.Error, M.V1>}) -> Empty:
  %h : fail_done.motive(_)
  Unit{}

def done_inj(+x: M.V1, +s: M.V1, h: {Done{x} == Done{s} : Result<&2, &2, M.Error, M.V1>}) -> {x == s : M.V1}:
  %h : {x == Result.default(&2, &2, M.Error, M.V1, _, x) : M.V1}
  {==}

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
      Empty.absurd({M.V1.up(s) == M.V2{i, p, c, M.Yearly{}, st, n} : M.V2}, fail_done(M.NotInV1{"period"}, s, h))
    case M.V2{i, p, c, M.Monthly{}, M.Paused{}, n}:
      Empty.absurd({M.V1.up(s) == M.V2{i, p, c, M.Monthly{}, M.Paused{}, n} : M.V2}, fail_done(M.NotInV1{"status"}, s, h))
    case M.V2{i, p, c, M.Monthly{}, M.Active{}, SCon{h1, t}}:
      Empty.absurd({M.V1.up(s) == M.V2{i, p, c, M.Monthly{}, M.Active{}, SCon{h1, t}} : M.V2}, fail_done(M.NotInV1{"note"}, s, h))
    case M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, SCon{h1, t}}:
      Empty.absurd({M.V1.up(s) == M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, SCon{h1, t}} : M.V2}, fail_done(M.NotInV1{"note"}, s, h))
    case M.V2{+i, +p, +c, M.Monthly{}, M.Active{}, SNil{}}:
      %done_inj(M.V1{i, p, c, True{}}, s, h) : {M.V1.up(_) == M.V2{i, p, c, M.Monthly{}, M.Active{}, SNil{}} : M.V2}
      {==}
    case M.V2{+i, +p, +c, M.Monthly{}, M.Cancelled{}, SNil{}}:
      %done_inj(M.V1{i, p, c, False{}}, s, h) : {M.V1.up(_) == M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, SNil{}} : M.V2}
      {==}

def Laws.down2_terms(r, s, h):
  +s = s
  %Laws.up_down2(r, s, h) : {M.V1.terms(s) == M.V2.terms(_) : M.Terms}
  Equal.sym(M.Terms, M.V2.terms(M.V1.up(s)), M.V1.terms(s), Laws.up1_terms(s))

def Laws.down2_domain(r):
  match r:
    case M.V2{i, p, c, M.Yearly{}, st, n}:
      {==}
    case M.V2{i, p, c, M.Monthly{}, M.Paused{}, n}:
      {==}
    case M.V2{i, p, c, M.Monthly{}, M.Active{}, SCon{h, t}}:
      {==}
    case M.V2{i, p, c, M.Monthly{}, M.Active{}, SNil{}}:
      {==}
    case M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, SCon{h, t}}:
      {==}
    case M.V2{i, p, c, M.Monthly{}, M.Cancelled{}, SNil{}}:
      {==}

# Validity
# --------

def Laws.upgrade_valid(r, h):
  match r:
    case M.R1{M.V1{i, p, c, a}}:
      h
    case M.R2{M.V2{i, p, c, pe, s, n}}:
      h
    case M.R3{M.V3{i, p, c, pe, s}}:
      h

def check_of_ok(m: Maybe<&2, String>, +r: M.Record, e: {m == M.Terms.problem(M.Record.terms(r)) : Maybe<&2, String>}) -> {Laws.decoded_ok(M.Record.check.of(m, r)) == True{} : Bool}:
  match m:
    case None{}:
      %e : {M.none(_) == True{} : Bool}
      {==}
    case Some{f}:
      {==}

def bind_ok(x: Result<&2, &2, M.Error, M.Record>) -> {Laws.decoded_ok(Result.bind(&2, &2, M.Error, M.Record, M.Record, x, M.Record.check)) == True{} : Bool}:
  match x:
    case Fail{e}:
      {==}
    case Done{+r}:
      check_of_ok(M.Terms.problem(M.Record.terms(r)), r, {==})

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
