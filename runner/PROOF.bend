import Base
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-mathlib@0.8.0.0/bool.bend as MBool
import bend-kit-collections@0.1.5.0/hmap.bend as M
import bend-kit-scheduler@0.4.3.0/queue.bend as Q
import bend-kit-scheduler@0.4.3.0/queue_laws.bend as QL
import bend-kit-scheduler@0.4.3.0/queue_proof.bend as QP
import bend-kit-collections@0.1.5.0/heap.bend as H
import bend-kit-collections@0.1.5.0/LAWS.bend as CL
import bend-kit-collections@0.1.5.0/PROOF.bend as CP
import bend-kit-resources@0.1.0.0/resources.bend as Res
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import ./model.bend as R
import ./LAWS.bend as Laws
import bend-kit-collections@0.1.5.0/order.bend as Order

def split(-P: Bool -> Type, b: Bool, yes: {b == True{} : Bool} -> P(True{}), no: {b == False{} : Bool} -> P(False{})) -> P(b):
  match b:
    case True{}:
      yes({==})
    case False{}:
      no({==})

# ---- replay

def replay.go(~A: Data, ~X: Type, ~enc: R.Op<A> -> X, ~dec: X -> Maybe<&2, R.Op<A>>, ~round: @op: R.Op<A> -> {dec(enc(op)) == Some{op} : Maybe<&2, R.Op<A>>},
    ops: List<&2, R.Op<A>>, s: R.State<A>) -> {Laws.replayed(~A, ~X, ~enc, ~dec, ops, s) == Some{Laws.live(~A, ops, s)} : Maybe<&2, R.State<A>>}:
  match ops:
    case Nil{}:
      {==}
    case Con{+op, rest}:
      %Equal.sym(Maybe<&2, R.Op<A>>, dec(enc(op)), Some{op}, round(op)) : {Laws.replay.from(~A, ~X, ~dec, Laws.encode.all(~A, ~X, ~enc, rest), R.apply.op(~A, _, s)) == Some{Laws.live(~A, rest, R.step(~A, s, op))} : Maybe<&2, R.State<A>>}
      replay.go(~A, ~X, ~enc, ~dec, ~round, rest, R.step(~A, s, op))

def Laws.replay_live(A, X, enc, dec, round, ops, s):
  replay.go(~A, ~X, ~enc, ~dec, ~round, ops, s)

def Laws.replay_prefix(A, X, enc, dec, round, ops, k, s):
  replay.go(~A, ~X, ~enc, ~dec, ~round, List.take(&2, R.Op<A>, ops, k), s)

def breaker.refl(k: String) -> {R.brk.eq(k, k) == True{} : Bool}:
  +k = k
  Equal.cong(Cmp, Bool, Cmp.is_eq, Order.string(k, k), EQ{}, CL.order_string_refl(k))

def breaker.cmp.eq(+c: Cmp, e: {Cmp.is_eq(c) == True{} : Bool}) -> {c == EQ{} : Cmp}:
  match c:
    case LT{}:
      Empty.absurd({LT{} == EQ{} : Cmp}, MBool.false_ne_true()(e))
    case EQ{}:
      {==}
    case GT{}:
      Empty.absurd({GT{} == EQ{} : Cmp}, MBool.false_ne_true()(e))

def breaker.sound(a: String, b: String, e: {R.brk.eq(a, b) == True{} : Bool}) -> {a == b : String}:
  +a = a
  +b = b
  CL.order_string_eq(a, b, breaker.cmp.eq(Order.string(a, b), e))

def breaker.next(-A: Data, bs: R.Breakers(), op: R.Op<A>) -> R.Breakers():
  match op:
    case R.Break{k, b}:
      R.step.broke(bs, k, b)
    case op:
      bs

def breaker.enqueued(-A: Data, r: Q.State<A> & Nat, ts: R.Tries(), ds: R.Graves(A), +bs: R.Breakers(), d: Nat) ->
    {R.breakers(A, R.step.enqueued(A, r, ts, ds, bs, d)) == bs : R.Breakers()}:
  match r:
    case (q, i):
      {==}

def breaker.selected(-A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: R.Tries(), ds: R.Graves(A), +bs: R.Breakers()) ->
    {R.breakers(A, R.step.selected(A, r, ts, ds, bs)) == bs : R.Breakers()}:
  match r:
    case (q, t):
      {==}

def breaker.completed(-A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: R.Tries(), ds: R.Graves(A), +bs: R.Breakers()) ->
    {R.breakers(A, R.step.completed(A, r, ts, ds, bs)) == bs : R.Breakers()}:
  match r:
    case (q, t):
      {==}

def breaker.requeued(-A: Data, r: Q.State<A> & Bool, ts: R.Tries(), ds: R.Graves(A), +bs: R.Breakers()) ->
    {R.breakers(A, R.step.requeued(A, r, ts, ds, bs)) == bs : R.Breakers()}:
  match r:
    case (q, t):
      {==}

def breaker.abandoned(~A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: R.Tries(), ds: R.Graves(A), +bs: R.Breakers(), w: R.Why, at: Nat) ->
    {R.breakers(A, R.step.abandoned(~A, r, ts, ds, bs, w, at)) == bs : R.Breakers()}:
  match r:
    case (q, t):
      {==}

def breaker.revived(~A: Data, m: Maybe<&2, R.Dead<A>>, i: Nat, n: Nat, h: H.Heap<Q.Ticket<A>>, r: List<&2, Q.Ticket<A>>, ts: R.Tries(), ds: R.Graves(A), +bs: R.Breakers(), d: Nat) ->
    {R.breakers(A, R.step.revived(~A, m, i, n, h, r, ts, ds, bs, d)) == bs : R.Breakers()}:
  match m:
    case None{}:
      {==}
    case Some{R.Dead{Q.Ticket{k, old, x}, w, at}}:
      {==}

def breaker.step(~A: Data, +s: R.State<A>, +op: R.Op<A>) ->
    {R.breakers(A, R.step(~A, s, op)) == breaker.next(A, R.breakers(A, s), op) : R.Breakers()}:
  match s op:
    case R.State{q, ts, ds, bs} R.Enqueue{d, x}:
      breaker.enqueued(A, Q.enqueue(~A, d, x, q), ts, ds, bs, d)
    case R.State{q, ts, ds, bs} R.Select{now}:
      breaker.selected(A, Q.select(~A, now, q), ts, ds, bs)
    case R.State{q, ts, ds, bs} R.Complete{i}:
      breaker.completed(A, Q.complete(A, i, q), R.tries.drop(ts, i), ds, bs)
    case R.State{q, ts, ds, bs} R.Cancel{i}:
      {==}
    case R.State{q, ts, ds, bs} R.Requeue{i, d}:
      breaker.requeued(A, Q.requeue(~A, i, d, q), R.tries.bump(ts, i), ds, bs)
    case R.State{q, ts, ds, bs} R.Defer{i, d}:
      breaker.requeued(A, Q.requeue(~A, i, d, q), ts, ds, bs)
    case R.State{q, ts, ds, bs} R.Abandon{i, w, at}:
      breaker.abandoned(~A, Q.complete(A, i, q), R.tries.drop(ts, i), ds, bs, w, at)
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.Revive{i, d}:
      breaker.revived(~A, R.dead.get(~A, ds, i), i, n, h, r, ts, ds, bs, d)
    case R.State{q, ts, ds, bs} R.Purge{t}:
      {==}
    case R.State{q, ts, ds, bs} R.PurgeAll{}:
      {==}
    case R.State{q, ts, ds, bs} R.Break{k, b}:
      {==}

def breaker.broke.wf(+bs: R.Breakers(), +k: String, b: Retry.State,
    wf: {Laws.breaker.wf(bs) == True{} : Bool}) -> {Laws.breaker.wf(R.step.broke(bs, k, b)) == True{} : Bool}:
  match b:
    case Retry.CircuitClosed{Nil{}}:
      CL.hmap_del_wf(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, bs, wf, k)
    case Retry.CircuitClosed{Con{f, fs}}:
      CL.hmap_put_wf(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, ~breaker.refl, ~breaker.sound, bs, wf, k, Retry.CircuitClosed{Con{f, fs}})
    case Retry.CircuitOpen{u}:
      CL.hmap_put_wf(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, ~breaker.refl, ~breaker.sound, bs, wf, k, Retry.CircuitOpen{u})
    case Retry.CircuitHalf{p}:
      CL.hmap_put_wf(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, ~breaker.refl, ~breaker.sound, bs, wf, k, Retry.CircuitHalf{p})

def breaker.next.wf(~A: Data, +bs: R.Breakers(), op: R.Op<A>,
    wf: {Laws.breaker.wf(bs) == True{} : Bool}) -> {Laws.breaker.wf(breaker.next(A, bs, op)) == True{} : Bool}:
  match op:
    case R.Break{k, b}:
      breaker.broke.wf(bs, k, b, wf)
    case R.Enqueue{d, x}:
      wf
    case R.Select{now}:
      wf
    case R.Complete{i}:
      wf
    case R.Cancel{i}:
      wf
    case R.Requeue{i, d}:
      wf
    case R.Defer{i, d}:
      wf
    case R.Abandon{i, w, at}:
      wf
    case R.Revive{i, d}:
      wf
    case R.Purge{t}:
      wf
    case R.PurgeAll{}:
      wf

def breaker.step.wf(~A: Data, +s: R.State<A>, +op: R.Op<A>,
    wf: {Laws.breaker.wf(R.breakers(A, s)) == True{} : Bool}) -> {Laws.breaker.wf(R.breakers(A, R.step(~A, s, op))) == True{} : Bool}:
  %Equal.sym(R.Breakers(), R.breakers(A, R.step(~A, s, op)), breaker.next(A, R.breakers(A, s), op), breaker.step(~A, s, op)) : {Laws.breaker.wf(_) == True{} : Bool}
  breaker.next.wf(~A, R.breakers(A, s), op, wf)

def breaker.put.same(+bs: R.Breakers(), +k: String, +b: Retry.State, wf: {Laws.breaker.wf(bs) == True{} : Bool}) ->
    {R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, M.HMap.put(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, bs, k, b), k)) == b : Retry.State}:
  Equal.cong(Maybe<&2, Retry.State>, Retry.State, R.brk.got,
    M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, M.HMap.put(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, bs, k, b), k), Some{b},
    CL.hmap_get_put_same(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, ~breaker.refl, bs, wf, k, b))

def breaker.put.other(+bs: R.Breakers(), +j: String, +b: Retry.State, +k: String, ne: {j != k : String}, wf: {Laws.breaker.wf(bs) == True{} : Bool}) ->
    {R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, M.HMap.put(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, bs, j, b), k)) ==
     R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, bs, k)) : Retry.State}:
  Equal.cong(Maybe<&2, Retry.State>, Retry.State, R.brk.got,
    M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, M.HMap.put(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, bs, j, b), k),
    M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, bs, k),
    CL.hmap_get_put_other_key(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, ~breaker.sound, bs, wf, j, k, ne, b))

def breaker.broke.same(+bs: R.Breakers(), +k: String, +b: Retry.State,
    wf: {Laws.breaker.wf(bs) == True{} : Bool}) ->
    {R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, R.step.broke(bs, k, b), k)) == b : Retry.State}:
  match b:
    case Retry.CircuitClosed{Nil{}}:
      %CL.hmap_get_del_same(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, ~breaker.sound, bs, wf, k) : {R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, R.step.broke(bs, k, Retry.CircuitClosed{Nil{}}), k)) == R.brk.got(_) : Retry.State}
      {==}
    case Retry.CircuitClosed{Con{f, fs}}:
      breaker.put.same(bs, k, Retry.CircuitClosed{Con{f, fs}}, wf)
    case Retry.CircuitOpen{u}:
      breaker.put.same(bs, k, Retry.CircuitOpen{u}, wf)
    case Retry.CircuitHalf{p}:
      breaker.put.same(bs, k, Retry.CircuitHalf{p}, wf)

