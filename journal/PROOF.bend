import Base
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-mathlib@0.8.0.0/bool.bend as MBool
import bend-mathlib@0.8.0.0/list.bend as MList
import ../lemmas/lemmas.bend as Lemmas
import ./LAWS.bend as Laws
import ./journal.bend as J

def cat(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, xs, ys)

def len(xs: List<&2, U32>) -> Nat:
  List.length(&2, U32, xs)

def R() -> Type:
  J.Recovery<&2, List<&2, U32>, List<&2, U32>>
def boom(-A: Type, e: {True{} == False{} : Bool}) -> A:
  Empty.absurd(A, MBool.false_ne_true()(Equal.sym(Bool, True{}, False{}, e)))

def boom2(-A: Type, e: {False{} == True{} : Bool}) -> A:
  Empty.absurd(A, MBool.false_ne_true()(e))

def eq_refl(+a: U32) -> {U32.is_eq(a, a) == True{} : Bool}:
  Equal.trans(Bool, U32.is_eq(a, a), Nat.is_eq(U32.to_nat(a), U32.to_nat(a)), True{}, Lemmas.u32_is_eq_nat(a, a), MNat.is_eq_refl(U32.to_nat(a)))

def le_not(+a: Nat, +b: Nat, h: MNat.le(a, b)) -> {Bool.not(Nat.is_le(a, b)) == False{} : Bool}:
  Equal.cong(Bool, Bool, x => Bool.not(x), Nat.is_le(a, b), True{}, h)

def not_lt(+a: Nat, +b: Nat, h: MNat.le(b, a)) -> {Nat.is_lt(a, b) == False{} : Bool}:
  +f = Equal.sym(Bool, Bool.not(Nat.is_le(b, a)), Nat.is_lt(a, b), MNat.not_is_le(b, a))
  Equal.trans(Bool, Nat.is_lt(a, b), Bool.not(Nat.is_le(b, a)), False{}, f, le_not(b, a, h))

def not_gt(+a: U32, +b: U32, h: MNat.le(U32.to_nat(a), U32.to_nat(b))) -> {U32.is_gt(a, b) == False{} : Bool}:
  Equal.trans(Bool, U32.is_gt(a, b), Nat.is_gt(U32.to_nat(a), U32.to_nat(b)), False{},
    Equal.cong(Cmp, Bool, c => Cmp.is_gt(c), U32.cmp(a, b), Nat.cmp(U32.to_nat(a), U32.to_nat(b)), Lemmas.u32_cmp_nat(a, b)),
    Equal.trans(Bool, Nat.is_gt(U32.to_nat(a), U32.to_nat(b)), Nat.is_lt(U32.to_nat(b), U32.to_nat(a)), False{},
      MNat.is_gt_eq_is_lt(U32.to_nat(a), U32.to_nat(b)), not_lt(U32.to_nat(b), U32.to_nat(a), h)))

def below(+max: U32, k: Nat, h: MNat.le(k, U32.to_nat(max))) -> MNat.lt(k, Lemmas.pow2(32n)):
  MNat.lt_of_le_of_lt(k, U32.to_nat(max), Lemmas.pow2(32n), h, Lemmas.u32_to_nat_lt(max))

def from_eq(+k: Nat, +max: U32, h: MNat.le(k, U32.to_nat(max))) -> {U32.to_nat(U32.from_nat(k)) == k : Nat}:
  Lemmas.u32_to_from_nat(k, below(max, k, h))

def drop_h(h: List<&2, U32>, rest: List<&2, U32>, n: Nat) ->
  {List.drop(&2, U32, cat(h, rest), Nat.add(len(h), n)) == List.drop(&2, U32, rest, n) : List<&2, U32>}:
  match h:
    case Nil{}:
      {==}
    case x <> t:
      drop_h(t, rest, n)

def drop_rest(+h: List<&2, U32>, +p: List<&2, U32>, +t: List<&2, U32>, e: {len(h) == 12n : Nat}) ->
  {List.drop(&2, U32, cat(h, cat(p, t)), Nat.add(12n, len(p))) == t : List<&2, U32>}:
  %e : {List.drop(&2, U32, cat(h, cat(p, t)), Nat.add(_, len(p))) == t : List<&2, U32>}
  Equal.trans(List<&2, U32>,
    List.drop(&2, U32, cat(h, cat(p, t)), Nat.add(len(h), len(p))),
    List.drop(&2, U32, cat(p, t), len(p)), t,
    drop_h(h, cat(p, t), len(p)), MList.drop_left(&2, U32, p, t))

def Step() -> Type:
  J.Step<List<&2, U32>, List<&2, U32>>

def got(+len: U32, +xs: List<&2, U32>, p: List<&2, U32>) -> Step:
  J.Got{p, List.drop(&2, U32, xs, Nat.add(12n, U32.to_nat(len)))}

def verdict_b(ok: Bool, +len: U32, +xs: List<&2, U32>, p: List<&2, U32>, c: {ok == True{} : Bool}) ->
  {J.next.verdict(~List<&2, U32>, ~List<&2, U32>, ~J.list.skip, ok, len, xs, p) == got(len, xs, p) : Step}:
  match ok:
    case True{}:
      {==}
    case False{}:
      boom2({J.Bad{"checksum mismatch", xs} == got(len, xs, p) : Step}, c)

