import Base
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-mathlib@0.8.0.0/bool.bend as MBool
import bend-kit-collections@0.1.6.0/hmap.bend as M
import bend-kit-scheduler@0.4.4.0/queue.bend as Q
import bend-kit-scheduler@0.4.4.0/queue_laws.bend as QL
import bend-kit-scheduler@0.4.4.0/queue_proof.bend as QP
import bend-kit-collections@0.1.6.0/heap.bend as H
import bend-kit-collections@0.1.6.0/LAWS.bend as CL
import bend-kit-collections@0.1.6.0/PROOF.bend as CP
import bend-kit-resources@0.1.0.0/resources.bend as Res
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import ./model.bend as R
import ./LAWS.bend as Laws
import bend-kit-collections@0.1.6.0/order.bend as Order
import bend-kit-collections@0.1.6.0/omap.bend as O
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes

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

def Laws.revive_budget(A, s, i, d, dead, found):
  match s dead:
    case R.State{Q.State{n, h, r}, ts, +ds, bs} R.Dead{Q.Ticket{k, old, x}, w, at}:
      %Equal.sym(Maybe<&2, R.Dead<A>>, R.dead.get(~A, ds, i), Some{R.Dead{Q.Ticket{k, old, x}, w, at}}, found) :
        {R.tries(A, R.step.revived(~A, _, i, n, h, r, ts, ds, bs, d)) == O.OMap.put(~Nat, ~R.Try, ~Nat.cmp, ts, i, R.Try{0n, d}) : R.Tries()}
      {==}

def Laws.replay_revive_budget(A, X, enc, dec, round, s, i, d, dead, found):
  %Equal.sym(Maybe<&2, R.State<A>>,
    Laws.replayed(~A, ~X, ~enc, ~dec, [R.Revive{i, d}], s),
    Some{R.step(~A, s, R.Revive{i, d})},
    replay.go(~A, ~X, ~enc, ~dec, ~round, [R.Revive{i, d}], s)) :
    {Laws.budget.recovered(A, _) == Some{O.OMap.put(~Nat, ~R.Try, ~Nat.cmp, R.tries(A, s), i, R.Try{0n, d})} : Maybe<&2, R.Tries()>}
  Equal.cong(R.Tries(), Maybe<&2, R.Tries()>, ts => Some{ts},
    R.tries(A, R.step(~A, s, R.Revive{i, d})),
    O.OMap.put(~Nat, ~R.Try, ~Nat.cmp, R.tries(A, s), i, R.Try{0n, d}),
    Laws.revive_budget(~A, s, i, d, dead, found))

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

def loop.retry.pool(~A: Data, tk: Q.Taken<A>, +p: Res.Pool, +s: R.State<A>, +i: Nat, d: Nat) ->
    {R.loop.pool(A, R.loop.retried(~A, tk, p, s, i, d)) == R.loop.pool(A, R.loop.finished(~A, tk, p, s, i)) : Res.Pool}:
  match tk p:
    case Q.Taken{fs, None{}} Res.Pool{o, c, h}:
      {==}
    case Q.Taken{fs, Some{t}} Res.Pool{o, c, h}:
      {==}

def loop.step.bound(~A: Data, e: R.LoopEvent, s: R.Loop<A>, bound: loop.bound(A, s)) -> loop.bound(A, R.loop.step(~A, e, s)):
  match e s:
    case R.Claim{+now} R.Loop{Res.Pool{+o, +c, +h}, +s, +fs}:
      loop.claim.bound(~A, o, c, h, s, fs, now, bound)
    case R.Finish{+i} R.Loop{Res.Pool{+o, +c, +h}, s, fs}:
      loop.finish.bound(~A, Q.take.list(A, fs, i), o, c, h, s, i, bound)
    case R.CancelFlight{i} R.Loop{p, s, fs}:
      bound
    case R.RetrySettle{+i, +d} R.Loop{Res.Pool{+o, +c, +h}, +s, +fs}:
      %Equal.sym(Res.Pool, R.loop.pool(A, R.loop.retried(~A, Q.take.list(A, fs, i), Res.Pool{o, c, h}, s, i, d)),
        R.loop.pool(A, R.loop.finished(~A, Q.take.list(A, fs, i), Res.Pool{o, c, h}, s, i)),
        loop.retry.pool(~A, Q.take.list(A, fs, i), Res.Pool{o, c, h}, s, i, d)) : MNat.le(Res.reserved(_), Res.capacity(_))
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
    case R.CancelFlight{i} R.Loop{p, s, fs}:
      {==}
    case R.RetrySettle{+i, +d} R.Loop{Res.Pool{+o, +c, +h}, +s, +fs}:
      %Equal.sym(Res.Pool, R.loop.pool(A, R.loop.retried(~A, Q.take.list(A, fs, i), Res.Pool{o, c, h}, s, i, d)),
        R.loop.pool(A, R.loop.finished(~A, Q.take.list(A, fs, i), Res.Pool{o, c, h}, s, i)),
        loop.retry.pool(~A, Q.take.list(A, fs, i), Res.Pool{o, c, h}, s, i, d)) : {Res.capacity(_) == c : Nat}
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
  Laws.flights.cover(A, R.loop.flights(A, s), Q.running(A, R.queue(A, R.loop.state(A, s))))

def loop.claim.sync.pick(~A: Data, k: R.Pick<A>, s: R.State<A>, fs: List<&2, Q.Ticket<A>>, now: Nat) -> Data:
  match k:
    case R.Idle{p}:
      Laws.flights.cover(A, fs, Q.running(A, R.queue(A, s)))
    case R.Picked{p, t, g}:
      Laws.flights.cover(A, Con{t, fs}, Q.running(A, R.queue(A, R.step(~A, s, R.Select{now}))))

def loop.claim.sync.took(~A: Data, r: Res.Reserve, +t: Q.Ticket<A>, +s: R.State<A>, +fs: List<&2, Q.Ticket<A>>, +now: Nat,
    same: Laws.flights.cover(A, fs, Q.running(A, R.queue(A, s))),
    selected: Laws.flights.cover(A, Con{t, fs}, Q.running(A, R.queue(A, R.step(~A, s, R.Select{now}))))) ->
    loop.claim.sync.pick(~A, R.pick.took(A, r, t), s, fs, now):
  match r:
    case Res.Took{p, g}:
      selected
    case Res.Refused{p}:
      same

def loop.selected.sync(~A: Data, +n: Nat, +size: Nat, +t: Q.Ticket<A>, +l: H.Heap<Q.Ticket<A>>, +r: H.Heap<Q.Ticket<A>>, +old: List<&2, Q.Ticket<A>>,
    +ts: R.Tries(), +ds: R.Graves(A), +bs: R.Breakers(), +fs: List<&2, Q.Ticket<A>>, +now: Nat,
    same: Laws.flights.cover(A, fs, old), due: {Nat.is_le(Q.deadline(A, t), now) == True{} : Bool}) ->
    Laws.flights.cover(A, Con{t, fs}, Q.running(A, R.queue(A, R.step(~A, R.State{Q.State{n, H.HNode{size, t, l, r}, old}, ts, ds, bs}, R.Select{now})))):
  %Equal.sym(Bool, Nat.is_le(Q.deadline(A, t), now), True{}, due) :
    Laws.flights.cover(A, Con{t, fs}, Q.running(A, R.queue(A, R.step.selected(A, Q.select.due(~A, _, n, H.HNode{size, t, l, r}, old, t, l, r), ts, ds, bs))))
  Laws.Keep{QL.Both{{==}, same}}