def breaker.broke.other(+bs: R.Breakers(), +j: String, b: Retry.State, +k: String, ne: {j != k : String},
    wf: {Laws.breaker.wf(bs) == True{} : Bool}) ->
    {R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, R.step.broke(bs, j, b), k)) ==
     R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, bs, k)) : Retry.State}:
  match b:
    case Retry.CircuitClosed{Nil{}}:
      %CL.hmap_get_del_other_key(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, ~breaker.sound, bs, j, k, ne) :
        {R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, R.step.broke(bs, j, Retry.CircuitClosed{Nil{}}), k)) == R.brk.got(_) : Retry.State}
      {==}
    case Retry.CircuitClosed{Con{f, fs}}:
      breaker.put.other(bs, j, Retry.CircuitClosed{Con{f, fs}}, k, ne, wf)
    case Retry.CircuitOpen{u}:
      breaker.put.other(bs, j, Retry.CircuitOpen{u}, k, ne, wf)
    case Retry.CircuitHalf{p}:
      breaker.put.other(bs, j, Retry.CircuitHalf{p}, k, ne, wf)

def breaker.next.other(~A: Data, +bs: R.Breakers(), +op: R.Op<A>, +k: String, untouched: Laws.breaker.untouched(A, op, k),
    wf: {Laws.breaker.wf(bs) == True{} : Bool}) ->
    {R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, breaker.next(A, bs, op), k)) ==
     R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, bs, k)) : Retry.State}:
  match op:
    case R.Break{j, b}:
      breaker.broke.other(bs, j, b, k, untouched, wf)
    case R.Enqueue{d, x}:
      {==}
    case R.Select{now}:
      {==}
    case R.Complete{i}:
      {==}
    case R.Cancel{i}:
      {==}
    case R.Requeue{i, d}:
      {==}
    case R.Defer{i, d}:
      {==}
    case R.Abandon{i, w, at}:
      {==}
    case R.Revive{i, d}:
      {==}
    case R.Purge{t}:
      {==}
    case R.PurgeAll{}:
      {==}

def breaker.live(~A: Data, ops: List<&2, R.Op<A>>, +s: R.State<A>, +k: String, untouched: Laws.breaker.untouched.all(A, ops, k),
    +wf: {Laws.breaker.wf(R.breakers(A, s)) == True{} : Bool}) ->
    {R.brk.get(A, Laws.live(~A, ops, s), k) == R.brk.get(A, s, k) : Retry.State}:
  match ops:
    case Nil{}:
      {==}
    case Con{+op, +rest}:
      (one, more) = untouched
      %Equal.sym(Retry.State, R.brk.get(A, Laws.live(~A, rest, R.step(~A, s, op)), k), R.brk.get(A, R.step(~A, s, op), k), breaker.live(~A, rest, R.step(~A, s, op), k, more, breaker.step.wf(~A, s, op, wf))) :
        {_ == R.brk.get(A, s, k) : Retry.State}
      %Equal.sym(R.Breakers(), R.breakers(A, R.step(~A, s, op)), breaker.next(A, R.breakers(A, s), op), breaker.step(~A, s, op)) :
        {R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, _, k)) == R.brk.get(A, s, k) : Retry.State}
      breaker.next.other(~A, R.breakers(A, s), op, k, one, wf)

def breaker.reachable.wf(~A: Data, ops: List<&2, R.Op<A>>, +s: R.State<A>,
    wf: {Laws.breaker.wf(R.breakers(A, s)) == True{} : Bool}) ->
    {Laws.breaker.wf(R.breakers(A, Laws.live(~A, ops, s))) == True{} : Bool}:
  match ops:
    case Nil{}:
      wf
    case Con{+op, rest}:
      breaker.reachable.wf(~A, rest, R.step(~A, s, op), breaker.step.wf(~A, s, op, wf))

def breaker.new.wf(~A: Data, ops: List<&2, R.Op<A>>) ->
    {Laws.breaker.wf(R.breakers(A, Laws.live(~A, ops, R.new(A)))) == True{} : Bool}:
  breaker.reachable.wf(~A, ops, R.new(A), {==})

def Laws.replay_breaker(A, X, enc, dec, round, s, wf, k, b, ops, untouched):
  +wf = wf
  %Equal.sym(Maybe<&2, R.State<A>>, Laws.replayed(~A, ~X, ~enc, ~dec, R.Break{k, b} <> ops, s), Some{Laws.live(~A, R.Break{k, b} <> ops, s)}, replay.go(~A, ~X, ~enc, ~dec, ~round, R.Break{k, b} <> ops, s)) :
    {Laws.breaker.recovered(A, _, k) == Some{b} : Maybe<&2, Retry.State>}
  %Equal.sym(Retry.State, R.brk.get(A, Laws.live(~A, ops, R.step(~A, s, R.Break{k, b})), k), R.brk.get(A, R.step(~A, s, R.Break{k, b}), k), breaker.live(~A, ops, R.step(~A, s, R.Break{k, b}), k, untouched, breaker.step.wf(~A, s, R.Break{k, b}, wf))) :
    {Some{_} == Some{b} : Maybe<&2, Retry.State>}
  %Equal.sym(R.Breakers(), R.breakers(A, R.step(~A, s, R.Break{k, b})), R.step.broke(R.breakers(A, s), k, b), breaker.step(~A, s, R.Break{k, b})) :
    {Some{R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, _, k))} == Some{b} : Maybe<&2, Retry.State>}
  %breaker.broke.same(R.breakers(A, s), k, b, wf) : {Some{R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, R.step.broke(R.breakers(A, s), k, b), k))} == Some{_} : Maybe<&2, Retry.State>}
  {==}

def calm.result(m: Maybe<&2, Retry.State>) -> Maybe<&2, Retry.State>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      Some{R.calm.state(b)}

def calm.entries(es: List<&2, M.Entry<String, Retry.State>>, +k: String) ->
    {M.HMap.entries.get(~String, ~Retry.State, ~R.brk.eq, R.calm.entries(es), k) ==
     calm.result(M.HMap.entries.get(~String, ~Retry.State, ~R.brk.eq, es, k)) : Maybe<&2, Retry.State>}:
  match es:
    case Nil{}:
      {==}
    case Con{M.Entry{+j, +b}, +rest}:
      split(c => {
        M.HMap.bool(Maybe<&2, Retry.State>, c, u => Some{R.calm.state(b)}, u => M.HMap.entries.get(~String, ~Retry.State, ~R.brk.eq, R.calm.entries(rest), k)) ==
        calm.result(M.HMap.bool(Maybe<&2, Retry.State>, c, u => Some{b}, u => M.HMap.entries.get(~String, ~Retry.State, ~R.brk.eq, rest, k))) : Maybe<&2, Retry.State>},
        R.brk.eq(k, j),
        e => {==},
        e => calm.entries(rest, k))

def calm.get(+n: Nat, +mask: U32, bs: R.Breakers(), +hash: U32, +k: String) ->
    {M.HMap.get.go(~String, ~Retry.State, ~R.brk.eq, n, mask, R.calm.map(bs), hash, k) ==
     calm.result(M.HMap.get.go(~String, ~Retry.State, ~R.brk.eq, n, mask, bs, hash, k)) : Maybe<&2, Retry.State>}:
  match n bs:
    case 0n M.HNil{}:
      {==}
    case 0n M.HLeaf{h, es}:
      calm.entries(es, k)
    case 0n M.HBranch{lo, hi}:
      {==}
    case 1n+p M.HNil{}:
      {==}
    case 1n+p M.HLeaf{+h, +es}:
      split(c => {
        M.HMap.bool(Maybe<&2, Retry.State>, c, u => M.HMap.entries.get(~String, ~Retry.State, ~R.brk.eq, R.calm.entries(es), k), u => None{}) ==
        calm.result(M.HMap.bool(Maybe<&2, Retry.State>, c, u => M.HMap.entries.get(~String, ~Retry.State, ~R.brk.eq, es, k), u => None{})) : Maybe<&2, Retry.State>},
        U32.is_eq(h, hash),
        e => calm.entries(es, k),
        e => {==})
    case 1n+p M.HBranch{+lo, +hi}:
      split(c => {
        M.HMap.bool(Maybe<&2, Retry.State>, c,
          u => M.HMap.get.go(~String, ~Retry.State, ~R.brk.eq, p, (mask << 1n : U32), R.calm.map(lo), hash, k),
          u => M.HMap.get.go(~String, ~Retry.State, ~R.brk.eq, p, (mask << 1n : U32), R.calm.map(hi), hash, k)) ==
        calm.result(M.HMap.bool(Maybe<&2, Retry.State>, c,
          u => M.HMap.get.go(~String, ~Retry.State, ~R.brk.eq, p, (mask << 1n : U32), lo, hash, k),
          u => M.HMap.get.go(~String, ~Retry.State, ~R.brk.eq, p, (mask << 1n : U32), hi, hash, k))) : Maybe<&2, Retry.State>},
        U32.is_eq((hash .&. mask : U32), 0),
        e => calm.get(p, (mask << 1n : U32), lo, hash, k),
        e => calm.get(p, (mask << 1n : U32), hi, hash, k))

def calm.got(m: Maybe<&2, Retry.State>) ->
    {R.brk.got(calm.result(m)) == R.calm.state(R.brk.got(m)) : Retry.State}:
  match m:
    case None{}:
      {==}
    case Some{b}:
      {==}

def calm.spec(b: Retry.State) -> {R.calm.state(b) == Laws.breaker.after_crash(b) : Retry.State}:
  match b:
    case Retry.CircuitClosed{fs}:
      {==}
    case Retry.CircuitOpen{until}:
      {==}
    case Retry.CircuitHalf{probes}:
      {==}

def Laws.calm_breaker(A, s, k):
  match s:
    case R.State{q, ts, ds, +bs}:
      +before = M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, bs, k)
      %calm.spec(R.brk.got(before)) :
        {R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, R.calm.map(bs), k)) == _ : Retry.State}
      Equal.trans(Retry.State,
        R.brk.got(M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, R.calm.map(bs), k)),
        R.brk.got(calm.result(before)), R.calm.state(R.brk.got(before)),
        Equal.cong(Maybe<&2, Retry.State>, Retry.State, R.brk.got,
          M.HMap.get(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, R.calm.map(bs), k), calm.result(before),
          calm.get(32n, 1, bs, R.brk.hash(k), k)),
        calm.got(before))

# ---- compaction

def restore.go(~A: Data, ~X: Type, ~enc: R.Rec<A> -> X, ~dec: X -> Maybe<&2, R.Rec<A>>, ~round: @r: R.Rec<A> -> {dec(enc(r)) == Some{r} : Maybe<&2, R.Rec<A>>},
    more: List<&2, R.Op<A>>, s: R.State<A>) -> {Laws.restore.from(~A, ~X, ~dec, Laws.encode.ops(~A, ~X, ~enc, more), Some{s}) == Some{Laws.live(~A, more, s)} : Maybe<&2, R.State<A>>}:
  match more:
    case Nil{}:
      {==}
    case Con{+op, rest}:
      %Equal.sym(Maybe<&2, R.Rec<A>>, dec(enc(R.Do{op})), Some{R.Do{op}}, round(R.Do{op})) : {Laws.restore.from(~A, ~X, ~dec, Laws.encode.ops(~A, ~X, ~enc, rest), R.load.rec(~A, _, s)) == Some{Laws.live(~A, rest, R.step(~A, s, op))} : Maybe<&2, R.State<A>>}
      restore.go(~A, ~X, ~enc, ~dec, ~round, rest, R.step(~A, s, op))