def body_b(whole: Bool, +len: U32, +xs: List<&2, U32>, +p: List<&2, U32>, w: {whole == True{} : Bool}, q: {List.take(&2, U32, List.drop(&2, U32, xs, 12n), U32.to_nat(len)) == p : List<&2, U32>}, c: {U32.is_eq(J.list.crc(p), J.list.field(List.drop(&2, U32, xs, 8n))) == True{} : Bool}) ->
  {J.next.body(~List<&2, U32>, ~List<&2, U32>, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, len, (xs, whole)) == got(len, xs, p) : Step}:
  match whole:
    case True{}:
      %Equal.sym(List<&2, U32>, List.take(&2, U32, List.drop(&2, U32, xs, 12n), U32.to_nat(len)), p, q) : {J.next.verdict(~List<&2, U32>, ~List<&2, U32>, ~J.list.skip, U32.is_eq(J.list.crc(_), J.list.field(List.drop(&2, U32, xs, 8n))), len, xs, _) == got(len, xs, p) : Step}
      verdict_b(U32.is_eq(J.list.crc(p), J.list.field(List.drop(&2, U32, xs, 8n))), len, xs, p, c)
    case False{}:
      boom2({J.Short{xs} == got(len, xs, p) : Step}, w)

def size_ok(+max: U32, +l: U32, +xs: List<&2, U32>, +p: List<&2, U32>, g: {U32.is_gt(l, max) == False{} : Bool}, w: MNat.le(Nat.add(12n, U32.to_nat(l)), len(xs)), q: {List.take(&2, U32, List.drop(&2, U32, xs, 12n), U32.to_nat(l)) == p : List<&2, U32>}, c: {U32.is_eq(J.list.crc(p), J.list.field(List.drop(&2, U32, xs, 8n))) == True{} : Bool}) ->
  {J.next.size(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, U32.is_gt(l, max), l, xs) == got(l, xs, p) : Step}:
  %Equal.sym(Bool, U32.is_gt(l, max), False{}, g) : {J.next.size(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, _, l, xs) == got(l, xs, p) : Step}
  %Equal.sym(Bool, Nat.is_le(Nat.add(12n, U32.to_nat(l)), len(xs)), True{}, w) : {J.next.body(~List<&2, U32>, ~List<&2, U32>, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, l, (xs, _)) == got(l, xs, p) : Step}
  body_b(True{}, l, xs, p, {==}, q, c)

def head_ok(+max: U32, +l: U32, +xs: List<&2, U32>, +p: List<&2, U32>, e: {U32.is_eq(J.list.field(List.drop(&2, U32, xs, 4n)), U32.not(l)) == True{} : Bool}, g: {U32.is_gt(l, max) == False{} : Bool}, w: MNat.le(Nat.add(12n, U32.to_nat(l)), len(xs)), q: {List.take(&2, U32, List.drop(&2, U32, xs, 12n), U32.to_nat(l)) == p : List<&2, U32>}, c: {U32.is_eq(J.list.crc(p), J.list.field(List.drop(&2, U32, xs, 8n))) == True{} : Bool}) ->
  {J.next.len(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, max, (xs, l)) == got(l, xs, p) : Step}:
  %Equal.sym(Bool, U32.is_eq(J.list.field(List.drop(&2, U32, xs, 4n)), U32.not(l)), True{}, e) : {J.next.head(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, _, max, l, xs) == got(l, xs, p) : Step}
  size_ok(max, l, xs, p, g, w, q, c)

def take_drop_zero(+xs: List<&2, U32>, +n: Nat, +p: List<&2, U32>, q: {List.take(&2, U32, xs, n) == p : List<&2, U32>}) ->
  {List.take(&2, U32, List.drop(&2, U32, xs, 0n), n) == p : List<&2, U32>}:
  %MList.drop_zero_sym(&2, U32, xs) : {List.take(&2, U32, _, n) == p : List<&2, U32>}
  q

def next_head(+max: U32, +l: U32, +z: U32, +p: List<&2, U32>, +t: List<&2, U32>, g: {U32.is_gt(l, max) == False{} : Bool}, w: MNat.le(Nat.add(12n, U32.to_nat(l)), len(cat(J.list.head(l, z), cat(p, t)))), q: {List.take(&2, U32, cat(p, t), U32.to_nat(l)) == p : List<&2, U32>}, c: {U32.is_eq(J.list.crc(p), z) == True{} : Bool}) ->
  {J.list.next(max, cat(J.list.head(l, z), cat(p, t))) == got(l, cat(J.list.head(l, z), cat(p, t)), p) : Step}:
  head_ok(max, l, cat(J.list.head(l, z), cat(p, t)), p, eq_refl(U32.not(l)), g, w, take_drop_zero(cat(p, t), U32.to_nat(l), p, q), c)