def loop.claim.sync.evidence(~A: Data, +p: Res.Pool, s: R.State<A>, +fs: List<&2, Q.Ticket<A>>, +now: Nat,
    +same: Laws.flights.cover(A, fs, Q.running(A, R.queue(A, s)))) ->
    loop.claim.sync.pick(~A, R.pick(~A, p, s, now), s, fs, now):
  match s:
    case R.State{Q.State{n, H.HLeaf{}, old}, ts, ds, bs}:
      same
    case R.State{Q.State{+n, H.HNode{+size, +t, +l, +r}, +old}, +ts, +ds, +bs}:
      split(b => loop.claim.sync.pick(~A, R.pick.sel(A, Q.select.due(~A, b, n, H.HNode{size, t, l, r}, old, t, l, r), p),
        R.State{Q.State{n, H.HNode{size, t, l, r}, old}, ts, ds, bs}, fs, now), Nat.is_le(Q.deadline(A, t), now),
        due => loop.claim.sync.took(~A, Res.reserve(p, 1n), t, R.State{Q.State{n, H.HNode{size, t, l, r}, old}, ts, ds, bs}, fs, now, same,
          loop.selected.sync(~A, n, size, t, l, r, old, ts, ds, bs, fs, now, same, due)),
        due => same)

def loop.claim.synced(~A: Data, k: R.Pick<A>, s: R.State<A>, fs: List<&2, Q.Ticket<A>>, now: Nat,
    same: loop.claim.sync.pick(~A, k, s, fs, now)) -> loop.sync(A, R.loop.claim(~A, k, s, fs, now)):
  match k:
    case R.Idle{p}:
      same
    case R.Picked{p, t, g}:
      same


def cover.nil(-A: Data, fs: List<&2, Q.Ticket<A>>) -> Laws.flights.cover(A, fs, Nil{}):
  match fs:
    case Nil{}:
      Unit{}
    case Con{t, rest}:
      Unit{}

def cover.skip(-A: Data, t: Q.Ticket<A>, fs: List<&2, Q.Ticket<A>>, rs: List<&2, Q.Ticket<A>>, e: Laws.flights.cover(A, fs, rs)) ->
    Laws.flights.cover(A, Con{t, fs}, rs):
  match rs:
    case Nil{}:
      Unit{}
    case Con{r, rest}:
      Laws.Skip{e}

def cover.right.keep(-A: Data, b: Bool, +t: Q.Ticket<A>, +fs: List<&2, Q.Ticket<A>>, +rs: List<&2, Q.Ticket<A>>, e: Laws.flights.cover(A, fs, rs)) ->
    Laws.flights.cover(A, Con{t, fs}, Q.remove.list.keep(A, b, t, rs)):
  match b:
    case True{}:
      cover.skip(A, t, fs, rs, e)
    case False{}:
      Laws.Keep{QL.Both{{==}, e}}

def cover.right(-A: Data, +fs: List<&2, Q.Ticket<A>>, +rs: List<&2, Q.Ticket<A>>, +i: Nat, e: Laws.flights.cover(A, fs, rs)) ->
    Laws.flights.cover(A, fs, Q.remove.list(A, rs, i)):
  match fs rs:
    case Nil{} Nil{}:
      Unit{}
    case Nil{} Con{r, rest}:
      match e:
    case Con{t, rest} Nil{}:
      Unit{}
    case Con{+t, +fs} Con{+r, +rs}:
      match e:
        case Laws.Skip{tail}:
          cover.skip(A, t, fs, Q.remove.list(A, Con{r, rs}, i), cover.right(A, fs, Con{r, rs}, i, tail))
        case Laws.Keep{QL.Both{eq, tail}}:
          %Equal.sym(Q.Ticket<A>, t, r, eq) : Laws.flights.cover(A, Con{_, fs}, Q.remove.list(A, Con{r, rs}, i))
          cover.right.keep(A, Nat.is_eq(Q.id(A, r), i), r, fs, Q.remove.list(A, rs, i), cover.right(A, fs, rs, i, tail))

def cover.both.skip(-A: Data, b: Bool, t: Q.Ticket<A>, +fs: List<&2, Q.Ticket<A>>, +rs: List<&2, Q.Ticket<A>>, e: Laws.flights.cover(A, fs, rs)) ->
    Laws.flights.cover(A, Q.remove.list.keep(A, b, t, fs), rs):
  match b:
    case True{}:
      e
    case False{}:
      cover.skip(A, t, fs, rs, e)

def cover.both.keep(-A: Data, b: Bool, +t: Q.Ticket<A>, +fs: List<&2, Q.Ticket<A>>, +rs: List<&2, Q.Ticket<A>>, e: Laws.flights.cover(A, fs, rs)) ->
    Laws.flights.cover(A, Q.remove.list.keep(A, b, t, fs), Q.remove.list.keep(A, b, t, rs)):
  match b:
    case True{}:
      e
    case False{}:
      Laws.Keep{QL.Both{{==}, e}}

def cover.both(-A: Data, +fs: List<&2, Q.Ticket<A>>, +rs: List<&2, Q.Ticket<A>>, +i: Nat, e: Laws.flights.cover(A, fs, rs)) ->
    Laws.flights.cover(A, Q.remove.list(A, fs, i), Q.remove.list(A, rs, i)):
  match fs rs:
    case Nil{} Nil{}:
      Unit{}
    case Nil{} Con{r, rest}:
      match e:
    case Con{t, rest} Nil{}:
      cover.nil(A, Q.remove.list(A, Con{t, rest}, i))
    case Con{+t, +fs} Con{+r, +rs}:
      match e:
        case Laws.Skip{tail}:
          cover.both.skip(A, Nat.is_eq(Q.id(A, t), i), t, Q.remove.list(A, fs, i), Q.remove.list(A, Con{r, rs}, i),
            cover.both(A, fs, Con{r, rs}, i, tail))
        case Laws.Keep{QL.Both{eq, tail}}:
          %Equal.sym(Q.Ticket<A>, t, r, eq) : Laws.flights.cover(A, Q.remove.list(A, Con{_, fs}, i), Q.remove.list(A, Con{r, rs}, i))
          cover.both.keep(A, Nat.is_eq(Q.id(A, r), i), r, Q.remove.list(A, fs, i), Q.remove.list(A, rs, i), cover.both(A, fs, rs, i, tail))

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

def taken.rest(-A: Data, tk: Q.Taken<A>) -> List<&2, Q.Ticket<A>>:
  Q.Taken{fs, m} = tk
  fs

