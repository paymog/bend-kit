# Content-addressed object store: Merkle trees, sync plans, and reachability GC with proved laws. Source: https://github.com/paymog/bend-kit/tree/main/storage
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-files@0.3.1.0/files.bend as Files
import bend-kit-crypto@0.2.2.2/crypto.bend as Crypto
import bend-kit-collections@0.1.5.0/omap.bend as OMap
import bend-kit-collections@0.1.5.0/order.bend as Order

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

# Octets packed four to a U32, low byte first, as Bytes packs them. Words past len are 0.
type Blob is Data:
  Blob{len: U32, words: List<&2, U32>}

# r is the array beside the word read at i - 1.
def Blob.read(n: Nat, r: Array<U32> & U32, +i: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      List.reverse(&2, U32, acc)
    case 1n+p:
      (a, w) = r
      Blob.read(p, Array.get(U32, a, i), (i + 1 : U32), Con{w, acc})

def Blob.of(b: Bytes.Bytes) -> Blob:
  Bytes.Bytes{+len, buf} = b
  Blob{len, Blob.read(U32.to_nat(((len + 3) / 4 : U32)), Array.get(U32, buf, 0), 1, Nil{})}

def Blob.write(ws: List<&2, U32>, a: Array<U32>, +i: U32) -> Array<U32>:
  match ws:
    case Nil{}:
      a
    case Con{w, t}:
      Blob.write(t, Array.set(U32, a, i, w), (i + 1 : U32))

def Blob.bytes(x: Blob) -> Bytes.Bytes:
  Blob{+len, ws} = x
  Bytes.Bytes{len, Blob.write(ws, Bytes.alloc(len), 0)}

def Blob.string(+s: String) -> Blob:
  Blob.of(Bytes.from_string(s))

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

# The canonical encoding: "file <len>\n" and the octets, "end\n", or "item <child> <rest> <name>\n".
def encode(o: Obj<String, Blob>) -> Bytes.Bytes:
  match o:
    case OFile{b}:
      Blob{+len, ws} = b
      Bytes.append(Bytes.from_string("file " ++ U32.show(len) ++ "\n"), Blob.bytes(Blob{len, ws}))
    case OEnd{}:
      Bytes.from_string("end\n")
    case OItem{n, c, r}:
      Bytes.from_string("item " ++ c ++ " " ++ r ++ " " ++ n ++ "\n")

def decode.when(ok: Bool, o: Obj<String, Blob>) -> Maybe<&2, Obj<String, Blob>>:
  match ok:
    case True{}:
      Some{o}
    case False{}:
      None{}

# rest is "<child> <rest> <name>".
def decode.item(+rest: String) -> Maybe<&2, Obj<String, Blob>>:
  +c = String.take(rest, 64n)
  +r = String.take(String.drop(rest, 65n), 64n)
  +n = String.drop(rest, 130n)
  decode.when(Bool.and(Bool.and(digest.ok(c), digest.ok(r)), Bool.and(name.ok(n),
    Bool.and(String.eq(String.take(String.drop(rest, 64n), 1n), " "), String.eq(String.take(String.drop(rest, 129n), 1n), " ")))),
    OItem{n, c, r})

def decode.file(m: Maybe<&2, U32>, +digits: String, +at: U32, b: Bytes.Bytes) -> Maybe<&2, Obj<String, Blob>>:
  match m:
    case None{}:
      None{}
    case Some{+n}:
      Bytes.Bytes{+len, buf} = b
      decode.when(Bool.and(String.eq(U32.show(n), digits), U32.is_eq((len - at : U32), n)),
        OFile{Blob.of(Bytes.snd(Bytes.slice(Bytes.Bytes{len, buf}, at, n)))})

def decode.head(+head: String, +at: U32, b: Bytes.Bytes) -> Maybe<&2, Obj<String, Blob>>:
  Bytes.Bytes{+len, buf} = b
  +whole = U32.is_eq(len, at)
  Bool.pick(Maybe<&2, Obj<String, Blob>>, String.starts_with(head, "file "),
    decode.file(U32.read(String.drop(head, 5n)), String.drop(head, 5n), at, Bytes.Bytes{len, buf}),
  Bool.pick(Maybe<&2, Obj<String, Blob>>, Bool.and(whole, String.eq(head, "end")), Some{OEnd{}},
  Bool.pick(Maybe<&2, Obj<String, Blob>>, Bool.and(whole, String.starts_with(head, "item ")), decode.item(String.drop(head, 5n)),
    None{})))

def decode.cut(+at: U32, r: Bytes.Bytes & Bytes.Bytes) -> Maybe<&2, Obj<String, Blob>>:
  (b, head) = r
  decode.head(Bytes.to_string(head), at, b)

def decode.at(r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&2, Obj<String, Blob>>:
  match r:
    case (b, None{}):
      None{}
    case (b, Some{+i}):
      decode.cut((i + 1 : U32), Bytes.slice(b, 0, i))

# The object that encode wrote, or None for any other octets.
def decode(b: Bytes.Bytes) -> Maybe<&2, Obj<String, Blob>>:
  decode.at(Bytes.find(b, "\n"))

# ---- IO that can fail

def Run(-A: Type) -> Type:
  IO(Result<&1, &1, U32 & String, A>)

def Run.pure(-A: Type, x: A) -> Run(A):
  IO.pure(Result<&1, &1, U32 & String, A>, Done{x})

def Run.fail(-A: Type, e: U32 & String) -> Run(A):
  IO.pure(Result<&1, &1, U32 & String, A>, Fail{e})

def Run.next(-A: Type, -B: Type, r: Result<&1, &1, U32 & String, A>, f: A -> Run(B)) -> Run(B):
  match r:
    case Done{x}:
      f(x)
    case Fail{e}:
      Run.fail(B, e)

def Run.bind(-A: Type, -B: Type, m: Run(A), f: A -> Run(B)) -> Run(B):
  IO.bind(Result<&1, &1, U32 & String, A>, Result<&1, &1, U32 & String, B>, m, r => Run.next(A, B, r, f))

def Run.lift(-A: Type, m: IO(A)) -> Run(A):
  IO.bind(A, Result<&1, &1, U32 & String, A>, m, x => Run.pure(A, x))

def Run.check(ok: Bool, +why: String) -> Run(Unit):
  match ok:
    case True{}:
      Run.pure(Unit, Unit{})
    case False{}:
      Run.fail(Unit, (22, "storage: " ++ why))

def Run.some(-A: Data, m: Maybe<&2, A>, +why: String) -> Run(A):
  match m:
    case Some{x}:
      Run.pure(A, x)
    case None{}:
      Run.fail(A, (22, "storage: " ++ why))

def digest.hex(r: U32 & Array<U32>) -> String:
  (n, a) = r
  Bytes.to_hex(Bytes.Bytes{n, a})

# The SHA-256 of b, as 64 lowercase hex characters.
def digest(b: Bytes.Bytes) -> Run(String):
  Bytes.Bytes{len, buf} = b
  do Run<String>:
    r : U32 & Array<U32> <- Crypto.sha256.words(len, buf)
    return digest.hex(r)

def commit.done(+d: String, o: Obj<String, Blob>, xs: Store<String, Blob>) -> Run(String & Store<String, Blob>):
  Run.pure(String & Store<String, Blob>, (d, Store.cat(String, Blob, xs, StCon{d, o, StNil{}})))

def commit.node(+o: Obj<String, Blob>, xs: Store<String, Blob>) -> Run(String & Store<String, Blob>):
  do Run<String & Store<String, Blob>>:
    d : String <- digest(encode(o))
    commit.done(d, o, xs)

def commit.item(+n: String, c: String & Store<String, Blob>, r: String & Store<String, Blob>) -> Run(String & Store<String, Blob>):
  (+dc, xs) = c
  (+dr, ys) = r
  do Run<String & Store<String, Blob>>:
    Run.check(name.ok(n), "invalid name " ++ n)
    commit.node(OItem{n, dc, dr}, Store.cat(String, Blob, xs, ys))

# hash and objects with H = SHA-256 of encode: the root digest and the objects, children first.
def commit(t: Tree<Blob>) -> Run(String & Store<String, Blob>):
  match t:
    case TFile{b}:
      commit.node(OFile{b}, StNil{})
    case TEnd{}:
      commit.node(OEnd{}, StNil{})
    case TItem{+n, c, r}:
      do Run<String & Store<String, Blob>>:
        x : String & Store<String, Blob> <- commit(c)
        y : String & Store<String, Blob> <- commit(r)
        commit.item(n, x, y)

def receive.two(+s: Index(String, Blob), +claimed: String, bb: Bytes.Bytes & Bytes.Bytes) -> Run(Index(String, Blob)):
  (b1, b2) = bb
  do Run<Index(String, Blob)>:
    computed : String <- digest(b1)
    o : Obj<String, Blob> <- Run.some(Obj<String, Blob>, decode(b2), "object " ++ claimed ++ " does not decode")
    Run.some(Index(String, Blob), Index.admit(~String, ~Blob, ~Order.string, s, claimed, computed, o), "object " ++ claimed ++ " does not match its digest")

# Ingress: the store with the object that b encodes. Fails when b does not decode or its SHA-256 is not claimed.
def receive(+s: Index(String, Blob), +claimed: String, b: Bytes.Bytes) -> Run(Index(String, Blob)):
  receive.two(s, claimed, Bytes.clone(b))

# ---- A store on disk: dir/objects/<digest> holds each encoded object, dir/roots/<name> a root digest.

def Disk.object(+dir: String, +d: String) -> String:
  dir ++ "/objects/" ++ d

def Disk.init(+dir: String) -> Run(Unit):
  do Run<Unit>:
    Files.mkdir_all(dir ++ "/objects")
    Files.mkdir_all(dir ++ "/roots")
    Files.mkdir_all(dir ++ "/tmp")

def write.close(r: File & Result<&1, &1, U32 & String, Unit>) -> Run(Unit):
  match r:
    case (f, x):
      do IO<Result<&1, &1, U32 & String, Unit>>:
        File.close(f)
        return x

def write.file(+path: String, b: Bytes.Bytes) -> Run(Unit):
  do Run<Unit>:
    f : File <- File.open(path, "w")
    r : File & Result<&1, &1, U32 & String, Unit> <- Run.lift(File & Result<&1, &1, U32 & String, Unit>, Files.write_bytes(f, b))
    write.close(r)

# Writes b to path through dir/tmp and a rename, so a reader sees all of b or nothing.
def write(+dir: String, +name: String, +path: String, b: Bytes.Bytes) -> Run(Unit):
  +tmp = dir ++ "/tmp/" ++ name
  do Run<Unit>:
    write.file(tmp, b)
    Files.rename(tmp, path)

def read.chunk(r: File & Result<&1, &1, U32 & String, Bytes.Bytes>) -> Run(File & Bytes.Bytes):
  match r:
    case (f, Fail{e}):
      do IO<Result<&1, &1, U32 & String, File & Bytes.Bytes>>:
        File.close(f)
        return Fail{e}
    case (f, Done{b}):
      Run.pure(File & Bytes.Bytes, (f, b))

def read.piece(f: File) -> Run(File & Bytes.Bytes):
  IO.bind(File & Result<&1, &1, U32 & String, Bytes.Bytes>, Result<&1, &1, U32 & String, File & Bytes.Bytes>, Files.read_bytes(f, 1048576), r => read.chunk(r))

# n more reads of up to 1 MiB each; fb holds the file and the last piece.
def read.go(n: Nat, fb: File & Bytes.Bytes, acc: Bytes.Bytes) -> Run(Bytes.Bytes):
  match n:
    case 0n:
      (f, b) = fb
      do IO<Result<&1, &1, U32 & String, Bytes.Bytes>>:
        File.close(f)
        return Done{Bytes.append(acc, b)}
    case 1n+p:
      (f, b) = fb
      Run.bind(File & Bytes.Bytes, Bytes.Bytes, read.piece(f), next => read.go(p, next, Bytes.append(acc, b)))

def read.check(+size: U32, b: Bytes.Bytes) -> Run(Bytes.Bytes):
  Bytes.Bytes{+len, buf} = b
  do Run<Bytes.Bytes>:
    Run.check(U32.is_eq(len, size), "short read")
    return Bytes.Bytes{len, buf}

def info.size(i: Files.Info) -> U32:
  Files.Info{k, +n, t} = i
  n

def read.sized(+path: String, +size: U32) -> Run(Bytes.Bytes):
  do Run<Bytes.Bytes>:
    f : File <- File.open(path, "r")
    b : Bytes.Bytes <- read.go(U32.to_nat((size / 1048576 + 1 : U32)), (f, Bytes.new(0)), Bytes.new(0))
    read.check(size, b)

# The whole file at path.
def read(+path: String) -> Run(Bytes.Bytes):
  do Run<Bytes.Bytes>:
    info : Files.Info <- Files.stat(path)
    read.sized(path, info.size(info))


def Disk.put.if(there: Bool, +dir: String, +d: String, +path: String, b: Bytes.Bytes) -> Run(Unit):
  match there:
    case True{}:
      Run.pure(Unit, Unit{})
    case False{}:
      write(dir, d, path, b)

# Writes the encoded object under its digest unless the file exists. Objects never change.
def Disk.put(+dir: String, +d: String, b: Bytes.Bytes) -> Run(Unit):
  +path = Disk.object(dir, d)
  do Run<Unit>:
    there : Bool <- Run.lift(Bool, Files.exists(path))
    Disk.put.if(there, dir, d, path, b)

def Disk.save(+dir: String, xs: Store<String, Blob>) -> Run(Unit):
  match xs:
    case StNil{}:
      Run.pure(Unit, Unit{})
    case StCon{+d, o, r}:
      do Run<Unit>:
        Disk.put(dir, d, encode(o))
        Disk.save(dir, r)

# Ingress into the store at dir: receive, then write the octets under their digest.
def Disk.receive.two(+dir: String, +s: Index(String, Blob), +claimed: String, bb: Bytes.Bytes & Bytes.Bytes) -> Run(Index(String, Blob)):
  (b1, b2) = bb
  do Run<Index(String, Blob)>:
    t : Index(String, Blob) <- receive(s, claimed, b1)
    Disk.put(dir, claimed, b2)
    return t

def Disk.receive(+dir: String, +s: Index(String, Blob), +claimed: String, b: Bytes.Bytes) -> Run(Index(String, Blob)):
  Disk.receive.two(dir, s, claimed, Bytes.clone(b))

def Disk.load.go(+dir: String, names: List<&2, String>, +s: Index(String, Blob)) -> Run(Index(String, Blob)):
  match names:
    case Nil{}:
      Run.pure(Index(String, Blob), s)
    case Con{+n, t}:
      do Run<Index(String, Blob)>:
        b : Bytes.Bytes <- read(Disk.object(dir, n))
        u : Index(String, Blob) <- receive(s, n, b)
        Disk.load.go(dir, t, u)

# Every object at dir, each checked against its file name. A tampered or undecodable object fails the load.
def Disk.load(+dir: String) -> Run(Index(String, Blob)):
  do Run<Index(String, Blob)>:
    names : List<&2, String> <- Files.list_dir(dir ++ "/objects")
    Disk.load.go(dir, names, Index.new(String, Blob))

def Disk.set_root(+dir: String, +name: String, +d: String) -> Run(Unit):
  do Run<Unit>:
    Run.check(Bool.and(name.ok(name), digest.ok(d)), "invalid root " ++ name)
    write(dir, "root." ++ name, dir ++ "/roots/" ++ name, Bytes.from_string(d))

def Disk.root.of(+name: String, +d: String) -> Run(String):
  do Run<String>:
    Run.check(digest.ok(d), "root " ++ name ++ " is not a digest")
    return d

def Disk.root(+dir: String, +name: String) -> Run(String):
  do Run<String>:
    b : Bytes.Bytes <- read(dir ++ "/roots/" ++ name)
    Disk.root.of(name, Bytes.to_string(b))

def Disk.roots.go(+dir: String, names: List<&2, String>) -> Run(List<&2, String>):
  match names:
    case Nil{}:
      Run.pure(List<&2, String>, Nil{})
    case Con{+n, t}:
      do Run<List<&2, String>>:
        d : String <- Disk.root(dir, n)
        ds : List<&2, String> <- Disk.roots.go(dir, t)
        return Con{d, ds}

# The digest of every named root.
def Disk.roots(+dir: String) -> Run(List<&2, String>):
  do Run<List<&2, String>>:
    names : List<&2, String> <- Files.list_dir(dir ++ "/roots")
    Disk.roots.go(dir, names)

def Disk.drop.one(live: Bool, +dir: String, +d: String) -> Run(U32):
  match live:
    case True{}:
      Run.pure(U32, 0)
    case False{}:
      do Run<U32>:
        Files.remove(Disk.object(dir, d))
        return 1

def Disk.drop(+dir: String, ds: List<&2, String>, +live: Index(String, Blob), +n: U32) -> Run(U32):
  match ds:
    case Nil{}:
      Run.pure(U32, n)
    case Con{+d, r}:
      do Run<U32>:
        k : U32 <- Disk.drop.one(Index.has(~String, ~Blob, ~Order.string, live, d), dir, d)
        Disk.drop(dir, r, live, (n + k : U32))

# Drops what gc drops: an object of s stays exactly when its digest is in the live set.
def Disk.collect.of(+dir: String, +retained: List<&2, String>, +s: Index(String, Blob)) -> Run(U32):
  do Run<U32>:
    ls : Store<String, Blob> <- Run.some(Store<String, Blob>, Index.live(~String, ~Blob, ~Order.string, limit(), s, retained), "a retained root does not load")
    Disk.drop(dir, OMap.OMap.keys(String, Obj<String, Blob>, s), Index.of(~String, ~Blob, ~Order.string, ls), 0)

# Deletes every object that no retained root reaches and answers how many it deleted. Fails, and
# deletes nothing, when a retained root does not load. No writer may run during the collection.
def Disk.collect(+dir: String, +retained: List<&2, String>) -> Run(U32):
  do Run<U32>:
    s : Index(String, Blob) <- Disk.load(dir)
    Disk.collect.of(dir, retained, s)

def sync.send(+dir: String, ys: Store<String, Blob>, +dst: Index(String, Blob), +n: U32) -> Run(U32):
  match ys:
    case StNil{}:
      Run.pure(U32, n)
    case StCon{+d, o, r}:
      do Run<U32>:
        t : Index(String, Blob) <- Disk.receive(dir, dst, d, encode(o))
        sync.send(dir, r, t, (n + 1 : U32))

def sync.of(+dst: String, +root: String, +a: Index(String, Blob), +b: Index(String, Blob)) -> Run(U32):
  do Run<U32>:
    ys : Store<String, Blob> <- Run.some(Store<String, Blob>, Index.plan(~String, ~Blob, ~Order.string, limit(), a, b, root), "the source cannot load " ++ root)
    sync.send(dst, ys, b, 0)

# Sends dst every object it needs to load root as src does, through ingress. Answers how many it sent.
def sync(+src: String, +dst: String, +root: String) -> Run(U32):
  do Run<U32>:
    a : Index(String, Blob) <- Disk.load(src)
    b : Index(String, Blob) <- Disk.load(dst)
    sync.of(dst, root, a, b)

# The tree under root at dir. Fails when an object is missing or tampered, or the tree is too deep.
def Disk.checkout(+dir: String, +root: String) -> Run(Tree<Blob>):
  do Run<Tree<Blob>>:
    s : Index(String, Blob) <- Disk.load(dir)
    Run.some(Tree<Blob>, Index.load(~String, ~Blob, ~Order.string, limit(), s, root), "root " ++ root ++ " does not load")

def Disk.commit.save(+dir: String, r: String & Store<String, Blob>) -> Run(String):
  (+d, xs) = r
  do Run<String>:
    Disk.save(dir, xs)
    return d

# Commits t to the store at dir and answers its root digest.
def Disk.commit(+dir: String, t: Tree<Blob>) -> Run(String):
  do Run<String>:
    r : String & Store<String, Blob> <- commit(t)
    Disk.commit.save(dir, r)

# ---- Artifact trees: a directory on disk as a Tree.

type Step is Data:
  Stat{}
  Statted{info: Files.Info}
  Listing{names: List<&2, String>}

# The tree at path. Regular files become TFile and directories become TItem chains in name order.
def snap(fuel: Nat, +path: String, step: Step) -> Run(Tree<Blob>):
  match fuel step:
    case 0n _:
      Run.fail(Tree<Blob>, (36, "storage: " ++ path ++ " is too deep"))
    case 1n+p Stat{}:
      Run.bind(Files.Info, Tree<Blob>, Files.stat(path), i => snap(p, path, Statted{i}))
    case 1n+p Statted{Files.Info{Files.Regular{}, s, t}}:
      Run.bind(Bytes.Bytes, Tree<Blob>, read(path), b => Run.pure(Tree<Blob>, TFile{Blob.of(b)}))
    case 1n+p Statted{Files.Info{Files.Directory{}, s, t}}:
      Run.bind(List<&2, String>, Tree<Blob>, Files.list_dir(path), ns => snap(p, path, Listing{ns}))
    case 1n+p Statted{Files.Info{Files.Other{}, s, t}}:
      Run.fail(Tree<Blob>, (22, "storage: " ++ path ++ " is not a file or a directory"))
    case 1n+p Listing{Nil{}}:
      Run.pure(Tree<Blob>, TEnd{})
    case 1n+(+p) Listing{Con{+n, ns}}:
      do Run<Tree<Blob>>:
        Run.check(name.ok(n), "invalid name " ++ n)
        c : Tree<Blob> <- snap(p, path ++ "/" ++ n, Stat{})
        r : Tree<Blob> <- snap(p, path, Listing{ns})
        return TItem{n, c, r}

def snapshot(+path: String) -> Run(Tree<Blob>):
  snap(limit(), path, Stat{})

# Writes t at path. chain is True when t is the rest of the listing of directory path.
def restore.go(t: Tree<Blob>, +path: String, chain: Bool) -> Run(Unit):
  match t chain:
    case TFile{b} False{}:
      write.file(path, Blob.bytes(b))
    case TEnd{} False{}:
      Files.mkdir(path)
    case TItem{+n, c, r} False{}:
      do Run<Unit>:
        Files.mkdir(path)
        Run.check(name.ok(n), "invalid name " ++ n)
        restore.go(c, path ++ "/" ++ n, False{})
        restore.go(r, path, True{})
    case TEnd{} True{}:
      Run.pure(Unit, Unit{})
    case TItem{+n, c, r} True{}:
      do Run<Unit>:
        Run.check(name.ok(n), "invalid name " ++ n)
        restore.go(c, path ++ "/" ++ n, False{})
        restore.go(r, path, True{})
    case TFile{b} True{}:
      Run.fail(Unit, (22, "storage: a file stands in the listing of " ++ path))

# Writes t as a new file or directory at path. Fails if path exists.
def restore(t: Tree<Blob>, +path: String) -> Run(Unit):
  restore.go(t, path, False{})
