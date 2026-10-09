import Base
import bend-mathlib@0.7.2.0/nat.bend as MNat
import ./resources.bend as Res
import ./LAWS.bend as Laws

def Laws.available_add_reserved(o, c, h, e):
  MNat.sub_add_cancel(c, h, e)

def Laws.reserve_admits(o, c, h, n, e):
  %Equal.sym(Bool, Nat.is_le(Nat.add(h, n), c), True{}, e) : {Laws.reserve.view(Res.reserve.go(_, o, c, h, n)) == (Res.Pool{o, c, Nat.add(h, n)}, Some{Laws.Held{o, n}}) : Res.Pool & Maybe<&2, Laws.Held>}
  {==}

def Laws.reserve_rejects(o, c, h, n, e):
  %Equal.sym(Bool, Nat.is_le(Nat.add(h, n), c), False{}, e) : {Laws.reserve.view(Res.reserve.go(_, o, c, h, n)) == (Res.Pool{o, c, h}, None{}) : Res.Pool & Maybe<&2, Laws.Held>}
  {==}

def reserve_capacity.go(b: Bool, -o: Nat, -c: Nat, -h: Nat, -n: Nat) -> {Res.capacity(Laws.reserve.pool(Res.reserve.go(b, o, c, h, n))) == c : Nat}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.reserve_capacity(o, c, h, n):
  +c = c
  +h = h
  +n = n
  reserve_capacity.go(Nat.is_le(Nat.add(h, n), c), o, c, h, n)

def reserve_bounded.go(b: Bool, -o: Nat, -c: Nat, -h: Nat, -n: Nat, eb: {Nat.is_le(Nat.add(h, n), c) == b : Bool}, e: MNat.le(h, c)) -> MNat.le(Res.reserved(Laws.reserve.pool(Res.reserve.go(b, o, c, h, n))), c):
  match b:
    case True{}:
      eb
    case False{}:
      e

def Laws.reserve_bounded(o, c, h, n, e):
  +c = c
  +h = h
  +n = n
  reserve_bounded.go(Nat.is_le(Nat.add(h, n), c), o, c, h, n, {==}, e)

def reserve_release.go(b: Bool, +o: Nat, +c: Nat, +h: Nat, +n: Nat) -> {Laws.round_trip(Res.reserve.go(b, o, c, h, n)) == Res.Pool{o, c, h} : Res.Pool}:
  match b:
    case True{}:
      %Equal.sym(Bool, Nat.is_eq(o, o), True{}, MNat.is_eq_refl(o)) : {Laws.release.pool(Res.release.go(Bool.and(_, Nat.is_le(n, Nat.add(h, n))), o, c, Nat.add(h, n), o, n)) == Res.Pool{o, c, h} : Res.Pool}
      %Equal.sym(Bool, Nat.is_le(n, Nat.add(h, n)), True{}, MNat.le_add_left(n, h)) : {Laws.release.pool(Res.release.go(_, o, c, Nat.add(h, n), o, n)) == Res.Pool{o, c, h} : Res.Pool}
      %Equal.sym(Nat, Nat.sub(Nat.add(h, n), n), h, MNat.add_sub_cancel(h, n)) : {Res.Pool{o, c, _} == Res.Pool{o, c, h} : Res.Pool}
      {==}
    case False{}:
      {==}

def Laws.reserve_release(o, c, h, n):
  +c = c
  +h = h
  +n = n
  reserve_release.go(Nat.is_le(Nat.add(h, n), c), o, c, h, n)

def Laws.release_frees(o, c, h, n, e):
  %Equal.sym(Bool, Nat.is_eq(o, o), True{}, MNat.is_eq_refl(o)) : {Laws.release.view(Res.release.go(Bool.and(_, Nat.is_le(n, h)), o, c, h, o, n)) == (Res.Pool{o, c, Nat.sub(h, n)}, None{}) : Res.Pool & Maybe<&2, Laws.Held>}
  %Equal.sym(Bool, Nat.is_le(n, h), True{}, e) : {Laws.release.view(Res.release.go(_, o, c, h, o, n)) == (Res.Pool{o, c, Nat.sub(h, n)}, None{}) : Res.Pool & Maybe<&2, Laws.Held>}
  {==}

def Laws.release_foreign(o, c, h, q, n, e):
  %Equal.sym(Bool, Nat.is_eq(o, q), False{}, e) : {Laws.release.view(Res.release.go(Bool.and(_, Nat.is_le(n, h)), o, c, h, q, n)) == (Res.Pool{o, c, h}, Some{Laws.Held{q, n}}) : Res.Pool & Maybe<&2, Laws.Held>}
  {==}