def loop.take.none(-A: Data, +fs: List<&2, Q.Ticket<A>>, +original: List<&2, Q.Ticket<A>>, +i: Nat,
    eq: {Q.Taken{fs, None{}} == Q.take.list(A, original, i) : Q.Taken<A>}) ->
    {fs == original : List<&2, Q.Ticket<A>>}:
  %Equal.sym(Q.Taken<A>, Q.Taken{fs, None{}}, Q.take.list(A, original, i), eq) : loop.take.unchanged(A, _, original)
  loop.take.original(A, original, i)

def loop.finish.synced(~A: Data, tk: Q.Taken<A>, p: Res.Pool, +n: Nat, +heap: H.Heap<Q.Ticket<A>>, +old: List<&2, Q.Ticket<A>>,
    +ts: R.Tries(), +ds: R.Graves(A), +bs: R.Breakers(), +i: Nat, +original: List<&2, Q.Ticket<A>>,
    same: Laws.flights.cover(A, original, old), +eq: {tk == Q.take.list(A, original, i) : Q.Taken<A>}) ->
    loop.sync(A, R.loop.finished(~A, tk, p, R.State{Q.State{n, heap, old}, ts, ds, bs}, i)):
  match tk p:
    case Q.Taken{+fs, None{}} Res.Pool{o, c, h}:
      %Equal.sym(List<&2, Q.Ticket<A>>, fs, original, loop.take.none(A, fs, original, i, eq)) : Laws.flights.cover(A, _, old)
      same
    case Q.Taken{+fs, Some{+t}} Res.Pool{o, c, h}:
      %Equal.sym(Q.Taken<A>, Q.take.list(A, old, i), Q.Taken{Q.remove.list(A, old, i), Q.find.list(A, old, i)}, QL.take_equivalent(A, old, i)) :
        Laws.flights.cover(A, fs, Q.running(A, R.queue(A, R.step.completed(A, Q.complete.taken(A, _, n, heap), R.tries.drop(ts, i), ds, bs))))
      %Equal.sym(Q.Taken<A>, Q.Taken{fs, Some{t}}, Q.take.list(A, original, i), eq) : Laws.flights.cover(A, taken.rest(A, _), Q.remove.list(A, old, i))
      %Equal.sym(Q.Taken<A>, Q.take.list(A, original, i), Q.Taken{Q.remove.list(A, original, i), Q.find.list(A, original, i)}, QL.take_equivalent(A, original, i)) :
        Laws.flights.cover(A, taken.rest(A, _), Q.remove.list(A, old, i))
      cover.both(A, original, old, i, same)

def loop.retry.running(~A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, d: Nat) ->
    {Q.running(A, QL.requeue.state(A, Q.requeue.completed(~A, r, d))) == Q.running(A, QL.state(A, r)) : List<&2, Q.Ticket<A>>}:
  match r:
    case (Q.State{n, h, rs}, None{}):
      {==}
    case (Q.State{n, h, rs}, Some{Q.Ticket{i, old, x}}):
      {==}

def loop.requeued.running(-A: Data, r: Q.State<A> & Bool, +ts: R.Tries(), +ds: R.Graves(A), +bs: R.Breakers()) ->
    {Q.running(A, R.queue(A, R.step.requeued(A, r, ts, ds, bs))) == Q.running(A, QL.requeue.state(A, r)) : List<&2, Q.Ticket<A>>}:
  match r:
    case (q, b):
      {==}

def loop.completed.running(-A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, +ts: R.Tries(), +ds: R.Graves(A), +bs: R.Breakers()) ->
    {Q.running(A, R.queue(A, R.step.completed(A, r, ts, ds, bs))) == Q.running(A, QL.state(A, r)) : List<&2, Q.Ticket<A>>}:
  match r:
    case (q, t):
      {==}

def loop.retry.sync(~A: Data, tk: Q.Taken<A>, +p: Res.Pool, +s: R.State<A>, +i: Nat, +d: Nat,
    same: loop.sync(A, R.loop.finished(~A, tk, p, s, i))) ->
    loop.sync(A, R.loop.retried(~A, tk, p, s, i, d)):
  match tk p s:
    case Q.Taken{fs, None{}} Res.Pool{o, c, h} R.State{q, ts, ds, bs}:
      same
    case Q.Taken{+fs, Some{t}} Res.Pool{o, c, h} R.State{Q.State{+n, +heap, +rs}, +ts, +ds, +bs}:
      +q = {Q.State{n, heap, rs} : Q.State<A>}
      %Equal.sym(List<&2, Q.Ticket<A>>,
        Q.running(A, R.queue(A, R.step(~A, R.State{q, ts, ds, bs}, R.Requeue{i, d}))),
        Q.running(A, QL.requeue.state(A, Q.requeue(~A, i, d, q))),
        loop.requeued.running(A, Q.requeue(~A, i, d, q), R.tries.bump(ts, i), ds, bs)) : Laws.flights.cover(A, fs, _)
      %Equal.sym(List<&2, Q.Ticket<A>>,
        Q.running(A, QL.requeue.state(A, Q.requeue(~A, i, d, q))),
        Q.running(A, QL.state(A, Q.complete(A, i, q))),
        loop.retry.running(~A, Q.complete(A, i, q), d)) : Laws.flights.cover(A, fs, _)
      %loop.completed.running(A, Q.complete(A, i, q), R.tries.drop(ts, i), ds, bs) : Laws.flights.cover(A, fs, _)
      same

def loop.step.sync(~A: Data, +e: R.LoopEvent, s: R.Loop<A>, same: loop.sync(A, s)) -> loop.sync(A, R.loop.step(~A, e, s)):
  match e s:
    case R.Claim{+now} R.Loop{+p, R.State{Q.State{+n, +heap, +old}, +ts, +ds, +bs}, +fs}:
      loop.claim.synced(~A, R.pick(~A, p, R.State{Q.State{n, heap, old}, ts, ds, bs}, now), R.State{Q.State{n, heap, old}, ts, ds, bs}, fs, now,
        loop.claim.sync.evidence(~A, p, R.State{Q.State{n, heap, old}, ts, ds, bs}, fs, now, same))
    case R.Finish{+i} R.Loop{+p, R.State{Q.State{+n, +heap, +old}, +ts, +ds, +bs}, +fs}:
      loop.finish.synced(~A, Q.take.list(A, fs, i), p, n, heap, old, ts, ds, bs, i, fs, same, {==})
    case R.CancelFlight{+i} R.Loop{p, R.State{Q.State{n, heap, +old}, ts, ds, bs}, +fs}:
      cover.right(A, fs, old, i, same)
    case R.RetrySettle{+i, +d} R.Loop{+p, R.State{Q.State{+n, +heap, +old}, +ts, +ds, +bs}, +fs}:
      loop.retry.sync(~A, Q.take.list(A, fs, i), p, R.State{Q.State{n, heap, old}, ts, ds, bs}, i, d,
        loop.finish.synced(~A, Q.take.list(A, fs, i), p, n, heap, old, ts, ds, bs, i, fs, same, {==}))

def Laws.loop_flights(A, es, s, same):
  match es:
    case Nil{}:
      same
    case Con{+e, rest}:
      +s = s
      Laws.loop_flights(~A, rest, R.loop.step(~A, e, s), loop.step.sync(~A, e, s, same))