def Laws.replay_snapshot(A, X, enc, dec, round, ops, s, more, t):
  %Equal.sym(Maybe<&2, R.Rec<A>>, dec(enc(R.Snap{Laws.live(~A, ops, s)})), Some{R.Snap{Laws.live(~A, ops, s)}}, round(R.Snap{Laws.live(~A, ops, s)})) : {Laws.restore.from(~A, ~X, ~dec, Laws.encode.ops(~A, ~X, ~enc, more), R.load.rec(~A, _, t)) == Some{Laws.live(~A, more, Laws.live(~A, ops, s))} : Maybe<&2, R.State<A>>}
  restore.go(~A, ~X, ~enc, ~dec, ~round, more, Laws.live(~A, ops, s))

# ---- retry

def Laws.requeue_wait(A, o, p, b, id, n, now, r, w, e):
  %Equal.sym(Retry.Plan, Retry.plan(o, p, b, n, now, r), Retry.PlanWait{w}, e) : {R.after.plan(A, _, o, b, id, now) == R.Requeue{id, Nat.add(now, w)} : R.Op<A>}
  {==}

def Laws.settled_complete(A, p, b, id, n, now, r):
  {==}

def Laws.unsafe_abandon(A, p, b, id, n, now, r):
  {==}

def Laws.failed_abandon(A, p, b, id, n, now, r):
  {==}

def Laws.rejected_abandon(A, p, b, id, n, now, r):
  {==}

def Laws.rejected_spares_breaker(c, s, now):
  {==}

def Laws.rejected_keeps_closed(c, fs, now):
  {==}

def Laws.transient_abandon(A, a, p, b, id, n, now, r, e):
  %Equal.sym(Retry.Plan, Retry.plan(Retry.Transient{a}, p, b, n, now, r), Retry.PlanStop{}, e) : {R.after.plan(A, _, Retry.Transient{a}, b, id, now) == R.Abandon{id, R.gave(b), now} : R.Op<A>}
  {==}

# ---- pool

# Every pick is Idle with the pool unchanged, or the reserve of one unit for a selected ticket.
def pick_cases(~A: Data, -P: R.Pick<A> -> Type, +p: Res.Pool, s: R.State<A>, +now: Nat, idle: P(R.Idle{p}),
    took: @t: Q.Ticket<A> -> P(R.pick.took(A, Res.reserve(p, 1n), t))) -> P(R.pick(~A, p, s, now)):
  match s:
    case R.State{Q.State{i, H.HLeaf{}, r}, ts, ds, bs}:
      idle
    case R.State{Q.State{i, H.HNode{n, +t, l, q}, r}, ts, ds, bs}:
      split(b => P(R.pick.sel(A, Q.select.due(~A, b, i, H.HNode{n, t, l, q}, r, t, l, q), p)), Nat.is_le(Q.deadline(A, t), now),
        e => took(t),
        e => idle)

def took.holds(-A: Data, +o: Nat, +c: Nat, +h: Nat, +t: Q.Ticket<A>) ->
    {Res.reserved(Laws.pick.pool(A, R.pick.took(A, Res.reserve(Res.Pool{o, c, h}, 1n), t))) == Laws.pick.held(A, R.pick.took(A, Res.reserve(Res.Pool{o, c, h}, 1n), t), h) : Nat}:
  split(b => {Res.reserved(Laws.pick.pool(A, R.pick.took(A, Res.reserve.go(b, o, c, h, 1n), t))) == Laws.pick.held(A, R.pick.took(A, Res.reserve.go(b, o, c, h, 1n), t), h) : Nat},
    Nat.is_le(Nat.add(h, 1n), c),
    e => {==},
    e => {==})

def Laws.pick_holds_one(A, o, c, h, s, now):
  +o = o
  +c = c
  pick_cases(~A, k => {Res.reserved(Laws.pick.pool(A, k)) == Laws.pick.held(A, k, h) : Nat}, Res.Pool{o, c, h}, s, now, {==}, t => took.holds(A, o, c, h, t))

def took.bounded(-A: Data, +o: Nat, +c: Nat, +h: Nat, e: MNat.le(h, c), +t: Q.Ticket<A>) ->
    MNat.le(Res.reserved(Laws.pick.pool(A, R.pick.took(A, Res.reserve(Res.Pool{o, c, h}, 1n), t))), c):
  split(b => MNat.le(Res.reserved(Laws.pick.pool(A, R.pick.took(A, Res.reserve.go(b, o, c, h, 1n), t))), c),
    Nat.is_le(Nat.add(h, 1n), c),
    f => f,
    f => e)

def Laws.pick_bounded(A, o, c, h, e, s, now):
  +o = o
  +c = c
  +h = h
  +now = now
  +e = e
  pick_cases(~A, k => MNat.le(Res.reserved(Laws.pick.pool(A, k)), c), Res.Pool{o, c, h}, s, now, e, t => took.bounded(A, o, c, h, e, t))

def zero_le(h: Nat) -> {Nat.is_le(0n, h) == True{} : Bool}:
  match h:
    case 0n:
      {==}
    case 1n+p:
      {==}

def took.release.go(+o: Nat, +c: Nat, +h: Nat) -> {Laws.release.pool(Res.release(Res.Pool{o, c, Nat.add(h, 1n)}, Res.Grant{o, 1n})) == Res.Pool{o, c, h} : Res.Pool}:
  %MNat.add_comm(1n, h) : {Laws.release.pool(Res.release(Res.Pool{o, c, _}, Res.Grant{o, 1n})) == Res.Pool{o, c, h} : Res.Pool}
  %Equal.sym(Bool, Nat.is_eq(o, o), True{}, MNat.is_eq_refl(o)) : {Laws.release.pool(Res.release.go(Bool.and(_, Nat.is_le(1n, 1n+h)), o, c, 1n+h, o, 1n)) == Res.Pool{o, c, h} : Res.Pool}
  %Equal.sym(Bool, Nat.is_le(0n, h), True{}, zero_le(h)) : {Laws.release.pool(Res.release.go(_, o, c, 1n+h, o, 1n)) == Res.Pool{o, c, h} : Res.Pool}
  %Equal.sym(Nat, Nat.sub(h, 0n), h, MNat.sub_zero(h)) : {Res.Pool{o, c, _} == Res.Pool{o, c, h} : Res.Pool}
  {==}

def took.release(-A: Data, +o: Nat, +c: Nat, +h: Nat, +t: Q.Ticket<A>) ->
    {Laws.pick.round(A, R.pick.took(A, Res.reserve(Res.Pool{o, c, h}, 1n), t)) == Res.Pool{o, c, h} : Res.Pool}:
  split(b => {Laws.pick.round(A, R.pick.took(A, Res.reserve.go(b, o, c, h, 1n), t)) == Res.Pool{o, c, h} : Res.Pool},
    Nat.is_le(Nat.add(h, 1n), c),
    f => took.release.go(o, c, h),
    f => {==})

def Laws.pick_release(A, o, c, h, s, now):
  +o = o
  +c = c
  +h = h
  +now = now
  pick_cases(~A, k => {Laws.pick.round(A, k) == Res.Pool{o, c, h} : Res.Pool}, Res.Pool{o, c, h}, s, now, {==}, t => took.release(A, o, c, h, t))

# ---- a finished ticket is never selected again

# Ticket i is not dead in ds, and ds is a well-formed trie.
def absent.dead(~A: Data, +i: Nat, ds: R.Graves(A)) -> Data:
  QL.Both<{R.dead.get(~A, ds, i) == None{} : Maybe<&2, R.Dead<A>>}, {Laws.dead.wf(~A, ds) == True{} : Bool}>

def anything(-A: Data, ds: R.Graves(A)) -> Data:
  Unit

# s will issue no id i again, ticket i is neither pending nor running, and P holds of the dead tickets.
def inv(-A: Data, +i: Nat, -P: R.Graves(A) -> Data, s: R.State<A>) -> Data:
  match s:
    case R.State{Q.State{n, h, r}, ts, ds, bs}:
      QL.Both<MNat.lt(i, n), QL.Both<QL.absent.heap(A, h, i), QL.Both<QL.absent.list(A, r, i), P(ds)>>>

# Ticket i is in no registry of s, and s will issue no id i again.
def gone(~A: Data, +i: Nat, s: R.State<A>) -> Data:
  inv(A, i, ds => absent.dead(~A, i, ds), s)

def lt_ne(i: Nat, n: Nat, e: MNat.lt(i, n)) -> {Nat.is_eq(n, i) == False{} : Bool}:
  match i n:
    case 0n 0n:
      Empty.absurd({Nat.is_eq(0n, 0n) == False{} : Bool}, MNat.lt_irrefl(0n, e))
    case 0n 1n+m:
      {==}
    case 1n+p 0n:
      {==}
    case 1n+p 1n+m:
      lt_ne(p, m, e)

# Removing ticket j keeps ticket i absent.
def remove_keeps.list(-A: Data, +xs: List<&2, Q.Ticket<A>>, +j: Nat, +i: Nat, +e: QL.absent.list(A, xs, i)) -> QL.absent.list(A, Q.remove.list(A, xs, j), i):
  match xs:
    case Nil{}:
      Unit{}
    case Con{t, rest}:
      QL.Both{et, er} = e
      +r2 = Q.remove.list(A, rest, j)
      +er2 = remove_keeps.list(A, rest, j, i, er)
      split(c => QL.absent.list(A, Q.remove.list.keep(A, c, t, r2), i), Nat.is_eq(Q.id(A, t), j),
        f => er2,
        f => QL.Both{et, er2})

def found.absent(-A: Data, m: Maybe<&2, Q.Ticket<A>>, +i: Nat) -> Data:
  match m:
    case None{}:
      Unit
    case Some{t}:
      QL.absent.ticket(A, i, t)

def taken.ok(-A: Data, tk: Q.Taken<A>, +i: Nat) -> Data:
  match tk:
    case Q.Taken{rest, found}:
      QL.Both<QL.absent.list(A, rest, i), found.absent(A, found, i)>

def keep_ok(-A: Data, b: Bool, t: Q.Ticket<A>, tk: Q.Taken<A>, +i: Nat, +et: QL.absent.ticket(A, i, t), etk: taken.ok(A, tk, i)) -> taken.ok(A, Q.take.keep(A, b, t, tk), i):
  match b tk:
    case True{} Q.Taken{rest, found}:
      QL.Both{erest, ef} = etk
      QL.Both{erest, et}
    case False{} Q.Taken{rest, found}:
      QL.Both{erest, ef} = etk
      QL.Both{QL.Both{et, erest}, ef}

# Taking ticket j from a list without ticket i leaves no i, and takes no i.
def take_ok(-A: Data, +xs: List<&2, Q.Ticket<A>>, +j: Nat, +i: Nat, e: QL.absent.list(A, xs, i)) -> taken.ok(A, Q.take.list(A, xs, j), i):
  match xs:
    case Nil{}:
      QL.Both{Unit{}, Unit{}}
    case Con{t, rest}:
      QL.Both{et, er} = e
      keep_ok(A, Nat.is_eq(Q.id(A, t), j), t, Q.take.list(A, rest, j), i, et, take_ok(A, rest, j, i, er))

def taken.rem_ok(-A: Data, tk: Q.Taken<A>, +i: Nat) -> Data:
  match tk:
    case Q.Taken{rest, found}:
      QL.absent.list(A, rest, i)

def ok_rem(-A: Data, tk: Q.Taken<A>, +i: Nat, etk: taken.ok(A, tk, i)) -> taken.rem_ok(A, tk, i):
  match tk:
    case Q.Taken{rest, found}:
      QL.Both{erest, ef} = etk
      erest

def keep_absent(-A: Data, b: Bool, t: Q.Ticket<A>, tk: Q.Taken<A>, +i: Nat, et: {b == False{} : Bool} -> QL.absent.ticket(A, i, t), erest: taken.rem_ok(A, tk, i)) ->
    taken.rem_ok(A, Q.take.keep(A, b, t, tk), i):
  match b tk:
    case True{} Q.Taken{rest, found}:
      erest
    case False{} Q.Taken{rest, found}:
      QL.Both{et({==}), erest}

