# Pure storage model, digest ordering, and canonical encoding.
import Base
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes
import bend-kit-collections@0.1.6.0/omap.bend as OMap
import bend-kit-collections@0.1.6.0/order.bend as Order

# The content: a file, or a directory as a chain of named entries that ends in End.
type Tree<-B: Data> is Data:
  TFile{data: B}
  TEnd{}
  TItem{name: String, child: Tree<B>, rest: Tree<B>}

# One stored object. An OItem names its child and the rest of its directory by digest.
type Obj<-D: Data, -B: Data> is Data:
  OFile{data: B}
  OEnd{}
  OItem{name: String, child: D, rest: D}

# Objects by digest, as a list: the model the laws reason about. get answers the first
# entry whose digest eq accepts. Index below answers the same in O(log n) comparisons.
type Store<-D: Data, -B: Data> is Data:
  StNil{}
  StCon{key: D, obj: Obj<D, B>, rest: Store<D, B>}

def Store.new(-D: Data, -B: Data) -> Store<D, B>:
  StNil{}

# eq(d, first key), or False when s is empty.
def Store.head(~D: Data, ~B: Data, ~eq: D -> D -> Bool, s: Store<D, B>, +d: D) -> Bool:
  match s:
    case StNil{}:
      False{}
    case StCon{k, o, r}:
      eq(d, k)

# hit is Store.head(s, d), so the walk stops at the first match.
def Store.get.go(~D: Data, ~B: Data, ~eq: D -> D -> Bool, s: Store<D, B>, +d: D, hit: Bool) -> Maybe<&2, Obj<D, B>>:
  match s hit:
    case StNil{} _:
      None{}
    case StCon{k, o, r} True{}:
      Some{o}
    case StCon{k, o, +r} False{}:
      Store.get.go(~D, ~B, ~eq, r, d, Store.head(~D, ~B, ~eq, r, d))

def Store.get(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +s: Store<D, B>, +d: D) -> Maybe<&2, Obj<D, B>>:
  Store.get.go(~D, ~B, ~eq, s, d, Store.head(~D, ~B, ~eq, s, d))

def Store.has(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +s: Store<D, B>, +d: D) -> Bool:
  Maybe.is_some(&2, Obj<D, B>, Store.get(~D, ~B, ~eq, s, d))

def Store.put.if(-D: Data, -B: Data, found: Bool, s: Store<D, B>, d: D, o: Obj<D, B>) -> Store<D, B>:
  match found:
    case True{}:
      s
    case False{}:
      StCon{d, o, s}

# Adds o under d unless d is present. The first object under a digest stays.
def Store.put(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +s: Store<D, B>, +d: D, o: Obj<D, B>) -> Store<D, B>:
  Store.put.if(D, B, Store.has(~D, ~B, ~eq, s, d), s, d, o)

# Puts each (digest, object) in order.
def Store.apply(~D: Data, ~B: Data, ~eq: D -> D -> Bool, xs: Store<D, B>, +s: Store<D, B>) -> Store<D, B>:
  match xs:
    case StNil{}:
      s
    case StCon{d, o, t}:
      Store.apply(~D, ~B, ~eq, t, Store.put(~D, ~B, ~eq, s, d, o))

def Store.size(-D: Data, -B: Data, s: Store<D, B>) -> U32:
  match s:
    case StNil{}:
      0
    case StCon{k, o, r}:
      (1 + Store.size(D, B, r) : U32)

# xs, then ys.
def Store.cat(-D: Data, -B: Data, xs: Store<D, B>, ys: Store<D, B>) -> Store<D, B>:
  match xs:
    case StNil{}:
      ys
    case StCon{k, o, r}:
      StCon{k, o, Store.cat(D, B, r, ys)}

# Some only when both halves loaded.
def Tree.item(-B: Data, n: String, c: Maybe<&2, Tree<B>>, r: Maybe<&2, Tree<B>>) -> Maybe<&2, Tree<B>>:
  match c r:
    case Some{x} Some{y}:
      Some{TItem{n, x, y}}
    case Some{x} None{}:
      None{}
    case None{} r:
      None{}

