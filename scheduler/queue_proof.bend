import Base
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-mathlib@0.8.0.0/bool.bend as MBool
import bend-kit-collections@0.1.4.1/heap.bend as H
import ./queue.bend as Q
import ./queue_laws.bend as L

def split(-P: Bool -> Type, b: Bool, yes: {b == True{} : Bool} -> P(True{}), no: {b == False{} : Bool} -> P(False{})) -> P(b):
  match b:
    case True{}:
      yes({==})
    case False{}:
      no({==})

def take_equivalent.step(-A: Data, b: Bool, t: Q.Ticket<A>, rest: List<&2, Q.Ticket<A>>, found: Maybe<&2, Q.Ticket<A>>) -> {Q.take.keep(A, b, t, Q.Taken{rest, found}) == Q.Taken{Q.remove.list.keep(A, b, t, rest), Q.find.list.choose(A, b, t, found)} : Q.Taken<A>}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def L.take_equivalent(A, xs, i):
  match xs:
    case Nil{}:
      {==}
    case Con{t, rest}:
      %Equal.sym(Q.Taken<A>, Q.take.list(A, rest, i), Q.Taken{Q.remove.list(A, rest, i), Q.find.list(A, rest, i)}, L.take_equivalent(A, rest, i)) : {Q.take.keep(A, Nat.is_eq(Q.id(A, t), i), t, _) == Q.Taken{Q.remove.list(A, t <> rest, i), Q.find.list(A, t <> rest, i)} : Q.Taken<A>}
      take_equivalent.step(A, Nat.is_eq(Q.id(A, t), i), t, Q.remove.list(A, rest, i), Q.find.list(A, rest, i))

def L.complete_equivalent(A, i, s):
  match s:
    case Q.State{n, h, r}:
      %Equal.sym(Q.Taken<A>, Q.take.list(A, r, i), Q.Taken{Q.remove.list(A, r, i), Q.find.list(A, r, i)}, L.take_equivalent(A, r, i)) : {Q.complete.taken(A, _, n, h) == L.complete.reference(A, i, Q.State{n, h, r}) : Q.State<A> & Maybe<&2, Q.Ticket<A>>}
      {==}

def L.requeue_equivalent(A, i, d, s):
  %Equal.sym(Q.State<A> & Maybe<&2, Q.Ticket<A>>, Q.complete(A, i, s), L.complete.reference(A, i, s), L.complete_equivalent(A, i, s)) : {Q.requeue.completed(~A, _, d) == L.requeue.reference(~A, i, d, s) : Q.State<A> & Bool}
  {==}

def key_refl(+d: Nat, +i: Nat) -> {Q.le.same(Nat.is_eq(d, d), i, i, d, d) == True{} : Bool}:
  %Equal.sym(Bool, Nat.is_eq(d, d), True{}, MNat.is_eq_refl(d)) : {Q.le.same(_, i, i, d, d) == True{} : Bool}
  MNat.le_refl(i)

def key_succ(b: Bool, i: Nat, j: Nat, d: Nat, e: Nat) -> {Q.le.same(b, i, j, 1n+d, 1n+e) == Q.le.same(b, i, j, d, e) : Bool}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def key_succ.premise(+d: Nat, +e: Nat, +i: Nat, +j: Nat, +b: Bool, p: {Q.le.same(Nat.is_eq(d, e), i, j, 1n+d, 1n+e) == b : Bool}) -> {Q.le.same(Nat.is_eq(d, e), i, j, d, e) == b : Bool}:
  Equal.trans(Bool, Q.le.same(Nat.is_eq(d, e), i, j, d, e), Q.le.same(Nat.is_eq(d, e), i, j, 1n+d, 1n+e), b, Equal.sym(Bool, Q.le.same(Nat.is_eq(d, e), i, j, 1n+d, 1n+e), Q.le.same(Nat.is_eq(d, e), i, j, d, e), key_succ(Nat.is_eq(d, e), i, j, d, e)), p)