def frame_bound(+max: U32, +p: List<&2, U32>, +t: List<&2, U32>, small: MNat.le(len(p), U32.to_nat(max))) ->
  MNat.le(Nat.add(12n, U32.to_nat(U32.from_nat(len(p)))), len(cat(J.list.head(U32.from_nat(len(p)), J.list.crc(p)), cat(p, t)))):
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(len(p))), len(p), from_eq(len(p), max, small)) : MNat.le(Nat.add(12n, _), len(cat(J.list.head(U32.from_nat(len(p)), J.list.crc(p)), cat(p, t))))
  %MList.length_append_sym(&2, U32, p, t) : MNat.le(len(p), _)
  MNat.le_add_right(len(p), len(t))

def from_small(+max: U32, +p: List<&2, U32>, +small: MNat.le(len(p), U32.to_nat(max))) ->
  MNat.le(U32.to_nat(U32.from_nat(len(p))), U32.to_nat(max)):
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(len(p))), len(p), from_eq(len(p), max, small)) : MNat.le(_, U32.to_nat(max))
  small

def frame_over(+max: U32, +p: List<&2, U32>, small: MNat.le(len(p), U32.to_nat(max))) ->
  {U32.is_gt(U32.from_nat(len(p)), max) == False{} : Bool}:
  not_gt(U32.from_nat(len(p)), max, from_small(max, p, small))

def frame_take(+max: U32, +p: List<&2, U32>, +t: List<&2, U32>, small: MNat.le(len(p), U32.to_nat(max))) ->
  {List.take(&2, U32, cat(p, t), U32.to_nat(U32.from_nat(len(p)))) == p : List<&2, U32>}:
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(len(p))), len(p), from_eq(len(p), max, small)) : {List.take(&2, U32, cat(p, t), _) == p : List<&2, U32>}
  MList.take_left(&2, U32, p, t)

def frame_drop(+max: U32, +p: List<&2, U32>, +t: List<&2, U32>, small: MNat.le(len(p), U32.to_nat(max))) ->
  {got(U32.from_nat(len(p)), cat(J.list.head(U32.from_nat(len(p)), J.list.crc(p)), cat(p, t)), p) == J.Got{p, t} : Step}:
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(len(p))), len(p), from_eq(len(p), max, small)) : {J.Got{p, List.drop(&2, U32, cat(J.list.head(U32.from_nat(len(p)), J.list.crc(p)), cat(p, t)), Nat.add(12n, _))} == J.Got{p, t} : Step}
  Equal.cong(List<&2, U32>, Step, s => J.Got{p, s},
    List.drop(&2, U32, cat(J.list.head(U32.from_nat(len(p)), J.list.crc(p)), cat(p, t)), Nat.add(12n, len(p))),
    t, drop_rest(J.list.head(U32.from_nat(len(p)), J.list.crc(p)), p, t, {==}))

def frame_next(+max: U32, +p: List<&2, U32>, +t: List<&2, U32>, +small: MNat.le(len(p), U32.to_nat(max))) ->
  {J.list.next(max, cat(J.list.frame(p), t)) == J.Got{p, t} : Step}:
  %MList.append_assoc_sym(&2, U32, J.list.head(U32.from_nat(len(p)), J.list.crc(p)), p, t) : {J.list.next(max, _) == J.Got{p, t} : Step}
  Equal.trans(Step,
    J.list.next(max, cat(J.list.head(U32.from_nat(len(p)), J.list.crc(p)), cat(p, t))),
    got(U32.from_nat(len(p)), cat(J.list.head(U32.from_nat(len(p)), J.list.crc(p)), cat(p, t)), p), J.Got{p, t},
    next_head(max, U32.from_nat(len(p)), J.list.crc(p), p, t, frame_over(max, p, small), frame_bound(max, p, t, small),
      frame_take(max, p, t, small), eq_refl(J.list.crc(p))),
    frame_drop(max, p, t, small))

def go(n: Nat, +max: U32, st: Step) -> R:
  J.recover.go(~&2, ~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, n, max, st)

def end_go(n: Nat, max: U32, xs: List<&2, U32>) -> {go(n, max, J.End{xs}) == J.Recovery{Nil{}, J.Clean{}, xs} : R}:
  match n:
    case 0n:
      {==}
    case 1n+m:
      {==}

def short_go(n: Nat, max: U32, xs: List<&2, U32>) -> {go(n, max, J.Short{xs}) == J.Recovery{Nil{}, J.Torn{}, xs} : R}:
  match n:
    case 0n:
      {==}
    case 1n+m:
      {==}

def bad_go(n: Nat, max: U32, why: String, xs: List<&2, U32>) -> {go(n, max, J.Bad{why, xs}) == J.Recovery{Nil{}, J.Corrupt{why}, xs} : R}:
  match n:
    case 0n:
      {==}
    case 1n+m:
      {==}

def clean_nil(n: Nat, +max: U32) -> {J.list.recover(n, max, Nil{}) == J.Recovery{Nil{}, J.Clean{}, Nil{}} : R}:
  end_go(n, max, Nil{})