# m is the object under the digest being loaded.
def load.go(~D: Data, ~B: Data, ~eq: D -> D -> Bool, fuel: Nat, +s: Store<D, B>, m: Maybe<&2, Obj<D, B>>) -> Maybe<&2, Tree<B>>:
  match fuel m:
    case 0n _:
      None{}
    case 1n+p None{}:
      None{}
    case 1n+p Some{OFile{b}}:
      Some{TFile{b}}
    case 1n+p Some{OEnd{}}:
      Some{TEnd{}}
    case 1n+(+p) Some{OItem{n, c, r}}:
      Tree.item(B, n, load.go(~D, ~B, ~eq, p, s, Store.get(~D, ~B, ~eq, s, c)), load.go(~D, ~B, ~eq, p, s, Store.get(~D, ~B, ~eq, s, r)))

# The tree under d, or None when an object is missing or the tree is deeper than fuel.
def load(~D: Data, ~B: Data, ~eq: D -> D -> Bool, fuel: Nat, +s: Store<D, B>, +d: D) -> Maybe<&2, Tree<B>>:
  load.go(~D, ~B, ~eq, fuel, s, Store.get(~D, ~B, ~eq, s, d))

def closure.item(-D: Data, -B: Data, d: D, o: Obj<D, B>, c: Maybe<&2, Store<D, B>>, r: Maybe<&2, Store<D, B>>) -> Maybe<&2, Store<D, B>>:
  match c r:
    case Some{xs} Some{ys}:
      Some{StCon{d, o, Store.cat(D, B, xs, ys)}}
    case Some{xs} None{}:
      None{}
    case None{} r:
      None{}

def closure.go(~D: Data, ~B: Data, ~eq: D -> D -> Bool, fuel: Nat, +s: Store<D, B>, +d: D, m: Maybe<&2, Obj<D, B>>) -> Maybe<&2, Store<D, B>>:
  match fuel m:
    case 0n _:
      None{}
    case 1n+p None{}:
      None{}
    case 1n+p Some{OFile{b}}:
      Some{StCon{d, OFile{b}, StNil{}}}
    case 1n+p Some{OEnd{}}:
      Some{StCon{d, OEnd{}, StNil{}}}
    case 1n+(+p) Some{OItem{n, +c, +r}}:
      closure.item(D, B, d, OItem{n, c, r},
        closure.go(~D, ~B, ~eq, p, s, c, Store.get(~D, ~B, ~eq, s, c)),
        closure.go(~D, ~B, ~eq, p, s, r, Store.get(~D, ~B, ~eq, s, r)))

# Every object that load(fuel, s, d) reads, parents first, or None when load fails.
def closure(~D: Data, ~B: Data, ~eq: D -> D -> Bool, fuel: Nat, +s: Store<D, B>, +d: D) -> Maybe<&2, Store<D, B>>:
  closure.go(~D, ~B, ~eq, fuel, s, d, Store.get(~D, ~B, ~eq, s, d))

# Store.has(t, first digest of xs), or False when xs is empty.
def need.head(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +t: Store<D, B>, xs: Store<D, B>) -> Bool:
  match xs:
    case StNil{}:
      False{}
    case StCon{d, o, rest}:
      Store.has(~D, ~B, ~eq, t, d)

# found is need.head(t, xs), so only the taken branch recurses.
def need.go(~D: Data, ~B: Data, ~eq: D -> D -> Bool, xs: Store<D, B>, +t: Store<D, B>, found: Bool) -> Store<D, B>:
  match xs found:
    case StNil{} _:
      StNil{}
    case StCon{d, o, +rest} True{}:
      need.go(~D, ~B, ~eq, rest, t, need.head(~D, ~B, ~eq, t, rest))
    case StCon{+d, +o, +rest} False{}:
      +u = Store.put(~D, ~B, ~eq, t, d, o)
      StCon{d, o, need.go(~D, ~B, ~eq, rest, u, need.head(~D, ~B, ~eq, u, rest))}

