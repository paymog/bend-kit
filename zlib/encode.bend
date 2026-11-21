import Base
import bend-kit-bits@0.3.0.0/bits.bend as Bits

type Token is Data:
  Lit{s: U32}
  Copy{ls: U32, le: U32, lv: U32, ds: U32, de: U32, dv: U32}

type Tree is Data:
  Leaf{s: U32}
  Branch{a: Tree, b: Tree}

type Weighted is Data:
  Weighted{weight: U32, tree: Tree}

def weight(x: Weighted) -> U32:
  Weighted{w, t} = x
  w

def insert.pick(before: Bool, x: Weighted, h: Weighted, t: List<&2, Weighted>, rest: Unit -> List<&2, Weighted>) -> List<&2, Weighted>:
  match before:
    case True{}:
      Con{x, Con{h, t}}
    case False{}:
      Con{h, rest(Unit{})}

def insert(xs: List<&2, Weighted>, +x: Weighted) -> List<&2, Weighted>:
  match xs:
    case Nil{}:
      Con{x, Nil{}}
    case Con{+h, +t}:
      insert.pick(U32.is_le(weight(x), weight(h)), x, h, t, u => insert(t, x))

def leaf.add(nonzero: Bool, xs: List<&2, Weighted>, +w: U32, +i: U32) -> List<&2, Weighted>:
  match nonzero:
    case True{}:
      insert(xs, Weighted{w, Leaf{i}})
    case False{}:
      xs

def leaves(freq: List<&2, U32>, +i: U32, xs: List<&2, Weighted>) -> List<&2, Weighted>:
  match freq:
    case Nil{}:
      xs
    case Con{+w, t}:
      leaves(t, (i + 1 : U32), leaf.add(U32.is_ne(w, 0), xs, w, i))

def merge(fuel: Nat, xs: List<&2, Weighted>) -> Tree:
  match fuel:
    case 0n:
      Leaf{0}
    case 1n+p:
      match xs:
        case Nil{}:
          Leaf{0}
        case Con{Weighted{+wa, a}, t}:
          match t:
            case Nil{}:
              a
            case Con{Weighted{+wb, b}, rest}:
              merge(p, insert(rest, Weighted{(wa + wb : U32), Branch{a, b}}))

def depths(t: Tree, +depth: U32, a: Array<U32>) -> Array<U32>:
  match t:
    case Leaf{+s}:
      Array.set(U32, a, s, depth)
    case Branch{l, r}:
      depths(r, (depth + 1 : U32), depths(l, (depth + 1 : U32), a))