# Taking ticket i leaves no i in the list.
def take_absent(-A: Data, +xs: List<&2, Q.Ticket<A>>, +i: Nat) -> taken.rem_ok(A, Q.take.list(A, xs, i), i):
  match xs:
    case Nil{}:
      Unit{}
    case Con{t, rest}:
      keep_absent(A, Nat.is_eq(Q.id(A, t), i), t, Q.take.list(A, rest, i), i, f => f, take_absent(A, rest, i))

def complete_inv(~A: Data, +i: Nat, -P: R.Graves(A) -> Data, tk: Q.Taken<A>, +n: Nat, +h: H.Heap<Q.Ticket<A>>, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(),
    lt: MNat.lt(i, n), eh: QL.absent.heap(A, h, i), erem: taken.rem_ok(A, tk, i), ed: P(ds)) ->
    inv(A, i, P, R.step.completed(A, Q.complete.taken(A, tk, n, h), ts, ds, bs)):
  match tk:
    case Q.Taken{rest, found}:
      QL.Both{lt, QL.Both{eh, QL.Both{erem, ed}}}

def found.of(-A: Data, tk: Q.Taken<A>) -> Maybe<&2, Q.Ticket<A>>:
  match tk:
    case Q.Taken{rest, found}:
      found

def abandon_inv(~A: Data, +i: Nat, -P: R.Graves(A) -> Data, tk: Q.Taken<A>, +n: Nat, +h: H.Heap<Q.Ticket<A>>, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(), w: R.Why, +at: Nat,
    lt: MNat.lt(i, n), eh: QL.absent.heap(A, h, i), erem: taken.rem_ok(A, tk, i), ed: P(R.dead.bury(~A, found.of(A, tk), ds, w, at))) ->
    inv(A, i, P, R.step.abandoned(~A, Q.complete.taken(A, tk, n, h), ts, ds, bs, w, at)):
  match tk:
    case Q.Taken{rest, found}:
      QL.Both{lt, QL.Both{eh, QL.Both{erem, ed}}}

def requeue_inv(~A: Data, +i: Nat, -P: R.Graves(A) -> Data, tk: Q.Taken<A>, +n: Nat, +h: H.Heap<Q.Ticket<A>>, +d: Nat, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(),
    lt: MNat.lt(i, n), eh: QL.absent.heap(A, h, i), etk: taken.ok(A, tk, i), ed: P(ds)) ->
    inv(A, i, P, R.step.requeued(A, Q.requeue.completed(~A, Q.complete.taken(A, tk, n, h), d), ts, ds, bs)):
  match tk:
    case Q.Taken{rest, None{}}:
      QL.Both{erest, ef} = etk
      QL.Both{lt, QL.Both{eh, QL.Both{erest, ed}}}
    case Q.Taken{rest, Some{Q.Ticket{j, old, x}}}:
      QL.Both{erest, ej} = etk
      QL.Both{lt, QL.Both{QP.merge_all.full(~A, QL.absent.ticket(A, i), H.HNode{1n, Q.Ticket{j, d, x}, H.HLeaf{}, H.HLeaf{}}, h, QL.Both{ej, QL.Both{Unit{}, Unit{}}}, eh), QL.Both{erest, ed}}}

def select_inv(~A: Data, +i: Nat, -P: R.Graves(A) -> Data, +now: Nat, +n: Nat, h: H.Heap<Q.Ticket<A>>, r: List<&2, Q.Ticket<A>>, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(),
    +lt: MNat.lt(i, n), +eh: QL.absent.heap(A, h, i), +er: QL.absent.list(A, r, i), +ed: P(ds)) ->
    inv(A, i, P, R.step.selected(A, Q.select(~A, now, Q.State{n, h, r}), ts, ds, bs)):
  match h:
    case H.HLeaf{}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}}
    case H.HNode{size, +t, +l, +q}:
      QL.Both{+et, QL.Both{+el, +eq}} = eh
      split(c => inv(A, i, P, R.step.selected(A, Q.select.due(~A, c, n, H.HNode{size, t, l, q}, r, t, l, q), ts, ds, bs)), Nat.is_le(Q.deadline(A, t), now),
        e => QL.Both{lt, QL.Both{QP.merge_all.full(~A, QL.absent.ticket(A, i), l, q, el, eq), QL.Both{QL.Both{et, er}, ed}}},
        e => QL.Both{lt, QL.Both{QL.Both{et, QL.Both{el, eq}}, QL.Both{er, ed}}})

# A Revive of j that finds a dead ticket pushes ticket j; it must not be i.
def revive.ok(-A: Data, m: Maybe<&2, R.Dead<A>>, +j: Nat, +i: Nat) -> Data:
  match m:
    case None{}:
      Unit
    case Some{x}:
      {Nat.is_eq(j, i) == False{} : Bool}

def revive_inv(~A: Data, +i: Nat, -P: R.Graves(A) -> Data, m: Maybe<&2, R.Dead<A>>, +j: Nat, +n: Nat, +h: H.Heap<Q.Ticket<A>>, r: List<&2, Q.Ticket<A>>, ts: R.Tries(),
    +rest: R.Graves(A), bs: R.Breakers(), +d: Nat, lt: MNat.lt(i, n), eh: QL.absent.heap(A, h, i), er: QL.absent.list(A, r, i), em: revive.ok(A, m, j, i), ed: P(rest), dropped: P(R.dead.drop(~A, rest, j))) ->
    inv(A, i, P, R.step.revived(~A, m, j, n, h, r, ts, rest, bs, d)):
  match m:
    case None{}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}}
    case Some{R.Dead{Q.Ticket{k, old, x}, w, at}}:
      QL.Both{lt, QL.Both{QP.merge_all.full(~A, QL.absent.ticket(A, i), H.HNode{1n, Q.Ticket{j, d, x}, H.HLeaf{}, H.HLeaf{}}, h, QL.Both{em, QL.Both{Unit{}, Unit{}}}, eh), QL.Both{er, dropped}}}

# ---- dead tickets

def P.gone(~A: Data, +i: Nat) -> (R.Graves(A) -> Data):
  ds => absent.dead(~A, i, ds)

def is_eq_of(+a: Nat, -b: Nat, e: {a == b : Nat}) -> {Nat.is_eq(a, b) == True{} : Bool}:
  %e : {Nat.is_eq(a, _) == True{} : Bool}
  MNat.is_eq_refl(a)

def ne_of(+a: Nat, +b: Nat, f: {Nat.is_eq(a, b) == False{} : Bool}) -> {a != b : Nat}:
  e => MBool.false_ne_true(Equal.trans(Bool, False{}, Nat.is_eq(a, b), True{}, Equal.sym(Bool, Nat.is_eq(a, b), False{}, f), is_eq_of(a, b, e)))

def get_drop_same(~A: Data, +ds: R.Graves(A), +j: Nat, +i: Nat, e: {Nat.is_eq(j, i) == True{} : Bool}, wf: {Laws.dead.wf(~A, ds) == True{} : Bool}) ->
    {R.dead.get(~A, R.dead.drop(~A, ds, j), i) == None{} : Maybe<&2, R.Dead<A>>}:
  %Equal.sym(Nat, j, i, MNat.eq_of_is_eq(j, i, e)) : {R.dead.get(~A, R.dead.drop(~A, ds, _), i) == None{} : Maybe<&2, R.Dead<A>>}
  CL.hmap_get_del_same(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ~MNat.eq_of_is_eq, ds, wf, i)

def get_drop_other(~A: Data, +ds: R.Graves(A), +j: Nat, +i: Nat, f: {Nat.is_eq(j, i) == False{} : Bool}, eg: {R.dead.get(~A, ds, i) == None{} : Maybe<&2, R.Dead<A>>}) ->
    {R.dead.get(~A, R.dead.drop(~A, ds, j), i) == None{} : Maybe<&2, R.Dead<A>>}:
  Equal.trans(Maybe<&2, R.Dead<A>>, R.dead.get(~A, R.dead.drop(~A, ds, j), i), R.dead.get(~A, ds, i), None{},
    CL.hmap_get_del_other_key(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ~MNat.eq_of_is_eq, ds, j, i, ne_of(j, i, f)), eg)

# Dropping any ticket keeps ticket i not dead and the trie well formed.
def drop_keeps(~A: Data, +ds: R.Graves(A), +j: Nat, +i: Nat, g: absent.dead(~A, i, ds)) -> absent.dead(~A, i, R.dead.drop(~A, ds, j)):
  QL.Both{+eg, +wf} = g
  QL.Both{split(b => {R.dead.get(~A, R.dead.drop(~A, ds, j), i) == None{} : Maybe<&2, R.Dead<A>>}, Nat.is_eq(j, i),
      e => get_drop_same(~A, ds, j, i, e, wf),
      f => get_drop_other(~A, ds, j, i, f, eg)),
    CL.hmap_del_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ds, wf, j)}

# Dropping ticket i leaves it not dead.
def drop_self(~A: Data, +ds: R.Graves(A), +i: Nat, +wf: {Laws.dead.wf(~A, ds) == True{} : Bool}) -> absent.dead(~A, i, R.dead.drop(~A, ds, i)):
  QL.Both{CL.hmap_get_del_same(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ~MNat.eq_of_is_eq, ds, wf, i),
    CL.hmap_del_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ds, wf, i)}

def drops_keeps(~A: Data, ks: List<&2, Nat>, +ds: R.Graves(A), +i: Nat, g: absent.dead(~A, i, ds)) -> absent.dead(~A, i, R.dead.drops(~A, ks, ds)):
  match ks:
    case Nil{}:
      g
    case Con{+k, rest}:
      drops_keeps(~A, rest, R.dead.drop(~A, ds, k), i, drop_keeps(~A, ds, k, i, g))

def purge_keeps(~A: Data, +ds: R.Graves(A), +t: Nat, +i: Nat, g: absent.dead(~A, i, ds)) -> absent.dead(~A, i, R.dead.purge(~A, ds, t)):
  drops_keeps(~A, R.dead.old(A, R.dead.list(A, ds), t), ds, i, g)

# Burying a ticket other than i keeps ticket i not dead.
def bury_keeps(~A: Data, m: Maybe<&2, Q.Ticket<A>>, +ds: R.Graves(A), +w: R.Why, +at: Nat, +i: Nat, ef: found.absent(A, m, i), g: absent.dead(~A, i, ds)) ->
    absent.dead(~A, i, R.dead.bury(~A, m, ds, w, at)):
  match m:
    case None{}:
      g
    case Some{Q.Ticket{+k, +d, +x}}:
      QL.Both{+eg, +wf} = g
      QL.Both{Equal.trans(Maybe<&2, R.Dead<A>>, R.dead.get(~A, R.dead.bury(~A, Some{Q.Ticket{k, d, x}}, ds, w, at), i), R.dead.get(~A, ds, i), None{},
          CL.hmap_get_put_other_key(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ~MNat.eq_of_is_eq, ds, wf, k, i, ne_of(k, i, ef), R.Dead{Q.Ticket{k, d, x}, w, at}), eg),
        CL.hmap_put_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ~MNat.is_eq_refl, ~MNat.eq_of_is_eq, ds, wf, k, R.Dead{Q.Ticket{k, d, x}, w, at})}

def bury_absent(~A: Data, tk: Q.Taken<A>, +ds: R.Graves(A), +w: R.Why, +at: Nat, +i: Nat, etk: taken.ok(A, tk, i), g: absent.dead(~A, i, ds)) ->
    absent.dead(~A, i, R.dead.bury(~A, found.of(A, tk), ds, w, at)):
  match tk:
    case Q.Taken{rest, found}:
      QL.Both{erest, ef} = etk
      bury_keeps(~A, found, ds, w, at, i, ef, g)