# The entries of xs whose digest t lacks, each digest once. t grows as entries are taken.
def need(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +xs: Store<D, B>, +t: Store<D, B>) -> Store<D, B>:
  need.go(~D, ~B, ~eq, xs, t, need.head(~D, ~B, ~eq, t, xs))

def plan.of(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +dst: Store<D, B>, m: Maybe<&2, Store<D, B>>) -> Maybe<&2, Store<D, B>>:
  match m:
    case None{}:
      None{}
    case Some{xs}:
      Some{need(~D, ~B, ~eq, xs, dst)}

# The objects dst needs to load root as src does, or None when src cannot load root.
def plan(~D: Data, ~B: Data, ~eq: D -> D -> Bool, fuel: Nat, +src: Store<D, B>, +dst: Store<D, B>, +root: D) -> Maybe<&2, Store<D, B>>:
  plan.of(~D, ~B, ~eq, dst, closure(~D, ~B, ~eq, fuel, src, root))

def live.cat(-D: Data, -B: Data, a: Maybe<&2, Store<D, B>>, b: Maybe<&2, Store<D, B>>) -> Maybe<&2, Store<D, B>>:
  match a b:
    case Some{xs} Some{ys}:
      Some{Store.cat(D, B, xs, ys)}
    case Some{xs} None{}:
      None{}
    case None{} b:
      None{}

# The closures of every root, or None when one root does not load.
def live(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +fuel: Nat, +s: Store<D, B>, roots: List<&2, D>) -> Maybe<&2, Store<D, B>>:
  match roots:
    case Nil{}:
      Some{StNil{}}
    case Con{r, t}:
      live.cat(D, B, closure(~D, ~B, ~eq, fuel, s, r), live(~D, ~B, ~eq, fuel, s, t))

# eq(d, k) for some entry (k, o) of ls.
def mem(~D: Data, ~B: Data, ~eq: D -> D -> Bool, ls: Store<D, B>, +d: D) -> Bool:
  match ls:
    case StNil{}:
      False{}
    case StCon{k, o, t}:
      Bool.or(eq(d, k), mem(~D, ~B, ~eq, t, d))

def keep.if(-D: Data, -B: Data, live: Bool, k: D, o: Obj<D, B>, r: Store<D, B>) -> Store<D, B>:
  match live:
    case True{}:
      StCon{k, o, r}
    case False{}:
      r

# The entries of s whose digest is in ls.
def keep(~D: Data, ~B: Data, ~eq: D -> D -> Bool, s: Store<D, B>, +ls: Store<D, B>) -> Store<D, B>:
  match s:
    case StNil{}:
      StNil{}
    case StCon{+k, o, r}:
      keep.if(D, B, mem(~D, ~B, ~eq, ls, k), k, o, keep(~D, ~B, ~eq, r, ls))

def gc.of(~D: Data, ~B: Data, ~eq: D -> D -> Bool, s: Store<D, B>, m: Maybe<&2, Store<D, B>>) -> Maybe<&2, Store<D, B>>:
  match m:
    case None{}:
      None{}
    case Some{ls}:
      Some{keep(~D, ~B, ~eq, s, ls)}

# s without the objects that no retained root reaches, or None when a root does not load.
def gc(~D: Data, ~B: Data, ~eq: D -> D -> Bool, fuel: Nat, +s: Store<D, B>, +roots: List<&2, D>) -> Maybe<&2, Store<D, B>>:
  gc.of(~D, ~B, ~eq, s, live(~D, ~B, ~eq, fuel, s, roots))

def admit.if(-D: Data, -B: Data, ok: Bool, s: Store<D, B>, keep: Store<D, B>) -> Maybe<&2, Store<D, B>>:
  match ok:
    case True{}:
      Some{s}
    case False{}:
      None{}

# Ingress: computed is the digest of o's encoding. None when it is not the claimed digest.
def admit(~D: Data, ~B: Data, ~eq: D -> D -> Bool, +s: Store<D, B>, +claimed: D, +computed: D, o: Obj<D, B>) -> Maybe<&2, Store<D, B>>:
  admit.if(D, B, eq(claimed, computed), Store.put(~D, ~B, ~eq, s, claimed, o), s)