def key_succ.conclusion(+d: Nat, +e: Nat, +i: Nat, +j: Nat, p: {Q.le.same(Nat.is_eq(d, e), i, j, d, e) == True{} : Bool}) -> {Q.le.same(Nat.is_eq(d, e), i, j, 1n+d, 1n+e) == True{} : Bool}:
  Equal.trans(Bool, Q.le.same(Nat.is_eq(d, e), i, j, 1n+d, 1n+e), Q.le.same(Nat.is_eq(d, e), i, j, d, e), True{}, key_succ(Nat.is_eq(d, e), i, j, d, e), p)

def key_flip(+d: Nat, +e: Nat, +i: Nat, +j: Nat, p: {Q.le.same(Nat.is_eq(d, e), i, j, d, e) == False{} : Bool}) -> {Q.le.same(Nat.is_eq(e, d), j, i, e, d) == True{} : Bool}:
  match d e:
    case 0n 0n:
      MNat.le_of_lt(j, i, MNat.lt_of_not_le(i, j, p))
    case 0n 1n+q:
      Empty.absurd({False{} == True{} : Bool}, MBool.true_ne_false()(p))
    case 1n+r 0n:
      {==}
    case 1n+r 1n+q:
      key_succ.conclusion(q, r, j, i, key_flip(r, q, i, j, key_succ.premise(r, q, i, j, False{}, p)))

def key_trans(+d: Nat, +e: Nat, +f: Nat, +i: Nat, +j: Nat, +k: Nat, p: {Q.le.same(Nat.is_eq(d, e), i, j, d, e) == True{} : Bool}, q: {Q.le.same(Nat.is_eq(e, f), j, k, e, f) == True{} : Bool}) -> {Q.le.same(Nat.is_eq(d, f), i, k, d, f) == True{} : Bool}:
  match d e f:
    case 0n 0n 0n:
      MNat.le_trans(i, j, k, p, q)
    case 0n 0n 1n+r:
      {==}
    case 0n 1n+s 0n:
      Empty.absurd({Nat.is_le(i, k) == True{} : Bool}, MBool.false_ne_true()(q))
    case 0n 1n+s 1n+r:
      {==}
    case 1n+r 0n 0n:
      Empty.absurd({False{} == True{} : Bool}, MBool.false_ne_true()(p))
    case 1n+r 0n 1n+t:
      Empty.absurd({Q.le.same(Nat.is_eq(1n+r, 1n+t), i, k, 1n+r, 1n+t) == True{} : Bool}, MBool.false_ne_true()(p))
    case 1n+r 1n+s 0n:
      Empty.absurd({False{} == True{} : Bool}, MBool.false_ne_true()(q))
    case 1n+r 1n+s 1n+t:
      key_succ.conclusion(r, t, i, k, key_trans(r, s, t, i, j, k, key_succ.premise(r, s, i, j, True{}, p), key_succ.premise(s, t, j, k, True{}, q)))

def le_refl(-A: Data, t: Q.Ticket<A>) -> {Q.le(A, t, t) == True{} : Bool}:
  match t:
    case Q.Ticket{i, d, x}:
      key_refl(d, i)

def le_flip(-A: Data, a: Q.Ticket<A>, b: Q.Ticket<A>, e: {Q.le(A, a, b) == False{} : Bool}) -> {Q.le(A, b, a) == True{} : Bool}:
  match a b:
    case Q.Ticket{i, d, x} Q.Ticket{j, f, y}:
      key_flip(d, f, i, j, e)

def le_trans(-A: Data, a: Q.Ticket<A>, b: Q.Ticket<A>, c: Q.Ticket<A>, e: {Q.le(A, a, b) == True{} : Bool}, f: {Q.le(A, b, c) == True{} : Bool}) -> {Q.le(A, a, c) == True{} : Bool}:
  match a b c:
    case Q.Ticket{i, d, x} Q.Ticket{j, g, y} Q.Ticket{k, h, z}:
      key_trans(d, g, h, i, j, k, e, f)