def Laws.loop_cancel_retains(A, i, p, s, fs):
  {==}

def Laws.loop_cancel_finish_releases(A, i, o, c, h, s, fs, t, found):
  Laws.loop_finish_releases(~A, i, o, c, h, R.step(~A, s, R.Cancel{i}), fs, t, found)


def Laws.loop_retry_settles(A, i, d, o, c, h, s, fs, t, found):
  +d = d
  +c = c
  +h = h
  +s = s
  %Equal.sym(Q.Taken<A>, Q.take.list(A, fs, i), Q.Taken{Q.remove.list(A, fs, i), Q.find.list(A, fs, i)}, QL.take_equivalent(A, fs, i)) :
    {R.loop.retried(~A, _, Res.Pool{o, c, h}, s, i, d) == R.Loop{R.loop.release(Res.release(Res.Pool{o, c, h}, Res.Grant{o, 1n})), R.step(~A, s, R.Requeue{i, d}), Q.remove.list(A, fs, i)} : R.Loop<A>}
  %Equal.sym(Maybe<&2, Q.Ticket<A>>, Q.find.list(A, fs, i), Some{t}, found) :
    {R.loop.retried(~A, Q.Taken{Q.remove.list(A, fs, i), _}, Res.Pool{o, c, h}, s, i, d) == R.Loop{R.loop.release(Res.release(Res.Pool{o, c, h}, Res.Grant{o, 1n})), R.step(~A, s, R.Requeue{i, d}), Q.remove.list(A, fs, i)} : R.Loop<A>}
  {==}

def Laws.loop_retry_pending(A, i, d, old, x, n, heap, rs, ts, ds, bs, o, c, h, fs, t, found):
  +old = old
  +ts = ts
  +ds = ds
  +bs = bs
  +o = o
  +c = c
  +h = h
  +fs = fs
  %Equal.sym(R.Loop<A>,
    R.loop.step(~A, R.RetrySettle{i, d}, R.Loop{Res.Pool{o, c, h}, R.State{Q.State{n, heap, Q.Ticket{i, old, x} <> rs}, ts, ds, bs}, fs}),
    R.Loop{R.loop.release(Res.release(Res.Pool{o, c, h}, Res.Grant{o, 1n})),
      R.step(~A, R.State{Q.State{n, heap, Q.Ticket{i, old, x} <> rs}, ts, ds, bs}, R.Requeue{i, d}), Q.remove.list(A, fs, i)},
    Laws.loop_retry_settles(~A, i, d, o, c, h, R.State{Q.State{n, heap, Q.Ticket{i, old, x} <> rs}, ts, ds, bs}, fs, t, found)) :
    {R.queue(A, R.loop.state(A, _)) == Q.State{n, H.Heap.push(~Q.Ticket<A>, ~(a => b => Q.le(A, a, b)), Q.Ticket{i, d, x}, heap), Q.remove.list(A, Q.Ticket{i, old, x} <> rs, i)} : Q.State<A>}
  %Equal.sym(Q.State<A> & Bool, Q.requeue(~A, i, d, Q.State{n, heap, Q.Ticket{i, old, x} <> rs}),
    (Q.State{n, H.Heap.push(~Q.Ticket<A>, ~(a => b => Q.le(A, a, b)), Q.Ticket{i, d, x}, heap), Q.remove.list(A, Q.Ticket{i, old, x} <> rs, i)}, True{}),
    QL.requeue_token(~A, i, d, old, x, n, heap, rs)) :
    {R.queue(A, R.step.requeued(A, _, R.tries.bump(ts, i), ds, bs)) == Q.State{n, H.Heap.push(~Q.Ticket<A>, ~(a => b => Q.le(A, a, b)), Q.Ticket{i, d, x}, heap), Q.remove.list(A, Q.Ticket{i, old, x} <> rs, i)} : Q.State<A>}
  {==}

def Laws.loop_retry_releases(A, i, d, o, c, h, s, fs, t, found):
  +o = o
  +c = c
  +h = h
  +s = s
  +fs = fs
  %Equal.sym(Res.Pool,
    R.loop.pool(A, R.loop.step(~A, R.RetrySettle{i, d}, R.Loop{Res.Pool{o, c, 1n+h}, s, fs})),
    R.loop.pool(A, R.loop.step(~A, R.Finish{i}, R.Loop{Res.Pool{o, c, 1n+h}, s, fs})),
    loop.retry.pool(~A, Q.take.list(A, fs, i), Res.Pool{o, c, 1n+h}, s, i, d)) : {_ == Res.Pool{o, c, h} : Res.Pool}
  Laws.loop_finish_releases(~A, i, o, c, h, s, fs, t, found)

def loop.retried.absent(~A: Data, tk: Q.Taken<A>, o: Nat, c: Nat, h: Nat, s: R.State<A>, +i: Nat, d: Nat, er: taken.rem_ok(A, tk, i)) ->
    QL.absent.list(A, R.loop.flights(A, R.loop.retried(~A, tk, Res.Pool{o, c, h}, s, i, d)), i):
  match tk:
    case Q.Taken{fs, None{}}:
      er
    case Q.Taken{fs, Some{t}}:
      er

def Laws.loop_retry_absent(A, i, d, s):
  match s:
    case R.Loop{Res.Pool{+o, +c, +h}, +s, +fs}:
      loop.retried.absent(~A, Q.take.list(A, fs, i), o, c, h, s, i, d, take_absent(A, fs, i))

def loop.retry.idle(~A: Data, +i: Nat, d: Nat, +s: R.Loop<A>, er: QL.absent.list(A, R.loop.flights(A, s), i)) ->
    {R.loop.step(~A, R.RetrySettle{i, d}, s) == s : R.Loop<A>}:
  match s:
    case R.Loop{Res.Pool{o, c, h}, s, fs}:
      %Equal.sym(Q.Taken<A>, Q.take.list(A, fs, i), Q.Taken{fs, None{}}, loop.take.idle(A, fs, i, er)) :
        {R.loop.retried(~A, _, Res.Pool{o, c, h}, s, i, d) == R.Loop{Res.Pool{o, c, h}, s, fs} : R.Loop<A>}
      {==}

def Laws.loop_retry_once(A, i, d, next, s):
  +d = d
  loop.retry.idle(~A, i, next, R.loop.step(~A, R.RetrySettle{i, d}, s), Laws.loop_retry_absent(~A, i, d, s))

def Laws.loop_retry_finish_once(A, i, d, s):
  +d = d
  loop.finish.idle(~A, i, R.loop.step(~A, R.RetrySettle{i, d}, s), Laws.loop_retry_absent(~A, i, d, s))

def Laws.loop_finish_retry_once(A, i, d, s):
  match s:
    case R.Loop{Res.Pool{+o, +c, +h}, +s, +fs}:
      loop.retry.idle(~A, i, d, R.loop.finished(~A, Q.take.list(A, fs, i), Res.Pool{o, c, h}, s, i),
        loop.finished.absent(~A, Q.take.list(A, fs, i), o, c, h, s, i, take_absent(A, fs, i)))

