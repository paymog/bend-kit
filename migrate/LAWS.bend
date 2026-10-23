import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import bend-kit-json@0.6.1.1/json.bend as Json
import ./migrate.bend as M

def v3(p: M.V3 & M.Dropped) -> M.V3:
  (r, d) = p
  r

def dropped(p: M.V3 & M.Dropped) -> M.Dropped:
  (r, d) = p
  d

def note(r: M.V2) -> String:
  M.V2{i, p, c, pe, s, n} = r
  n

# The v2 record rebuilt from what V2.up keeps and what it drops.
def restore(p: M.V3 & M.Dropped) -> M.V2:
  (r, d) = p
  M.V3.restore(r, d)

# The direct meaning of a v1 record in v3: a monthly price, active or cancelled.
def direct(r: M.V1) -> M.V3:
  M.V1{i, p, c, a} = r
  M.V3{i, p, c, M.Monthly{}, M.Status.of_active(a)}

def monthly(p: M.Period) -> Bool:
  match p:
    case M.Monthly{}:
      True{}
    case M.Yearly{}:
      False{}

def unpaused(s: M.Status) -> Bool:
  match s:
    case M.Paused{}:
      False{}
    case M.Active{}:
      True{}
    case M.Cancelled{}:
      True{}

# The v2 records that v1 can hold: monthly, not paused, and with no note.
def in_v1(r: M.V2) -> Bool:
  M.V2{i, p, c, pe, s, n} = r
  Bool.and(monthly(pe), Bool.and(unpaused(s), String.is_empty(n)))

# A decode answer is an error or a valid record.
def decoded_ok(r: Result<&2, &2, M.Error, M.Record>) -> Bool:
  match r:
    case Fail{e}:
      True{}
    case Done{x}:
      M.Record.valid(x)

# Business fields
# ---------------

law up1_terms:
  for r: M.V1
  {M.V2.terms(M.V1.up(r)) == M.V1.terms(r) : M.Terms}

law up2_terms:
  for r: M.V2
  {M.V3.terms(v3(M.V2.up(r))) == M.V2.terms(r) : M.Terms}

law down2_terms:
  for r: M.V2
  for s: M.V1
  for h: {M.V2.down(r) == Done{s} : Result<&2, &2, M.Error, M.V1>}
  {M.V1.terms(s) == M.V2.terms(r) : M.Terms}

law down3_terms:
  for r: M.V3
  {M.V2.terms(M.V3.down(r)) == M.V3.terms(r) : M.Terms}

law upgrade_terms:
  for r: M.Record
  {M.V3.terms(v3(M.Record.upgrade(r))) == M.Record.terms(r) : M.Terms}

# Validity
# --------

# A valid record of any version upgrades to a valid v3 record.
law upgrade_valid:
  for r: M.Record
  for h: {M.Record.valid(r) == True{} : Bool}
  {M.Terms.valid(M.V3.terms(v3(M.Record.upgrade(r)))) == True{} : Bool}

# Decode never returns a record that breaks the business rules.
law decode_val_valid:
  for v: Json.Val
  {decoded_ok(M.decode.val(v)) == True{} : Bool}

law decode_valid:
  for b: Bytes.Bytes
  {decoded_ok(M.decode(b)) == True{} : Bool}

# Chains
# ------

# v1 through v2 to v3 is the direct v1 meaning, and drops nothing.
law chain_v1:
  for r: M.V1
  {M.Record.upgrade(M.R1{r}) == (direct(r), M.Dropped{""}) : M.V3 & M.Dropped}

law chain_v2:
  for r: M.V2
  {M.Record.upgrade(M.R2{r}) == M.V2.up(r) : M.V3 & M.Dropped}

law chain_v3:
  for r: M.V3
  {M.Record.upgrade(M.R3{r}) == (r, M.Dropped{""}) : M.V3 & M.Dropped}

# Reversible: v1 and v2
# ---------------------

law down_up1:
  for r: M.V1
  {M.V2.down(M.V1.up(r)) == Done{r} : Result<&2, &2, M.Error, M.V1>}

law up_down2:
  for r: M.V2
  for s: M.V1
  for h: {M.V2.down(r) == Done{s} : Result<&2, &2, M.Error, M.V1>}
  {M.V1.up(s) == r : M.V2}

# V2.down succeeds exactly on the records v1 can hold.
law down2_domain:
  for r: M.V2
  {Result.is_done(&2, &2, M.Error, M.V1, M.V2.down(r)) == in_v1(r) : Bool}

# Lossy: v2 to v3
# ---------------

# The dropped part is exactly the note: with it, the v2 record comes back.
law up2_restore:
  for r: M.V2
  {restore(M.V2.up(r)) == r : M.V2}

law up2_dropped:
  for +r: M.V2
  {dropped(M.V2.up(r)) == M.Dropped{note(r)} : M.Dropped}

# Two records that differ only in their notes upgrade to the same v3 record.
law up2_forgets_note:
  for +i: U32
  for +p: String
  for +c: U32
  for +pe: M.Period
  for +s: M.Status
  for n: String
  for m: String
  {v3(M.V2.up(M.V2{i, p, c, pe, s, n})) == v3(M.V2.up(M.V2{i, p, c, pe, s, m})) : M.V3}

# A v3 record with an empty note round-trips through v2.
law up_down3:
  for r: M.V3
  {M.V2.up(M.V3.down(r)) == (r, M.Dropped{""}) : M.V3 & M.Dropped}