# The Merkle digest of t under the object hash H.
def hash(~D: Data, ~B: Data, ~H: Obj<D, B> -> D, t: Tree<B>) -> D:
  match t:
    case TFile{b}:
      H(OFile{b})
    case TEnd{}:
      H(OEnd{})
    case TItem{n, c, r}:
      H(OItem{n, hash(~D, ~B, ~H, c), hash(~D, ~B, ~H, r)})

# The objects of t with their digests, children before parents; hash(t) is the last digest.
def objects(~D: Data, ~B: Data, ~H: Obj<D, B> -> D, t: Tree<B>) -> Store<D, B>:
  match t:
    case TFile{+b}:
      StCon{H(OFile{b}), OFile{b}, StNil{}}
    case TEnd{}:
      StCon{H(OEnd{}), OEnd{}, StNil{}}
    case TItem{+n, +c, +r}:
      +o = {OItem{n, hash(~D, ~B, ~H, c), hash(~D, ~B, ~H, r)} : Obj<D, B>}
      Store.cat(D, B, objects(~D, ~B, ~H, c),
        Store.cat(D, B, objects(~D, ~B, ~H, r), StCon{H(o), o, StNil{}}))

# True when load with this fuel reaches every node of t.
def fits(-B: Data, fuel: Nat, t: Tree<B>) -> Bool:
  match fuel t:
    case 0n _:
      False{}
    case 1n+p TFile{b}:
      True{}
    case 1n+p TEnd{}:
      True{}
    case 1n+(+p) TItem{n, c, r}:
      Bool.and(fits(B, p, c), fits(B, p, r))

# True when every entry (k, o) has eq(k, H(o)).
def valid(~D: Data, ~B: Data, ~H: Obj<D, B> -> D, ~eq: D -> D -> Bool, s: Store<D, B>) -> Bool:
  match s:
    case StNil{}:
      True{}
    case StCon{k, +o, r}:
      Bool.and(eq(k, H(o)), valid(~D, ~B, ~H, ~eq, r))

# ---- Index: objects by digest in an ordered map under cmp. Index.of(xs) answers every
# get, load, plan, and live as Store.apply(xs, Store.new) does under eq (the index_ laws).

def Index(-D: Data, -B: Data) -> Data:
  OMap.OMap<D, Obj<D, B>>

def Index.new(-D: Data, -B: Data) -> Index(D, B):
  OMap.OTip{}

def Index.size(-D: Data, -B: Data, m: Index(D, B)) -> U32:
  OMap.OMap.size(D, Obj<D, B>, m)

def Index.get(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, m: Index(D, B), +d: D) -> Maybe<&2, Obj<D, B>>:
  OMap.OMap.get(~D, ~Obj<D, B>, ~cmp, m, d)

def Index.has(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, m: Index(D, B), +d: D) -> Bool:
  Maybe.is_some(&2, Obj<D, B>, Index.get(~D, ~B, ~cmp, m, d))

def Index.put.if(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, found: Bool, m: Index(D, B), +d: D, o: Obj<D, B>) -> Index(D, B):
  match found:
    case True{}:
      m
    case False{}:
      OMap.OMap.put(~D, ~Obj<D, B>, ~cmp, m, d, o)

# Adds o under d unless d is present, as Store.put does.
def Index.put(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, +m: Index(D, B), +d: D, o: Obj<D, B>) -> Index(D, B):
  Index.put.if(~D, ~B, ~cmp, Index.has(~D, ~B, ~cmp, m, d), m, d, o)

# Puts each (digest, object) in order.
def Index.apply(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, xs: Store<D, B>, +m: Index(D, B)) -> Index(D, B):
  match xs:
    case StNil{}:
      m
    case StCon{d, o, t}:
      Index.apply(~D, ~B, ~cmp, t, Index.put(~D, ~B, ~cmp, m, d, o))