def loop.requeue.absent(~A: Data, +q: Q.State<A>, +i: Nat, +d: Nat, er: QL.absent.list(A, Q.running(A, q), i)) ->
    {Q.requeue(~A, i, d, q) == (q, False{}) : Q.State<A> & Bool}:
  match q:
    case Q.State{+n, +h, +rs}:
      %Equal.sym(Q.Taken<A>, Q.take.list(A, rs, i), Q.Taken{rs, None{}}, loop.take.idle(A, rs, i, er)) :
        {Q.requeue.completed(~A, Q.complete.taken(A, _, n, h), d) == (Q.State{n, h, rs}, False{}) : Q.State<A> & Bool}
      {==}

def loop.retry.cancelled(~A: Data, tk: Q.Taken<A>, p: Res.Pool, +s: R.State<A>, +i: Nat, +d: Nat) ->
    {R.queue(A, R.loop.state(A, R.loop.retried(~A, tk, p, R.step(~A, s, R.Cancel{i}), i, d))) ==
     R.queue(A, R.step(~A, s, R.Cancel{i})) : Q.State<A>}:
  match tk p s:
    case Q.Taken{fs, None{}} Res.Pool{o, c, h} R.State{Q.State{n, heap, rs}, ts, ds, bs}:
      {==}
    case Q.Taken{fs, Some{t}} Res.Pool{o, c, h} R.State{Q.State{+n, +heap, +rs}, +ts, +ds, +bs}:
      +q = {Q.State{n, heap, rs} : Q.State<A>}
      %Equal.sym(Q.State<A> & Bool, Q.requeue(~A, i, d, Q.cancel(~A, i, q)), (Q.cancel(~A, i, q), False{}),
        loop.requeue.absent(~A, Q.cancel(~A, i, q), i, d, QL.cancel_running_absent(~A, i, q))) :
        {R.queue(A, R.step.requeued(A, _, R.tries.bump(R.tries.drop(ts, i), i), R.dead.drop(~A, ds, i), bs)) == Q.cancel(~A, i, q) : Q.State<A>}
      {==}

def Laws.loop_cancel_retry_queue(A, i, d, s):
  match s:
    case R.Loop{p, +s, fs}:
      loop.retry.cancelled(~A, Q.take.list(A, fs, i), p, s, i, d)

# ---- decoded breaker tries


def read.next(-T: Data, -U: Data, -P: Maybe<&1, R.Rd & U> -> Data, none: P(None{}),
    m: Maybe<&1, R.Rd & T>, -f: T -> R.Dec(U), good: @x: T -> @r: R.Rd -> P(f(x)(r))) ->
    P(R.Dec.next(T, U, m, f)):
  match m:
    case None{}:
      none
    case Some{(r, x)}:
      good(x)(r)

def decoded.breakers(bs: R.Breakers()) -> Data:
  {Laws.breaker.wf(bs) == True{} : Bool}

def decoded.state(-A: Data, s: R.State<A>) -> Data:
  +Sigma<decoded.breakers(R.breakers(A, s)), _ => {Laws.dead.wf(~A, R.dead(A, s)) == True{} : Bool}>

def decoded.rec(-A: Data, r: R.Rec<A>) -> Data:
  match r:
    case R.Snap{s}:
      decoded.state(A, s)
    case R.Do{op}:
      Unit


def read.compose(-T: Data, -U: Data, -V: Data, -P: Maybe<&1, R.Rd & V> -> Data, none: P(None{}),
    m: Maybe<&1, R.Rd & T>, -f: T -> R.Dec(U), -g: U -> R.Dec(V),
    good: @x: T -> @r: R.Rd -> P(R.Dec.next(U, V, f(x)(r), g))) ->
    P(R.Dec.next(U, V, R.Dec.next(T, U, m, f), g)):
  match m:
    case None{}:
      none
    case Some{(r, x)}:
      good(x)(r)

def read.brks(-T: Data, -P: Maybe<&1, R.Rd & T> -> Data, +none: P(None{}),
    +fuel: Nat, more: Bool, +acc: R.Breakers(), wf: decoded.breakers(acc), -end: R.Breakers() -> R.Dec(T),
    good: @bs: R.Breakers() -> decoded.breakers(bs) -> @r: R.Rd -> P(end(bs)(r)), r: R.Rd) ->
    P(R.Dec.next(R.Breakers(), T, R.rd.brks(fuel, more, acc)(r), end)):
  match fuel more:
    case 0n b:
      none
    case 1n+f False{}:
      good(acc)(wf)(r)
    case 1n+f True{}:
      read.compose(String, R.Breakers(), T, P, none, R.rd.key()(r),
        k => R.Dec.bind(Retry.State, R.Breakers(), R.rd.brk(f), b =>
          R.Dec.bind(Bool, R.Breakers(), R.rd.flag(), m =>
            R.rd.brks(f, m, M.HMap.put(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, acc, k, b)))), end,
        +k => r => read.compose(Retry.State, R.Breakers(), T, P, none, R.rd.brk(f)(r),
          b => R.Dec.bind(Bool, R.Breakers(), R.rd.flag(), m =>
            R.rd.brks(f, m, M.HMap.put(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, acc, k, b))), end,
          +b => r => read.compose(Bool, R.Breakers(), T, P, none, R.rd.flag()(r),
            m => R.rd.brks(f, m, M.HMap.put(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, acc, k, b)), end,
            m => r => read.brks(T, P, none, f, m, M.HMap.put(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, acc, k, b),
              CL.hmap_put_wf(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, ~breaker.refl, ~breaker.sound, acc, wf, k, b), end, good, r))))


def read.wf.if(~A: Data, ok: Bool, +ds: R.Graves(A),
    valid: {R.rd.valid(~A, ds) == ok : Bool},
    -T: Data, -P: Maybe<&1, R.Rd & T> -> Data, none: P(None{}),
    -end: R.Graves(A) -> R.Dec(T),
    good: @xs: R.Graves(A) -> {Laws.dead.wf(~A, xs) == True{} : Bool} ->
      @r: R.Rd -> P(end(xs)(r)), r: R.Rd) ->
    P(R.Dec.next(R.Graves(A), T, R.rd.wf(A, ok, ds)(r), end)):
  match ok:
    case True{}:
      good(ds)(decoded.wf(~A, ds, valid))(r)
    case False{}:
      none

def read.wf(~A: Data, +ds: R.Graves(A),
    -T: Data, -P: Maybe<&1, R.Rd & T> -> Data, none: P(None{}),
    -end: R.Graves(A) -> R.Dec(T),
    good: @xs: R.Graves(A) -> {Laws.dead.wf(~A, xs) == True{} : Bool} ->
      @r: R.Rd -> P(end(xs)(r)), r: R.Rd) ->
    P(R.Dec.next(R.Graves(A), T, R.rd.wf(A, R.rd.valid(~A, ds), ds)(r), end)):
  read.wf.if(~A, R.rd.valid(~A, ds), ds, {==}, T, P, none, end, good, r)

