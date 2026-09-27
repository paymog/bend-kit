import Base
import ./concurrency.bend as Conc

def inc(x: U32) -> U32:
  (x + 1 : U32)

def add(a: U32, b: U32) -> U32:
  (a + b : U32)

def cat(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, xs, ys)

def arr() -> Array<U32>:
  ANode{ANode{ALeaf{1}, ALeaf{2}}, ANode{ALeaf{3}, ALeaf{4}}}

def runs() -> Array<List<&2, U32>>:
  ANode{ANode{ALeaf{[1]}, ALeaf{[2, 3]}}, ANode{ALeaf{Nil{}}, ALeaf{[4]}}}

# par_map is List.map, in order, for any worker count.
law map_empty:
  {Conc.par_map(~U32, ~U32, ~inc, 8, Nil{}) == Nil{} : List<U32>}

law map_zero_workers:
  {Conc.par_map(~U32, ~U32, ~inc, 0, [1, 2, 3]) == [2, 3, 4] : List<U32>}

law map_one_worker:
  {Conc.par_map(~U32, ~U32, ~inc, 1, [1, 2, 3, 4, 5]) == [2, 3, 4, 5, 6] : List<U32>}

# Three workers round down to two parts; the split is uneven.
law map_uneven:
  {Conc.par_map(~U32, ~U32, ~inc, 3, [1, 2, 3, 4, 5]) == [2, 3, 4, 5, 6] : List<U32>}

law map_eight_workers:
  {Conc.par_map(~U32, ~U32, ~inc, 8, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
    == [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] : List<U32>}

# More workers than elements leaves some parts empty.
law map_more_workers:
  {Conc.par_map(~U32, ~U32, ~inc, 16, [1, 2, 3]) == [2, 3, 4] : List<U32>}

law reduce_sum:
  {Conc.par_reduce(~U32, ~add, 4, 0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]) == 55 : U32}

law reduce_empty:
  {Conc.par_reduce(~U32, ~add, 8, 0, Nil{}) == 0 : U32}

# cat is associative but not commutative, so the parts combine in order.
law reduce_order:
  {Conc.par_reduce(~List<&2, U32>, ~cat, 4, Nil{}, [[1], [2, 3], Nil{}, [4], [5]])
    == [1, 2, 3, 4, 5] : List<&2, U32>}

law map_array:
  {Array.to_list(~U32, Conc.par_map.array(~U32, ~U32, ~inc, 4, arr())) == [2, 3, 4, 5] : List<U32>}

law map_array_one_worker:
  {Array.to_list(~U32, Conc.par_map.array(~U32, ~U32, ~inc, 1, arr())) == [2, 3, 4, 5] : List<U32>}

law reduce_array_sum:
  {Conc.par_reduce.array(~U32, ~add, 8, arr()) == 10 : U32}

law reduce_array_order:
  {Conc.par_reduce.array(~List<&2, U32>, ~cat, 2, runs()) == [1, 2, 3, 4] : List<&2, U32>}