# Merging cannot introduce an element that violates any predicate P. Fuel zero
# returns the left heap, so this lemma does not trust cached heap sizes.
def merge_all(~A: Data, -P: Q.Ticket<A> -> Data, +fuel: Nat, +a: H.Heap<Q.Ticket<A>>, +b: H.Heap<Q.Ticket<A>>, +ea: L.all.heap(A, P, a), +eb: L.all.heap(A, P, b)) -> L.all.heap(A, P, H.Heap.merge.go(~Q.Ticket<A>, ~(x => y => Q.le(A, x, y)), fuel, a, b)):
  match fuel:
    case 0n:
      ea
    case 1n+f:
      match a b:
        case H.HLeaf{} H.HLeaf{}:
          Unit{}
        case H.HLeaf{} H.HNode{nb, y, bl, br}:
          eb
        case H.HNode{na, x, al, ar} H.HLeaf{}:
          ea
        case H.HNode{na, x, al, ar} H.HNode{nb, y, bl, br}:
          L.Both{ex, L.Both{eal, ear}} = ea
          L.Both{ey, L.Both{ebl, ebr}} = eb
          split(c => L.all.heap(A, P, H.HNode{Nat.add(na, nb), Bool.pick(Q.Ticket<A>, c, x, y), H.Heap.merge.go(~Q.Ticket<A>, ~(x => y => Q.le(A, x, y)), f, Bool.pick(H.Heap<Q.Ticket<A>>, c, ar, br), Bool.pick(H.Heap<Q.Ticket<A>>, c, H.HNode{nb, y, bl, br}, H.HNode{na, x, al, ar})), Bool.pick(H.Heap<Q.Ticket<A>>, c, al, bl)}), Q.le(A, x, y),
            e => L.Both{ex, L.Both{merge_all(~A, P, f, ar, H.HNode{nb, y, bl, br}, ear, L.Both{ey, L.Both{ebl, ebr}}), eal}},
            e => L.Both{ey, L.Both{merge_all(~A, P, f, br, H.HNode{na, x, al, ar}, ebr, L.Both{ex, L.Both{eal, ear}}), ebl}})

def merge_all.full(~A: Data, -P: Q.Ticket<A> -> Data, +a: H.Heap<Q.Ticket<A>>, +b: H.Heap<Q.Ticket<A>>, ea: L.all.heap(A, P, a), eb: L.all.heap(A, P, b)) -> L.all.heap(A, P, H.Heap.merge(~Q.Ticket<A>, ~(x => y => Q.le(A, x, y)), a, b)):
  merge_all(~A, P, Nat.add(H.Heap.size(Q.Ticket<A>, a), H.Heap.size(Q.Ticket<A>, b)), a, b, ea, eb)

def below_trans(-A: Data, h: H.Heap<Q.Ticket<A>>, +a: Q.Ticket<A>, +b: Q.Ticket<A>, e: {Q.le(A, a, b) == True{} : Bool}, eh: L.below(A, h, b)) -> L.below(A, h, a):
  match h:
    case H.HLeaf{}:
      Unit{}
    case H.HNode{n, t, l, r}:
      L.Both{et, L.Both{el, er}} = eh
      +e = e
      L.Both{le_trans(A, a, b, t, e, et), L.Both{below_trans(A, l, a, b, e, el), below_trans(A, r, a, b, e, er)}}

def merge_ordered(~A: Data, +fuel: Nat, +a: H.Heap<Q.Ticket<A>>, +b: H.Heap<Q.Ticket<A>>, +ea: L.ordered(A, a), +eb: L.ordered(A, b)) -> L.ordered(A, H.Heap.merge.go(~Q.Ticket<A>, ~(x => y => Q.le(A, x, y)), fuel, a, b)):
  match fuel:
    case 0n:
      ea
    case 1n+f:
      match a b:
        case H.HLeaf{} H.HLeaf{}:
          Unit{}
        case H.HLeaf{} H.HNode{nb, y, bl, br}:
          eb
        case H.HNode{na, x, al, ar} H.HLeaf{}:
          ea
        case H.HNode{na, x, al, ar} H.HNode{nb, y, bl, br}:
          L.Both{L.Both{xal, xar}, L.Both{oal, oar}} = ea
          L.Both{L.Both{ybl, ybr}, L.Both{obl, obr}} = eb
          split(c => L.ordered(A, H.HNode{Nat.add(na, nb), Bool.pick(Q.Ticket<A>, c, x, y), H.Heap.merge.go(~Q.Ticket<A>, ~(x => y => Q.le(A, x, y)), f, Bool.pick(H.Heap<Q.Ticket<A>>, c, ar, br), Bool.pick(H.Heap<Q.Ticket<A>>, c, H.HNode{nb, y, bl, br}, H.HNode{na, x, al, ar})), Bool.pick(H.Heap<Q.Ticket<A>>, c, al, bl)}), Q.le(A, x, y),
            +e => L.Both{L.Both{merge_all(~A, L.bound.ticket(A, x), f, ar, H.HNode{nb, y, bl, br}, xar, L.Both{e, L.Both{below_trans(A, bl, x, y, e, ybl), below_trans(A, br, x, y, e, ybr)}}), xal}, L.Both{merge_ordered(~A, f, ar, H.HNode{nb, y, bl, br}, oar, L.Both{L.Both{ybl, ybr}, L.Both{obl, obr}}), oal}},
            e => (
              +e = le_flip(A, x, y, e)
              L.Both{L.Both{merge_all(~A, L.bound.ticket(A, y), f, br, H.HNode{na, x, al, ar}, ybr, L.Both{e, L.Both{below_trans(A, al, y, x, e, xal), below_trans(A, ar, y, x, e, xar)}}), ybl}, L.Both{merge_ordered(~A, f, br, H.HNode{na, x, al, ar}, obr, L.Both{L.Both{xal, xar}, L.Both{oal, oar}}), obl}}))