def read.state(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>,
    -P: Maybe<&1, R.Rd & R.State<A>> -> Data, +none: P(None{}),
    some: @s: R.State<A> -> decoded.state(A, s) -> @r: R.Rd -> P(Some{(r, s)}), +fuel: Nat, r: R.Rd) ->
    P(R.rd.state(~A, ~pdec, fuel)(r)):
  read.next(Nat, R.State<A>, P, none, R.rd.u64()(r),
    n => (do R.Dec<R.State<A>>:
      +hf : Bool <- R.rd.flag()
      +h : H.Heap<Q.Ticket<A>> <- R.rd.heap(~A, ~pdec, fuel, hf)
      +rf : Bool <- R.rd.flag()
      +run : List<&2, Q.Ticket<A>> <- R.rd.run(~A, ~pdec, fuel, rf)
      +tf : Bool <- R.rd.flag()
      +ts : O.OMap<Nat, R.Try> <- R.rd.tries(fuel, tf)
      +dk : U32 <- R.rd.u32()
      +dt : R.Graves(A) <- R.rd.graves(~A, ~pdec, fuel, U32.is_eq(dk, 0), U32.is_eq(dk, 1), U32.is_eq(dk, 2))
      +ds : R.Graves(A) <- R.rd.wf(A, R.rd.valid(~A, dt), dt)
      +bf : Bool <- R.rd.flag()
      bs : R.Breakers() <- R.rd.brks(fuel, bf, M.HMap.new(String, Retry.State))
      return R.State{Q.State{n, h, run}, ts, ds, bs}),
    +n => r => read.next(Bool, R.State<A>, P, none, R.rd.flag()(r),
      hf => (do R.Dec<R.State<A>>:
        +h : H.Heap<Q.Ticket<A>> <- R.rd.heap(~A, ~pdec, fuel, hf)
        +rf : Bool <- R.rd.flag()
        +run : List<&2, Q.Ticket<A>> <- R.rd.run(~A, ~pdec, fuel, rf)
        +tf : Bool <- R.rd.flag()
        +ts : O.OMap<Nat, R.Try> <- R.rd.tries(fuel, tf)
        +dk : U32 <- R.rd.u32()
        +dt : R.Graves(A) <- R.rd.graves(~A, ~pdec, fuel, U32.is_eq(dk, 0), U32.is_eq(dk, 1), U32.is_eq(dk, 2))
        +ds : R.Graves(A) <- R.rd.wf(A, R.rd.valid(~A, dt), dt)
        +bf : Bool <- R.rd.flag()
        bs : R.Breakers() <- R.rd.brks(fuel, bf, M.HMap.new(String, Retry.State))
        return R.State{Q.State{n, h, run}, ts, ds, bs}),
      +hf => r => read.next(H.Heap<Q.Ticket<A>>, R.State<A>, P, none, R.rd.heap(~A, ~pdec, fuel, hf)(r),
        h => (do R.Dec<R.State<A>>:
          +rf : Bool <- R.rd.flag()
          +run : List<&2, Q.Ticket<A>> <- R.rd.run(~A, ~pdec, fuel, rf)
          +tf : Bool <- R.rd.flag()
          +ts : O.OMap<Nat, R.Try> <- R.rd.tries(fuel, tf)
          +dk : U32 <- R.rd.u32()
          +dt : R.Graves(A) <- R.rd.graves(~A, ~pdec, fuel, U32.is_eq(dk, 0), U32.is_eq(dk, 1), U32.is_eq(dk, 2))
          +ds : R.Graves(A) <- R.rd.wf(A, R.rd.valid(~A, dt), dt)
          +bf : Bool <- R.rd.flag()
          bs : R.Breakers() <- R.rd.brks(fuel, bf, M.HMap.new(String, Retry.State))
          return R.State{Q.State{n, h, run}, ts, ds, bs}),
        +h => r => read.next(Bool, R.State<A>, P, none, R.rd.flag()(r),
          rf => (do R.Dec<R.State<A>>:
            +run : List<&2, Q.Ticket<A>> <- R.rd.run(~A, ~pdec, fuel, rf)
            +tf : Bool <- R.rd.flag()
            +ts : O.OMap<Nat, R.Try> <- R.rd.tries(fuel, tf)
            +dk : U32 <- R.rd.u32()
            +dt : R.Graves(A) <- R.rd.graves(~A, ~pdec, fuel, U32.is_eq(dk, 0), U32.is_eq(dk, 1), U32.is_eq(dk, 2))
            +ds : R.Graves(A) <- R.rd.wf(A, R.rd.valid(~A, dt), dt)
            +bf : Bool <- R.rd.flag()
            bs : R.Breakers() <- R.rd.brks(fuel, bf, M.HMap.new(String, Retry.State))
            return R.State{Q.State{n, h, run}, ts, ds, bs}),
          +rf => r => read.next(List<&2, Q.Ticket<A>>, R.State<A>, P, none, R.rd.run(~A, ~pdec, fuel, rf)(r),
            run => (do R.Dec<R.State<A>>:
              +tf : Bool <- R.rd.flag()
              +ts : O.OMap<Nat, R.Try> <- R.rd.tries(fuel, tf)
              +dk : U32 <- R.rd.u32()
              +dt : R.Graves(A) <- R.rd.graves(~A, ~pdec, fuel, U32.is_eq(dk, 0), U32.is_eq(dk, 1), U32.is_eq(dk, 2))
              +ds : R.Graves(A) <- R.rd.wf(A, R.rd.valid(~A, dt), dt)
              +bf : Bool <- R.rd.flag()
              bs : R.Breakers() <- R.rd.brks(fuel, bf, M.HMap.new(String, Retry.State))
              return R.State{Q.State{n, h, run}, ts, ds, bs}),
            +run => r => read.next(Bool, R.State<A>, P, none, R.rd.flag()(r),
              tf => (do R.Dec<R.State<A>>:
                +ts : O.OMap<Nat, R.Try> <- R.rd.tries(fuel, tf)
                +dk : U32 <- R.rd.u32()
                +dt : R.Graves(A) <- R.rd.graves(~A, ~pdec, fuel, U32.is_eq(dk, 0), U32.is_eq(dk, 1), U32.is_eq(dk, 2))
                +ds : R.Graves(A) <- R.rd.wf(A, R.rd.valid(~A, dt), dt)
                +bf : Bool <- R.rd.flag()
                bs : R.Breakers() <- R.rd.brks(fuel, bf, M.HMap.new(String, Retry.State))
                return R.State{Q.State{n, h, run}, ts, ds, bs}),
              +tf => r => read.next(O.OMap<Nat, R.Try>, R.State<A>, P, none, R.rd.tries(fuel, tf)(r),
                ts => (do R.Dec<R.State<A>>:
                  +dk : U32 <- R.rd.u32()
                  +dt : R.Graves(A) <- R.rd.graves(~A, ~pdec, fuel, U32.is_eq(dk, 0), U32.is_eq(dk, 1), U32.is_eq(dk, 2))
                  +ds : R.Graves(A) <- R.rd.wf(A, R.rd.valid(~A, dt), dt)
                  +bf : Bool <- R.rd.flag()
                  bs : R.Breakers() <- R.rd.brks(fuel, bf, M.HMap.new(String, Retry.State))
                  return R.State{Q.State{n, h, run}, ts, ds, bs}),
                +ts => r => read.next(U32, R.State<A>, P, none, R.rd.u32()(r),
                  dk => (do R.Dec<R.State<A>>:
                    +dt : R.Graves(A) <- R.rd.graves(~A, ~pdec, fuel, U32.is_eq(dk, 0), U32.is_eq(dk, 1), U32.is_eq(dk, 2))
                    +ds : R.Graves(A) <- R.rd.wf(A, R.rd.valid(~A, dt), dt)
                    +bf : Bool <- R.rd.flag()
                    bs : R.Breakers() <- R.rd.brks(fuel, bf, M.HMap.new(String, Retry.State))
                    return R.State{Q.State{n, h, run}, ts, ds, bs}),
                  +dk => r => read.next(R.Graves(A), R.State<A>, P, none, R.rd.graves(~A, ~pdec, fuel, U32.is_eq(dk, 0), U32.is_eq(dk, 1), U32.is_eq(dk, 2))(r),
                    dt => (do R.Dec<R.State<A>>:
                      +ds : R.Graves(A) <- R.rd.wf(A, R.rd.valid(~A, dt), dt)
                      +bf : Bool <- R.rd.flag()
                      bs : R.Breakers() <- R.rd.brks(fuel, bf, M.HMap.new(String, Retry.State))
                      return R.State{Q.State{n, h, run}, ts, ds, bs}),
                    +dt => r => read.wf(~A, dt, R.State<A>, P, none,
                      ds => (do R.Dec<R.State<A>>:
                        +bf : Bool <- R.rd.flag()
                        bs : R.Breakers() <- R.rd.brks(fuel, bf, M.HMap.new(String, Retry.State))
                        return R.State{Q.State{n, h, run}, ts, ds, bs}),
                      +ds => dwf => r => read.next(Bool, R.State<A>, P, none, R.rd.flag()(r),
                        bf => (do R.Dec<R.State<A>>:
                          bs : R.Breakers() <- R.rd.brks(fuel, bf, M.HMap.new(String, Retry.State))
                          return R.State{Q.State{n, h, run}, ts, ds, bs}),
                        +bf => r => read.brks(R.State<A>, P, none, fuel, bf, M.HMap.new(String, Retry.State), {==},
                          bs => R.Dec.pure(R.State<A>, R.State{Q.State{n, h, run}, ts, ds, bs}),
                          bs => wf => r => some(R.State{Q.State{n, h, run}, ts, ds, bs})((wf, dwf))(r), r)), r))))))))))

