# crdt

Replicated data types with proved merges. The package has one type: a grow-only counter (G-Counter), as in Shapiro et al., "A comprehensive study of Convergent and Commutative Replicated Data Types" (2011). Each replica counts its own events. Replicas exchange whole states in any order, and every replica that has seen the same states holds the same counter.

```bend
import bend-kit-crdt@0.1.0.0/crdt.bend as Crdt
```

It imports `bend-kit-cbor@0.2.0.0` and `bend-kit-bytes@0.3.2.0` for the wire form.

## State

A state is a `List<&2, U32>`. Entry `i` is the count of replica `i`, and a missing entry counts as 0. Replica IDs are small `Nat` indices, 0 to n - 1, because the list is dense. A state is valid when its last entry is not 0, so each count vector has one form. `new`, `inc`, `merge`, and `decode` give only valid states.

## Example

Replica 0 receives the state of replica 1 twice.

```bend
import Base
import bend-kit-crdt@0.1.0.0/crdt.bend as Crdt

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

It prints `7`. [check.bend](check.bend) runs three replicas that send CBOR states with a duplicate, a stale copy, and reordered updates.

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

## Trust boundary

The proofs cover the pure functions. They do not cover the network or storage. Convergence holds under these conditions:

- Every replica eventually receives every state that the others send. The package does not retry, deliver, or persist.
- Each replica has one ID and increments only its own entry. Two writers on one ID can lose increments.
- Replicas are not malicious. A replica can send a state with any counts, and a receiver merges it.

The package does not delete entries, compact states, or retire replicas.

## Bench

`bench/` times increments and merges among 16 replicas against `crdts` in Rust. See [bench/README.md](bench/README.md).