def peel(+n: Nat, +max: U32, +p: List<&2, U32>, +t: List<&2, U32>, small: MNat.le(len(p), U32.to_nat(max))) ->
  {J.list.recover(1n+n, max, cat(J.list.frame(p), t)) == J.recover.con(~&2, ~List<&2, U32>, ~List<&2, U32>, p, J.list.recover(n, max, t)) : R}:
  %Equal.sym(Step, J.list.next(max, cat(J.list.frame(p), t)), J.Got{p, t}, frame_next(max, p, t, small)) : {go(1n+n, max, _) == J.recover.con(~&2, ~List<&2, U32>, ~List<&2, U32>, p, J.list.recover(n, max, t)) : R}
  {==}

def prefix(rs: List<&2, List<&2, U32>>, n: Nat, +max: U32, +t: List<&2, U32>, +tail: J.Tail, +fits: {Laws.fit(max, rs) == True{} : Bool}, enough: MNat.le(List.length(&2, List<&2, U32>, rs), n), stop: @m:Nat -> {J.list.recover(m, max, t) == J.Recovery{Nil{}, tail, t} : R}) ->
  {J.list.recover(n, max, cat(J.list.log(rs), t)) == J.Recovery{rs, tail, t} : R}:
  match rs:
    case Nil{}:
      stop(n)
    case Con{+p, +r}:
      match n:
        case 0n:
          boom2({J.list.recover(0n, max, cat(J.list.log(Con{p, r}), t)) == J.Recovery{Con{p, r}, tail, t} : R}, enough)
        case 1n+ +m:
          +small = MBool.eq_true_of_and_left(Nat.is_le(len(p), U32.to_nat(max)), Laws.fit(max, r), fits)
          +fitr = MBool.eq_true_of_and_right(Nat.is_le(len(p), U32.to_nat(max)), Laws.fit(max, r), fits)
          %MList.append_assoc_sym(&2, U32, J.list.frame(p), J.list.log(r), t) : {J.list.recover(1n+m, max, _) == J.Recovery{Con{p, r}, tail, t} : R}
          %Equal.sym(R, J.list.recover(1n+m, max, cat(J.list.frame(p), cat(J.list.log(r), t))), J.recover.con(~&2, ~List<&2, U32>, ~List<&2, U32>, p, J.list.recover(m, max, cat(J.list.log(r), t))), peel(m, max, p, cat(J.list.log(r), t), small)) : {_ == J.Recovery{Con{p, r}, tail, t} : R}
          %Equal.sym(R, J.list.recover(m, max, cat(J.list.log(r), t)), J.Recovery{r, tail, t}, prefix(r, m, max, t, tail, fitr, enough, stop)) : {J.recover.con(~&2, ~List<&2, U32>, ~List<&2, U32>, p, _) == J.Recovery{Con{p, r}, tail, t} : R}
          {==}

def Laws.roundtrip(n, max, rs, fits, enough):
  %MList.append_nil(&2, U32, J.list.log(rs)) : {J.list.recover(n, max, _) == J.Recovery{rs, J.Clean{}, Nil{}} : R}
  prefix(rs, n, max, Nil{}, J.Clean{}, fits, enough, m => clean_nil(m, max))

def bad_len_next(+max: U32, +x: U32, +y: U32, +more: List<&2, U32>, differ: {U32.is_eq(y, U32.not(x)) == False{} : Bool}) ->
  {J.list.next(max, cat([x, 0, 0, 0, y, 0, 0, 0], more)) == J.Bad{"length check mismatch", cat([x, 0, 0, 0, y, 0, 0, 0], more)} : Step}:
  %Equal.sym(Bool, Nat.is_le(0n, len(more)), True{}, MNat.zero_le(len(more))) : {J.next.start(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, max, (cat([x, 0, 0, 0, y, 0, 0, 0], more), _)) == J.Bad{"length check mismatch", cat([x, 0, 0, 0, y, 0, 0, 0], more)} : Step}
  %Equal.sym(Bool, U32.is_eq(y, U32.not(x)), False{}, differ) : {J.next.head(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, _, max, x, cat([x, 0, 0, 0, y, 0, 0, 0], more)) == J.Bad{"length check mismatch", cat([x, 0, 0, 0, y, 0, 0, 0], more)} : Step}
  {==}

def over_next(+max: U32, +x: U32, +z: U32, +more: List<&2, U32>, big: {U32.is_gt(x, max) == True{} : Bool}) ->
  {J.list.next(max, cat(J.list.head(x, z), more)) == J.Bad{"length over max", cat(J.list.head(x, z), more)} : Step}:
  %Equal.sym(Bool, U32.is_eq(U32.not(x), U32.not(x)), True{}, eq_refl(U32.not(x))) : {J.next.head(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, _, max, x, cat(J.list.head(x, z), more)) == J.Bad{"length over max", cat(J.list.head(x, z), more)} : Step}
  %Equal.sym(Bool, U32.is_gt(x, max), True{}, big) : {J.next.size(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, _, x, cat(J.list.head(x, z), more)) == J.Bad{"length over max", cat(J.list.head(x, z), more)} : Step}
  {==}

def stop_bad(+n: Nat, +max: U32, +xs: List<&2, U32>, +why: String, e: {J.list.next(max, xs) == J.Bad{why, xs} : Step}) ->
  {J.list.recover(n, max, xs) == J.Recovery{Nil{}, J.Corrupt{why}, xs} : R}:
  %Equal.sym(Step, J.list.next(max, xs), J.Bad{why, xs}, e) : {go(n, max, _) == J.Recovery{Nil{}, J.Corrupt{why}, xs} : R}
  bad_go(n, max, why, xs)

