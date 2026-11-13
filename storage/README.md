# storage

An immutable content-addressed object store for artifact trees, such as a build output directory. Each object is named by the SHA-256 of its canonical encoding. Two stores exchange only the objects one of them lacks, every object is checked against its digest when it enters a store, and collection keeps every object that a retained root reaches. `LAWS.bend` states these properties for every store, and `PROOF.bend` proves them.

```bend
import bend-kit-storage@0.2.0.0/storage.bend as S
```

It imports `bend-kit-bytes@0.3.3.0`, `bend-kit-files@0.3.1.0`, `bend-kit-crypto@0.2.2.2`, and `bend-kit-collections@0.1.5.0`. SHA-256 comes from OpenSSL 3 through `crypto`; set `BEND_LIBCRYPTO` when `libcrypto.3` is not on the default path.

## Example

Snapshot a build directory into store `a`, send it to store `b`, and restore it from `b`.

```bend
import Base
import bend-kit-storage@0.2.0.0/storage.bend as S

def ship(+root: String) -> S.Run(Unit):
  do S.Run<Unit>:
    S.Disk.set_root("a", "release", root)
    sent : U32 <- S.sync("a", "b", root)
    t : S.Tree<S.Blob> <- S.Disk.checkout("b", root)
    S.restore(t, "restored")
    S.Run.lift(Unit, IO.print(root))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.try(Unit, S.Disk.init("a"))
    IO.try(Unit, S.Disk.init("b"))
    t : S.Tree<S.Blob> <- IO.try(S.Tree<S.Blob>, S.snapshot("build"))
    root : String <- IO.try(String, S.Disk.commit("a", t))
    IO.try(Unit, ship(root))
```

It prints the root digest. A second `sync` sends nothing. [check.bend](check.bend) runs three stores through a partial transfer, a repeated transfer, a tampered object, a missing object, and a collection.

## Model

The pure core is generic. A digest has any `Data` type `D` with an equality test `eq: D -> D -> Bool`, and a file payload has any `Data` type `B`.

| type | values |
|---|---|
| `Tree<B>` | `TFile{data}`, or a directory: `TEnd{}` or `TItem{name, child, rest}`, where `rest` is the rest of the listing |
| `Obj<D, B>` | `OFile{data}`, `OEnd{}`, or `OItem{name, child, rest}`, where `child` and `rest` are digests |
| `Store<D, B>` | `StNil{}` or `StCon{key, obj, rest}`: objects by digest, as a list |
| `Index(D, B)` | `OMap<D, Obj<D, B>>` from `collections`: objects by digest, ordered by a comparator `cmp: D -> D -> Cmp` |

Each directory entry is one object, and the end of every listing is the same `OEnd` object. So equal subtrees and equal listing tails are stored once, and a change to one file adds the new file and the entries above it.

A store is valid when every key equals the hash of its object. `put` adds an object unless its digest is already there, so the first object under a digest stays and a store never changes an object.

`Store` is the model: the laws reason about it, and its `get` and `put` walk the list. `Index` is what the disk layer uses: `get` and `put` take O(log n) comparisons. `Index.of(xs)` puts the entries of `xs` in order, and the `index_` laws prove that it answers every `get`, `load`, `plan`, and `live` exactly as the list store `Store.apply(xs, Store.new)` does. So every law about `Store` holds for the index.

The disk layer fixes `D` to `String` (64 lowercase hex characters of SHA-256), `B` to `Blob`, the octets of a file packed four to a `U32`, and `cmp` to `Order.string` from `collections`.

## Encoding

`encode` writes one of three forms. Names are octet strings, one `Char` for each octet.

| object | octets |
|---|---|
| `OFile{b}` | `file <len>\n`, then the octets; `<len>` is decimal with no leading zero |
| `OEnd{}` | `end\n` |
| `OItem{n, c, r}` | `item <c> <r> <n>\n` |

`decode` accepts exactly these forms. It refuses trailing octets, a wrong length, a digest that is not 64 lowercase hex characters, and a name that is empty, `.`, or `..`, is longer than 255 octets, or holds NUL, newline, `/`, or a `Char` above 255. So a restored tree cannot write outside its directory.

## API

Import `storage.bend` as `S`. The pure functions take `~D`, `~B`, and `~eq` or `~cmp` as templates, as in `S.load(~String, ~S.Blob, ~String.eq, fuel, s, d)` or `S.Index.load(~String, ~S.Blob, ~Order.string, fuel, m, d)`.

| def | result |
|---|---|
| `Store.get(s, d)`, `Store.has(s, d)` | the first object under `d`; whether there is one |
| `Store.put(s, d, o)`, `Store.apply(xs, s)` | `s` with `o` under `d` unless `d` is present; each entry of `xs` put in order |
| `load(fuel, s, d)` | `Maybe`: the tree under `d`; `None` when an object is missing or the tree needs more than `fuel` levels |
| `closure(fuel, s, d)` | `Maybe`: every object `load` reads |
| `plan(fuel, src, dst, root)` | `Maybe`: the objects of the closure of `root` in `src` that `dst` lacks, each once; `None` when `src` cannot load `root` |
| `live(fuel, s, roots)` | `Maybe`: the closures of every root; `None` when a root does not load |
| `gc(fuel, s, roots)` | `Maybe`: `s` without the objects no root reaches; `None` when a root does not load |
| `admit(s, claimed, computed, o)` | `Maybe`: `s` with `o` under `claimed`; `None` when `eq(claimed, computed)` is false |
| `hash(~H, t)`, `objects(~H, t)` | the Merkle digest of `t` under the object hash `H`; the objects of `t` with their digests, children first |
| `fits(fuel, t)`, `valid(~H, s)` | whether `load` with `fuel` reaches every node of `t`; whether every key of `s` is the hash of its object |
| `Index.new`, `Index.size(m)`, `Index.get(m, d)`, `Index.has(m, d)`, `Index.put(m, d, o)`, `Index.apply(xs, m)`, `Index.of(xs)` | the `Store` operations on an index; `Index.of(xs)` is `Index.apply(xs, Index.new)` |
| `Index.load`, `Index.closure`, `Index.plan`, `Index.live`, `Index.admit` | `load`, `closure`, `plan`, `live`, and `admit` on an index; `plan` takes two indexes |