def copy.list(xs: List<U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{h, copy.list(t)}

def shrink(freq: List<&2, U32>) -> List<&2, U32>:
  match freq:
    case Nil{}:
      Nil{}
    case Con{+w, t}:
      Con{((w + 1) >> 1n : U32), shrink(t)}

def tree.lens(+count: Nat, freq: List<&2, U32>) -> List<&2, U32>:
  List.take(&2, U32, copy.list(Array.to_list(~U32, depths(merge(count, leaves(freq, 0, Nil{})), 0, Array.new(U32, 9n, 0)))), count)

def maxlen(xs: List<&2, U32>, +best: U32) -> U32:
  match xs:
    case Nil{}:
      best
    case Con{+h, t}:
      maxlen(t, Bool.pick(U32, U32.is_lt(best, h), h, best))

def limited(fuel: Nat, +count: Nat, +freq: List<&2, U32>, +ls: List<&2, U32>, ok: Bool) -> List<&2, U32>:
  match fuel:
    case 0n:
      ls
    case 1n+p:
      match ok:
        case True{}:
          ls
        case False{}:
          +nextfreq = shrink(freq)
          +next = tree.lens(count, nextfreq)
          limited(p, count, nextfreq, next, U32.is_le(maxlen(next, 0), 15))

# Sixteen halvings reduce every nonzero frequency in a 32 KiB block to one.
def tree.lengths(+count: Nat, +freq: List<&2, U32>) -> List<&2, U32>:
  +ls = tree.lens(count, freq)
  limited(16n, count, freq, ls, U32.is_le(maxlen(ls, 0), 15))

def bump.of(r: Array<U32> & U32, +s: U32) -> Array<U32>:
  (a, +n) = r
  Array.set(U32, a, s, (n + 1 : U32))

def bump(a: Array<U32>, +s: U32) -> Array<U32>:
  bump.of(Array.get(U32, a, s), s)

def frequencies(xs: List<&2, Token>, l: Array<U32>, d: Array<U32>) -> Array<U32> & Array<U32>:
  match xs:
    case Nil{}:
      (l, d)
    case Con{Lit{s}, t}:
      frequencies(t, bump(l, s), d)
    case Con{Copy{ls, le, lv, ds, de, dv}, t}:
      frequencies(t, bump(l, ls), bump(d, ds))

def encodings(xs: List<&2, Bits.Encoding>, a: Array<U32>) -> Array<U32>:
  match xs:
    case Nil{}:
      a
    case Con{Bits.Encoding{+s, +l, +v}, t}:
      encodings(t, Array.set(U32, a, s, (U32.shln(Bits.rev(U32.to_nat(l), v, 0), 5n) .|. l : U32)))

def codes(m: Maybe<&2, List<&2, Bits.Encoding>>) -> Maybe<&1, Array<U32>>:
  match m:
    case None{}:
      None{}
    case Some{xs}:
      Some{encodings(xs, Array.new(U32, 9n, 0))}

def write.of(r: Array<U32> & U32, w: Bits.Writer) -> Bits.Writer & Array<U32>:
  (a, +v) = r
  (Bits.Writer.lsb(w, (v .&. 31 : U32), U32.shrn(v, 5n)), a)

def write(w: Bits.Writer, a: Array<U32>, +s: U32) -> Bits.Writer & Array<U32>:
  write.of(Array.get(U32, a, s), w)

def emit.dist(r: Bits.Writer & Array<U32>, l: Array<U32>, +de: U32, dv: U32) -> Bits.Writer & Array<U32> & Array<U32>:
  (w, d) = r
  (Bits.Writer.lsb(w, de, dv), l, d)

def emit.copy(r: Bits.Writer & Array<U32>, d: Array<U32>, +le: U32, lv: U32, ds: U32, +de: U32, dv: U32) -> Bits.Writer & Array<U32> & Array<U32>:
  (w, l) = r
  emit.dist(write(Bits.Writer.lsb(w, le, lv), d, ds), l, de, dv)

def emit.lit(r: Bits.Writer & Array<U32>, d: Array<U32>) -> Bits.Writer & Array<U32> & Array<U32>:
  (w, l) = r
  (w, l, d)

def emit.end(r: Bits.Writer & Array<U32>) -> Bits.Writer:
  (w, l) = r
  w

def emit(xs: List<&2, Token>, st: Bits.Writer & Array<U32> & Array<U32>) -> Bits.Writer:
  match xs:
    case Nil{}:
      (w, l, d) = st
      emit.end(write(w, l, 256))
    case Con{Lit{s}, t}:
      (w, l, d) = st
      emit(t, emit.lit(write(w, l, s), d))
    case Con{Copy{ls, +le, lv, ds, +de, dv}, t}:
      (w, l, d) = st
      emit(t, emit.copy(write(w, l, ls), d, le, lv, ds, de, dv))

def lens.write(xs: List<&2, U32>, w: Bits.Writer) -> Bits.Writer:
  match xs:
    case Nil{}:
      w
    case Con{+h, t}:
      lens.write(t, Bits.Writer.lsb(w, 4, Bits.rev(4n, h, 0)))

def header(xs: List<&2, U32>, w: Bits.Writer) -> Bits.Writer:
  match xs:
    case Nil{}:
      w
    case Con{h, t}:
      header(t, Bits.Writer.lsb(w, 3, h))

type Plan is Data:
  Fixed{}
  Dynamic{ll: List<&2, U32>, dl: List<&2, U32>}

def cost(freq: List<&2, U32>, lens: List<&2, U32>, +acc: U32) -> U32:
  match freq:
    case Nil{}:
      acc
    case Con{+f, ft}:
      match lens:
        case Nil{}:
          acc
        case Con{+l, lt}:
          cost(ft, lt, (acc + f * l : U32))

def fixed.len(+s: U32) -> U32:
  Bool.pick(U32, U32.is_lt(s, 144), 8, Bool.pick(U32, U32.is_lt(s, 256), 9, Bool.pick(U32, U32.is_lt(s, 280), 7, 8)))

def fixed.cost(freq: List<&2, U32>, +i: U32, +acc: U32) -> U32:
  match freq:
    case Nil{}:
      acc
    case Con{+f, t}:
      fixed.cost(t, (i + 1 : U32), (acc + f * fixed.len(i) : U32))

def total(freq: List<&2, U32>, +acc: U32) -> U32:
  match freq:
    case Nil{}:
      acc
    case Con{+f, t}:
      total(t, (acc + f : U32))

def first(xs: List<&2, U32>) -> U32:
  match xs:
    case Nil{}:
      0
    case Con{h, t}:
      h

def second(xs: List<&2, U32>) -> U32:
  match xs:
    case Nil{}:
      0
    case Con{h, t}:
      first(t)

def plan.pick(fixed: Bool, ll: List<&2, U32>, dl: List<&2, U32>) -> Plan:
  match fixed:
    case True{}:
      Fixed{}
    case False{}:
      Dynamic{ll, dl}

def plan.of(r: Array<U32> & Array<U32>) -> Plan:
  (lf, df) = r
  +lf = List.take(&2, U32, copy.list(Array.to_list(~U32, lf)), 286n)
  +df = List.take(&2, U32, copy.list(Array.to_list(~U32, df)), 30n)
  +ll = tree.lengths(286n, lf)
  +dl = tree.lengths(30n, df)
  +fixed = (3 + fixed.cost(lf, 0, 0) + total(df, 0) * 5 - 18 : U32)
  +dynamic = (1338 + cost(lf, ll, 0) + cost(df, dl, 0) - first(ll) - first(dl) - second(dl) : U32)
  plan.pick(U32.is_le(fixed, dynamic), ll, dl)

def plan(xs: List<&2, Token>) -> Plan:
  plan.of(frequencies(xs, bump(bump(Array.new(U32, 9n, 0), 0), 256), bump(bump(Array.new(U32, 5n, 0), 0), 1)))

type Tables is Type:
  Tables{lit: Array<U32>, dist: Array<U32>}

def tables.dist(lit: Array<U32>, m: Maybe<&1, Array<U32>>) -> Maybe<&1, Tables>:
  match m:
    case None{}:
      None{}
    case Some{dist}:
      Some{Tables{lit, dist}}

def tables.lit(m: Maybe<&1, Array<U32>>, dl: List<&2, U32>) -> Maybe<&1, Tables>:
  match m:
    case None{}:
      None{}
    case Some{lit}:
      tables.dist(lit, codes(Bits.Huff.encode_lens(dl)))

def tables(ll: List<&2, U32>, dl: List<&2, U32>) -> Maybe<&1, Tables>:
  tables.lit(codes(Bits.Huff.encode_lens(ll)), dl)

# ponytail: four bits per code length; use run-length symbols when header size matters.
def dynamic(xs: List<&2, Token>, w: Bits.Writer, +last: U32, ll: List<&2, U32>, dl: List<&2, U32>, tables: Tables) -> Bits.Writer:
  Tables{l, d} = tables
  w = Bits.Writer.lsb(Bits.Writer.lsb(Bits.Writer.lsb(Bits.Writer.lsb(w, 3, (4 + last : U32)), 5, 29), 5, 29), 4, 15)
  w = header([0, 0, 0, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4], w)
  emit(xs, (lens.write(dl, lens.write(ll, w)), l, d))
