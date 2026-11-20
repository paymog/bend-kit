# Quantified queue contracts. Heap ordering is an explicit input invariant;
# selection safety and cancellation/one-shot laws do not require it.
import Base
import bend-kit-collections@0.1.5.0/heap.bend as H
import ./queue.bend as Q

# Ordinary & pairs are affine even when their fields are Data. Invariant
# conjunctions contain only evidence, so a Data constructor permits reuse.
type Both<-A: Data, -B: Data> is Data:
  Both{left: A, right: B}

def state(-A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>) -> Q.State<A>:
  (s, t) = r
  s

def selected(-A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>) -> Maybe<&2, Q.Ticket<A>>:
  (s, t) = r
  t

def requeued(-A: Data, r: Q.State<A> & Bool) -> Bool:
  (s, b) = r
  b

def enqueued(-A: Data, r: Q.State<A> & Nat) -> Q.State<A>:
  (s, i) = r
  s

def assigned(-A: Data, r: Q.State<A> & Nat) -> Nat:
  (s, i) = r
  i

# Reference semantics are deliberately simple; the live transition takes one
# pass and its equivalence is proved universally, including duplicate IDs.
def complete.reference(-A: Data, +i: Nat, s: Q.State<A>) -> Q.State<A> & Maybe<&2, Q.Ticket<A>>:
  match s:
    case Q.State{n, h, +r}:
      (Q.State{n, h, Q.remove.list(A, r, i)}, Q.find.list(A, r, i))

def requeue.reference(~A: Data, i: Nat, d: Nat, s: Q.State<A>) -> Q.State<A> & Bool:
  Q.requeue.completed(~A, complete.reference(A, i, s), d)

law take_equivalent:
  for -A: Data
  for +xs: List<&2, Q.Ticket<A>>
  for +i: Nat
  {Q.take.list(A, xs, i) == Q.Taken{Q.remove.list(A, xs, i), Q.find.list(A, xs, i)} : Q.Taken<A>}

law complete_equivalent:
  for -A: Data
  for +i: Nat
  for +s: Q.State<A>
  {Q.complete(A, i, s) == complete.reference(A, i, s) : Q.State<A> & Maybe<&2, Q.Ticket<A>>}

law requeue_equivalent:
  for ~A: Data
  for +i: Nat
  for d: Nat
  for +s: Q.State<A>
  {Q.requeue(~A, i, d, s) == requeue.reference(~A, i, d, s) : Q.State<A> & Bool}

def absent.list(-A: Data, xs: List<&2, Q.Ticket<A>>, +i: Nat) -> Data:
  match xs:
    case Nil{}:
      Unit
    case Con{t, rest}:
      Both<{Nat.is_eq(Q.id(A, t), i) == False{} : Bool}, absent.list(A, rest, i)>

def all.heap(-A: Data, -P: Q.Ticket<A> -> Data, h: H.Heap<Q.Ticket<A>>) -> Data:
  match h:
    case H.HLeaf{}:
      Unit
    case H.HNode{n, t, l, r}:
      Both<P(t), Both<all.heap(A, P, l), all.heap(A, P, r)>>

def absent.ticket(-A: Data, i: Nat, t: Q.Ticket<A>) -> Data:
  {Nat.is_eq(Q.id(A, t), i) == False{} : Bool}

def bound.ticket(-A: Data, lower: Q.Ticket<A>, t: Q.Ticket<A>) -> Data:
  {Q.le(A, lower, t) == True{} : Bool}

def absent.heap(-A: Data, h: H.Heap<Q.Ticket<A>>, +i: Nat) -> Data:
  all.heap(A, absent.ticket(A, i), h)

def below(-A: Data, h: H.Heap<Q.Ticket<A>>, +t: Q.Ticket<A>) -> Data:
  all.heap(A, bound.ticket(A, t), h)