def merge_ordered.full(~A: Data, +a: H.Heap<Q.Ticket<A>>, +b: H.Heap<Q.Ticket<A>>, ea: L.ordered(A, a), eb: L.ordered(A, b)) -> L.ordered(A, H.Heap.merge(~Q.Ticket<A>, ~(x => y => Q.le(A, x, y)), a, b)):
  merge_ordered(~A, Nat.add(H.Heap.size(Q.Ticket<A>, a), H.Heap.size(Q.Ticket<A>, b)), a, b, ea, eb)

def remove_all(~A: Data, -P: Q.Ticket<A> -> Data, +h: H.Heap<Q.Ticket<A>>, +i: Nat, +eh: L.all.heap(A, P, h)) -> L.all.heap(A, P, Q.remove.heap(~A, h, i)):
  match h:
    case H.HLeaf{}:
      Unit{}
    case H.HNode{n, t, l, r}:
      L.Both{et, L.Both{el, er}} = eh
      +l2 = Q.remove.heap(~A, l, i)
      +r2 = Q.remove.heap(~A, r, i)
      +el2 = remove_all(~A, P, l, i, el)
      +er2 = remove_all(~A, P, r, i, er)
      split(c => L.all.heap(A, P, Q.remove.heap.keep(~A, c, t, l2, r2)), Nat.is_eq(Q.id(A, t), i),
        e => merge_all.full(~A, P, l2, r2, el2, er2),
        e => L.Both{et, L.Both{el2, er2}})

def remove_ordered(~A: Data, +h: H.Heap<Q.Ticket<A>>, +i: Nat, +eh: L.ordered(A, h)) -> L.ordered(A, Q.remove.heap(~A, h, i)):
  match h:
    case H.HLeaf{}:
      Unit{}
    case H.HNode{n, t, l, r}:
      L.Both{L.Both{el, er}, L.Both{ol, or}} = eh
      +l2 = Q.remove.heap(~A, l, i)
      +r2 = Q.remove.heap(~A, r, i)
      +ol2 = remove_ordered(~A, l, i, ol)
      +or2 = remove_ordered(~A, r, i, or)
      split(c => L.ordered(A, Q.remove.heap.keep(~A, c, t, l2, r2)), Nat.is_eq(Q.id(A, t), i),
        e => merge_ordered.full(~A, l2, r2, ol2, or2),
        e => L.Both{L.Both{remove_all(~A, L.bound.ticket(A, t), l, i, el), remove_all(~A, L.bound.ticket(A, t), r, i, er)}, L.Both{ol2, or2}})

