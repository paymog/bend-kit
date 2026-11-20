# Pure generic scheduler queue; Nat deadlines and never-reused FIFO IDs.
import Base
import bend-kit-collections@0.1.5.0/heap.bend as H

type Ticket<-A: Data> is Data:
  Ticket{id: Nat, deadline: Nat, payload: A}

type State<-A: Data> is Data:
  State{next_id: Nat, pending: H.Heap<Ticket<A>>, running: List<&2, Ticket<A>>}

def id(-A: Data, t: Ticket<A>) -> Nat:
  match t:
    case Ticket{i, d, x}:
      i

def deadline(-A: Data, t: Ticket<A>) -> Nat:
  match t:
    case Ticket{i, d, x}:
      d

def payload(-A: Data, t: Ticket<A>) -> A:
  match t:
    case Ticket{i, d, x}:
      x

def le.same(b: Bool, i: Nat, j: Nat, d: Nat, e: Nat) -> Bool:
  match b:
    case True{}:
      Nat.is_le(i, j)
    case False{}:
      Nat.is_le(d, e)

def le(-A: Data, a: Ticket<A>, b: Ticket<A>) -> Bool:
  match a b:
    case Ticket{i, +d, x} Ticket{j, +e, y}:
      le.same(Nat.is_eq(d, e), i, j, d, e)

def new(-A: Data) -> State<A>:
  State{0n, H.Heap.new(Ticket<A>), Nil{}}

def enqueue(~A: Data, d: Nat, x: A, s: State<A>) -> State<A> & Nat:
  match s:
    case State{+i, h, r}:
      (State{1n+i, H.Heap.push(~Ticket<A>, ~(a => b => le(A, a, b)), Ticket{i, d, x}, h), r}, i)

def select.due(~A: Data, b: Bool, i: Nat, h: H.Heap<Ticket<A>>, r: List<&2, Ticket<A>>, t: Ticket<A>, l: H.Heap<Ticket<A>>, q: H.Heap<Ticket<A>>) -> State<A> & Maybe<&2, Ticket<A>>:
  match b:
    case False{}:
      (State{i, h, r}, None{})
    case True{}:
      +t = t
      (State{i, H.Heap.merge(~Ticket<A>, ~(a => b => le(A, a, b)), l, q), t <> r}, Some{t})

def select(~A: Data, now: Nat, s: State<A>) -> State<A> & Maybe<&2, Ticket<A>>:
  match s:
    case State{i, H.HLeaf{}, r}:
      (State{i, H.HLeaf{}, r}, None{})
    case State{i, H.HNode{+n, +t, +l, +q}, r}:
      select.due(~A, Nat.is_le(deadline(A, t), now), i, H.HNode{n, t, l, q}, r, t, l, q)

# ponytail: eager O(n) cancellation; indexed deletion if cancellation dominates.
def remove.list.keep(-A: Data, b: Bool, t: Ticket<A>, rest: List<&2, Ticket<A>>) -> List<&2, Ticket<A>>:
  match b:
    case True{}:
      rest
    case False{}:
      t <> rest

def remove.list(-A: Data, xs: List<&2, Ticket<A>>, +i: Nat) -> List<&2, Ticket<A>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+t, rest}:
      remove.list.keep(A, Nat.is_eq(id(A, t), i), t, remove.list(A, rest, i))

def remove.heap.keep(~A: Data, b: Bool, t: Ticket<A>, l: H.Heap<Ticket<A>>, r: H.Heap<Ticket<A>>) -> H.Heap<Ticket<A>>:
  match b:
    case True{}:
      H.Heap.merge(~Ticket<A>, ~(a => b => le(A, a, b)), l, r)
    case False{}:
      +l = l
      +r = r
      H.HNode{1n+Nat.add(H.Heap.size(Ticket<A>, l), H.Heap.size(Ticket<A>, r)), t, l, r}

def remove.heap(~A: Data, h: H.Heap<Ticket<A>>, +i: Nat) -> H.Heap<Ticket<A>>:
  match h:
    case H.HLeaf{}:
      H.HLeaf{}
    case H.HNode{n, +t, l, r}:
      remove.heap.keep(~A, Nat.is_eq(id(A, t), i), t, remove.heap(~A, l, i), remove.heap(~A, r, i))

def cancel(~A: Data, i: Nat, s: State<A>) -> State<A>:
  match s:
    case State{n, h, r}:
      +i = i
      State{n, remove.heap(~A, h, i), remove.list(A, r, i)}

# Reference observation for laws; completion uses the single-pass take below.
def find.list.choose(-A: Data, b: Bool, t: Ticket<A>, rest: Maybe<&2, Ticket<A>>) -> Maybe<&2, Ticket<A>>:
  match b:
    case True{}:
      Some{t}
    case False{}:
      rest

def find.list(-A: Data, xs: List<&2, Ticket<A>>, +i: Nat) -> Maybe<&2, Ticket<A>>:
  match xs:
    case Nil{}:
      None{}
    case Con{+t, rest}:
      find.list.choose(A, Nat.is_eq(id(A, t), i), t, find.list(A, rest, i))

type Taken<-A: Data> is Data:
  Taken{remaining: List<&2, Ticket<A>>, found: Maybe<&2, Ticket<A>>}

# Remove all matching entries and return the first token in one traversal.
def take.keep(-A: Data, b: Bool, t: Ticket<A>, result: Taken<A>) -> Taken<A>:
  match b:
    case True{}:
      match result:
        case Taken{rest, found}:
          Taken{rest, Some{t}}
    case False{}:
      match result:
        case Taken{rest, found}:
          Taken{t <> rest, found}

def take.list(-A: Data, xs: List<&2, Ticket<A>>, +i: Nat) -> Taken<A>:
  match xs:
    case Nil{}:
      Taken{Nil{}, None{}}
    case Con{+t, rest}:
      take.keep(A, Nat.is_eq(id(A, t), i), t, take.list(A, rest, i))

def complete.taken(-A: Data, result: Taken<A>, n: Nat, h: H.Heap<Ticket<A>>) -> State<A> & Maybe<&2, Ticket<A>>:
  match result:
    case Taken{r, found}:
      (State{n, h, r}, found)

def complete(-A: Data, i: Nat, s: State<A>) -> State<A> & Maybe<&2, Ticket<A>>:
  match s:
    case State{n, h, r}:
      complete.taken(A, take.list(A, r, i), n, h)

def requeue.found(~A: Data, found: Maybe<&2, Ticket<A>>, d: Nat, s: State<A>) -> State<A> & Bool:
  match found:
    case None{}:
      (s, False{})
    case Some{Ticket{i, old, x}}:
      match s:
        case State{n, h, r}:
          (State{n, H.Heap.push(~Ticket<A>, ~(a => b => le(A, a, b)), Ticket{i, d, x}, h), r}, True{})

def requeue.completed(~A: Data, r: State<A> & Maybe<&2, Ticket<A>>, d: Nat) -> State<A> & Bool:
  (s, found) = r
  requeue.found(~A, found, d, s)

def requeue(~A: Data, i: Nat, d: Nat, s: State<A>) -> State<A> & Bool:
  requeue.completed(~A, complete(A, i, s), d)

# Non-consuming observations used by adapters and laws.
def next_id(-A: Data, s: State<A>) -> Nat:
  match s:
    case State{n, h, r}:
      n

def pending(-A: Data, s: State<A>) -> H.Heap<Ticket<A>>:
  match s:
    case State{n, h, r}:
      h

def running(-A: Data, s: State<A>) -> List<&2, Ticket<A>>:
  match s:
    case State{n, h, r}:
      r
