import Base
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-resources@0.1.0.0/resources.bend as Res
import ./ledger.bend as Ledger

def state(capacity: Nat, +held: Nat, completed: Nat, rejected: Nat) -> Ledger.Ledger:
  Ledger.Ledger{Res.Pool{0n, capacity, held}, Res.Grant{0n, held}, completed, rejected}

def snapshot(counted: Ledger.Counts & Ledger.Ledger) -> Ledger.Counts:
  (counts, kept) = counted
  counts

def view(ledger: Ledger.Ledger) -> Ledger.Counts:
  snapshot(Ledger.counts(ledger))

def give(value: Maybe<&1, Ledger.Ledger>) -> Maybe<&1, Ledger.Ledger>:
  match value:
    case None{}:
      None{}
    case Some{ledger}:
      Ledger.give(ledger)

def bounded(value: Maybe<&1, Ledger.Ledger>) -> Data:
  match value:
    case None{}:
      Unit
    case Some{Ledger.Ledger{Res.Pool{owner, capacity, held}, lent, completed, rejected}}:
      MNat.le(held, capacity)

law counts:
  for c: Nat
  for h: Nat
  for d: Nat
  for r: Nat
  {view(state(c, h, d, r)) == Ledger.Counts{c, h, d, r} : Ledger.Counts}

law fresh_give:
  for c: Nat
  {Ledger.give(Ledger.open(c)) == None{} : Maybe<&1, Ledger.Ledger>}

law lend_admits:
  for c: Nat
  for h: Nat
  for d: Nat
  for r: Nat
  for fits: MNat.le(Nat.add(h, 1n), c)
  {Ledger.lend(state(c, h, d, r)) == Some{state(c, Nat.add(h, 1n), d, r)} : Maybe<&1, Ledger.Ledger>}

law give_releases:
  for c: Nat
  for h: Nat
  for d: Nat
  for r: Nat
  {Ledger.give(state(c, 1n+h, d, r)) == Some{state(c, h, 1n+d, r)} : Maybe<&1, Ledger.Ledger>}

law lend_give:
  for c: Nat
  for h: Nat
  for d: Nat
  for r: Nat
  for fits: MNat.le(Nat.add(h, 1n), c)
  {give(Ledger.lend(state(c, h, d, r))) == Some{state(c, h, 1n+d, r)} : Maybe<&1, Ledger.Ledger>}

law full_lend:
  for c: Nat
  for d: Nat
  for r: Nat
  {Ledger.lend(state(c, c, d, r)) == None{} : Maybe<&1, Ledger.Ledger>}

law open_bounded:
  for c: Nat
  bounded(Some{Ledger.open(c)})

law lend_bounded:
  for c: Nat
  for h: Nat
  for d: Nat
  for r: Nat
  for valid: MNat.le(h, c)
  bounded(Ledger.lend(state(c, h, d, r)))

law give_bounded:
  for c: Nat
  for h: Nat
  for d: Nat
  for r: Nat
  for valid: MNat.le(h, c)
  bounded(Ledger.give(state(c, h, d, r)))

law conservation:
  for c: Nat
  for h: Nat
  for valid: MNat.le(h, c)
  {Nat.add(Res.available(Res.Pool{0n, c, h}), Res.reserved(Res.Pool{0n, c, h})) == c : Nat}
