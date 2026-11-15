# crdt

Replicated data types with proved merges. The package has two grow-only counters (G-Counters), as in Shapiro et al., "A comprehensive study of Convergent and Commutative Replicated Data Types" (2011). `GCounter` keys replicas by small dense indices. `KCounter` keys them by sparse IDs of any `Data` type, such as random 32-bit node IDs or `String` names. Each replica counts its own events. Replicas exchange whole states in any order, and every replica that has seen the same states holds the same counter.

```bend
import bend-kit-crdt@0.2.0.0/crdt.bend as Crdt
```

It imports `bend-kit-cbor@0.3.0.0` and `bend-kit-bytes@0.3.3.0` for the wire form.

## State

A state is a `List<&2, U32>`. Entry `i` is the count of replica `i`, and a missing entry counts as 0. Replica IDs are small `Nat` indices, 0 to n - 1, because the list is dense. A state is valid when its last entry is not 0, so each count vector has one form. `new`, `inc`, `merge`, and `decode` give only valid states.

## Example

Replica 0 receives the state of replica 1 twice.

```bend
import Base
import bend-kit-crdt@0.2.0.0/crdt.bend as Crdt

def total(m: Maybe<&2, U32>) -> String:
  match m:
    case Some{v}:
      U32.show(v)
    case None{}:
      "overflow"

def main() -> IO(Unit):
  # Replica 0 counted 2 events, and replica 1 counted 5.
  +a = {[2] : List<&2, U32>}
  +b = {[0, 5] : List<&2, U32>}
  # A merges B's state twice; the repeat changes nothing.
  +x = Crdt.GCounter.merge(Crdt.GCounter.merge(a, b), b)
  IO.print(total(Crdt.GCounter.value(x)))
```

It prints `7`. [check.bend](check.bend) runs three replicas that send CBOR states with a duplicate, a stale copy, and reordered updates, once with `GCounter` and once with `KCounter` IDs 7, 1000000, and 4000000000.

## API

Import `crdt.bend` as `Crdt`.

| def | result |
|---|---|
| `GCounter.new()` | the empty state |
| `GCounter.inc(s, i: Nat)` | `Maybe`: `s` with 1 added to replica `i`; `None` when that count is 4294967295 |
| `GCounter.get(s, i: Nat)` | `U32`: the count of replica `i` |
| `GCounter.merge(a, b)` | the component-wise maximum |
| `GCounter.merge_all(xs)` | the merge of a list of states |
| `GCounter.value(s)` | `Maybe<&2, U32>`: the sum of the counts; `None` when the sum does not fit in a `U32` |
| `GCounter.le(a, b)` | `Bool`: `a` is at most `b` in each entry |
| `GCounter.valid(s)` | `Bool`: `s` has no trailing 0 |
| `GCounter.to_cbor(s)`, `GCounter.encode(s)` | a CBOR array of unsigned integers, as a `Cbor.Val` or as `Bytes`; `encode` is always `Some` |
| `GCounter.from_cbor(v, cap: U32)`, `GCounter.decode(b, cap: U32)` | `Maybe`: a valid state with at most `cap` entries |

Counts are exact `U32` values. An increment or a total that would pass 4294967295 returns `None`; nothing wraps.

The wire form is a CBOR array. Item `i` is the count of replica `i`. `decode` returns `None` for bytes that are not CBOR, a value that is not an array, an item that is not an unsigned integer below 2^32, a trailing 0, or more than `cap` items.

## Laws

`LAWS.bend` states these for every state, and `PROOF.bend` proves them:

| law | claim |
|---|---|
| `merge_comm`, `merge_assoc`, `merge_idem` | merge is commutative, associative, and idempotent |
| `merge_upper_l`, `merge_upper_r`, `merge_least` | merge is the least upper bound in the component-wise order `le` |
| `inc_grows` | a successful increment gives a state at least `s` |
| `merge_valid`, `inc_valid` | merge and increment keep a state valid |
| `converge` | if each state in `xs` is in `ys` and each state in `ys` is in `xs`, `merge_all(xs) == merge_all(ys)` |
| `from_cbor_valid` | `from_cbor` returns only valid states |
| `cbor_roundtrip` | a valid state with at most `cap` entries decodes to itself |

The equalities are equalities of lists. Valid states have one form, so no separate equivalence is needed. `converge` is the reason duplicates and reordering do not matter: a replica's state is the merge of the states it has received, and that merge does not depend on order or repeats.

## KCounter

A `KCounter<K>` is a list of `(id, count)` entries: `KNil{}` or `KCon{id, count, rest}`. Every function takes the ID type `~K` and a comparator `~cmp: K -> K -> Cmp` as templates. A state is valid when its IDs are strictly ascending under `cmp` and no count is 0, so each counter has one form. `new`, `inc`, `merge`, and `decode` give only valid states. A state holds one entry per replica that has counted, so an ID of 1,000,000 costs one entry, not 1,000,000.