def Laws.bad_len(n, max, rs, x, y, more, fits, enough, differ):
  +differ = differ
  prefix(rs, n, max, cat([x, 0, 0, 0, y, 0, 0, 0], more), J.Corrupt{"length check mismatch"}, fits, enough,
    m => stop_bad(m, max, cat([x, 0, 0, 0, y, 0, 0, 0], more), "length check mismatch", bad_len_next(max, x, y, more, differ)))

def Laws.over_max(n, max, rs, x, z, more, fits, enough, big):
  +big = big
  prefix(rs, n, max, cat(J.list.head(x, z), more), J.Corrupt{"length over max"}, fits, enough,
    m => stop_bad(m, max, cat(J.list.head(x, z), more), "length over max", over_next(max, x, z, more, big)))

def payload_bound(+d: List<&2, U32>, +t: List<&2, U32>, +k: Nat, e: {k == len(d) : Nat}) -> MNat.le(k, len(cat(d, t))):
  %Equal.sym(Nat, k, len(d), e) : MNat.le(_, len(cat(d, t)))
  %MList.length_append_sym(&2, U32, d, t) : MNat.le(len(d), _)
  MNat.le_add_right(len(d), len(t))

def payload_take(+d: List<&2, U32>, +t: List<&2, U32>, +k: Nat, e: {k == len(d) : Nat}) ->
  {List.take(&2, U32, List.drop(&2, U32, cat(d, t), 0n), k) == d : List<&2, U32>}:
  %Equal.sym(Nat, k, len(d), e) : {List.take(&2, U32, List.drop(&2, U32, cat(d, t), 0n), _) == d : List<&2, U32>}
  take_drop_zero(cat(d, t), len(d), d, MList.take_left(&2, U32, d, t))

def sum_next(+max: U32, +l: U32, +z: U32, +d: List<&2, U32>, +t: List<&2, U32>, g: {U32.is_gt(l, max) == False{} : Bool}, +e: {U32.to_nat(l) == len(d) : Nat}, differ: {U32.is_eq(J.list.crc(d), z) == False{} : Bool}) ->
  {J.list.next(max, cat(J.list.head(l, z), cat(d, t))) == J.Bad{"checksum mismatch", cat(J.list.head(l, z), cat(d, t))} : Step}:
  %Equal.sym(Bool, U32.is_eq(U32.not(l), U32.not(l)), True{}, eq_refl(U32.not(l))) : {J.next.head(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, _, max, l, cat(J.list.head(l, z), cat(d, t))) == J.Bad{"checksum mismatch", cat(J.list.head(l, z), cat(d, t))} : Step}
  %Equal.sym(Bool, U32.is_gt(l, max), False{}, g) : {J.next.size(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, _, l, cat(J.list.head(l, z), cat(d, t))) == J.Bad{"checksum mismatch", cat(J.list.head(l, z), cat(d, t))} : Step}
  %Equal.sym(Bool, Nat.is_le(U32.to_nat(l), len(cat(d, t))), True{}, payload_bound(d, t, U32.to_nat(l), e)) : {J.next.body(~List<&2, U32>, ~List<&2, U32>, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, l, (cat(J.list.head(l, z), cat(d, t)), _)) == J.Bad{"checksum mismatch", cat(J.list.head(l, z), cat(d, t))} : Step}
  %Equal.sym(List<&2, U32>, List.take(&2, U32, List.drop(&2, U32, cat(d, t), 0n), U32.to_nat(l)), d, payload_take(d, t, U32.to_nat(l), e)) : {J.next.verdict(~List<&2, U32>, ~List<&2, U32>, ~J.list.skip, U32.is_eq(J.list.crc(_), z), l, cat(J.list.head(l, z), cat(d, t)), _) == J.Bad{"checksum mismatch", cat(J.list.head(l, z), cat(d, t))} : Step}
  %Equal.sym(Bool, U32.is_eq(J.list.crc(d), z), False{}, differ) : {J.next.verdict(~List<&2, U32>, ~List<&2, U32>, ~J.list.skip, _, l, cat(J.list.head(l, z), cat(d, t)), d) == J.Bad{"checksum mismatch", cat(J.list.head(l, z), cat(d, t))} : Step}
  {==}

def Laws.bad_sum(n, max, rs, p, d, more, fits, enough, small, same, differ):
  +small = small
  +same = same
  +differ = differ
  prefix(rs, n, max, cat(J.list.head(U32.from_nat(len(p)), J.list.crc(p)), cat(d, more)), J.Corrupt{"checksum mismatch"}, fits, enough,
    m => stop_bad(m, max, cat(J.list.head(U32.from_nat(len(p)), J.list.crc(p)), cat(d, more)), "checksum mismatch",
      sum_next(max, U32.from_nat(len(p)), J.list.crc(p), d, more, frame_over(max, p, small),
        Equal.trans(Nat, U32.to_nat(U32.from_nat(len(p))), len(p), len(d), from_eq(len(p), max, small), Equal.sym(Nat, len(d), len(p), same)), differ)))