def release_excess.go(b: Bool, -o: Nat, -c: Nat, -h: Nat, -q: Nat, -n: Nat) -> {Laws.release.view(Res.release.go(Bool.and(b, False{}), o, c, h, q, n)) == (Res.Pool{o, c, h}, Some{Laws.Held{q, n}}) : Res.Pool & Maybe<&2, Laws.Held>}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.release_excess(o, c, h, q, n, e):
  +o = o
  +q = q
  %Equal.sym(Bool, Nat.is_le(n, h), False{}, e) : {Laws.release.view(Res.release.go(Bool.and(Nat.is_eq(o, q), _), o, c, h, q, n)) == (Res.Pool{o, c, h}, Some{Laws.Held{q, n}}) : Res.Pool & Maybe<&2, Laws.Held>}
  release_excess.go(Nat.is_eq(o, q), o, c, h, q, n)

def release_capacity.go(b: Bool, -o: Nat, -c: Nat, -h: Nat, -q: Nat, -n: Nat) -> {Res.capacity(Laws.release.pool(Res.release.go(b, o, c, h, q, n))) == c : Nat}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.release_capacity(o, c, h, q, n):
  +o = o
  +q = q
  +n = n
  +h = h
  release_capacity.go(Bool.and(Nat.is_eq(o, q), Nat.is_le(n, h)), o, c, h, q, n)

def release_bounded.go(b: Bool, -o: Nat, +c: Nat, +h: Nat, -q: Nat, +n: Nat, e: MNat.le(h, c)) -> MNat.le(Res.reserved(Laws.release.pool(Res.release.go(b, o, c, h, q, n))), c):
  match b:
    case True{}:
      MNat.le_trans(Nat.sub(h, n), h, c, MNat.sub_le(h, n), e)
    case False{}:
      e

def Laws.release_bounded(o, c, h, q, n, e):
  +o = o
  +q = q
  +n = n
  +h = h
  release_bounded.go(Bool.and(Nat.is_eq(o, q), Nat.is_le(n, h)), o, c, h, q, n, e)

def Laws.split_parts(o, a, n, e):
  %Equal.sym(Bool, Nat.is_le(n, a), True{}, e) : {Laws.split.view(Res.split.go(_, o, a, n)) == [Laws.Held{o, n}, Laws.Held{o, Nat.sub(a, n)}] : List<&2, Laws.Held>}
  {==}

def split_total.go(b: Bool, -o: Nat, +a: Nat, +n: Nat, eb: {Nat.is_le(n, a) == b : Bool}) -> {Laws.total(Laws.split.view(Res.split.go(b, o, a, n))) == a : Nat}:
  match b:
    case True{}:
      %Equal.sym(Nat, Nat.add(Nat.sub(a, n), 0n), Nat.sub(a, n), MNat.add_zero(Nat.sub(a, n))) : {Nat.add(n, _) == a : Nat}
      MNat.add_sub_of_le(n, a, eb)
    case False{}:
      MNat.add_zero(a)

def Laws.split_total(o, a, n):
  +a = a
  +n = n
  split_total.go(Nat.is_le(n, a), o, a, n, {==})

def Laws.combine_joins(o, a, b):
  %Equal.sym(Bool, Nat.is_eq(o, o), True{}, MNat.is_eq_refl(o)) : {Laws.combine.view(Res.combine.go(_, o, a, o, b)) == [Laws.Held{o, Nat.add(a, b)}] : List<&2, Laws.Held>}
  {==}

def Laws.combine_apart(o, a, q, b, e):
  %Equal.sym(Bool, Nat.is_eq(o, q), False{}, e) : {Laws.combine.view(Res.combine.go(_, o, a, q, b)) == [Laws.Held{o, a}, Laws.Held{q, b}] : List<&2, Laws.Held>}
  {==}

def combine_total.go(s: Bool, -o: Nat, +a: Nat, -q: Nat, +b: Nat) -> {Laws.total(Laws.combine.view(Res.combine.go(s, o, a, q, b))) == Nat.add(a, b) : Nat}:
  match s:
    case True{}:
      MNat.add_zero(Nat.add(a, b))
    case False{}:
      Equal.cong(Nat, Nat, x => Nat.add(a, x), Nat.add(b, 0n), b, MNat.add_zero(b))

def Laws.combine_total(o, a, q, b):
  +o = o
  +q = q
  combine_total.go(Nat.is_eq(o, q), o, a, q, b)