def remove_absent.heap(~A: Data, +h: H.Heap<Q.Ticket<A>>, +i: Nat) -> L.absent.heap(A, Q.remove.heap(~A, h, i), i):
  match h:
    case H.HLeaf{}:
      Unit{}
    case H.HNode{n, t, l, r}:
      +l2 = Q.remove.heap(~A, l, i)
      +r2 = Q.remove.heap(~A, r, i)
      +el = remove_absent.heap(~A, l, i)
      +er = remove_absent.heap(~A, r, i)
      split(c => L.absent.heap(A, Q.remove.heap.keep(~A, c, t, l2, r2), i), Nat.is_eq(Q.id(A, t), i),
        e => merge_all.full(~A, L.absent.ticket(A, i), l2, r2, el, er),
        e => L.Both{e, L.Both{el, er}})

def remove_absent.list(-A: Data, +xs: List<&2, Q.Ticket<A>>, +i: Nat) -> L.absent.list(A, Q.remove.list(A, xs, i), i):
  match xs:
    case Nil{}:
      Unit{}
    case Con{t, rest}:
      +r2 = Q.remove.list(A, rest, i)
      +er = remove_absent.list(A, rest, i)
      split(c => L.absent.list(A, Q.remove.list.keep(A, c, t, r2), i), Nat.is_eq(Q.id(A, t), i),
        e => er,
        e => L.Both{e, er})

def L.absent_find(A, xs, i, e):
  match xs:
    case Nil{}:
      {==}
    case Con{t, rest}:
      L.Both{et, er} = e
      %Equal.sym(Bool, Nat.is_eq(Q.id(A, t), i), False{}, et) : {Q.find.list.choose(A, _, t, Q.find.list(A, rest, i)) == None{} : Maybe<&2, Q.Ticket<A>>}
      L.absent_find(A, rest, i, er)

def L.new_ordered(A):
  Unit{}

def L.equal_deadline_fifo(A, i, j, d, x, y):
  +d = d
  %Equal.sym(Bool, Nat.is_eq(d, d), True{}, MNat.is_eq_refl(d)) : {Q.le.same(_, i, j, d, d) == Nat.is_le(i, j) : Bool}
  {==}

def L.enqueue_id(A, d, x, s):
  match s:
    case Q.State{n, h, r}:
      {==}

def L.cancel_pending_absent(A, i, s):
  match s:
    case Q.State{n, h, r}:
      remove_absent.heap(~A, h, i)

def L.cancel_running_absent(A, i, s):
  match s:
    case Q.State{n, h, r}:
      remove_absent.list(A, r, i)

def L.complete_one_shot(A, i, s):
  match s:
    case Q.State{+n, +h, r}:
      +r = r
      %Equal.sym(Q.State<A> & Maybe<&2, Q.Ticket<A>>, Q.complete(A, i, Q.State{n, h, r}), L.complete.reference(A, i, Q.State{n, h, r}), L.complete_equivalent(A, i, Q.State{n, h, r})) : {L.selected(A, Q.complete(A, i, L.state(A, _))) == None{} : Maybe<&2, Q.Ticket<A>>}
      %Equal.sym(Q.State<A> & Maybe<&2, Q.Ticket<A>>, Q.complete(A, i, Q.State{n, h, Q.remove.list(A, r, i)}), L.complete.reference(A, i, Q.State{n, h, Q.remove.list(A, r, i)}), L.complete_equivalent(A, i, Q.State{n, h, Q.remove.list(A, r, i)})) : {L.selected(A, _) == None{} : Maybe<&2, Q.Ticket<A>>}
      L.absent_find(A, Q.remove.list(A, r, i), i, remove_absent.list(A, r, i))

def L.cancel_complete(A, i, s):
  match s:
    case Q.State{n, h, r}:
      +r = r
      %Equal.sym(Q.State<A> & Maybe<&2, Q.Ticket<A>>, Q.complete(A, i, Q.cancel(~A, i, Q.State{n, h, r})), L.complete.reference(A, i, Q.cancel(~A, i, Q.State{n, h, r})), L.complete_equivalent(A, i, Q.cancel(~A, i, Q.State{n, h, r}))) : {L.selected(A, _) == None{} : Maybe<&2, Q.Ticket<A>>}
      L.absent_find(A, Q.remove.list(A, r, i), i, remove_absent.list(A, r, i))

