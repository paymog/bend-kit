# Pure bounded owner accounting; host lifecycle effects are outside these laws.
import Base
import bend-kit-resources@0.1.0.0/resources.bend as Res

type Counts is Data:
  Counts{capacity: Nat, in_use: Nat, completed: Nat, rejected: Nat}

type Ledger is Type:
  Ledger{pool: Res.Pool, lent: Res.Grant, completed: Nat, rejected: Nat}

def open(capacity: Nat) -> Ledger:
  Ledger{Res.new(0n, capacity), Res.Grant{0n, 0n}, 0n, 0n}

def counts(ledger: Ledger) -> Counts & Ledger:
  Ledger{+pool, lent, +completed, +rejected} = ledger
  (Counts{Res.capacity(pool), Res.reserved(pool), completed, rejected}, Ledger{pool, lent, completed, rejected})

def refuse(ledger: Ledger) -> Ledger:
  Ledger{pool, lent, completed, rejected} = ledger
  Ledger{pool, lent, completed, 1n+rejected}

def joined(combined: Res.Combine, pool: Res.Pool, completed: Nat, rejected: Nat) -> Maybe<&1, Ledger>:
  match combined:
    case Res.Joined{grant}:
      Some{Ledger{pool, grant, completed, rejected}}
    case Res.Apart{first, second}:
      None{}

def took(reserved: Res.Reserve, lent: Res.Grant, completed: Nat, rejected: Nat) -> Maybe<&1, Ledger>:
  match reserved:
    case Res.Took{pool, grant}:
      joined(Res.combine(lent, grant), pool, completed, rejected)
    case Res.Refused{pool}:
      None{}

def lend(ledger: Ledger) -> Maybe<&1, Ledger>:
  Ledger{pool, lent, completed, rejected} = ledger
  took(Res.reserve(pool, 1n), lent, completed, rejected)

def released(released: Res.Release, rest: Res.Grant, completed: Nat, rejected: Nat) -> Maybe<&1, Ledger>:
  match released:
    case Res.Released{pool}:
      Some{Ledger{pool, rest, 1n+completed, rejected}}
    case Res.Kept{pool, grant}:
      None{}

def split(parts: Res.Split, pool: Res.Pool, completed: Nat, rejected: Nat) -> Maybe<&1, Ledger>:
  match parts:
    case Res.Parts{one, rest}:
      released(Res.release(pool, one), rest, completed, rejected)
    case Res.Whole{grant}:
      None{}

def give(ledger: Ledger) -> Maybe<&1, Ledger>:
  Ledger{pool, lent, completed, rejected} = ledger
  split(Res.split(lent, 1n), pool, completed, rejected)