# The root must bound both subtrees recursively, not just its direct children.
# No law takes the desired selection result as an assumption.
# Cached sizes are a separate construction invariant of collections' heap:
# new/push/merge build them and remove.heap recomputes each retained size.
# ordered deliberately concerns ordering only. The order/absence merge lemmas
# hold even for malformed sizes; they do not claim element conservation for
# forged HNode values whose merge fuel can run out early.
def ordered(-A: Data, h: H.Heap<Q.Ticket<A>>) -> Data:
  match h:
    case H.HLeaf{}:
      Unit
    case H.HNode{n, +t, +l, +r}:
      Both<Both<below(A, l, t), below(A, r, t)>, Both<ordered(A, l), ordered(A, r)>>

def due(-A: Data, t: Maybe<&2, Q.Ticket<A>>, now: Nat) -> Data:
  match t:
    case None{}:
      Unit
    case Some{t}:
      {Nat.is_le(Q.deadline(A, t), now) == True{} : Bool}

def minimum(-A: Data, h: H.Heap<Q.Ticket<A>>, selected: Maybe<&2, Q.Ticket<A>>) -> Data:
  match selected:
    case None{}:
      Unit
    case Some{t}:
      below(A, h, t)

law new_ordered:
  for -A: Data
  ordered(A, Q.pending(A, Q.new(A)))

law select_due:
  for ~A: Data
  for now: Nat
  for s: Q.State<A>
  due(A, selected(A, Q.select(~A, now, s)), now)

law select_minimum:
  for ~A: Data
  for now: Nat
  for +s: Q.State<A>
  for e: ordered(A, Q.pending(A, s))
  minimum(A, Q.pending(A, s), selected(A, Q.select(~A, now, s)))

law equal_deadline_fifo:
  for -A: Data
  for i: Nat
  for j: Nat
  for d: Nat
  for x: A
  for y: A
  {Q.le(A, Q.Ticket{i, d, x}, Q.Ticket{j, d, y}) == Nat.is_le(i, j) : Bool}

law enqueue_id:
  for ~A: Data
  for d: Nat
  for x: A
  for +s: Q.State<A>
  {Q.next_id(A, enqueued(A, Q.enqueue(~A, d, x, s))) == 1n+Q.next_id(A, s) : Nat}

law cancel_pending_absent:
  for ~A: Data
  for i: Nat
  for s: Q.State<A>
  absent.heap(A, Q.pending(A, Q.cancel(~A, i, s)), i)

law cancel_running_absent:
  for ~A: Data
  for i: Nat
  for s: Q.State<A>
  absent.list(A, Q.running(A, Q.cancel(~A, i, s)), i)

law absent_find:
  for -A: Data
  for +xs: List<&2, Q.Ticket<A>>
  for +i: Nat
  for e: absent.list(A, xs, i)
  {Q.find.list(A, xs, i) == None{} : Maybe<&2, Q.Ticket<A>>}

law complete_one_shot:
  for -A: Data
  for +i: Nat
  for s: Q.State<A>
  {selected(A, Q.complete(A, i, state(A, Q.complete(A, i, s)))) == None{} : Maybe<&2, Q.Ticket<A>>}

law cancel_complete:
  for ~A: Data
  for +i: Nat
  for s: Q.State<A>
  {selected(A, Q.complete(A, i, Q.cancel(~A, i, s))) == None{} : Maybe<&2, Q.Ticket<A>>}

law cancel_requeue:
  for ~A: Data
  for +i: Nat
  for d: Nat
  for s: Q.State<A>
  {requeued(A, Q.requeue(~A, i, d, Q.cancel(~A, i, s))) == False{} : Bool}

law complete_requeue:
  for ~A: Data
  for +i: Nat
  for d: Nat
  for s: Q.State<A>
  {requeued(A, Q.requeue(~A, i, d, state(A, Q.complete(A, i, s)))) == False{} : Bool}

# An absent ID stays absent on every selection, in both registries. Combined
# with cancellation above this covers any number of intervening selections.
law select_absent:
  for ~A: Data
  for now: Nat
  for +i: Nat
  for +s: Q.State<A>
  for eh: absent.heap(A, Q.pending(A, s), i)
  for er: absent.list(A, Q.running(A, s), i)
  absent.heap(A, Q.pending(A, state(A, Q.select(~A, now, s))), i) & absent.list(A, Q.running(A, state(A, Q.select(~A, now, s))), i)