def any_ok(-A: Data, m: Maybe<&2, R.Dead<A>>, +j: Nat, +i: Nat, f: {Nat.is_eq(j, i) == False{} : Bool}) -> revive.ok(A, m, j, i):
  match m:
    case None{}:
      Unit{}
    case Some{x}:
      f

def same_ok(~A: Data, +ds: R.Graves(A), +j: Nat, +i: Nat, e: {Nat.is_eq(j, i) == True{} : Bool}, eg: {R.dead.get(~A, ds, i) == None{} : Maybe<&2, R.Dead<A>>}) ->
    revive.ok(A, R.dead.get(~A, ds, j), j, i):
  %Equal.sym(Nat, j, i, MNat.eq_of_is_eq(j, i, e)) : revive.ok(A, R.dead.get(~A, ds, _), j, i)
  %Equal.sym(Maybe<&2, R.Dead<A>>, R.dead.get(~A, ds, i), None{}, eg) : revive.ok(A, _, j, i)
  Unit{}

# A Revive of j, when ticket i is not dead, pushes no ticket i.
def revive_ok(~A: Data, +ds: R.Graves(A), +j: Nat, +i: Nat, +eg: {R.dead.get(~A, ds, i) == None{} : Maybe<&2, R.Dead<A>>}) -> revive.ok(A, R.dead.get(~A, ds, j), j, i):
  split(b => revive.ok(A, R.dead.get(~A, ds, j), j, i), Nat.is_eq(j, i),
    e => same_ok(~A, ds, j, i, e, eg),
    f => any_ok(A, R.dead.get(~A, ds, j), j, i, f))

# ---- every op keeps a gone ticket gone

def step_gone(~A: Data, +i: Nat, s: R.State<A>, op: R.Op<A>, g: gone(~A, i, s)) -> gone(~A, i, R.step(~A, s, op)):
  match s op:
    case R.State{Q.State{+n, h, r}, ts, ds, bs} R.Enqueue{d, x}:
      QL.Both{+lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{MNat.lt_trans(i, n, 1n+n, lt, MNat.lt_succ_self(n)), QL.Both{QP.merge_all.full(~A, QL.absent.ticket(A, i), H.HNode{1n, Q.Ticket{n, d, x}, H.HLeaf{}, H.HLeaf{}}, h, QL.Both{lt_ne(i, n, lt), QL.Both{Unit{}, Unit{}}}, eh), QL.Both{er, ed}}}
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.Select{now}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      select_inv(~A, i, P.gone(~A, i), now, n, h, r, ts, ds, bs, lt, eh, er, ed)
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Complete{+j}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      complete_inv(~A, i, P.gone(~A, i), Q.take.list(A, r, j), n, h, R.tries.drop(ts, j), ds, bs, lt, eh, ok_rem(A, Q.take.list(A, r, j), i, take_ok(A, r, j, i, er)), ed)
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Cancel{+j}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{lt, QL.Both{QP.remove_all(~A, QL.absent.ticket(A, i), h, j, eh), QL.Both{remove_keeps.list(A, r, j, i, er), drop_keeps(~A, ds, j, i, ed)}}}
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Requeue{+j, d}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      requeue_inv(~A, i, P.gone(~A, i), Q.take.list(A, r, j), n, h, d, R.tries.bump(ts, j), ds, bs, lt, eh, take_ok(A, r, j, i, er), ed)
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Defer{+j, d}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      requeue_inv(~A, i, P.gone(~A, i), Q.take.list(A, r, j), n, h, d, ts, ds, bs, lt, eh, take_ok(A, r, j, i, er), ed)
    case R.State{Q.State{n, h, +r}, ts, +ds, bs} R.Abandon{+j, +w, +at}:
      QL.Both{lt, QL.Both{eh, QL.Both{+er, ed}}} = g
      abandon_inv(~A, i, P.gone(~A, i), Q.take.list(A, r, j), n, h, R.tries.drop(ts, j), ds, bs, w, at, lt, eh, ok_rem(A, Q.take.list(A, r, j), i, take_ok(A, r, j, i, er)),
        bury_absent(~A, Q.take.list(A, r, j), ds, w, at, i, take_ok(A, r, j, i, er), ed))
    case R.State{Q.State{n, h, r}, ts, +ds, bs} R.Revive{+j, d}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{+eg, +wf} = ed
      revive_inv(~A, i, P.gone(~A, i), R.dead.get(~A, ds, j), j, n, h, r, ts, ds, bs, d, lt, eh, er, revive_ok(~A, ds, j, i, eg), QL.Both{eg, wf}, drop_keeps(~A, ds, j, i, QL.Both{eg, wf}))
    case R.State{Q.State{n, h, r}, ts, +ds, bs} R.Purge{+t}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{lt, QL.Both{eh, QL.Both{er, purge_keeps(~A, ds, t, i, ed)}}}
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.PurgeAll{}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{lt, QL.Both{eh, QL.Both{er, QL.Both{{==}, {==}}}}}
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.Break{k, b}:
      g

def live_gone(~A: Data, +i: Nat, ops: List<&2, R.Op<A>>, +s: R.State<A>, g: gone(~A, i, s)) -> gone(~A, i, Laws.live(~A, ops, s)):
  match ops:
    case Nil{}:
      g
    case Con{op, rest}:
      +op = op
      live_gone(~A, i, rest, R.step(~A, s, op), step_gone(~A, i, s, op, g))

# Every op but a Revive of i keeps ticket i out of the queue, whether or not it is dead.
def step_buried(~A: Data, +i: Nat, s: R.State<A>, op: R.Op<A>, g: inv(A, i, anything(A), s), no: {Laws.revived(A, op, i) == False{} : Bool}) ->
    inv(A, i, anything(A), R.step(~A, s, op)):
  match s op:
    case R.State{Q.State{+n, h, r}, ts, ds, bs} R.Enqueue{d, x}:
      QL.Both{+lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{MNat.lt_trans(i, n, 1n+n, lt, MNat.lt_succ_self(n)), QL.Both{QP.merge_all.full(~A, QL.absent.ticket(A, i), H.HNode{1n, Q.Ticket{n, d, x}, H.HLeaf{}, H.HLeaf{}}, h, QL.Both{lt_ne(i, n, lt), QL.Both{Unit{}, Unit{}}}, eh), QL.Both{er, Unit{}}}}
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.Select{now}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      select_inv(~A, i, anything(A), now, n, h, r, ts, ds, bs, lt, eh, er, Unit{})
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Complete{+j}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      complete_inv(~A, i, anything(A), Q.take.list(A, r, j), n, h, R.tries.drop(ts, j), ds, bs, lt, eh, ok_rem(A, Q.take.list(A, r, j), i, take_ok(A, r, j, i, er)), Unit{})
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Cancel{+j}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{lt, QL.Both{QP.remove_all(~A, QL.absent.ticket(A, i), h, j, eh), QL.Both{remove_keeps.list(A, r, j, i, er), Unit{}}}}
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Requeue{+j, d}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      requeue_inv(~A, i, anything(A), Q.take.list(A, r, j), n, h, d, R.tries.bump(ts, j), ds, bs, lt, eh, take_ok(A, r, j, i, er), Unit{})
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Defer{+j, d}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      requeue_inv(~A, i, anything(A), Q.take.list(A, r, j), n, h, d, ts, ds, bs, lt, eh, take_ok(A, r, j, i, er), Unit{})
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Abandon{+j, w, at}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      abandon_inv(~A, i, anything(A), Q.take.list(A, r, j), n, h, R.tries.drop(ts, j), ds, bs, w, at, lt, eh, ok_rem(A, Q.take.list(A, r, j), i, take_ok(A, r, j, i, er)), Unit{})
    case R.State{Q.State{n, h, r}, ts, +ds, bs} R.Revive{+j, d}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      revive_inv(~A, i, anything(A), R.dead.get(~A, ds, j), j, n, h, r, ts, ds, bs, d, lt, eh, er, any_ok(A, R.dead.get(~A, ds, j), j, i, no), Unit{}, Unit{})
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.Purge{t}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{lt, QL.Both{eh, QL.Both{er, Unit{}}}}
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.PurgeAll{}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{lt, QL.Both{eh, QL.Both{er, Unit{}}}}
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.Break{k, b}:
      g

def or_false_left(a: Bool, b: Bool, e: {Bool.or(a, b) == False{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, MBool.false_ne_true(Equal.sym(Bool, True{}, False{}, e)))
    case False{}:
      {==}

def or_false_right(a: Bool, b: Bool, e: {Bool.or(a, b) == False{} : Bool}) -> {b == False{} : Bool}:
  match a:
    case True{}:
      Empty.absurd({b == False{} : Bool}, MBool.false_ne_true(Equal.sym(Bool, True{}, False{}, e)))
    case False{}:
      e

def live_buried(~A: Data, +i: Nat, ops: List<&2, R.Op<A>>, +s: R.State<A>, g: inv(A, i, anything(A), s), +kept: {Laws.revives(A, ops, i) == False{} : Bool}) ->
    inv(A, i, anything(A), Laws.live(~A, ops, s)):
  match ops:
    case Nil{}:
      g
    case Con{op, +rest}:
      +op = op
      live_buried(~A, i, rest, R.step(~A, s, op), step_buried(~A, i, s, op, g, or_false_left(Laws.revived(A, op, i), Laws.revives(A, rest, i), kept)),
        or_false_right(Laws.revived(A, op, i), Laws.revives(A, rest, i), kept))

def absent_of_has(-A: Data, h: H.Heap<Q.Ticket<A>>, +i: Nat, +e: {Laws.has(A, h, i) == False{} : Bool}) -> QL.absent.heap(A, h, i):
  match h:
    case H.HLeaf{}:
      Unit{}
    case H.HNode{n, +t, +l, +r}:
      +rest = or_false_right(Nat.is_eq(Q.id(A, t), i), Bool.or(Laws.has(A, l, i), Laws.has(A, r, i)), e)
      QL.Both{or_false_left(Nat.is_eq(Q.id(A, t), i), Bool.or(Laws.has(A, l, i), Laws.has(A, r, i)), e),
        QL.Both{absent_of_has(A, l, i, or_false_left(Laws.has(A, l, i), Laws.has(A, r, i), rest)), absent_of_has(A, r, i, or_false_right(Laws.has(A, l, i), Laws.has(A, r, i), rest))}}

def finish_gone(~A: Data, +i: Nat, s: R.State<A>, fresh: MNat.lt(i, Q.next_id(A, R.queue(A, s))), idle: {Laws.has(A, Q.pending(A, R.queue(A, s)), i) == False{} : Bool},
    alive: {R.dead.get(~A, R.dead(A, s), i) == None{} : Maybe<&2, R.Dead<A>>}, wf: {Laws.dead.wf(~A, R.dead(A, s)) == True{} : Bool}) -> gone(~A, i, R.step(~A, s, R.Complete{i})):
  match s:
    case R.State{Q.State{n, +h, +r}, ts, ds, bs}:
      complete_inv(~A, i, P.gone(~A, i), Q.take.list(A, r, i), n, h, R.tries.drop(ts, i), ds, bs, fresh, absent_of_has(A, h, i, idle), take_absent(A, r, i), QL.Both{alive, wf})

def cancel_gone(~A: Data, +i: Nat, s: R.State<A>, fresh: MNat.lt(i, Q.next_id(A, R.queue(A, s))), wf: {Laws.dead.wf(~A, R.dead(A, s)) == True{} : Bool}) ->
    gone(~A, i, R.step(~A, s, R.Cancel{i})):
  match s:
    case R.State{Q.State{n, +h, +r}, ts, +ds, bs}:
      QL.Both{fresh, QL.Both{QP.remove_absent.heap(~A, h, i), QL.Both{QP.remove_absent.list(A, r, i), drop_self(~A, ds, i, wf)}}}

def abandon_buried(~A: Data, +i: Nat, s: R.State<A>, w: R.Why, +at: Nat, fresh: MNat.lt(i, Q.next_id(A, R.queue(A, s))), idle: {Laws.has(A, Q.pending(A, R.queue(A, s)), i) == False{} : Bool}) ->
    inv(A, i, anything(A), R.step(~A, s, R.Abandon{i, w, at})):
  match s:
    case R.State{Q.State{n, +h, +r}, ts, ds, bs}:
      abandon_inv(~A, i, anything(A), Q.take.list(A, r, i), n, h, R.tries.drop(ts, i), ds, bs, w, at, fresh, absent_of_has(A, h, i, idle), take_absent(A, r, i), Unit{})

def selected_same(-A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>) -> {QL.selected(A, r) == Laws.selected(A, r) : Maybe<&2, Q.Ticket<A>>}:
  match r:
    case (q, t):
      {==}

# A Select from a state where i is neither pending nor running never takes i.
def never(~A: Data, +now: Nat, +i: Nat, -P: R.Graves(A) -> Data, s: R.State<A>, g: inv(A, i, P, s), t: Q.Ticket<A>, e: {Laws.next(~A, now, s) == Some{t} : Maybe<&2, Q.Ticket<A>>}) ->
    {Nat.is_eq(Q.id(A, t), i) == False{} : Bool}:
  match s:
    case R.State{Q.State{+n, +h, +r}, ts, ds, bs}:
      QL.Both{lt, QL.Both{eh, rest}} = g
      %e : QP.selected_absent(A, i, _)
      %selected_same(A, Q.select(~A, now, Q.State{n, h, r})) : QP.selected_absent(A, i, _)
      QP.select_selected_absent(~A, now, i, Q.State{n, h, r}, eh)

def Laws.complete_never_selected(A, i, s, fresh, idle, alive, wf, ops, now, t, e):
  +s = s
  +ops = ops
  never(~A, now, i, P.gone(~A, i), Laws.live(~A, ops, R.step(~A, s, R.Complete{i})), live_gone(~A, i, ops, R.step(~A, s, R.Complete{i}), finish_gone(~A, i, s, fresh, idle, alive, wf)), t, e)

def Laws.cancel_never_selected(A, i, s, fresh, wf, ops, now, t, e):
  +s = s
  +ops = ops
  never(~A, now, i, P.gone(~A, i), Laws.live(~A, ops, R.step(~A, s, R.Cancel{i})), live_gone(~A, i, ops, R.step(~A, s, R.Cancel{i}), cancel_gone(~A, i, s, fresh, wf)), t, e)

def Laws.dead_never_selected(A, i, s, fresh, idle, w, at, ops, kept, now, t, e):
  +s = s
  +w = w
  +at = at
  +ops = ops
  never(~A, now, i, anything(A), Laws.live(~A, ops, R.step(~A, s, R.Abandon{i, w, at})), live_buried(~A, i, ops, R.step(~A, s, R.Abandon{i, w, at}), abandon_buried(~A, i, s, w, at, fresh, idle), kept), t, e)

def unsome(-T: Data, d: T, m: Maybe<&2, T>) -> T:
  match m:
    case None{}:
      d
    case Some{x}:
      x

def some_inj(-T: Data, +a: T, b: T, e: {Some{a} == Some{b} : Maybe<&2, T>}) -> {a == b : T}:
  %e : {a == unsome(T, a, _) : T}
  {==}

def moved(~A: Data, +i: Nat, x: R.State<A>, y: R.State<A>, q: {x == y : R.State<A>}, g: gone(~A, i, x)) -> gone(~A, i, y):
  %q : gone(~A, i, _)
  g

def Laws.recovered_never_selected(A, X, enc, dec, round, i, s, fresh, idle, alive, wf, ops, r, back, now, t, e):
  +r = r
  +s1 = R.step(~A, s, R.Complete{i})
  +q = some_inj(R.State<A>, Laws.live(~A, ops, s1), r,
    Equal.trans(Maybe<&2, R.State<A>>, Some{Laws.live(~A, ops, s1)}, Laws.replayed(~A, ~X, ~enc, ~dec, ops, s1), Some{r},
      Equal.sym(Maybe<&2, R.State<A>>, Laws.replayed(~A, ~X, ~enc, ~dec, ops, s1), Some{Laws.live(~A, ops, s1)}, replay.go(~A, ~X, ~enc, ~dec, ~round, ops, s1)), back))
  never(~A, now, i, P.gone(~A, i), r, moved(~A, i, Laws.live(~A, ops, s1), r, q, live_gone(~A, i, ops, s1, finish_gone(~A, i, s, fresh, idle, alive, wf))), t, e)

# ---- every op keeps the dead-ticket trie well formed

def WF(~A: Data, ds: R.Graves(A)) -> Data:
  {Laws.dead.wf(~A, ds) == True{} : Bool}

def wf.enqueued(~A: Data, r: Q.State<A> & Nat, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(), d: Nat, wf: WF(~A, ds)) -> WF(~A, R.dead(A, R.step.enqueued(A, r, ts, ds, bs, d))):
  match r:
    case (q, i):
      wf

def wf.selected(~A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(), wf: WF(~A, ds)) -> WF(~A, R.dead(A, R.step.selected(A, r, ts, ds, bs))):
  match r:
    case (q, t):
      wf

def wf.requeued(~A: Data, r: Q.State<A> & Bool, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(), wf: WF(~A, ds)) -> WF(~A, R.dead(A, R.step.requeued(A, r, ts, ds, bs))):
  match r:
    case (q, b):
      wf

def wf.completed(~A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(), wf: WF(~A, ds)) -> WF(~A, R.dead(A, R.step.completed(A, r, ts, ds, bs))):
  match r:
    case (q, t):
      wf

def bury_wf(~A: Data, m: Maybe<&2, Q.Ticket<A>>, +ds: R.Graves(A), +w: R.Why, +at: Nat, +wf: WF(~A, ds)) -> WF(~A, R.dead.bury(~A, m, ds, w, at)):
  match m:
    case None{}:
      wf
    case Some{Q.Ticket{+k, +d, +x}}:
      CL.hmap_put_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ~MNat.is_eq_refl, ~MNat.eq_of_is_eq, ds, wf, k, R.Dead{Q.Ticket{k, d, x}, w, at})

def wf.abandoned(~A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: R.Tries(), +ds: R.Graves(A), bs: R.Breakers(), +w: R.Why, +at: Nat, +wf: WF(~A, ds)) ->
    WF(~A, R.dead(A, R.step.abandoned(~A, r, ts, ds, bs, w, at))):
  match r:
    case (q, t):
      bury_wf(~A, t, ds, w, at, wf)

def wf.revived(~A: Data, m: Maybe<&2, R.Dead<A>>, +j: Nat, n: Nat, h: H.Heap<Q.Ticket<A>>, r: List<&2, Q.Ticket<A>>, ts: R.Tries(), +rest: R.Graves(A), bs: R.Breakers(), +d: Nat,
    wf: WF(~A, rest)) -> WF(~A, R.dead(A, R.step.revived(~A, m, j, n, h, r, ts, rest, bs, d))):
  match m:
    case None{}:
      wf
    case Some{R.Dead{Q.Ticket{k, old, x}, w, at}}:
      CL.hmap_del_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, rest, wf, j)

def drops_wf(~A: Data, ks: List<&2, Nat>, +ds: R.Graves(A), +wf: WF(~A, ds)) -> WF(~A, R.dead.drops(~A, ks, ds)):
  match ks:
    case Nil{}:
      wf
    case Con{+k, rest}:
      drops_wf(~A, rest, R.dead.drop(~A, ds, k), CL.hmap_del_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ds, wf, k))

def step_wf(~A: Data, s: R.State<A>, op: R.Op<A>, wf: WF(~A, R.dead(A, s))) -> WF(~A, R.dead(A, R.step(~A, s, op))):
  match s op:
    case R.State{q, ts, ds, bs} R.Enqueue{+d, x}:
      wf.enqueued(~A, Q.enqueue(~A, d, x, q), ts, ds, bs, d, wf)
    case R.State{q, ts, ds, bs} R.Select{now}:
      wf.selected(~A, Q.select(~A, now, q), ts, ds, bs, wf)
    case R.State{q, ts, ds, bs} R.Complete{+i}:
      wf.completed(~A, Q.complete(A, i, q), R.tries.drop(ts, i), ds, bs, wf)
    case R.State{q, ts, ds, bs} R.Cancel{+i}:
      CL.hmap_del_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ds, wf, i)
    case R.State{q, ts, ds, bs} R.Requeue{+i, d}:
      wf.requeued(~A, Q.requeue(~A, i, d, q), R.tries.bump(ts, i), ds, bs, wf)
    case R.State{q, ts, ds, bs} R.Defer{i, d}:
      wf.requeued(~A, Q.requeue(~A, i, d, q), ts, ds, bs, wf)
    case R.State{q, ts, ds, bs} R.Abandon{+i, w, at}:
      wf.abandoned(~A, Q.complete(A, i, q), R.tries.drop(ts, i), ds, bs, w, at, wf)
    case R.State{Q.State{n, h, r}, ts, +ds, bs} R.Revive{+i, d}:
      wf.revived(~A, R.dead.get(~A, ds, i), i, n, h, r, ts, ds, bs, d, wf)
    case R.State{q, ts, +ds, bs} R.Purge{t}:
      drops_wf(~A, R.dead.old(A, R.dead.list(A, ds), t), ds, wf)
    case R.State{q, ts, ds, bs} R.PurgeAll{}:
      {==}
    case R.State{q, ts, ds, bs} R.Break{k, b}:
      wf

