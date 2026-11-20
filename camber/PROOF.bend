import Base
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-resources@0.1.0.0/resources.bend as Res
import ./ledger.bend as Ledger
import ./LAWS.bend as Laws
import ../resources/LAWS.bend as ResourceLaws
import ../resources/PROOF.bend as ResourceProof

def Laws.counts(c, h, d, r):
  {==}

def Laws.fresh_give(c):
  {==}

def Laws.lend_admits(c, h, d, r, fits):
  %Equal.sym(Bool, Nat.is_le(Nat.add(h, 1n), c), True{}, fits) : {Ledger.took(Res.reserve.go(_, 0n, c, h, 1n), Res.Grant{0n, h}, d, r) == Some{Laws.state(c, Nat.add(h, 1n), d, r)} : Maybe<&1, Ledger.Ledger>}
  {==}

def Laws.give_releases(c, h, d, r):
  +h = h
  %Equal.sym(Bool, Nat.is_le(0n, h), True{}, MNat.zero_le(h)) : {Ledger.split(Res.split.go(_, 0n, 1n+h, 1n), Res.Pool{0n, c, 1n+h}, d, r) == Some{Laws.state(c, h, 1n+d, r)} : Maybe<&1, Ledger.Ledger>}
  %Equal.sym(Bool, Nat.is_le(0n, h), True{}, MNat.zero_le(h)) : {Ledger.released(Res.release.go(_, 0n, c, 1n+h, 0n, 1n), Res.Grant{0n, Nat.sub(h, 0n)}, d, r) == Some{Laws.state(c, h, 1n+d, r)} : Maybe<&1, Ledger.Ledger>}
  %Equal.sym(Nat, Nat.sub(h, 0n), h, MNat.sub_zero(h)) : {Some{Laws.state(c, _, 1n+d, r)} == Some{Laws.state(c, h, 1n+d, r)} : Maybe<&1, Ledger.Ledger>}
  {==}

def add_one(+h: Nat) -> {Nat.add(h, 1n) == 1n+h : Nat}:
  %Equal.sym(Nat, Nat.add(h, 1n), 1n+Nat.add(h, 0n), MNat.add_succ(h, 0n)) : {_ == 1n+h : Nat}
  %Equal.sym(Nat, Nat.add(h, 0n), h, MNat.add_zero(h)) : {1n+_ == 1n+h : Nat}
  {==}

def Laws.lend_give(c, h, d, r, fits):
  +c = c
  +h = h
  +d = d
  +r = r
  %Equal.sym(Maybe<&1, Ledger.Ledger>, Ledger.lend(Laws.state(c, h, d, r)), Some{Laws.state(c, Nat.add(h, 1n), d, r)}, Laws.lend_admits(c, h, d, r, fits)) : {Laws.give(_) == Some{Laws.state(c, h, 1n+d, r)} : Maybe<&1, Ledger.Ledger>}
  %Equal.sym(Nat, Nat.add(h, 1n), 1n+h, add_one(h)) : {Ledger.give(Laws.state(c, _, d, r)) == Some{Laws.state(c, h, 1n+d, r)} : Maybe<&1, Ledger.Ledger>}
  Laws.give_releases(c, h, d, r)

def successor_not_le(+c: Nat) -> {Nat.is_le(1n+c, c) == False{} : Bool}:
  match c:
    case 0n:
      {==}
    case 1n+p:
      successor_not_le(p)

def Laws.full_lend(c, d, r):
  +c = c
  %Equal.sym(Nat, Nat.add(c, 1n), 1n+c, add_one(c)) : {Ledger.took(Res.reserve.go(Nat.is_le(_, c), 0n, c, c, 1n), Res.Grant{0n, c}, d, r) == None{} : Maybe<&1, Ledger.Ledger>}
  %Equal.sym(Bool, Nat.is_le(1n+c, c), False{}, successor_not_le(c)) : {Ledger.took(Res.reserve.go(_, 0n, c, c, 1n), Res.Grant{0n, c}, d, r) == None{} : Maybe<&1, Ledger.Ledger>}
  {==}

def Laws.open_bounded(c):
  MNat.zero_le(c)

def lend_bounded(fits: Bool, +c: Nat, +h: Nat, -d: Nat, -r: Nat, evidence: {Nat.is_le(Nat.add(h, 1n), c) == fits : Bool}) -> Laws.bounded(Ledger.took(Res.reserve.go(fits, 0n, c, h, 1n), Res.Grant{0n, h}, d, r)):
  match fits:
    case False{}:
      Unit{}
    case True{}:
      evidence

def Laws.lend_bounded(c, h, d, r, valid):
  +c = c
  +h = h
  lend_bounded(Nat.is_le(Nat.add(h, 1n), c), c, h, d, r, {==})

def Laws.give_bounded(c, h, d, r, valid):
  match h:
    case 0n:
      Unit{}
    case 1n+p:
      +p = p
      +c = c
      %Equal.sym(Maybe<&1, Ledger.Ledger>, Ledger.give(Laws.state(c, 1n+p, d, r)), Some{Laws.state(c, p, 1n+d, r)}, Laws.give_releases(c, p, d, r)) : Laws.bounded(_)
      MNat.le_trans(p, 1n+p, c, MNat.le_succ(p), valid)

def Laws.conservation(c, h, valid):
  ResourceLaws.available_add_reserved(0n, c, h, valid)