def decoded.maybe(-T: Data, P: T -> Data, m: Maybe<&2, T>) -> Data:
  match m:
    case None{}:
      Unit
    case Some{x}:
      P(x)

def read.done.keep(~A: Data, keep: Bool, +s: R.State<A>, wf: decoded.state(A, s)) ->
    decoded.maybe(R.Rec<A>, r => decoded.rec(A, r),
      R.decode.snapped(A, Bool.pick(Maybe<&2, R.State<A>>, keep, Some{s}, None{}))):
  match keep:
    case True{}:
      wf
    case False{}:
      Unit{}

def read.done.some(~A: Data, +len: U32, +s: R.State<A>, wf: decoded.state(A, s), r: R.Rd) ->
    decoded.maybe(R.Rec<A>, x => decoded.rec(A, x),
      R.decode.snapped(A, R.rd.done(R.State<A>, len, Some{(r, s)}))):
  match r:
    case R.Rd{b, +at}:
      read.done.keep(~A, U32.is_eq(at, len), s, wf)

def decode.snap.valid(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, b: Bytes.Bytes) ->
    decoded.maybe(R.Rec<A>, r => decoded.rec(A, r), R.decode.snapped(A, R.decode.snap(~A, ~pdec, b))):
  match b:
    case Bytes.Bytes{+len, buf}:
      read.state(~A, ~pdec,
        m => decoded.maybe(R.Rec<A>, r => decoded.rec(A, r), R.decode.snapped(A, R.rd.done(R.State<A>, len, m))),
        Unit{}, +s => wf => r => read.done.some(~A, len, s, wf, r),
        U32.to_nat((len / 4 + 1 : U32)), R.Rd{Bytes.Bytes{len, buf}, 4})

def decode.did.valid(~A: Data, m: Maybe<&2, R.Op<A>>) ->
    decoded.maybe(R.Rec<A>, r => decoded.rec(A, r), R.decode.did(A, m)):
  match m:
    case None{}:
      Unit{}
    case Some{op}:
      Unit{}

def decode.rec.if.valid(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, snap: Bool, b: Bytes.Bytes) ->
    decoded.maybe(R.Rec<A>, r => decoded.rec(A, r), R.decode.rec.if(~A, ~pdec, snap, b)):
  match snap:
    case True{}:
      decode.snap.valid(~A, ~pdec, b)
    case False{}:
      decode.did.valid(~A, R.decode(~A, ~pdec, b))

def decode.rec.tag.valid(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, pair: Bytes.Bytes & U32) ->
    decoded.maybe(R.Rec<A>, r => decoded.rec(A, r), R.decode.rec.tag(~A, ~pdec, pair)):
  match pair:
    case (b, +tag):
      decode.rec.if.valid(~A, ~pdec, U32.is_eq(tag, 14), b)

def decode.rec.valid(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, b: Bytes.Bytes) ->
    decoded.maybe(R.Rec<A>, r => decoded.rec(A, r), R.decode.rec(~A, ~pdec, b)):
  decode.rec.tag.valid(~A, ~pdec, R.get.u32(Bytes.get.u32le(b, 0)))

def snapshot.state.wf(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, b: Bytes.Bytes, +s: R.State<A>,
    e: {R.decode.rec(~A, ~pdec, b) == Some{R.Snap{s}} : Maybe<&2, R.Rec<A>>}) ->
    decoded.state(A, s):
  %e : decoded.maybe(R.Rec<A>, r => decoded.rec(A, r), _)
  decode.rec.valid(~A, ~pdec, b)

def decoded.breaker(~A: Data, +s: R.State<A>, wf: decoded.state(A, s)) ->
    {Laws.breaker.wf(R.breakers(A, s)) == True{} : Bool}:
  match wf:
    case (bw, dw):
      bw

def decoded.dead(~A: Data, +s: R.State<A>, wf: decoded.state(A, s)) ->
    {Laws.dead.wf(~A, R.dead(A, s)) == True{} : Bool}:
  match wf:
    case (bw, dw):
      dw

def snapshot.breaker.wf(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, b: Bytes.Bytes, +s: R.State<A>,
    e: {R.decode.rec(~A, ~pdec, b) == Some{R.Snap{s}} : Maybe<&2, R.Rec<A>>}) ->
    {Laws.breaker.wf(R.breakers(A, s)) == True{} : Bool}:
  decoded.breaker(~A, s, snapshot.state.wf(~A, ~pdec, b, s, e))