Each level of a tree and each entry of a listing costs one unit of fuel. The disk layer uses `limit()`, 1,048,576.

The disk layer returns `S.Run(A)`, which is `IO(Result<&1, &1, U32 & String, A>)`. Use it in a `do S.Run<A>:` block, or unwrap it with `IO.try`.

| def | result |
|---|---|
| `encode(o)`, `decode(b)` | the canonical octets of `o`; `Maybe`: the object that `b` encodes |
| `digest(b)` | the SHA-256 of `b` as hex |
| `commit(t)` | the root digest and `objects(t)`, with `H` = SHA-256 of `encode`; fails on an invalid name |
| `receive(m, claimed, b)` | ingress: index `m` with the object `b` encodes; fails when `b` does not decode or its digest is not `claimed` |
| `Disk.init(dir)` | creates `dir/objects`, `dir/roots`, and `dir/tmp` |
| `Disk.commit(dir, t)` | writes the objects of `t` and answers its root digest |
| `Disk.load(dir)` | an `Index` of every object, each through `receive` against its file name |
| `Disk.receive(dir, m, claimed, b)` | `receive`, then writes `b` under its digest |
| `Disk.checkout(dir, root)` | the tree under `root`; fails when an object is missing or tampered |
| `Disk.set_root(dir, name, d)`, `Disk.root(dir, name)`, `Disk.roots(dir)` | named roots in `dir/roots` |
| `Disk.collect(dir, retained)` | deletes the objects that `live` does not reach and answers how many; deletes nothing when a retained root does not load |
| `sync(src, dst, root)` | sends `dst` the objects of `Index.plan` through `Disk.receive` and answers how many |
| `snapshot(path)`, `restore(t, path)` | a directory on disk as a `Tree`; a `Tree` written as a new file or directory |

## Laws

`LAWS.bend` states these for every digest type, payload type, store, and tree. `PROOF.bend` proves them.

| law | claim |
|---|---|
| `build_load` | putting `objects(t)` in a valid store lets `load` return `t` from `hash(t)`, when `fits(fuel, t)` |
| `load_hash` | a tree that `load` returns from a valid store hashes back to the requested digest, so no load is partial or substituted |
| `plan_some` | `plan` succeeds exactly when the source can load the root |
| `sync_load` | after applying the plan to a valid destination, the destination loads the root exactly as the source does |
| `apply_twice` | applying the same objects twice gives the same store as applying them once |
| `gc_load` | collection leaves the load of every retained root unchanged |
| `admit_valid` | ingress keeps a valid store valid when the computed digest is the hash of the object |
| `admit_rejects` | ingress refuses an object whose computed digest is not the claimed one |
| `index_get`, `index_load`, `index_plan`, `index_live` | `Index.of(xs)` answers as `Store.apply(xs, Store.new)` does |
| `index_has_mem`, `gc_has` | the index of a live set has a digest exactly when `mem` does; `gc` keeps an object of `s` exactly when `mem` says it is live, so `Disk.collect` deletes what `gc` drops |

The laws take the facts they need as hypotheses: `eq` is sound (`eq(x, y)` gives `x == y`) and reflexive, and `H` is injective (`inj`). The `index_` laws take `cmp` as a total order whose `EQ` means equal (the facts `collections` uses for `OMap`) and `agree`: `eq(x, y)` is `Cmp.is_eq(cmp(x, y))`. The disk layer uses `Order.string`; `collections` proves that it is a total order. The fixture laws check the same functions on `U32` digests with a toy hash.

## Trust boundary

The proofs cover the pure core. They do not cover hashing, the disk, or the copy between two stores.

- **Collision resistance.** The proofs assume that the object hash is injective. SHA-256 is not injective; the assumption is that no one finds two objects with one digest.
- **Native hashing.** `digest` calls OpenSSL. The proofs assume it computes SHA-256 of the octets it receives. `commit` repeats the shape of `objects` and `hash` in `IO`; the proofs cover `objects` and `hash`.
- **Encoding.** `decode` is the inverse of `encode` on the objects `commit` writes. `check.bend` tests this; no law states it.
- **Filesystem.** A write goes to `dir/tmp` and then a rename, so a reader sees a whole object or none. Nothing calls `fsync`. After a crash an object file can be empty or short; `Disk.load` then fails on that object, because its digest does not match.
- **Concurrent writers.** Two writers can commit at once: objects never change, and a rename replaces a file with the same octets. `Disk.set_root` keeps the last rename. `Disk.collect` needs a frozen root set: no commit, sync, or root change may run during it, or it can delete an object that a new root needs.
- **Trees on disk.** `snapshot` follows symbolic links and fails on other special files. A link cycle fails at the fuel limit.

## Limits

- `get` and `put` on an `Index` take O(log n) comparisons of digests. Each comparison walks two digest `String`s. See [bench/README.md](bench/README.md).
- `Disk.load` reads and checks every object in the store. `sync`, `Disk.checkout`, and `Disk.collect` load the whole store first.
- A file is at most 4 GiB minus one octet, because `Blob.len` is a `U32`.

## Bench

`bench/` times a commit and a load of an artifact tree against the obvious loop over a library SHA-256 and a map in C, Rust, Python, and JavaScript. See [bench/README.md](bench/README.md).