def Index.of(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, xs: Store<D, B>) -> Index(D, B):
  Index.apply(~D, ~B, ~cmp, xs, Index.new(D, B))

def Index.load.go(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, fuel: Nat, +s: Index(D, B), m: Maybe<&2, Obj<D, B>>) -> Maybe<&2, Tree<B>>:
  match fuel m:
    case 0n _:
      None{}
    case 1n+p None{}:
      None{}
    case 1n+p Some{OFile{b}}:
      Some{TFile{b}}
    case 1n+p Some{OEnd{}}:
      Some{TEnd{}}
    case 1n+(+p) Some{OItem{n, c, r}}:
      Tree.item(B, n, Index.load.go(~D, ~B, ~cmp, p, s, Index.get(~D, ~B, ~cmp, s, c)), Index.load.go(~D, ~B, ~cmp, p, s, Index.get(~D, ~B, ~cmp, s, r)))

def Index.load(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, fuel: Nat, +s: Index(D, B), +d: D) -> Maybe<&2, Tree<B>>:
  Index.load.go(~D, ~B, ~cmp, fuel, s, Index.get(~D, ~B, ~cmp, s, d))

def Index.closure.go(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, fuel: Nat, +s: Index(D, B), +d: D, m: Maybe<&2, Obj<D, B>>) -> Maybe<&2, Store<D, B>>:
  match fuel m:
    case 0n _:
      None{}
    case 1n+p None{}:
      None{}
    case 1n+p Some{OFile{b}}:
      Some{StCon{d, OFile{b}, StNil{}}}
    case 1n+p Some{OEnd{}}:
      Some{StCon{d, OEnd{}, StNil{}}}
    case 1n+(+p) Some{OItem{n, +c, +r}}:
      closure.item(D, B, d, OItem{n, c, r},
        Index.closure.go(~D, ~B, ~cmp, p, s, c, Index.get(~D, ~B, ~cmp, s, c)),
        Index.closure.go(~D, ~B, ~cmp, p, s, r, Index.get(~D, ~B, ~cmp, s, r)))

def Index.closure(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, fuel: Nat, +s: Index(D, B), +d: D) -> Maybe<&2, Store<D, B>>:
  Index.closure.go(~D, ~B, ~cmp, fuel, s, d, Index.get(~D, ~B, ~cmp, s, d))

def Index.need.head(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, +t: Index(D, B), xs: Store<D, B>) -> Bool:
  match xs:
    case StNil{}:
      False{}
    case StCon{d, o, rest}:
      Index.has(~D, ~B, ~cmp, t, d)

def Index.need.go(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, xs: Store<D, B>, +t: Index(D, B), found: Bool) -> Store<D, B>:
  match xs found:
    case StNil{} _:
      StNil{}
    case StCon{d, o, +rest} True{}:
      Index.need.go(~D, ~B, ~cmp, rest, t, Index.need.head(~D, ~B, ~cmp, t, rest))
    case StCon{+d, +o, +rest} False{}:
      +u = Index.put(~D, ~B, ~cmp, t, d, o)
      StCon{d, o, Index.need.go(~D, ~B, ~cmp, rest, u, Index.need.head(~D, ~B, ~cmp, u, rest))}

def Index.need(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, +xs: Store<D, B>, +t: Index(D, B)) -> Store<D, B>:
  Index.need.go(~D, ~B, ~cmp, xs, t, Index.need.head(~D, ~B, ~cmp, t, xs))

def Index.plan.of(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, +dst: Index(D, B), m: Maybe<&2, Store<D, B>>) -> Maybe<&2, Store<D, B>>:
  match m:
    case None{}:
      None{}
    case Some{xs}:
      Some{Index.need(~D, ~B, ~cmp, xs, dst)}

def Index.plan(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, fuel: Nat, +src: Index(D, B), +dst: Index(D, B), +root: D) -> Maybe<&2, Store<D, B>>:
  Index.plan.of(~D, ~B, ~cmp, dst, Index.closure(~D, ~B, ~cmp, fuel, src, root))