def calm.absent(es: List<&2, M.Entry<String, Retry.State>>, +k: String) ->
    {CL.hmap_absent(~String, ~Retry.State, ~R.brk.eq, R.calm.entries(es), k) ==
     CL.hmap_absent(~String, ~Retry.State, ~R.brk.eq, es, k) : Bool}:
  match es:
    case Nil{}:
      {==}
    case Con{M.Entry{+j, b}, +rest}:
      %calm.absent(rest, k) : {Bool.not(R.brk.eq(k, j)) && CL.hmap_absent(~String, ~Retry.State, ~R.brk.eq, R.calm.entries(rest), k) == Bool.not(R.brk.eq(k, j)) && _ : Bool}
      {==}

def calm.distinct(es: List<&2, M.Entry<String, Retry.State>>) ->
    {CL.hmap_distinct(~String, ~Retry.State, ~R.brk.eq, R.calm.entries(es)) ==
     CL.hmap_distinct(~String, ~Retry.State, ~R.brk.eq, es) : Bool}:
  match es:
    case Nil{}:
      {==}
    case Con{M.Entry{+j, b}, +rest}:
      %calm.absent(rest, j) : {CL.hmap_absent(~String, ~Retry.State, ~R.brk.eq, R.calm.entries(rest), j) && CL.hmap_distinct(~String, ~Retry.State, ~R.brk.eq, R.calm.entries(rest)) == _ && CL.hmap_distinct(~String, ~Retry.State, ~R.brk.eq, rest) : Bool}
      %calm.distinct(rest) : {CL.hmap_absent(~String, ~Retry.State, ~R.brk.eq, R.calm.entries(rest), j) && CL.hmap_distinct(~String, ~Retry.State, ~R.brk.eq, R.calm.entries(rest)) == CL.hmap_absent(~String, ~Retry.State, ~R.brk.eq, R.calm.entries(rest), j) && _ : Bool}
      {==}

def calm.hashed(es: List<&2, M.Entry<String, Retry.State>>, +h: U32) ->
    {CL.hmap_hashed(~String, ~Retry.State, ~R.brk.hash, R.calm.entries(es), h) ==
     CL.hmap_hashed(~String, ~Retry.State, ~R.brk.hash, es, h) : Bool}:
  match es:
    case Nil{}:
      {==}
    case Con{M.Entry{+j, b}, +rest}:
      %calm.hashed(rest, h) : {U32.is_eq(h, R.brk.hash(j)) && CL.hmap_hashed(~String, ~Retry.State, ~R.brk.hash, R.calm.entries(rest), h) == U32.is_eq(h, R.brk.hash(j)) && _ : Bool}
      {==}

def calm.map.wf(+n: Nat, bs: R.Breakers()) ->
    {CL.hmap_wf.go(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, n, R.calm.map(bs)) ==
     CL.hmap_wf.go(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, n, bs) : Bool}:
  match n bs:
    case 0n M.HNil{}:
      {==}
    case 0n M.HLeaf{h, es}:
      calm.distinct(es)
    case 0n M.HBranch{lo, hi}:
      {==}
    case 1n+p M.HNil{}:
      {==}
    case 1n+p M.HLeaf{+h, +es}:
      %calm.hashed(es, h) : {CL.hmap_hashed(~String, ~Retry.State, ~R.brk.hash, R.calm.entries(es), h) && CL.hmap_distinct(~String, ~Retry.State, ~R.brk.eq, R.calm.entries(es)) == _ && CL.hmap_distinct(~String, ~Retry.State, ~R.brk.eq, es) : Bool}
      %calm.distinct(es) : {CL.hmap_hashed(~String, ~Retry.State, ~R.brk.hash, R.calm.entries(es), h) && CL.hmap_distinct(~String, ~Retry.State, ~R.brk.eq, R.calm.entries(es)) == CL.hmap_hashed(~String, ~Retry.State, ~R.brk.hash, R.calm.entries(es), h) && _ : Bool}
      {==}
    case 1n+p M.HBranch{+lo, +hi}:
      %calm.map.wf(p, lo) : {CL.hmap_wf.go(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, p, R.calm.map(lo)) && CL.hmap_wf.go(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, p, R.calm.map(hi)) == _ && CL.hmap_wf.go(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, p, hi) : Bool}
      %calm.map.wf(p, hi) : {CL.hmap_wf.go(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, p, R.calm.map(lo)) && CL.hmap_wf.go(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, p, R.calm.map(hi)) == CL.hmap_wf.go(~String, ~Retry.State, ~R.brk.hash, ~R.brk.eq, p, R.calm.map(lo)) && _ : Bool}
      {==}

def calm.breaker.wf(~A: Data, +s: R.State<A>, wf: decoded.breakers(R.breakers(A, s))) ->
    {Laws.breaker.wf(R.breakers(A, R.calm(A, s))) == True{} : Bool}:
  match s:
    case R.State{q, ts, ds, +bs}:
      %Equal.sym(Bool, Laws.breaker.wf(R.calm.map(bs)), Laws.breaker.wf(bs), calm.map.wf(32n, bs)) :
        { _ == True{} : Bool}
      wf


def snapshot.recovered.breaker.wf(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, b: Bytes.Bytes, +s: R.State<A>,
    e: {R.decode.rec(~A, ~pdec, b) == Some{R.Snap{s}} : Maybe<&2, R.Rec<A>>}) ->
    {Laws.breaker.wf(R.breakers(A, R.calm(A, s))) == True{} : Bool}:
  calm.breaker.wf(~A, s, snapshot.breaker.wf(~A, ~pdec, b, s, e))

def snapshot.dead.wf(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, b: Bytes.Bytes, +s: R.State<A>,
    e: {R.decode.rec(~A, ~pdec, b) == Some{R.Snap{s}} : Maybe<&2, R.Rec<A>>}) ->
    {Laws.dead.wf(~A, R.dead(A, s)) == True{} : Bool}:
  decoded.dead(~A, s, snapshot.state.wf(~A, ~pdec, b, s, e))

def calm.dead(~A: Data, s: R.State<A>) ->
    {R.dead(A, R.calm(A, s)) == R.dead(A, s) : R.Graves(A)}:
  match s:
    case R.State{q, ts, ds, bs}:
      {==}

def calm.dead.wf(~A: Data, +s: R.State<A>, wf: {Laws.dead.wf(~A, R.dead(A, s)) == True{} : Bool}) ->
    {Laws.dead.wf(~A, R.dead(A, R.calm(A, s))) == True{} : Bool}:
  %Equal.sym(R.Graves(A), R.dead(A, R.calm(A, s)), R.dead(A, s), calm.dead(~A, s)) :
    {Laws.dead.wf(~A, _) == True{} : Bool}
  wf

def snapshot.recovered.dead.wf(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, b: Bytes.Bytes, +s: R.State<A>,
    e: {R.decode.rec(~A, ~pdec, b) == Some{R.Snap{s}} : Maybe<&2, R.Rec<A>>}) ->
    {Laws.dead.wf(~A, R.dead(A, R.calm(A, s))) == True{} : Bool}:
  calm.dead.wf(~A, s, snapshot.dead.wf(~A, ~pdec, b, s, e))