def lt_not_le(a: Nat, b: Nat, h: MNat.lt(a, b)) -> {Nat.is_le(b, a) == False{} : Bool}:
  match a b:
    case 0n 0n:
      boom2({True{} == False{} : Bool}, h)
    case 0n 1n+m:
      {==}
    case 1n+n 0n:
      Empty.absurd({Nat.is_le(0n, 1n+n) == False{} : Bool}, MNat.lt_zero(1n+n)(h))
    case 1n+n 1n+m:
      lt_not_le(n, m, h)

def torn_bound(+max: U32, +p: List<&2, U32>, +k: Nat, small: MNat.le(len(p), U32.to_nat(max)), cut: MNat.lt(1n+k, len(J.list.frame(p)))) ->
  {Nat.is_le(Nat.add(12n, U32.to_nat(U32.from_nat(len(p)))), len(List.take(&2, U32, J.list.frame(p), 1n+k))) == False{} : Bool}:
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(len(p))), len(p), from_eq(len(p), max, small)) : {Nat.is_le(Nat.add(12n, _), len(List.take(&2, U32, J.list.frame(p), 1n+k))) == False{} : Bool}
  lt_not_le(len(List.take(&2, U32, J.list.frame(p), 1n+k)), Nat.add(12n, len(p)),
    MNat.lt_of_le_of_lt(len(List.take(&2, U32, J.list.frame(p), 1n+k)), 1n+k, Nat.add(12n, len(p)),
      MList.length_take_le(&2, U32, J.list.frame(p), 1n+k), cut))

def torn_long(+max: U32, +p: List<&2, U32>, +m: Nat, +small: MNat.le(len(p), U32.to_nat(max)), cut: MNat.lt(8n+m, len(J.list.frame(p)))) ->
  {J.list.next(max, List.take(&2, U32, J.list.frame(p), 8n+m)) == J.Short{List.take(&2, U32, J.list.frame(p), 8n+m)} : Step}:
  +xs = List.take(&2, U32, J.list.frame(p), 8n+m)
  %Equal.sym(Bool, Nat.is_le(0n, len(List.take(&2, U32, cat([J.list.crc(p), 0, 0, 0], p), m))), True{}, MNat.zero_le(len(List.take(&2, U32, cat([J.list.crc(p), 0, 0, 0], p), m)))) : {J.next.start(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, max, (xs, _)) == J.Short{xs} : Step}
  %Equal.sym(Bool, U32.is_eq(U32.not(U32.from_nat(len(p))), U32.not(U32.from_nat(len(p)))), True{}, eq_refl(U32.not(U32.from_nat(len(p))))) : {J.next.head(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, _, max, U32.from_nat(len(p)), xs) == J.Short{xs} : Step}
  %Equal.sym(Bool, U32.is_gt(U32.from_nat(len(p)), max), False{}, frame_over(max, p, small)) : {J.next.size(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, _, U32.from_nat(len(p)), xs) == J.Short{xs} : Step}
  %Equal.sym(Bool, Nat.is_le(Nat.add(12n, U32.to_nat(U32.from_nat(len(p)))), len(xs)), False{}, torn_bound(max, p, 7n+m, small, cut)) : {J.next.body(~List<&2, U32>, ~List<&2, U32>, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, U32.from_nat(len(p)), (xs, _)) == J.Short{xs} : Step}
  {==}

def torn_next(k: Nat, +max: U32, +p: List<&2, U32>, small: MNat.le(len(p), U32.to_nat(max)), cut: MNat.lt(1n+k, len(J.list.frame(p)))) ->
  {J.list.next(max, List.take(&2, U32, J.list.frame(p), 1n+k)) == J.Short{List.take(&2, U32, J.list.frame(p), 1n+k)} : Step}:
  match k:
    case 0n:
      {==}
    case 1n:
      {==}
    case 2n:
      {==}
    case 3n:
      {==}
    case 4n:
      {==}
    case 5n:
      {==}
    case 6n:
      {==}
    case 7n+m:
      torn_long(max, p, m, small, cut)

def stop_short(+n: Nat, +max: U32, +xs: List<&2, U32>, e: {J.list.next(max, xs) == J.Short{xs} : Step}) ->
  {J.list.recover(n, max, xs) == J.Recovery{Nil{}, J.Torn{}, xs} : R}:
  %Equal.sym(Step, J.list.next(max, xs), J.Short{xs}, e) : {go(n, max, _) == J.Recovery{Nil{}, J.Torn{}, xs} : R}
  short_go(n, max, xs)

def Laws.torn(n, max, rs, p, k, fits, enough, small, cut):
  +small = small
  +cut = cut
  prefix(rs, n, max, List.take(&2, U32, J.list.frame(p), 1n+k), J.Torn{}, fits, enough,
    m => stop_short(m, max, List.take(&2, U32, J.list.frame(p), 1n+k), torn_next(k, max, p, small, cut)))