law absent_selected:
  for ~A: Data
  for now: Nat
  for +i: Nat
  for +s: Q.State<A>
  for eh: absent.heap(A, Q.pending(A, s), i)
  for t: Q.Ticket<A>
  for e: {selected(A, Q.select(~A, now, s)) == Some{t} : Maybe<&2, Q.Ticket<A>>}
  {Nat.is_eq(Q.id(A, t), i) == False{} : Bool}

law enqueue_ordered:
  for ~A: Data
  for d: Nat
  for x: A
  for +s: Q.State<A>
  for e: ordered(A, Q.pending(A, s))
  ordered(A, Q.pending(A, enqueued(A, Q.enqueue(~A, d, x, s))))

law select_ordered:
  for ~A: Data
  for now: Nat
  for +s: Q.State<A>
  for e: ordered(A, Q.pending(A, s))
  ordered(A, Q.pending(A, state(A, Q.select(~A, now, s))))

law cancel_ordered:
  for ~A: Data
  for i: Nat
  for +s: Q.State<A>
  for e: ordered(A, Q.pending(A, s))
  ordered(A, Q.pending(A, Q.cancel(~A, i, s)))

def requeue.state(-A: Data, r: Q.State<A> & Bool) -> Q.State<A>:
  (s, b) = r
  s

law requeue_ordered:
  for ~A: Data
  for +i: Nat
  for d: Nat
  for +s: Q.State<A>
  for e: ordered(A, Q.pending(A, s))
  ordered(A, Q.pending(A, requeue.state(A, Q.requeue(~A, i, d, s))))

law complete_ordered:
  for -A: Data
  for i: Nat
  for +s: Q.State<A>
  for e: ordered(A, Q.pending(A, s))
  ordered(A, Q.pending(A, state(A, Q.complete(A, i, s))))

law enqueue_assigned_id:
  for ~A: Data
  for d: Nat
  for x: A
  for +s: Q.State<A>
  {assigned(A, Q.enqueue(~A, d, x, s)) == Q.next_id(A, s) : Nat}

law cancel_keeps_counter:
  for ~A: Data
  for i: Nat
  for +s: Q.State<A>
  {Q.next_id(A, Q.cancel(~A, i, s)) == Q.next_id(A, s) : Nat}

law complete_keeps_counter:
  for -A: Data
  for i: Nat
  for +s: Q.State<A>
  {Q.next_id(A, state(A, Q.complete(A, i, s))) == Q.next_id(A, s) : Nat}

law select_keeps_counter:
  for ~A: Data
  for now: Nat
  for +s: Q.State<A>
  {Q.next_id(A, state(A, Q.select(~A, now, s))) == Q.next_id(A, s) : Nat}

law requeue_keeps_counter:
  for ~A: Data
  for i: Nat
  for d: Nat
  for +s: Q.State<A>
  {Q.next_id(A, requeue.state(A, Q.requeue(~A, i, d, s))) == Q.next_id(A, s) : Nat}

# The running token, not a newly assigned ID, is moved back to pending.
law requeue_token:
  for ~A: Data
  for +i: Nat
  for d: Nat
  for old: Nat
  for x: A
  for n: Nat
  for h: H.Heap<Q.Ticket<A>>
  for r: List<&2, Q.Ticket<A>>
  {Q.requeue(~A, i, d, Q.State{n, h, Q.Ticket{i, old, x} <> r})
   == (Q.State{n, H.Heap.push(~Q.Ticket<A>, ~(a => b => Q.le(A, a, b)), Q.Ticket{i, d, x}, h), Q.remove.list(A, Q.Ticket{i, old, x} <> r, i)}, True{}) : Q.State<A> & Bool}

law complete_token:
  for -A: Data
  for +i: Nat
  for old: Nat
  for x: A
  for n: Nat
  for h: H.Heap<Q.Ticket<A>>
  for r: List<&2, Q.Ticket<A>>
  {selected(A, Q.complete(A, i, Q.State{n, h, Q.Ticket{i, old, x} <> r}))
   == Some{Q.Ticket{i, old, x}} : Maybe<&2, Q.Ticket<A>>}
