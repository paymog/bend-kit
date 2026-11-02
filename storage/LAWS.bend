import Base
import ./storage.bend as S

# eq(d, x) for some root x.
def member(~D: Data, ~eq: D -> D -> Bool, xs: List<&2, D>, +d: D) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{x, t}:
      Bool.or(eq(d, x), member(~D, ~eq, t, d))

# Tree construction and traversal preserve content. A valid store keeps every
# digest equal to the hash of its object; inj is the collision-resistance assumption.
law build_load:
  for ~D: Data
  for ~B: Data
  for ~H: S.Obj<D, B> -> D
  for ~eq: D -> D -> Bool
  for ~sound: @x: D -> @y: D -> {eq(x, y) == True{} : Bool} -> {x == y : D}
  for ~refl: @x: D -> {eq(x, x) == True{} : Bool}
  for ~inj: @a: S.Obj<D, B> -> @b: S.Obj<D, B> -> {H(a) == H(b) : D} -> {a == b : S.Obj<D, B>}
  for t: S.Tree<B>
  for s: S.Store<D, B>
  for fuel: Nat
  for hs: {S.valid(~D, ~B, ~H, ~eq, s) == True{} : Bool}
  for hf: {S.fits(B, fuel, t) == True{} : Bool}
  {S.load(~D, ~B, ~eq, fuel, S.Store.apply(~D, ~B, ~eq, S.objects(~D, ~B, ~H, t), s), S.hash(~D, ~B, ~H, t))
   == Some{t} : Maybe<&2, S.Tree<B>>}

# A load that succeeds from a valid store hashes back to the requested root:
# there is no partial or substituted reconstruction.
law load_hash:
  for ~D: Data
  for ~B: Data
  for ~H: S.Obj<D, B> -> D
  for ~eq: D -> D -> Bool
  for ~sound: @x: D -> @y: D -> {eq(x, y) == True{} : Bool} -> {x == y : D}
  for fuel: Nat
  for s: S.Store<D, B>
  for d: D
  for t: S.Tree<B>
  for hs: {S.valid(~D, ~B, ~H, ~eq, s) == True{} : Bool}
  for hl: {S.load(~D, ~B, ~eq, fuel, s, d) == Some{t} : Maybe<&2, S.Tree<B>>}
  {S.hash(~D, ~B, ~H, t) == d : D}

# A plan exists exactly when the source can load the root.
law plan_some:
  for ~D: Data
  for ~B: Data
  for ~eq: D -> D -> Bool
  for fuel: Nat
  for src: S.Store<D, B>
  for dst: S.Store<D, B>
  for root: D
  {Maybe.is_some(&2, S.Store<D, B>, S.plan(~D, ~B, ~eq, fuel, src, dst, root))
   == Maybe.is_some(&2, S.Tree<B>, S.load(~D, ~B, ~eq, fuel, src, root)) : Bool}

# Applying the plan lets the destination load the root exactly as the source does.
law sync_load:
  for ~D: Data
  for ~B: Data
  for ~H: S.Obj<D, B> -> D
  for ~eq: D -> D -> Bool
  for ~sound: @x: D -> @y: D -> {eq(x, y) == True{} : Bool} -> {x == y : D}
  for ~refl: @x: D -> {eq(x, x) == True{} : Bool}
  for ~inj: @a: S.Obj<D, B> -> @b: S.Obj<D, B> -> {H(a) == H(b) : D} -> {a == b : S.Obj<D, B>}
  for fuel: Nat
  for src: S.Store<D, B>
  for dst: S.Store<D, B>
  for root: D
  for ys: S.Store<D, B>
  for hs: {S.valid(~D, ~B, ~H, ~eq, src) == True{} : Bool}
  for hd: {S.valid(~D, ~B, ~H, ~eq, dst) == True{} : Bool}
  for hp: {S.plan(~D, ~B, ~eq, fuel, src, dst, root) == Some{ys} : Maybe<&2, S.Store<D, B>>}
  {S.load(~D, ~B, ~eq, fuel, S.Store.apply(~D, ~B, ~eq, ys, dst), root)
   == S.load(~D, ~B, ~eq, fuel, src, root) : Maybe<&2, S.Tree<B>>}

# A repeated transfer does not change the store.
law apply_twice:
  for ~D: Data
  for ~B: Data
  for ~eq: D -> D -> Bool
  for ~sound: @x: D -> @y: D -> {eq(x, y) == True{} : Bool} -> {x == y : D}
  for ~refl: @x: D -> {eq(x, x) == True{} : Bool}
  for xs: S.Store<D, B>
  for s: S.Store<D, B>
  {S.Store.apply(~D, ~B, ~eq, xs, S.Store.apply(~D, ~B, ~eq, xs, s))
   == S.Store.apply(~D, ~B, ~eq, xs, s) : S.Store<D, B>}