def Shape(xs: List<&2, U32>, st: Step) -> Type:
  match st:
    case J.End{s}:
      {s == xs : List<&2, U32>}
    case J.Short{s}:
      {s == xs : List<&2, U32>}
    case J.Bad{why, s}:
      {s == xs : List<&2, U32>}
    case J.Got{p, s}:
      {cat(List.take(&2, U32, xs, 12n), cat(p, s)) == xs : List<&2, U32>}

def shape_got(+xs: List<&2, U32>, +l: U32) ->
  Shape(xs, J.Got{List.take(&2, U32, List.drop(&2, U32, xs, 12n), U32.to_nat(l)), List.drop(&2, U32, xs, Nat.add(12n, U32.to_nat(l)))}):
  %MList.drop_drop(&2, U32, xs, 12n, U32.to_nat(l)) : {cat(List.take(&2, U32, xs, 12n), cat(List.take(&2, U32, List.drop(&2, U32, xs, 12n), U32.to_nat(l)), _)) == xs : List<&2, U32>}
  %MList.take_append_drop_sym(&2, U32, List.drop(&2, U32, xs, 12n), U32.to_nat(l)) : {cat(List.take(&2, U32, xs, 12n), _) == xs : List<&2, U32>}
  MList.take_append_drop(&2, U32, xs, 12n)

def shape_verdict(ok: Bool, +l: U32, +xs: List<&2, U32>) ->
  Shape(xs, J.next.verdict(~List<&2, U32>, ~List<&2, U32>, ~J.list.skip, ok, l, xs, List.take(&2, U32, List.drop(&2, U32, xs, 12n), U32.to_nat(l)))):
  match ok:
    case True{}:
      shape_got(xs, l)
    case False{}:
      {==}

def shape_body(whole: Bool, +l: U32, +xs: List<&2, U32>) ->
  Shape(xs, J.next.body(~List<&2, U32>, ~List<&2, U32>, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, l, (xs, whole))):
  match whole:
    case True{}:
      shape_verdict(U32.is_eq(J.list.crc(List.take(&2, U32, List.drop(&2, U32, xs, 12n), U32.to_nat(l))), J.list.field(List.drop(&2, U32, xs, 8n))), l, xs)
    case False{}:
      {==}

def shape_size(over: Bool, +l: U32, +xs: List<&2, U32>) ->
  Shape(xs, J.next.size(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, over, l, xs)):
  match over:
    case True{}:
      {==}
    case False{}:
      shape_body(Nat.is_le(Nat.add(12n, U32.to_nat(l)), len(xs)), l, xs)

def shape_head(ok: Bool, +max: U32, +l: U32, +xs: List<&2, U32>) ->
  Shape(xs, J.next.head(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, ok, max, l, xs)):
  match ok:
    case True{}:
      shape_size(U32.is_gt(l, max), l, xs)
    case False{}:
      {==}

def shape_start(both: Bool, +max: U32, +xs: List<&2, U32>) ->
  Shape(xs, J.next.start(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, max, (xs, both))):
  match both:
    case True{}:
      shape_head(U32.is_eq(J.list.field(List.drop(&2, U32, xs, 4n)), U32.not(J.list.field(List.drop(&2, U32, xs, 0n)))), max, J.list.field(List.drop(&2, U32, xs, 0n)), xs)
    case False{}:
      {==}

def shape_any(some: Bool, +max: U32, +xs: List<&2, U32>) ->
  Shape(xs, J.next.any(~List<&2, U32>, ~List<&2, U32>, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, max, (xs, some))):
  match some:
    case True{}:
      shape_start(Nat.is_le(8n, len(xs)), max, xs)
    case False{}:
      {==}

def shape_next(+max: U32, +xs: List<&2, U32>) -> Shape(xs, J.list.next(max, xs)):
  shape_any(Nat.is_le(1n, len(xs)), max, xs)

def slices(r: R, +xs: List<&2, U32>) -> Type:
  &hs:List<&2, List<&2, U32>> ->
    {cat(Laws.weave(Laws.records(r), hs), Laws.rest(r)) == xs : List<&2, U32>}

def slices_eq(+p: List<&2, U32>, +rs: List<&2, List<&2, U32>>, +hs: List<&2, List<&2, U32>>, +rest: List<&2, U32>, +h: List<&2, U32>, +s: List<&2, U32>, +xs: List<&2, U32>, sh: {cat(h, cat(p, s)) == xs : List<&2, U32>}, e: {cat(Laws.weave(rs, hs), rest) == s : List<&2, U32>}) ->
  {cat(Laws.weave(Con{p, rs}, Con{h, hs}), rest) == xs : List<&2, U32>}:
  %MList.append_assoc_sym(&2, U32, h, cat(p, Laws.weave(rs, hs)), rest) : {_ == xs : List<&2, U32>}
  %MList.append_assoc_sym(&2, U32, p, Laws.weave(rs, hs), rest) : {cat(h, _) == xs : List<&2, U32>}
  %Equal.sym(List<&2, U32>, cat(Laws.weave(rs, hs), rest), s, e) : {cat(h, cat(p, _)) == xs : List<&2, U32>}
  sh

