# collections

Ordered maps, a hash map, a vector, a deque, and a binary heap. Import the file you call. `collections.bend` imports the others and does not re-export them.

```bend
import bend-kit-collections@0.1.2.0/omap.bend as OMap
import bend-kit-collections@0.1.2.0/hmap.bend as HMap
import bend-kit-collections@0.1.2.0/vec.bend as Vec
import bend-kit-collections@0.1.2.0/deque.bend as Deque
import bend-kit-collections@0.1.2.0/heap.bend as Heap
```

Keys and values are `Data`. A comparator or hash is a template, so you can pass `U32.cmp` or your own def.

## Which file

`omap.bend` is a weight-balanced tree. `OMap.put`, `get`, and `del` take `~cmp` and cost O(log n) comparisons. `OSet` is `OMap` with `Unit` values. `OMap.put` replaces the value at an equal key.

`hmap.bend` is a hash trie. `HMap.put` takes `~hash` and `~eq`. Equal keys must hash alike. Collisions are stored and compared with `~eq`.

`vec.bend` is a growable array. `push` doubles and is amortized O(1). `get` and `pop` return `None` at or past the length. `set` at that index leaves the vector unchanged.

`deque.bend` pushes and pops at either end in amortized O(1). A `Data` deque can be copied with `+`.

`heap.bend` is a binary heap. `push` and `pop` take `~le` and are amortized O(log n) when the heap is used once. `peek` and `size` are O(1).

`nat_order.bend` is lemmas for the ordered-map proofs, not a collection. It and `PROOF.bend` take generic Nat and Bool lemmas from `bend-mathlib@0.7.2.0`. The published files do not import it.