def Index.live(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, +fuel: Nat, +s: Index(D, B), roots: List<&2, D>) -> Maybe<&2, Store<D, B>>:
  match roots:
    case Nil{}:
      Some{StNil{}}
    case Con{r, t}:
      live.cat(D, B, Index.closure(~D, ~B, ~cmp, fuel, s, r), Index.live(~D, ~B, ~cmp, fuel, s, t))

def Index.admit.if(-D: Data, -B: Data, ok: Bool, s: Index(D, B)) -> Maybe<&2, Index(D, B)>:
  match ok:
    case True{}:
      Some{s}
    case False{}:
      None{}

# admit on an index: None when claimed is not computed.
def Index.admit(~D: Data, ~B: Data, ~cmp: D -> D -> Cmp, +s: Index(D, B), +claimed: D, +computed: D, o: Obj<D, B>) -> Maybe<&2, Index(D, B)>:
  Index.admit.if(D, B, Cmp.is_eq(cmp(claimed, computed)), Index.put(~D, ~B, ~cmp, s, claimed, o))

# ---- SHA-256 content addressing on disk

# File octets and the SHA-256 of their canonical file encoding.
type Blob is Data:
  Blob{len: U32, words: List<&2, U32>, digest: Digest}

# r is the array beside the word read at i - 1.
def Blob.read(n: Nat, r: Array<U32> & U32, +i: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      List.reverse(&2, U32, acc)
    case 1n+p:
      (a, w) = r
      Blob.read(p, Array.get(U32, a, i), (i + 1 : U32), Con{w, acc})

def Blob.pack(d: Digest, b: Bytes.Bytes) -> Blob:
  Bytes.Bytes{+len, buf} = b
  Blob{len, Blob.read(U32.to_nat(((len + 3) / 4 : U32)), Array.get(U32, buf, 0), 1, Nil{}), d}

def Blob.write(ws: List<&2, U32>, a: Array<U32>, +i: U32) -> Array<U32>:
  match ws:
    case Nil{}:
      a
    case Con{w, t}:
      Blob.write(t, Array.set(U32, a, i, w), (i + 1 : U32))

def Blob.bytes(x: Blob) -> Bytes.Bytes:
  Blob{+len, ws, d} = x
  Bytes.Bytes{len, Blob.write(ws, Bytes.alloc(len), 0)}

# A zero last carry may lie past the array, where a write would wrap to word 0.
def Blob.write.last(zero: Bool, a: Array<U32>, +j: U32, +carry: U32) -> Array<U32>:
  match zero:
    case True{}:
      a
    case False{}:
      Array.set(U32, a, j, carry)

# Writes ws from octet 4 * j + lo / 8 on; carry holds the octets of word j below lo.
def Blob.write.shift(ws: List<&2, U32>, a: Array<U32>, +j: U32, +lo: Nat, +hi: Nat, +carry: U32) -> Array<U32>:
  match ws:
    case Nil{}:
      Blob.write.last(U32.is_eq(carry, 0), a, j, carry)
    case Con{+w, t}:
      Blob.write.shift(t, Array.set(U32, a, j, (carry .|. U32.shln(w, lo) : U32)), (j + 1 : U32), lo, hi, U32.shrn(w, hi))


# Loads and collections give up past this many levels. Each directory entry is one level.
def limit() -> Nat:
  U32.to_nat(1048576)

def char.ok(+c: U32) -> Bool:
  Bool.and(U32.is_lt(c, 256), Bool.and(U32.is_ne(c, 0), Bool.and(U32.is_ne(c, 10), U32.is_ne(c, 47))))

def chars.ok(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(char.ok(c), chars.ok(t))

# A directory entry name: one to 255 octets, not "." or "..", with no NUL, newline, or "/".
def name.ok(+n: String) -> Bool:
  +k = String.length(n)
  Bool.and(Nat.is_lt(0n, k), Bool.and(Nat.is_le(k, 255n), Bool.and(Bool.not(String.eq(n, ".")),
    Bool.and(Bool.not(String.eq(n, "..")), chars.ok(n)))))

def hex.ok(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.or(Bool.and(U32.is_le(48, c), U32.is_le(c, 57)), Bool.and(U32.is_le(97, c), U32.is_le(c, 102))), hex.ok(t))

# 64 lowercase hex characters.
def digest.ok(+d: String) -> Bool:
  Bool.and(Nat.is_eq(String.length(d), 64n), hex.ok(d))

# A SHA-256 digest: its 32 octets packed four to a U32, low octet first, as Bytes packs them.
type Digest is Data:
  Digest{words: List<&2, U32>}

def Digest.order(a: List<&2, U32>, b: List<&2, U32>) -> Cmp:
  match a b:
    case Nil{} Nil{}:
      EQ{}
    case Nil{} Con{y, t}:
      LT{}
    case Con{x, s} Nil{}:
      GT{}
    case Con{+x, s} Con{+y, t}:
      Order.string.fin(U32.cmp(x, y), Digest.order(s, t))

# A total order on digests (the digest_cmp_ laws). It is not hex order.
def Digest.cmp(a: Digest, b: Digest) -> Cmp:
  match a b:
    case Digest{x} Digest{y}:
      Digest.order(x, y)

def Digest.hex(d: Digest) -> String:
  match d:
    case Digest{ws}:
      Bytes.to_hex(Bytes.Bytes{32, Blob.write(ws, Bytes.alloc(32), 0)})

def nibble(+c: U32) -> U32:
  Bool.pick(U32, U32.is_lt(c, 97), (c - 48 : U32), (c - 87 : U32))

# Two hex digits per octet.
def unhex(s: String) -> List<&2, U32>:
  match s:
    case SCon{Chr{+h}, SCon{Chr{+l}, t}}:
      Con{(nibble(h) * 16 + nibble(l) : U32), unhex(t)}
    case _:
      Nil{}

# Four octets per word, low octet first.
def pack(bs: List<&2, U32>) -> List<&2, U32>:
  match bs:
    case Con{+a, Con{+b, Con{+c, Con{+d, t}}}}:
      Con{(a + b * 256 + c * 65536 + d * 16777216 : U32), pack(t)}
    case _:
      Nil{}

def Digest.read.if(ok: Bool, s: String) -> Maybe<&2, Digest>:
  match ok:
    case True{}:
      Some{Digest{pack(unhex(s))}}
    case False{}:
      None{}

# The digest that 64 lowercase hex characters name, or None.
def Digest.read(+s: String) -> Maybe<&2, Digest>:
  Digest.read.if(digest.ok(s), s)

def encode.file.at(+len: U32, ws: List<&2, U32>, +hl: U32, r: Array<U32> & U32) -> Bytes.Bytes:
  (a, c) = r
  +lo = ((hl .&. 3 : U32) * 8 : U32)
  Bytes.Bytes{(hl + len : U32), Blob.write.shift(ws, a, (hl >> 2n : U32), U32.to_nat(lo), U32.to_nat((32 - lo : U32)), c)}

def encode.file.pick(aligned: Bool, +len: U32, ws: List<&2, U32>, +hl: U32, a: Array<U32>) -> Bytes.Bytes:
  match aligned:
    case True{}:
      Bytes.Bytes{(hl + len : U32), Blob.write(ws, a, (hl >> 2n : U32))}
    case False{}:
      encode.file.at(len, ws, hl, Array.get(U32, a, (hl >> 2n : U32)))

# The header h, then the words of a Blob of len octets, written once without a byte loop.
def encode.file(+len: U32, ws: List<&2, U32>, h: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+hl, hb} = h
  encode.file.pick(U32.is_eq((hl .&. 3 : U32), 0), len, ws, hl, Bytes.grow(hl, hb, (hl + len : U32)))

# The canonical encoding: "file <len>\n" and the octets, "end\n", or "item <child> <rest> <name>\n".
def encode(o: Obj<Digest, Blob>) -> Bytes.Bytes:
  match o:
    case OFile{b}:
      Blob{+len, ws, d} = b
      encode.file(len, ws, Bytes.from_string("file " ++ U32.show(len) ++ "\n"))
    case OEnd{}:
      Bytes.from_string("end\n")
    case OItem{n, c, r}:
      Bytes.from_string("item " ++ Digest.hex(c) ++ " " ++ Digest.hex(r) ++ " " ++ n ++ "\n")


def digest.of(r: U32 & Array<U32>) -> Digest:
  (n, a) = r
  Digest{Blob.read(8n, Array.get(U32, a, 0), 1, Nil{})}

def decode.when(ok: Bool, o: Obj<Digest, Blob>) -> Maybe<&2, Obj<Digest, Blob>>:
  match ok:
    case True{}:
      Some{o}
    case False{}:
      None{}

def decode.item.of(ok: Bool, n: String, c: Maybe<&2, Digest>, r: Maybe<&2, Digest>) -> Maybe<&2, Obj<Digest, Blob>>:
  match ok c r:
    case True{} Some{x} Some{y}:
      Some{OItem{n, x, y}}
    case _ _ _:
      None{}

# rest is "<child> <rest> <name>".
def decode.item(+rest: String) -> Maybe<&2, Obj<Digest, Blob>>:
  +n = String.drop(rest, 130n)
  decode.item.of(Bool.and(name.ok(n),
    Bool.and(String.eq(String.take(String.drop(rest, 64n), 1n), " "), String.eq(String.take(String.drop(rest, 129n), 1n), " "))),
    n, Digest.read(String.take(rest, 64n)), Digest.read(String.take(String.drop(rest, 65n), 64n)))

def decode.file(m: Maybe<&2, U32>, d: Digest, +digits: String, +at: U32, b: Bytes.Bytes) -> Maybe<&2, Obj<Digest, Blob>>:
  match m:
    case None{}:
      None{}
    case Some{+n}:
      Bytes.Bytes{+len, buf} = b
      decode.when(Bool.and(String.eq(U32.show(n), digits), U32.is_eq((len - at : U32), n)),
        OFile{Blob.pack(d, Bytes.snd(Bytes.slice(Bytes.Bytes{len, buf}, at, n)))})

def decode.head(d: Digest, +head: String, +at: U32, b: Bytes.Bytes) -> Maybe<&2, Obj<Digest, Blob>>:
  Bytes.Bytes{+len, buf} = b
  +whole = U32.is_eq(len, at)
  Bool.pick(Maybe<&2, Obj<Digest, Blob>>, String.starts_with(head, "file "),
    decode.file(U32.read(String.drop(head, 5n)), d, String.drop(head, 5n), at, Bytes.Bytes{len, buf}),
  Bool.pick(Maybe<&2, Obj<Digest, Blob>>, Bool.and(whole, String.eq(head, "end")), Some{OEnd{}},
  Bool.pick(Maybe<&2, Obj<Digest, Blob>>, Bool.and(whole, String.starts_with(head, "item ")), decode.item(String.drop(head, 5n)),
    None{})))

def decode.cut(d: Digest, +at: U32, r: Bytes.Bytes & Bytes.Bytes) -> Maybe<&2, Obj<Digest, Blob>>:
  (b, head) = r
  decode.head(d, Bytes.to_string(head), at, b)

def decode.at(d: Digest, r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&2, Obj<Digest, Blob>>:
  match r:
    case (b, None{}):
      None{}
    case (b, Some{+i}):
      decode.cut(d, (i + 1 : U32), Bytes.slice(b, 0, i))

def decode.hashed(d: Digest, b: Bytes.Bytes) -> Maybe<&2, Obj<Digest, Blob>>:
  decode.at(d, Bytes.find(b, "\n"))

def digests.add(m: Maybe<&2, Digest>, ds: List<&2, Digest>) -> List<&2, Digest>:
  match m:
    case Some{d}:
      Con{d, ds}
    case None{}:
      ds

# The digests that names name. Other names are left out.
def digests(names: List<&2, String>) -> List<&2, Digest>:
  match names:
    case Nil{}:
      Nil{}
    case Con{+n, t}:
      digests.add(Digest.read(n), digests(t))