Replica 7 counts 2 events. Replica 4000000000 counts 1 event and merges the state of replica 7 twice.

```bend
import Base
import bend-kit-crdt@0.2.0.0/crdt.bend as Crdt

def total(m: Maybe<&2, U32>) -> String:
  match m:
    case Some{v}:
      U32.show(v)
    case None{}:
      "overflow"

def main() -> IO(Unit):
  +a = {Crdt.KCon{7, 2, Crdt.KNil{}} : Crdt.KCounter<U32>}
  +b = {Crdt.KCon{4000000000, 1, Crdt.KNil{}} : Crdt.KCounter<U32>}
  +x = Crdt.KCounter.merge(~U32, ~U32.cmp, Crdt.KCounter.merge(~U32, ~U32.cmp, b, a), a)
  IO.print(total(Crdt.KCounter.value(U32, x)))
```

It prints `3`.

| def | result |
|---|---|
| `KCounter.new(K)` | the empty state |
| `KCounter.inc(~K, ~cmp, s, k)` | `Maybe`: `s` with 1 added to replica `k`; `None` when that count is 4294967295 |
| `KCounter.get(~K, ~cmp, s, k)` | `U32`: the count of replica `k`, 0 when it is missing |
| `KCounter.merge(~K, ~cmp, a, b)` | the entry-wise maximum, in one pass over both states |
| `KCounter.merge_all(~K, ~cmp, xs)` | the merge of a list of states |
| `KCounter.value(K, s)` | `Maybe<&2, U32>`: the sum of the counts; `None` when the sum does not fit in a `U32` |
| `KCounter.le(~K, ~cmp, a, b)` | `Bool`: each count in `a` is at most the count of its ID in `b` |
| `KCounter.valid(~K, ~cmp, s)` | `Bool`: IDs strictly ascend and no count is 0 |
| `KCounter.to_cbor(~K, ~enc, s)`, `KCounter.encode(~K, ~enc, s)` | a CBOR map from `enc(id)` to count, in ID order, as a `Cbor.Val` or as `Bytes`; `encode` is `None` only when `enc` gives a value with no CBOR form |
| `KCounter.from_cbor(~K, ~cmp, ~dec, v, cap: U32)`, `KCounter.decode(~K, ~cmp, ~dec, b, cap: U32)` | `Maybe`: a valid state with at most `cap` entries |

`decode` returns `None` for bytes that are not CBOR, a value that is not a map, a key that `dec` refuses, a count that is not an unsigned integer below 2^32, a count of 0, keys that are not strictly ascending under `cmp` (this also rejects a repeated key), or more than `cap` entries.

`KCounter` states are not canonical in general: an unsorted list or one with a repeated ID still has a meaning. `get` reads the largest count under any ID that `cmp` makes equal to `k`. So the join laws compare two states by `get` at every ID, not as lists. They hold for every state, valid or not, and for every comparator with the order facts that each law names.

| law | claim |
|---|---|
| `k_merge_comm`, `k_merge_assoc`, `k_merge_idem` | for every ID `k`, `get` of each side is equal |
| `k_merge_upper_l`, `k_merge_upper_r`, `k_merge_least` | merge is the least upper bound in the order `le` |
| `k_inc_grows` | a successful increment gives a state at least `s` |
| `k_merge_valid`, `k_inc_valid` | merge and increment keep a state valid |
| `k_converge` | if each state in `xs` is in `ys` and each state in `ys` is in `xs`, `get` of `merge_all(xs)` and `merge_all(ys)` agree at every ID |
| `k_from_cbor_valid` | `from_cbor` returns only valid states, for every `dec` |
| `k_cbor_roundtrip` | a valid state with at most `cap` entries decodes to itself when `dec(enc(x)) == Some{x}` |

The order facts are `refl` (`cmp(x, x) == EQ`), `eq` (`cmp(x, y) == EQ` gives `x == y`), and `flip` (`cmp(y, x)` is the flip of `cmp(x, y)`). `U32.cmp` and a lexicographic `String` comparator have all three.

## Trust boundary

The proofs cover the pure functions. They do not cover the network or storage. Convergence holds under these conditions:

- Every replica eventually receives every state that the others send. The package does not retry, deliver, or persist.
- Each replica has one ID and increments only its own entry. Two writers on one ID can lose increments.
- Replicas are not malicious. A replica can send a state with any counts, and a receiver merges it.
- For `KCounter`, `cmp` is a total order on IDs and `dec` reads exactly the IDs that `enc` writes. The proofs take these as hypotheses; the code cannot check them.

The package does not delete entries, compact states, or retire replicas.

## Bench

`bench/` times increments and merges among 16 replicas against `crdts` in Rust, once with dense IDs and once with sparse `KCounter` IDs. See [bench/README.md](bench/README.md).