def Laws.revive_pending(A, s, i, old, x, running, wf, w, at, d):
  match s:
    case R.State{Q.State{n, +h, +r}, +ts, +ds, +bs}:
      %Equal.sym(Q.Taken<A>, Q.take.list(A, r, i), Q.Taken{Q.remove.list(A, r, i), Q.find.list(A, r, i)}, QL.take_equivalent(A, r, i)) :
        Laws.revive.post(~A, R.step(~A, R.step.abandoned(~A, Q.complete.taken(A, _, n, h), R.tries.drop(ts, i), ds, bs, w, at), R.Revive{i, d}), h, i, d, x)
      %Equal.sym(Maybe<&2, Q.Ticket<A>>, Q.find.list(A, r, i), Some{Q.Ticket{i, old, x}}, running) :
        Laws.revive.post(~A, R.step(~A, R.step.abandoned(~A, (Q.State{n, h, Q.remove.list(A, r, i)}, _), R.tries.drop(ts, i), ds, bs, w, at), R.Revive{i, d}), h, i, d, x)
      +buried = R.dead.bury(~A, Some{Q.Ticket{i, old, x}}, ds, w, at)
      %Equal.sym(Maybe<&2, R.Dead<A>>, R.dead.get(~A, buried, i), Some{R.Dead{Q.Ticket{i, old, x}, w, at}},
        CL.hmap_get_put_same(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ~MNat.is_eq_refl, ds, wf, i, R.Dead{Q.Ticket{i, old, x}, w, at})) :
        Laws.revive.post(~A, R.step.revived(~A, _, i, n, h, Q.remove.list(A, r, i), R.tries.drop(ts, i), buried, bs, d), h, i, d, x)
      QL.Both{{==}, CL.hmap_get_del_same(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ~MNat.eq_of_is_eq, buried,
        bury_wf(~A, Some{Q.Ticket{i, old, x}}, ds, w, at, wf), i)}