def slices_con(+p: List<&2, U32>, r: R, +h: List<&2, U32>, +s: List<&2, U32>, +xs: List<&2, U32>, sh: {cat(h, cat(p, s)) == xs : List<&2, U32>}, ih: slices(r, s)) ->
  slices(J.recover.con(~&2, ~List<&2, U32>, ~List<&2, U32>, p, r), xs):
  match r:
    case J.Recovery{+rs, tail, +rest}:
      (+hs, e) = ih
      (Con{h, hs}, slices_eq(p, rs, hs, rest, h, s, xs, sh, e))

def slices_go(n: Nat, st: Step, +max: U32, +xs: List<&2, U32>, sh: Shape(xs, st)) -> slices(go(n, max, st), xs):
  match n st:
    case 0n J.End{s}:
      (Nil{}, sh)
    case 0n J.Short{s}:
      (Nil{}, sh)
    case 0n J.Bad{why, s}:
      (Nil{}, sh)
    case 0n J.Got{+p, +s}:
      slices_con(p, J.Recovery{Nil{}, J.Corrupt{"frame budget exhausted"}, s}, List.take(&2, U32, xs, 12n), s, xs, sh, (Nil{}, {==}))
    case 1n+m J.End{s}:
      (Nil{}, sh)
    case 1n+m J.Short{s}:
      (Nil{}, sh)
    case 1n+m J.Bad{why, s}:
      (Nil{}, sh)
    case 1n+ +m J.Got{+p, +s}:
      slices_con(p, J.list.recover(m, max, s), List.take(&2, U32, xs, 12n), s, xs, sh, slices_go(m, J.list.next(max, s), max, s, shape_next(max, s)))

def Laws.slices(n, max, xs):
  slices_go(n, J.list.next(max, xs), max, xs, shape_next(max, xs))

def folded(~A: Type, ~step: A -> List<&2, U32> -> A, r: R, acc: A) -> J.Replay<A, List<&2, U32>>:
  match r:
    case J.Recovery{rs, tail, rest}:
      J.Replay{List.foldl(~&2, ~List<&2, U32>, ~A, ~step, rs, acc), tail, rest}

def fold_con(~A: Type, ~step: A -> List<&2, U32> -> A, +p: List<&2, U32>, r: R, -acc: A) ->
  {folded(~A, ~step, J.recover.con(~&2, ~List<&2, U32>, ~List<&2, U32>, p, r), acc) == folded(~A, ~step, r, step(acc, p)) : J.Replay<A, List<&2, U32>>}:
  match r:
    case J.Recovery{rs, tail, rest}:
      {==}

def replay_go(~A: Type, ~step: A -> List<&2, U32> -> A, n: Nat, st: Step, +max: U32, acc: A) ->
  {J.replay.go(~List<&2, U32>, ~List<&2, U32>, ~A, ~J.list.fits, ~J.list.u32, ~J.list.cut, ~J.list.skip, ~J.list.sum, ~step, n, max, st, acc) == folded(~A, ~step, go(n, max, st), acc) : J.Replay<A, List<&2, U32>>}:
  match n st:
    case 0n J.End{s}:
      {==}
    case 0n J.Short{s}:
      {==}
    case 0n J.Bad{why, s}:
      {==}
    case 0n J.Got{p, s}:
      {==}
    case 1n+m J.End{s}:
      {==}
    case 1n+m J.Short{s}:
      {==}
    case 1n+m J.Bad{why, s}:
      {==}
    case 1n+ +m J.Got{+p, +s}:
      %Equal.sym(J.Replay<A, List<&2, U32>>, folded(~A, ~step, J.recover.con(~&2, ~List<&2, U32>, ~List<&2, U32>, p, J.list.recover(m, max, s)), acc), folded(~A, ~step, J.list.recover(m, max, s), step(acc, p)), fold_con(~A, ~step, p, J.list.recover(m, max, s), acc)) : {J.list.replay(~A, ~step, m, max, s, step(acc, p)) == _ : J.Replay<A, List<&2, U32>>}
      replay_go(~A, ~step, m, J.list.next(max, s), max, step(acc, p))

def folded_eq(~A: Type, ~step: A -> List<&2, U32> -> A, r: R, -acc: A) ->
  {folded(~A, ~step, r, acc) == J.Replay{List.foldl(~&2, ~List<&2, U32>, ~A, ~step, Laws.records(r), acc), Laws.tail(r), Laws.rest(r)} : J.Replay<A, List<&2, U32>>}:
  match r:
    case J.Recovery{rs, tail, rest}:
      {==}

def Laws.replay(A, step, n, max, xs, acc):
  +n = n
  Equal.trans(J.Replay<A, List<&2, U32>>,
    J.list.replay(~A, ~step, n, max, xs, acc),
    folded(~A, ~step, J.list.recover(n, max, xs), acc),
    J.Replay{List.foldl(~&2, ~List<&2, U32>, ~A, ~step, Laws.records(J.list.recover(n, max, xs)), acc), Laws.tail(J.list.recover(n, max, xs)), Laws.rest(J.list.recover(n, max, xs))},
    replay_go(~A, ~step, n, J.list.next(max, xs), max, acc),
    folded_eq(~A, ~step, J.list.recover(n, max, xs), acc))
