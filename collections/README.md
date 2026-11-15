# collections

Ordered maps, a hash map, a vector, a deque, and a binary heap. Import the file you call. `collections.bend` imports the others and does not re-export them.

```bend
import bend-kit-collections@0.1.5.0/omap.bend as OMap
import bend-kit-collections@0.1.5.0/hmap.bend as HMap
import bend-kit-collections@0.1.5.0/vec.bend as Vec
import bend-kit-collections@0.1.5.0/deque.bend as Deque
import bend-kit-collections@0.1.5.0/heap.bend as Heap
import bend-kit-collections@0.1.5.0/order.bend as Order
```

Keys and values are `Data`. A comparator or hash is a template, so you can pass `U32.cmp` or your own def.

## Which file

`omap.bend` is a weight-balanced tree. `OMap.put`, `get`, and `del` take `~cmp` and cost O(log n) comparisons. `OSet` is `OMap` with `Unit` values. `OMap.put` replaces the value at an equal key.

`hmap.bend` is a hash trie. `HMap.put` takes `~hash` and `~eq`. Equal keys must hash alike. Collisions are stored and compared with `~eq`.

`vec.bend` is a growable array. `Vec.push` doubles a full buffer and is amortized O(1). `Vec.get` returns the vector beside `None` at or past its length. `Vec.pop` takes no index and returns the vector beside `None` when it is empty. `Vec.set` at or past the length leaves the vector unchanged.

`deque.bend` pushes and pops at either end in amortized O(1). A `Data` deque can be copied with `+`.

`heap.bend` is a binary heap. `push` and `pop` take `~le` and are amortized O(log n) when the heap is used once. `peek` and `size` are O(1).

`order.bend` holds comparators. `Order.string` orders strings by code point, with a prefix before its extensions. It gives the same answers as `String.order`, but it does not rebuild the two strings on each call. Pass it as `~Order.string` to `OMap` or a sort.

## Laws

`collections.bend` imports `PROOF.bend`, so `LAWS.bend` and `PROOF.bend` publish with the package. A dependent package can cite a law in its own proofs: import `bend-kit-collections@0.1.5.0/LAWS.bend` for the claim and `bend-kit-collections@0.1.5.0/PROOF.bend` for its proof. The proofs hold for the `OMap` and `Order` of the same version only.

The `OMap` laws `omap_put_searchtree`, `omap_get_put_same`, and `omap_get_put_other_key` hold for any comparator that is a total order. They take its `refl`, `eq`, `flip`, and `trans` facts as templates. `order_string_refl`, `order_string_eq`, `order_string_flip`, and `order_string_trans` are those facts for `Order.string`.

`nat_order.bend` contains lemmas for the ordered-map proofs, not a collection. It and `PROOF.bend` take generic Nat and Bool lemmas from `bend-mathlib@0.8.0.0`, and `PROOF.bend` takes the `U32` comparison laws from its `u32.bend`.

## API

Import `omap.bend` as `OMap` for this call.

| def | returns |
|---|---|
| `OMap.OMap.keys(K, V, m) -> List<&2, K>` | All keys in comparator order. `K` and `V` are `Data` types. |