def Laws.revive_noop(A, s, i, d, alive):
  match s:
    case R.State{Q.State{n, h, r}, ts, +ds, bs}:
      %Equal.sym(Maybe<&2, R.Dead<A>>, R.dead.get(~A, ds, i), None{}, alive) :
        {R.step.revived(~A, _, i, n, h, r, ts, ds, bs, d) == R.State{Q.State{n, h, r}, ts, ds, bs} : R.State<A>}
      {==}

def Laws.dead_wf(A, s, wf, op):
  step_wf(~A, s, op, wf)

# The decoder's adjacent comparisons imply the existing dead-ticket invariant.
def ascending.clash(+a: Nat, +b: Nat, e: {a == b : Nat}) -> MNat.lt(a, b) -> Empty:
  %Equal.sym(Nat, a, b, e) : MNat.lt(_, b) -> Empty
  h => MNat.lt_irrefl(b)(h)

def ascending.ne(+a: Nat, +b: Nat, h: MNat.lt(a, b)) -> {Bool.not(Nat.is_eq(a, b)) == True{} : Bool}:
  split(c => {Bool.not(c) == True{} : Bool}, Nat.is_eq(a, b),
    e => Empty.absurd({Bool.not(True{}) == True{} : Bool}, ascending.clash(a, b, MNat.eq_of_is_eq(a, b, e))(h)),
    e => {==})