def requeue_absent(~A: Data, +i: Nat, d: Nat, +s: Q.State<A>, e: {Q.find.list(A, Q.running(A, s), i) == None{} : Maybe<&2, Q.Ticket<A>>}) -> {L.requeued(A, Q.requeue(~A, i, d, s)) == False{} : Bool}:
  match s:
    case Q.State{n, h, r}:
      %Equal.sym(Q.State<A> & Bool, Q.requeue(~A, i, d, Q.State{n, h, r}), L.requeue.reference(~A, i, d, Q.State{n, h, r}), L.requeue_equivalent(~A, i, d, Q.State{n, h, r})) : {L.requeued(A, _) == False{} : Bool}
      %Equal.sym(Maybe<&2, Q.Ticket<A>>, Q.find.list(A, r, i), None{}, e) : {L.requeued(A, Q.requeue.completed(~A, (Q.State{n, h, Q.remove.list(A, r, i)}, _), d)) == False{} : Bool}
      {==}

def L.cancel_requeue(A, i, d, s):
  match s:
    case Q.State{n, h, +r}:
      requeue_absent(~A, i, d, Q.State{n, Q.remove.heap(~A, h, i), Q.remove.list(A, r, i)}, L.absent_find(A, Q.remove.list(A, r, i), i, remove_absent.list(A, r, i)))

def L.complete_requeue(A, i, d, s):
  match s:
    case Q.State{+n, +h, +r}:
      %Equal.sym(Q.State<A> & Maybe<&2, Q.Ticket<A>>, Q.complete(A, i, Q.State{n, h, r}), L.complete.reference(A, i, Q.State{n, h, r}), L.complete_equivalent(A, i, Q.State{n, h, r})) : {L.requeued(A, Q.requeue(~A, i, d, L.state(A, _))) == False{} : Bool}
      requeue_absent(~A, i, d, Q.State{n, h, Q.remove.list(A, r, i)}, L.absent_find(A, Q.remove.list(A, r, i), i, remove_absent.list(A, r, i)))

def L.select_due(A, now, s):
  match s:
    case Q.State{i, H.HLeaf{}, r}:
      Unit{}
    case Q.State{i, H.HNode{n, t, l, q}, r}:
      +t = t
      +now = now
      split(c => L.due(A, L.selected(A, Q.select.due(~A, c, i, H.HNode{n, t, l, q}, r, t, l, q)), now), Nat.is_le(Q.deadline(A, t), now),
        e => e,
        e => Unit{})

def L.select_minimum(A, now, s, e):
  match s:
    case Q.State{i, H.HLeaf{}, r}:
      Unit{}
    case Q.State{i, H.HNode{n, t, l, q}, r}:
      L.Both{L.Both{el, eq}, L.Both{ol, oq}} = e
      split(c => L.minimum(A, H.HNode{n, t, l, q}, L.selected(A, Q.select.due(~A, c, i, H.HNode{n, t, l, q}, r, t, l, q))), Nat.is_le(Q.deadline(A, t), now),
        e => L.Both{le_refl(A, t), L.Both{el, eq}},
        e => Unit{})

def L.select_absent(A, now, i, s, eh, er):
  match s:
    case Q.State{n, H.HLeaf{}, r}:
      (Unit{}, er)
    case Q.State{n, H.HNode{size, t, l, q}, r}:
      L.Both{+et, L.Both{+el, +eq}} = eh
      +er = er
      split(c => L.absent.heap(A, Q.pending(A, L.state(A, Q.select.due(~A, c, n, H.HNode{size, t, l, q}, r, t, l, q))), i) & L.absent.list(A, Q.running(A, L.state(A, Q.select.due(~A, c, n, H.HNode{size, t, l, q}, r, t, l, q))), i), Nat.is_le(Q.deadline(A, t), now),
        e => (merge_all.full(~A, L.absent.ticket(A, i), l, q, el, eq), L.Both{et, er}),
        e => (L.Both{et, L.Both{el, eq}}, er))

def selected_absent(-A: Data, +i: Nat, m: Maybe<&2, Q.Ticket<A>>) -> Data:
  match m:
    case None{}:
      Unit
    case Some{t}:
      {Nat.is_eq(Q.id(A, t), i) == False{} : Bool}