# Collection keeps every object that a retained root reaches.
law gc_load:
  for ~D: Data
  for ~B: Data
  for ~eq: D -> D -> Bool
  for ~sound: @x: D -> @y: D -> {eq(x, y) == True{} : Bool} -> {x == y : D}
  for ~refl: @x: D -> {eq(x, x) == True{} : Bool}
  for fuel: Nat
  for s: S.Store<D, B>
  for roots: List<&2, D>
  for g: S.Store<D, B>
  for r: D
  for hg: {S.gc(~D, ~B, ~eq, fuel, s, roots) == Some{g} : Maybe<&2, S.Store<D, B>>}
  for hr: {member(~D, ~eq, roots, r) == True{} : Bool}
  {S.load(~D, ~B, ~eq, fuel, g, r) == S.load(~D, ~B, ~eq, fuel, s, r) : Maybe<&2, S.Tree<B>>}

# Ingress keeps a valid store valid when the native hash is honest.
law admit_valid:
  for ~D: Data
  for ~B: Data
  for ~H: S.Obj<D, B> -> D
  for ~eq: D -> D -> Bool
  for ~sound: @x: D -> @y: D -> {eq(x, y) == True{} : Bool} -> {x == y : D}
  for ~refl: @x: D -> {eq(x, x) == True{} : Bool}
  for s: S.Store<D, B>
  for claimed: D
  for o: S.Obj<D, B>
  for u: S.Store<D, B>
  for hs: {S.valid(~D, ~B, ~H, ~eq, s) == True{} : Bool}
  for ha: {S.admit(~D, ~B, ~eq, s, claimed, H(o), o) == Some{u} : Maybe<&2, S.Store<D, B>>}
  {S.valid(~D, ~B, ~H, ~eq, u) == True{} : Bool}

# A tampered object, whose digest is not the claimed one, is refused.
law admit_rejects:
  for ~D: Data
  for ~B: Data
  for ~eq: D -> D -> Bool
  for s: S.Store<D, B>
  for claimed: D
  for computed: D
  for o: S.Obj<D, B>
  for he: {eq(claimed, computed) == False{} : Bool}
  {S.admit(~D, ~B, ~eq, s, claimed, computed, o) == None{} : Maybe<&2, S.Store<D, B>>}

# Fixtures: U32 digests and payloads, with a toy object hash.
def toy(o: S.Obj<U32, U32>) -> U32:
  match o:
    case S.OFile{b}:
      (b * 7 + 1 : U32)
    case S.OEnd{}:
      2
    case S.OItem{n, c, r}:
      (c * 1000 + r * 10 + 3 : U32)

# A directory with "a" holding a file of 5, and "b" holding an empty directory.
def tree() -> S.Tree<U32>:
  S.TItem{"a", S.TFile{5}, S.TItem{"b", S.TEnd{}, S.TEnd{}}}

def built() -> S.Store<U32, U32>:
  S.Store.apply(~U32, ~U32, ~U32.is_eq, S.objects(~U32, ~U32, ~toy, tree()), S.Store.new(U32, U32))

def root() -> U32:
  S.hash(~U32, ~U32, ~toy, tree())

law fixture_root:
  {root() == 56233 : U32}

law fixture_build:
  {S.load(~U32, ~U32, ~U32.is_eq, 3n, built(), root()) == Some{tree()} : Maybe<&2, S.Tree<U32>>}

law fixture_fuel:
  {S.load(~U32, ~U32, ~U32.is_eq, 2n, built(), root()) == None{} : Maybe<&2, S.Tree<U32>>}

# The shared empty directory is stored once: four objects for five nodes.
law fixture_dedup:
  {S.Store.size(U32, U32, built()) == 4 : U32}

# Without the file object, the root does not load.
law fixture_missing:
  {S.load(~U32, ~U32, ~U32.is_eq, 3n, S.keep(~U32, ~U32, ~U32.is_eq, built(),
     S.StCon{2, S.OEnd{}, S.StCon{2023, S.OItem{"b", 2, 2}, S.StCon{root(), S.OItem{"a", 36, 2023}, S.StNil{}}}}), root())
   == None{} : Maybe<&2, S.Tree<U32>>}

# A destination that holds the empty directory needs the other three objects.
law fixture_plan:
  {S.plan(~U32, ~U32, ~U32.is_eq, 3n, built(), S.StCon{2, S.OEnd{}, S.StNil{}}, root())
   == Some{S.StCon{root(), S.OItem{"a", 36, 2023}, S.StCon{36, S.OFile{5}, S.StCon{2023, S.OItem{"b", 2, 2}, S.StNil{}}}}}
   : Maybe<&2, S.Store<U32, U32>>}

law fixture_tamper:
  {S.admit(~U32, ~U32, ~U32.is_eq, S.Store.new(U32, U32), 36, toy(S.OFile{6}), S.OFile{6})
   == None{} : Maybe<&2, S.Store<U32, U32>>}

# Retaining only the "b" subtree drops the file and the top directory.
law fixture_gc:
  {S.gc(~U32, ~U32, ~U32.is_eq, 3n, built(), [2023])
   == Some{S.StCon{2023, S.OItem{"b", 2, 2}, S.StCon{2, S.OEnd{}, S.StNil{}}}} : Maybe<&2, S.Store<U32, U32>>}