def ascending.absent(~A: Data, xs: List<&2, M.Entry<Nat, R.Dead<A>>>, +previous: Nat, +key: Nat,
    +bound: {Nat.is_le(key, previous) == True{} : Bool},
    +ordered: {R.rd.ascending(~A, xs, previous) == True{} : Bool}) ->
    {CL.hmap_absent(~Nat, ~R.Dead<A>, ~Nat.is_eq, xs, key) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{M.Entry{+j, v}, +rest}:
      +step = MBool.eq_true_of_and_left(Nat.is_lt(previous, j), R.rd.ascending(~A, rest, j), ordered)
      +tail = MBool.eq_true_of_and_right(Nat.is_lt(previous, j), R.rd.ascending(~A, rest, j), ordered)
      +kj = MNat.lt_of_le_of_lt(key, previous, j, bound, step)
      MBool.and_eq_true(Bool.not(Nat.is_eq(key, j)), CL.hmap_absent(~Nat, ~R.Dead<A>, ~Nat.is_eq, rest, key),
        ascending.ne(key, j, kj),
        ascending.absent(~A, rest, j, key, MNat.le_of_lt(key, j, kj), tail))

def ascending.distinct(~A: Data, xs: List<&2, M.Entry<Nat, R.Dead<A>>>, +previous: Nat,
    ordered: {R.rd.ascending(~A, xs, previous) == True{} : Bool}) ->
    {CL.hmap_distinct(~Nat, ~R.Dead<A>, ~Nat.is_eq, xs) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{M.Entry{+j, v}, +rest}:
      +tail = MBool.eq_true_of_and_right(Nat.is_lt(previous, j), R.rd.ascending(~A, rest, j), ordered)
      MBool.and_eq_true(CL.hmap_absent(~Nat, ~R.Dead<A>, ~Nat.is_eq, rest, j), CL.hmap_distinct(~Nat, ~R.Dead<A>, ~Nat.is_eq, rest),
        ascending.absent(~A, rest, j, j, MNat.le_refl(j), tail),
        ascending.distinct(~A, rest, j, tail))

def distinct.wf(~A: Data, xs: List<&2, M.Entry<Nat, R.Dead<A>>>,
    ordered: {R.rd.distinct(~A, xs) == True{} : Bool}) ->
    {CL.hmap_distinct(~Nat, ~R.Dead<A>, ~Nat.is_eq, xs) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{M.Entry{+j, v}, +rest}:
      +ordered = ordered
      MBool.and_eq_true(CL.hmap_absent(~Nat, ~R.Dead<A>, ~Nat.is_eq, rest, j), CL.hmap_distinct(~Nat, ~R.Dead<A>, ~Nat.is_eq, rest),
        ascending.absent(~A, rest, j, j, MNat.le_refl(j), ordered),
        ascending.distinct(~A, rest, j, ordered))

def valid.wf.go(~A: Data, +n: Nat, ds: R.Graves(A), +valid: {R.rd.valid.go(~A, n, ds) == True{} : Bool}) ->
    {CL.hmap_wf.go(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, n, ds) == True{} : Bool}:
  match n:
    case 0n:
      match ds:
        case M.HNil{}:
          {==}
        case M.HLeaf{h, es}:
          distinct.wf(~A, es, valid)
        case M.HBranch{lo, hi}:
          valid
    case 1n+p:
      match ds:
        case M.HNil{}:
          {==}
        case M.HLeaf{+h, +es}:
          MBool.and_eq_true(CL.hmap_hashed(~Nat, ~R.Dead<A>, ~R.dead.hash, es, h), CL.hmap_distinct(~Nat, ~R.Dead<A>, ~Nat.is_eq, es),
            MBool.eq_true_of_and_left(CL.hmap_hashed(~Nat, ~R.Dead<A>, ~R.dead.hash, es, h), R.rd.distinct(~A, es), valid),
            distinct.wf(~A, es, MBool.eq_true_of_and_right(CL.hmap_hashed(~Nat, ~R.Dead<A>, ~R.dead.hash, es, h), R.rd.distinct(~A, es), valid)))
        case M.HBranch{+lo, +hi}:
          MBool.and_eq_true(CL.hmap_wf.go(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, p, lo), CL.hmap_wf.go(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, p, hi),
            valid.wf.go(~A, p, lo, MBool.eq_true_of_and_left(R.rd.valid.go(~A, p, lo), R.rd.valid.go(~A, p, hi), valid)),
            valid.wf.go(~A, p, hi, MBool.eq_true_of_and_right(R.rd.valid.go(~A, p, lo), R.rd.valid.go(~A, p, hi), valid)))

def decoded.wf(~A: Data, ds: R.Graves(A), valid: {R.rd.valid(~A, ds) == True{} : Bool}) ->
    {Laws.dead.wf(~A, ds) == True{} : Bool}:
  valid.wf.go(~A, 32n, ds, valid)

# ---- settle loop

def loop.bound(-A: Data, +s: R.Loop<A>) -> Data:
  MNat.le(Res.reserved(R.loop.pool(A, s)), Res.capacity(R.loop.pool(A, s)))

def loop.claim.bound(~A: Data, +o: Nat, +c: Nat, +h: Nat, +s: R.State<A>, +fs: List<&2, Q.Ticket<A>>, +now: Nat, +e: MNat.le(h, c)) ->
    loop.bound(A, R.loop.claim(~A, R.pick(~A, Res.Pool{o, c, h}, s, now), s, fs, now)):
  pick_cases(~A, k => loop.bound(A, R.loop.claim(~A, k, s, fs, now)), Res.Pool{o, c, h}, s, now, e,
    t => split(b => loop.bound(A, R.loop.claim(~A, R.pick.took(A, Res.reserve.go(b, o, c, h, 1n), t), s, fs, now)),
      Nat.is_le(Nat.add(h, 1n), c), f => f, f => e))

def loop.finish.bound(~A: Data, tk: Q.Taken<A>, +o: Nat, +c: Nat, +h: Nat, s: R.State<A>, i: Nat, +e: MNat.le(h, c)) ->
    loop.bound(A, R.loop.finished(~A, tk, Res.Pool{o, c, h}, s, i)):
  match tk:
    case Q.Taken{fs, None{}}:
      e
    case Q.Taken{fs, Some{t}}:
      split(b => MNat.le(Res.reserved(R.loop.release(Res.release.go(b, o, c, h, o, 1n))), Res.capacity(R.loop.release(Res.release.go(b, o, c, h, o, 1n)))),
        Bool.and(Nat.is_eq(o, o), Nat.is_le(1n, h)),
        f => MNat.le_trans(Nat.sub(h, 1n), h, c, MNat.sub_le(h, 1n), e),
        f => e)

def loop.step.bound(~A: Data, e: R.LoopEvent, s: R.Loop<A>, bound: loop.bound(A, s)) -> loop.bound(A, R.loop.step(~A, e, s)):
  match e s:
    case R.Claim{+now} R.Loop{Res.Pool{+o, +c, +h}, +s, +fs}:
      loop.claim.bound(~A, o, c, h, s, fs, now, bound)
    case R.Finish{+i} R.Loop{Res.Pool{+o, +c, +h}, s, fs}:
      loop.finish.bound(~A, Q.take.list(A, fs, i), o, c, h, s, i, bound)

def Laws.loop_capacity(A, es, s, bound):
  match es:
    case Nil{}:
      bound
    case Con{+e, rest}:
      +s = s
      Laws.loop_capacity(~A, rest, R.loop.step(~A, e, s), loop.step.bound(~A, e, s, bound))

def loop.claim.cap(~A: Data, +o: Nat, +c: Nat, +h: Nat, +s: R.State<A>, +fs: List<&2, Q.Ticket<A>>, +now: Nat) ->
    {Res.capacity(R.loop.pool(A, R.loop.claim(~A, R.pick(~A, Res.Pool{o, c, h}, s, now), s, fs, now))) == c : Nat}:
  pick_cases(~A, k => {Res.capacity(R.loop.pool(A, R.loop.claim(~A, k, s, fs, now))) == c : Nat}, Res.Pool{o, c, h}, s, now, {==},
    t => split(b => {Res.capacity(R.loop.pool(A, R.loop.claim(~A, R.pick.took(A, Res.reserve.go(b, o, c, h, 1n), t), s, fs, now))) == c : Nat},
      Nat.is_le(Nat.add(h, 1n), c), f => {==}, f => {==}))

def loop.finish.cap(~A: Data, tk: Q.Taken<A>, +o: Nat, +c: Nat, +h: Nat, s: R.State<A>, i: Nat) ->
    {Res.capacity(R.loop.pool(A, R.loop.finished(~A, tk, Res.Pool{o, c, h}, s, i))) == c : Nat}:
  match tk:
    case Q.Taken{fs, None{}}:
      {==}
    case Q.Taken{fs, Some{t}}:
      split(b => {Res.capacity(R.loop.release(Res.release.go(b, o, c, h, o, 1n))) == c : Nat},
        Bool.and(Nat.is_eq(o, o), Nat.is_le(1n, h)), f => {==}, f => {==})

def loop.step.cap(~A: Data, e: R.LoopEvent, s: R.Loop<A>) ->
    {Res.capacity(R.loop.pool(A, R.loop.step(~A, e, s))) == Res.capacity(R.loop.pool(A, s)) : Nat}:
  match e s:
    case R.Claim{+now} R.Loop{Res.Pool{+o, +c, +h}, +s, +fs}:
      loop.claim.cap(~A, o, c, h, s, fs, now)
    case R.Finish{+i} R.Loop{Res.Pool{+o, +c, +h}, s, fs}:
      loop.finish.cap(~A, Q.take.list(A, fs, i), o, c, h, s, i)

def Laws.loop_capacity_stable(A, es, s):
  match es:
    case Nil{}:
      {==}
    case Con{+e, rest}:
      +s = s
      Equal.trans(Nat, Res.capacity(R.loop.pool(A, R.loop.fold(~A, rest, R.loop.step(~A, e, s)))), Res.capacity(R.loop.pool(A, R.loop.step(~A, e, s))), Res.capacity(R.loop.pool(A, s)),
        Laws.loop_capacity_stable(~A, rest, R.loop.step(~A, e, s)), loop.step.cap(~A, e, s))

def Laws.loop_finish_releases(A, i, o, c, h, s, fs, t, found):
  +o = o
  +c = c
  +h = h
  +s = s
  +fs = fs
  %Equal.sym(Q.Taken<A>, Q.take.list(A, fs, i), Q.Taken{Q.remove.list(A, fs, i), Q.find.list(A, fs, i)}, QL.take_equivalent(A, fs, i)) : {R.loop.pool(A, R.loop.finished(~A, _, Res.Pool{o, c, 1n+h}, s, i)) == Res.Pool{o, c, h} : Res.Pool}
  %Equal.sym(Maybe<&2, Q.Ticket<A>>, Q.find.list(A, fs, i), Some{t}, found) : {R.loop.pool(A, R.loop.finished(~A, Q.Taken{Q.remove.list(A, fs, i), _}, Res.Pool{o, c, 1n+h}, s, i)) == Res.Pool{o, c, h} : Res.Pool}
  %MNat.add_comm(h, 1n) : {R.loop.release(Res.release(Res.Pool{o, c, _}, Res.Grant{o, 1n})) == Res.Pool{o, c, h} : Res.Pool}
  took.release.go(o, c, h)

def loop.take.idle(-A: Data, +fs: List<&2, Q.Ticket<A>>, +i: Nat, er: QL.absent.list(A, fs, i)) ->
    {Q.take.list(A, fs, i) == Q.Taken{fs, None{}} : Q.Taken<A>}:
  match fs:
    case Nil{}:
      {==}
    case Con{+t, +rest}:
      QL.Both{et, erest} = er
      %Equal.sym(Q.Taken<A>, Q.take.list(A, rest, i), Q.Taken{rest, None{}}, loop.take.idle(A, rest, i, erest)) : {Q.take.keep(A, Nat.is_eq(Q.id(A, t), i), t, _) == Q.Taken{Con{t, rest}, None{}} : Q.Taken<A>}
      %Equal.sym(Bool, Nat.is_eq(Q.id(A, t), i), False{}, et) : {Q.take.keep(A, _, t, Q.Taken{rest, None{}}) == Q.Taken{Con{t, rest}, None{}} : Q.Taken<A>}
      {==}

def loop.finish.idle(~A: Data, +i: Nat, +s: R.Loop<A>, er: QL.absent.list(A, R.loop.flights(A, s), i)) ->
    {R.loop.step(~A, R.Finish{i}, s) == s : R.Loop<A>}:
  match s:
    case R.Loop{Res.Pool{o, c, h}, s, fs}:
      %Equal.sym(Q.Taken<A>, Q.take.list(A, fs, i), Q.Taken{fs, None{}}, loop.take.idle(A, fs, i, er)) : {R.loop.finished(~A, _, Res.Pool{o, c, h}, s, i) == R.Loop{Res.Pool{o, c, h}, s, fs} : R.Loop<A>}
      {==}

def loop.finished.absent(~A: Data, tk: Q.Taken<A>, o: Nat, c: Nat, h: Nat, s: R.State<A>, +i: Nat, er: taken.rem_ok(A, tk, i)) ->
    QL.absent.list(A, R.loop.flights(A, R.loop.finished(~A, tk, Res.Pool{o, c, h}, s, i)), i):
  match tk:
    case Q.Taken{fs, None{}}:
      er
    case Q.Taken{fs, Some{t}}:
      er

def Laws.loop_finish_once(A, i, s):
  match s:
    case R.Loop{Res.Pool{+o, +c, +h}, +s, +fs}:
      loop.finish.idle(~A, i, R.loop.finished(~A, Q.take.list(A, fs, i), Res.Pool{o, c, h}, s, i),
        loop.finished.absent(~A, Q.take.list(A, fs, i), o, c, h, s, i, take_absent(A, fs, i)))

def loop.sync(-A: Data, +s: R.Loop<A>) -> Data:
  {R.loop.flights(A, s) == Q.running(A, R.queue(A, R.loop.state(A, s))) : List<&2, Q.Ticket<A>>}

def loop.claim.sync.pick(-A: Data, k: R.Pick<A>, s: R.State<A>, fs: List<&2, Q.Ticket<A>>, now: Nat) -> Data:
  match k:
    case R.Idle{p}:
      {fs == Q.running(A, R.queue(A, s)) : List<&2, Q.Ticket<A>>}
    case R.Picked{p, t, g}:
      {Con{t, fs} == Q.running(A, R.queue(A, R.step(~A, s, R.Select{now}))) : List<&2, Q.Ticket<A>>}

def loop.claim.sync.took(~A: Data, r: Res.Reserve, +t: Q.Ticket<A>, +s: R.State<A>, +fs: List<&2, Q.Ticket<A>>, +now: Nat,
    same: {fs == Q.running(A, R.queue(A, s)) : List<&2, Q.Ticket<A>>},
    selected: {Con{t, fs} == Q.running(A, R.queue(A, R.step(~A, s, R.Select{now}))) : List<&2, Q.Ticket<A>>}) ->
    loop.claim.sync.pick(A, R.pick.took(A, r, t), s, fs, now):
  match r:
    case Res.Took{p, g}:
      selected
    case Res.Refused{p}:
      same

def loop.selected.sync(~A: Data, +n: Nat, +size: Nat, +t: Q.Ticket<A>, +l: H.Heap<Q.Ticket<A>>, +r: H.Heap<Q.Ticket<A>>, +old: List<&2, Q.Ticket<A>>,
    +ts: R.Tries(), +ds: R.Graves(A), +bs: R.Breakers(), +fs: List<&2, Q.Ticket<A>>, +now: Nat,
    same: {fs == old : List<&2, Q.Ticket<A>>}, due: {Nat.is_le(Q.deadline(A, t), now) == True{} : Bool}) ->
    {Con{t, fs} == Q.running(A, R.queue(A, R.step(~A, R.State{Q.State{n, H.HNode{size, t, l, r}, old}, ts, ds, bs}, R.Select{now}))) : List<&2, Q.Ticket<A>>}:
  %Equal.sym(Bool, Nat.is_le(Q.deadline(A, t), now), True{}, due) :
    {Con{t, fs} == Q.running(A, R.queue(A, R.step.selected(A, Q.select.due(~A, _, n, H.HNode{size, t, l, r}, old, t, l, r), ts, ds, bs))) : List<&2, Q.Ticket<A>>}
  %Equal.sym(List<&2, Q.Ticket<A>>, fs, old, same) : {Con{t, _} == Con{t, old} : List<&2, Q.Ticket<A>>}
  {==}

def loop.claim.sync.evidence(~A: Data, +p: Res.Pool, s: R.State<A>, +fs: List<&2, Q.Ticket<A>>, +now: Nat,
    +same: {fs == Q.running(A, R.queue(A, s)) : List<&2, Q.Ticket<A>>}) ->
    loop.claim.sync.pick(A, R.pick(~A, p, s, now), s, fs, now):
  match s:
    case R.State{Q.State{n, H.HLeaf{}, old}, ts, ds, bs}:
      same
    case R.State{Q.State{+n, H.HNode{+size, +t, +l, +r}, +old}, +ts, +ds, +bs}:
      split(b => loop.claim.sync.pick(A, R.pick.sel(A, Q.select.due(~A, b, n, H.HNode{size, t, l, r}, old, t, l, r), p),
        R.State{Q.State{n, H.HNode{size, t, l, r}, old}, ts, ds, bs}, fs, now), Nat.is_le(Q.deadline(A, t), now),
        due => loop.claim.sync.took(~A, Res.reserve(p, 1n), t, R.State{Q.State{n, H.HNode{size, t, l, r}, old}, ts, ds, bs}, fs, now, same,
          loop.selected.sync(~A, n, size, t, l, r, old, ts, ds, bs, fs, now, same, due)),
        due => same)

def loop.claim.synced(~A: Data, k: R.Pick<A>, s: R.State<A>, fs: List<&2, Q.Ticket<A>>, now: Nat,
    same: loop.claim.sync.pick(A, k, s, fs, now)) -> loop.sync(A, R.loop.claim(~A, k, s, fs, now)):
  match k:
    case R.Idle{p}:
      same
    case R.Picked{p, t, g}:
      same

def loop.take.unchanged(-A: Data, tk: Q.Taken<A>, old: List<&2, Q.Ticket<A>>) -> Data:
  match tk:
    case Q.Taken{fs, None{}}:
      {fs == old : List<&2, Q.Ticket<A>>}
    case Q.Taken{fs, Some{t}}:
      Unit

def loop.take.keep.unchanged(-A: Data, b: Bool, +t: Q.Ticket<A>, +old: List<&2, Q.Ticket<A>>, tk: Q.Taken<A>,
    er: loop.take.unchanged(A, tk, old)) -> loop.take.unchanged(A, Q.take.keep(A, b, t, tk), Con{t, old}):
  match b tk:
    case True{} Q.Taken{fs, m}:
      Unit{}
    case False{} Q.Taken{fs, None{}}:
      %Equal.sym(List<&2, Q.Ticket<A>>, fs, old, er) : {Con{t, _} == Con{t, old} : List<&2, Q.Ticket<A>>}
      {==}
    case False{} Q.Taken{fs, Some{f}}:
      Unit{}

def loop.take.original(-A: Data, +xs: List<&2, Q.Ticket<A>>, +i: Nat) -> loop.take.unchanged(A, Q.take.list(A, xs, i), xs):
  match xs:
    case Nil{}:
      {==}
    case Con{+t, +rest}:
      loop.take.keep.unchanged(A, Nat.is_eq(Q.id(A, t), i), t, rest, Q.take.list(A, rest, i), loop.take.original(A, rest, i))

def loop.finish.synced(~A: Data, tk: Q.Taken<A>, p: Res.Pool, +n: Nat, +heap: H.Heap<Q.Ticket<A>>, +old: List<&2, Q.Ticket<A>>,
    +ts: R.Tries(), +ds: R.Graves(A), +bs: R.Breakers(), +i: Nat,
    eq: {tk == Q.take.list(A, old, i) : Q.Taken<A>}) ->
    loop.sync(A, R.loop.finished(~A, tk, p, R.State{Q.State{n, heap, old}, ts, ds, bs}, i)):
  match tk p:
    case Q.Taken{fs, None{}} Res.Pool{o, c, h}:
      %Equal.sym(Q.Taken<A>, Q.Taken{fs, None{}}, Q.take.list(A, old, i), eq) : loop.take.unchanged(A, _, old)
      loop.take.original(A, old, i)
    case Q.Taken{fs, Some{t}} Res.Pool{o, c, h}:
      %eq : {fs == Q.running(A, R.queue(A, R.step.completed(A, Q.complete.taken(A, _, n, heap), R.tries.drop(ts, i), ds, bs))) : List<&2, Q.Ticket<A>>}
      {==}

def loop.step.sync(~A: Data, +e: R.LoopEvent, s: R.Loop<A>, same: loop.sync(A, s)) -> loop.sync(A, R.loop.step(~A, e, s)):
  match e s:
    case R.Claim{+now} R.Loop{+p, R.State{Q.State{+n, +heap, +old}, +ts, +ds, +bs}, +fs}:
      loop.claim.synced(~A, R.pick(~A, p, R.State{Q.State{n, heap, old}, ts, ds, bs}, now), R.State{Q.State{n, heap, old}, ts, ds, bs}, fs, now,
        loop.claim.sync.evidence(~A, p, R.State{Q.State{n, heap, old}, ts, ds, bs}, fs, now, same))
    case R.Finish{+i} R.Loop{+p, R.State{Q.State{+n, +heap, +old}, +ts, +ds, +bs}, +fs}:
      %Equal.sym(List<&2, Q.Ticket<A>>, fs, old, same) : loop.sync(A, R.loop.finished(~A, Q.take.list(A, _, i), p, R.State{Q.State{n, heap, old}, ts, ds, bs}, i))
      loop.finish.synced(~A, Q.take.list(A, old, i), p, n, heap, old, ts, ds, bs, i, {==})

def Laws.loop_flights(A, es, s, same):
  match es:
    case Nil{}:
      same
    case Con{+e, rest}:
      +s = s
      Laws.loop_flights(~A, rest, R.loop.step(~A, e, s), loop.step.sync(~A, e, s, same))