def select_selected_absent(~A: Data, now: Nat, +i: Nat, +s: Q.State<A>, eh: L.absent.heap(A, Q.pending(A, s), i)) -> selected_absent(A, i, L.selected(A, Q.select(~A, now, s))):
  match s:
    case Q.State{n, H.HLeaf{}, r}:
      Unit{}
    case Q.State{n, H.HNode{size, t, l, q}, r}:
      L.Both{et, L.Both{el, eq}} = eh
      split(c => selected_absent(A, i, L.selected(A, Q.select.due(~A, c, n, H.HNode{size, t, l, q}, r, t, l, q))), Nat.is_le(Q.deadline(A, t), now),
        e => et,
        e => Unit{})

def L.absent_selected(A, now, i, s, eh, t, e):
  %e : selected_absent(A, i, _)
  select_selected_absent(~A, now, i, s, eh)

def push_ordered(~A: Data, t: Q.Ticket<A>, h: H.Heap<Q.Ticket<A>>, e: L.ordered(A, h)) -> L.ordered(A, H.Heap.push(~Q.Ticket<A>, ~(x => y => Q.le(A, x, y)), t, h)):
  merge_ordered.full(~A, H.HNode{1n, t, H.HLeaf{}, H.HLeaf{}}, h, L.Both{L.Both{Unit{}, Unit{}}, L.Both{Unit{}, Unit{}}}, e)

def L.enqueue_ordered(A, d, x, s, e):
  match s:
    case Q.State{n, h, r}:
      push_ordered(~A, Q.Ticket{n, d, x}, h, e)

def L.select_ordered(A, now, s, e):
  match s:
    case Q.State{i, H.HLeaf{}, r}:
      Unit{}
    case Q.State{i, H.HNode{n, t, l, q}, r}:
      L.Both{L.Both{el, eq}, L.Both{+ol, +oq}} = e
      split(c => L.ordered(A, Q.pending(A, L.state(A, Q.select.due(~A, c, i, H.HNode{n, t, l, q}, r, t, l, q)))), Nat.is_le(Q.deadline(A, t), now),
        e => merge_ordered.full(~A, l, q, ol, oq),
        e2 => L.Both{L.Both{el, eq}, L.Both{ol, oq}})

def L.cancel_ordered(A, i, s, e):
  match s:
    case Q.State{n, h, r}:
      remove_ordered(~A, h, i, e)

def requeue_ordered.found(~A: Data, found: Maybe<&2, Q.Ticket<A>>, d: Nat, +s: Q.State<A>, e: L.ordered(A, Q.pending(A, s))) -> L.ordered(A, Q.pending(A, L.requeue.state(A, Q.requeue.found(~A, found, d, s)))):
  match found:
    case None{}:
      e
    case Some{Q.Ticket{i, old, x}}:
      match s:
        case Q.State{n, h, r}:
          push_ordered(~A, Q.Ticket{i, d, x}, h, e)

def L.requeue_ordered(A, i, d, s, e):
  match s:
    case Q.State{n, h, r}:
      +d = d
      %Equal.sym(Q.State<A> & Bool, Q.requeue(~A, i, d, Q.State{n, h, r}), L.requeue.reference(~A, i, d, Q.State{n, h, r}), L.requeue_equivalent(~A, i, d, Q.State{n, h, r})) : L.ordered(A, Q.pending(A, L.requeue.state(A, _)))
      requeue_ordered.found(~A, Q.find.list(A, r, i), d, Q.State{n, h, Q.remove.list(A, r, i)}, e)

def L.complete_ordered(A, i, s, e):
  match s:
    case Q.State{n, h, r}:
      %Equal.sym(Q.State<A> & Maybe<&2, Q.Ticket<A>>, Q.complete(A, i, Q.State{n, h, r}), L.complete.reference(A, i, Q.State{n, h, r}), L.complete_equivalent(A, i, Q.State{n, h, r})) : L.ordered(A, Q.pending(A, L.state(A, _)))
      e

def L.enqueue_assigned_id(A, d, x, s):
  match s:
    case Q.State{n, h, r}:
      {==}

def L.cancel_keeps_counter(A, i, s):
  match s:
    case Q.State{n, h, r}:
      {==}

