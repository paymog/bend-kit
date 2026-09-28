# HMap: a hash trie keyed by any Data type, with equality-checked collision buckets.
# Equal keys must have equal hashes; different keys with one hash share a bucket.
import Base

type Entry<-K: Data, -V: Data> is Data:
  Entry{key: K, val: V}

type HMap<-K: Data, -V: Data> is Data:
  HNil{}
  HLeaf{hash: U32, entries: List<&2, Entry<K, V>>}
  HBranch{lo: HMap<K, V>, hi: HMap<K, V>}

def HMap.new(-K: Data, -V: Data) -> HMap<K, V>:
  HNil{}

def HMap.bool(-A: Type, b: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match b:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def HMap.entries.put(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool,
  xs: List<&2, Entry<K, V>>, +k: K, +v: V
) -> List<&2, Entry<K, V>>:
  match xs:
    case Nil{}:
      [Entry{k, v}]
    case Con{Entry{+key, +val}, +rest}:
      HMap.bool(List<&2, Entry<K, V>>, eq(k, key),
        u => Entry{key, v} <> rest,
        u => Entry{key, val} <> HMap.entries.put(~K, ~V, ~eq, rest, k, v))

def HMap.entries.get(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool,
  xs: List<&2, Entry<K, V>>, +k: K
) -> Maybe<&2, V>:
  match xs:
    case Nil{}:
      None{}
    case Con{Entry{+key, +val}, +rest}:
      HMap.bool(Maybe<&2, V>, eq(k, key),
        u => Some{val},
        u => HMap.entries.get(~K, ~V, ~eq, rest, k))

def HMap.split.side(
  -K: Data, -V: Data, left: Bool, old: HMap<K, V>, fresh: HMap<K, V>
) -> HMap<K, V>:
  match left:
    case True{}:
      HBranch{old, fresh}
    case False{}:
      HBranch{fresh, old}

def HMap.split(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool,
  +n: Nat, +mask: U32, +oldhash: U32, +entries: List<&2, Entry<K, V>>,
  +hash: U32, +k: K, +v: V
) -> HMap<K, V>:
  match n:
    case 0n:
      HLeaf{oldhash, HMap.entries.put(~K, ~V, ~eq, entries, k, v)}
    case 1n+p:
      HMap.bool(HMap<K, V>, U32.is_eq((oldhash .&. mask : U32), (hash .&. mask : U32)),
        u => HMap.bool(HMap<K, V>, U32.is_eq((oldhash .&. mask : U32), 0),
          x => HBranch{HMap.split(~K, ~V, ~eq, p, (mask << 1n : U32), oldhash, entries, hash, k, v), HNil{}},
          x => HBranch{HNil{}, HMap.split(~K, ~V, ~eq, p, (mask << 1n : U32), oldhash, entries, hash, k, v)}),
        u => HMap.split.side(K, V, U32.is_eq((oldhash .&. mask : U32), 0),
          HLeaf{oldhash, entries}, HLeaf{hash, [Entry{k, v}]}))

def HMap.put.go(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool,
  +n: Nat, +mask: U32, m: HMap<K, V>, +hash: U32, +k: K, +v: V
) -> HMap<K, V>:
  match n:
    case 0n:
      match m:
        case HNil{}:
          HLeaf{hash, [Entry{k, v}]}
        case HLeaf{oldhash, entries}:
          HLeaf{oldhash, HMap.entries.put(~K, ~V, ~eq, entries, k, v)}
        case HBranch{lo, hi}:
          HBranch{lo, hi}
    case 1n+p:
      match m:
        case HNil{}:
          HLeaf{hash, [Entry{k, v}]}
        case HLeaf{+oldhash, +entries}:
          HMap.bool(HMap<K, V>, U32.is_eq(oldhash, hash),
            u => HLeaf{oldhash, HMap.entries.put(~K, ~V, ~eq, entries, k, v)},
            u => HMap.split(~K, ~V, ~eq, n, mask, oldhash, entries, hash, k, v))
        case HBranch{+lo, +hi}:
          HMap.bool(HMap<K, V>, U32.is_eq((hash .&. mask : U32), 0),
            u => HBranch{HMap.put.go(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hash, k, v), hi},
            u => HBranch{lo, HMap.put.go(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hash, k, v)})

def HMap.put(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  m: HMap<K, V>, +k: K, v: V
) -> HMap<K, V>:
  HMap.put.go(~K, ~V, ~eq, 32n, 1, m, hash(k), k, v)

def HMap.get.go(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool,
  +n: Nat, +mask: U32, m: HMap<K, V>, +hash: U32, +k: K
) -> Maybe<&2, V>:
  match n:
    case 0n:
      match m:
        case HNil{}:
          None{}
        case HLeaf{oldhash, entries}:
          HMap.entries.get(~K, ~V, ~eq, entries, k)
        case HBranch{lo, hi}:
          None{}
    case 1n+p:
      match m:
        case HNil{}:
          None{}
        case HLeaf{oldhash, entries}:
          HMap.bool(Maybe<&2, V>, U32.is_eq(oldhash, hash),
            u => HMap.entries.get(~K, ~V, ~eq, entries, k),
            u => None{})
        case HBranch{+lo, +hi}:
          HMap.bool(Maybe<&2, V>, U32.is_eq((hash .&. mask : U32), 0),
            u => HMap.get.go(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hash, k),
            u => HMap.get.go(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hash, k))

def HMap.get(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  m: HMap<K, V>, +k: K
) -> Maybe<&2, V>:
  HMap.get.go(~K, ~V, ~eq, 32n, 1, m, hash(k), k)

def HMap.size(-K: Data, -V: Data, m: HMap<K, V>) -> Nat:
  match m:
    case HNil{}:
      0n
    case HLeaf{hash, entries}:
      List.length(&2, Entry<K, V>, entries)
    case HBranch{lo, hi}:
      Nat.add(HMap.size(K, V, lo), HMap.size(K, V, hi))