def L.complete_keeps_counter(A, i, s):
  match s:
    case Q.State{n, h, r}:
      %Equal.sym(Q.State<A> & Maybe<&2, Q.Ticket<A>>, Q.complete(A, i, Q.State{n, h, r}), L.complete.reference(A, i, Q.State{n, h, r}), L.complete_equivalent(A, i, Q.State{n, h, r})) : {Q.next_id(A, L.state(A, _)) == n : Nat}
      {==}

def L.select_keeps_counter(A, now, s):
  match s:
    case Q.State{i, H.HLeaf{}, r}:
      {==}
    case Q.State{i, H.HNode{n, t, l, q}, r}:
      split(c => {Q.next_id(A, L.state(A, Q.select.due(~A, c, i, H.HNode{n, t, l, q}, r, t, l, q))) == i : Nat}, Nat.is_le(Q.deadline(A, t), now),
        e => {==}, e => {==})

def requeue_counter.found(~A: Data, found: Maybe<&2, Q.Ticket<A>>, d: Nat, +s: Q.State<A>) -> {Q.next_id(A, L.requeue.state(A, Q.requeue.found(~A, found, d, s))) == Q.next_id(A, s) : Nat}:
  match found:
    case None{}:
      {==}
    case Some{Q.Ticket{i, old, x}}:
      match s:
        case Q.State{n, h, r}:
          {==}

def L.requeue_keeps_counter(A, i, d, s):
  match s:
    case Q.State{n, h, r}:
      +i = i
      +d = d
      %Equal.sym(Q.State<A> & Bool, Q.requeue(~A, i, d, Q.State{n, h, r}), L.requeue.reference(~A, i, d, Q.State{n, h, r}), L.requeue_equivalent(~A, i, d, Q.State{n, h, r})) : {Q.next_id(A, L.requeue.state(A, _)) == n : Nat}
      requeue_counter.found(~A, Q.find.list(A, r, i), d, Q.State{n, h, Q.remove.list(A, r, i)})

def L.requeue_token(A, i, d, old, x, n, h, r):
  +x = x
  +n = n
  +h = h
  +r = r
  +d = d
  %Equal.sym(Q.State<A> & Bool, Q.requeue(~A, i, d, Q.State{n, h, Q.Ticket{i, old, x} <> r}), L.requeue.reference(~A, i, d, Q.State{n, h, Q.Ticket{i, old, x} <> r}), L.requeue_equivalent(~A, i, d, Q.State{n, h, Q.Ticket{i, old, x} <> r})) : {_ == (Q.State{n, H.Heap.push(~Q.Ticket<A>, ~(a => b => Q.le(A, a, b)), Q.Ticket{i, d, x}, h), Q.remove.list(A, Q.Ticket{i, old, x} <> r, i)}, True{}) : Q.State<A> & Bool}
  %Equal.sym(Bool, Nat.is_eq(i, i), True{}, MNat.is_eq_refl(i)) : {Q.requeue.completed(~A, (Q.State{n, h, Q.remove.list(A, Q.Ticket{i, old, x} <> r, i)}, Q.find.list.choose(A, _, Q.Ticket{i, old, x}, Q.find.list(A, r, i))), d) == (Q.State{n, H.Heap.push(~Q.Ticket<A>, ~(a => b => Q.le(A, a, b)), Q.Ticket{i, d, x}, h), Q.remove.list(A, Q.Ticket{i, old, x} <> r, i)}, True{}) : Q.State<A> & Bool}
  {==}

def L.complete_token(A, i, old, x, n, h, r):
  +x = x
  +r = r
  %Equal.sym(Q.State<A> & Maybe<&2, Q.Ticket<A>>, Q.complete(A, i, Q.State{n, h, Q.Ticket{i, old, x} <> r}), L.complete.reference(A, i, Q.State{n, h, Q.Ticket{i, old, x} <> r}), L.complete_equivalent(A, i, Q.State{n, h, Q.Ticket{i, old, x} <> r})) : {L.selected(A, _) == Some{Q.Ticket{i, old, x}} : Maybe<&2, Q.Ticket<A>>}
  %Equal.sym(Bool, Nat.is_eq(i, i), True{}, MNat.is_eq_refl(i)) : {Q.find.list.choose(A, _, Q.Ticket{i, old, x}, Q.find.list(A, r, i)) == Some{Q.Ticket{i, old, x}} : Maybe<&2, Q.Ticket<A>>}
  {==}
