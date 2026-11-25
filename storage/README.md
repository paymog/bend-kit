# storage

An immutable content-addressed object store for artifact trees, such as a build output directory. Each object is named by the SHA-256 of its canonical encoding. Two stores exchange only the objects one of them lacks, every object is checked against its digest when it enters a store, and collection keeps every object that a retained root reaches. `LAWS.bend` states these properties for every store, and `PROOF.bend` proves them.

```bend
import bend-kit-storage@0.10.0.0/storage.bend as S
import bend-kit-storage@0.10.0.0/pure.bend as P
```

`pure.bend` owns the model, digest types and ordering, and encoding and decoding helpers. It imports no foreign effects. `LAWS.bend` and `PROOF.bend` import only this module. `storage.bend` owns hashing and disk IO. Import both modules for disk operations; pure types and constructors use `P`, and effects use `S`.

It imports `bend-kit-bytes@0.3.3.1`, `bend-kit-files@0.4.0.1`, `bend-kit-crypto@0.2.2.2`, and `bend-kit-collections@0.1.6.0`. SHA-256 comes from OpenSSL 3 through `crypto`; set `BEND_LIBCRYPTO` when `libcrypto.3` is not on the default path.

## Example

Snapshot a build directory into store `a`, send it to store `b`, and restore it from `b`.

```bend
import Base
import bend-kit-storage@0.10.0.0/storage.bend as S
import bend-kit-storage@0.10.0.0/pure.bend as P

def ship(+root: P.Digest) -> S.Run(Unit):
  do S.Run<Unit>:
    S.Disk.set_root("a", "release", root)
    sent : U32 <- S.sync("a", "b", root)
    t : P.Tree<P.Blob> <- S.Disk.checkout("b", root)
    S.restore(t, "restored")
    S.Run.lift(Unit, IO.print(P.Digest.hex(root)))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.try(Unit, S.Disk.init("a"))
    IO.try(Unit, S.Disk.init("b"))
    t : P.Tree<P.Blob> <- IO.try(P.Tree<P.Blob>, S.snapshot("build"))
    root : P.Digest <- IO.try(P.Digest, S.Disk.commit("a", t))
    IO.try(Unit, ship(root))
```

It prints the root digest in hex. A second `sync` sends nothing. [check.bend](check.bend) runs three stores through a partial transfer, a repeated transfer, a tampered object, a missing object, and a collection.

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

The disk layer fixes `D` to `Digest`, `B` to `Blob`, the octets of a file packed four to a `U32`, and `cmp` to `Digest.cmp`. A `Digest` holds the 32 octets of a SHA-256 packed into eight `U32`s. Files and roots on disk name a digest by its 64 lowercase hex characters: `Digest.hex(d)` writes them and `Digest.read(s)` reads them back.

`Blob.of(bytes)` and `Blob.string(text)` return `Run(Blob)`. They hash the packed bytes before building the reusable word list. A Blob carries the SHA-256 of its canonical file encoding. `commit` reuses this digest without encoding the file or walking its word list. `Tree` and `Obj` stay `Data`. Construct Blobs through these functions, `snapshot`, or `decode`; a manually forged Blob can carry a digest that does not match its contents.

## Encoding

`encode` writes one of three forms. Names are octet strings, one `Char` for each octet.

| object | octets |
|---|---|
| `OFile{b}` | `file <len>\n`, then the octets; `<len>` is decimal with no leading zero |
| `OEnd{}` | `end\n` |
| `OItem{n, c, r}` | `item <c> <r> <n>\n` |

`decode` accepts exactly these forms. It refuses trailing octets, a wrong length, a digest that is not 64 lowercase hex characters, and a name that is empty, `.`, or `..`, is longer than 255 octets, or holds NUL, newline, `/`, or a `Char` above 255. So a restored tree cannot write outside its directory.

## API

Import `storage.bend` as `S`. The pure functions take `~D`, `~B`, and `~eq` or `~cmp` as templates, as in `P.load(~U32, ~U32, ~U32.is_eq, fuel, s, d)` or `P.Index.load(~P.Digest, ~P.Blob, ~P.Digest.cmp, fuel, m, d)`.

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
| `encode(o)` | the canonical octets of `o`, as a pure `Bytes` |
| `decode(b)` | `Run(Maybe)`: the object that `b` encodes, with a verified cached file digest |
| `Blob.of(b)`, `Blob.string(s)` | `Run(Blob)`: reusable file octets with their canonical SHA-256 |
| `object.digest(o)` | `Run(Digest)`: the cached file digest, or SHA-256 of an end or item encoding |
| `digest(b)` | the SHA-256 of `b` as a `Digest` |
| `Digest.hex(d)`, `Digest.read(s)`, `Digest.cmp(a, b)` | 64 lowercase hex characters; `Maybe`: the digest that `s` names; a total order on digests, not hex order |
| `commit(t)` | the root digest and `objects(t)`, with `H` = SHA-256 of `encode`; fails on an invalid name |
| `receive(m, claimed, b)` | ingress: index `m` with the object `b` encodes; fails when `b` does not decode or its digest is not `claimed` |
| `Disk.init(dir)` | creates `dir/objects`, `dir/roots`, and `dir/tmp` |
| `Disk.commit(dir, t)` | writes the objects of `t` and answers its root digest |
| `Disk.load(dir)` | an `Index` of every object, each through `receive` against its file name |
| `Disk.fetch(dir, root)` | an `Index` of the objects that `root` reaches, each read once through `receive`; other objects are not read, and a missing object is left out |
| `Disk.receive(dir, m, claimed, b)` | `receive`, then writes `b` under its digest |
| `Disk.checkout(dir, root)` | the tree under `root`, through `Disk.fetch`; fails when an object is missing or tampered |
| `Disk.set_root(dir, name, d)`, `Disk.root(dir, name)`, `Disk.roots(dir)` | named roots in `dir/roots` |
| `Disk.collect(dir, retained)` | deletes the objects that `live` does not reach and answers how many; deletes nothing when a retained root does not load. It reads only the objects the retained roots reach |
| `Disk.collect_named(dir)` | selects all named roots and collects their closure under one exclusive lock; malformed roots and missing or corrupt closures cause no deletion |
| `Disk.clean_tmp(dir)` | exclusively deletes files directly under `dir/tmp` and answers how many; fails immediately while a cooperating writer is active |
| `sync(src, dst, root)` | sends `dst` the objects of `Index.plan` through `Disk.receive` and answers how many. It reads the objects `root` reaches in `src`, and in `dst` only those of them that `dst` holds |
| `snapshot(path)`, `restore(t, path)` | a directory on disk as a `Tree`; a `Tree` written as a new file or directory |

`Disk.set_root` validates canonical objects with 64 KiB reads and keeps only links and a visited index. It verifies and syncs each reachable digest once, then syncs the objects directory before publishing the root. Payload memory does not grow with file size. Index memory grows with the number of distinct objects. `root_check.bend`, included in both package check lanes, checks a 17 MiB file and a 24-level shared graph without expanding its paths.

Use `Disk.collect_named` to retain the current named roots. Separate `Disk.roots` and `Disk.collect` calls are not a transaction: a root writer can enter between them. Keep `Disk.collect` for an external retention policy. Its caller must protect root selection when that policy requires it.

## HTTP synchronization

Import `bend-kit-storage@0.10.0.0/http.bend` as `Transport`. This module adds `bend-kit-http@0.44.0.1`; the pure storage core does not import HTTP.

Import HTTP models and state functions from `pure.bend` as `Pure`, and client/server handles and effects from `http.bend` as `Http`:

```bend
import bend-kit-http@0.44.0.1/pure.bend as Pure
import bend-kit-http@0.44.0.1/http.bend as Http
```

Handlers take `Pure.Req`; server configuration uses `Pure.server.config(host, port)`. Startup errors and server exits are `Pure.StartupError` and `Pure.ServerExit`. Model deadlines use `bend-kit-time@0.3.0.2/pure.bend` values returned by `Http.clock.now()` and `Http.clock.mono()`.

`Transport.handle(dir, request)` returns `Http.WriteHead<Transport.Source>`. It serves `GET /objects/<digest>` as `application/octet-stream`. Invalid paths and missing objects return 404; other disk failures return 500. Mount it with `Http.server.start(~String, ~Unit, dir, Unit{}, config)` and `Transport.server.run(~observe, server)`. The observer has type `String -> U32 -> Completion.Outcome -> IO(Unit)` and may call `Completion.ignore(status, outcome)`. Custom write servers can use `Transport.write` and `Transport.dispose`, or `Transport.talk` with their own context and start handler. The caller owns the listener, bind address, admission limits, shutdown, authentication, and TLS termination.

The client is:

```bend
import Base
import bend-kit-storage@0.10.0.0/storage.bend as S
import bend-kit-storage@0.10.0.0/pure.bend as P
import bend-kit-storage@0.10.0.0/http.bend as Transport

def pull(+root: P.Digest) -> S.Run(U32):
  Transport.sync("https://artifacts.example", "b", root)
```

Initialize destination `b` first. Supply an HTTP(S) origin without a trailing slash and a trusted root digest. The result counts fetched objects. A second sync fetches nothing. The client walks local objects too, so an existing parent does not hide a missing descendant. It validates local and fetched objects with bounded reads. Each remote response goes to its own temporary file. SHA-256 and canonical encoding must pass before an atomic rename publishes the object. A missing object, non-200 status, transport error, bad encoding, digest mismatch, or depth overflow fails the sync. Failed transfers remove their temporary files. Verified objects already received remain available for a retry; no root is published automatically.

One owned HTTP client pool serves the whole walk. It reuses idle connections between object GETs and closes every retained connection before the sync returns, on success or failure.

HTTP failures keep the `S.Run` error pair. Request and stream errors distinguish invalid URLs, DNS, connection, TLS, read, write, timeout, redirect, and invalid responses. Host errors retain their code and message. Invalid responses can mean malformed data, unsupported framing, or a response limit. Transfer errors and non-200 statuses include the claimed object digest.

The design follows [Git's dumb HTTP protocol](https://git-scm.com/docs/http-protocol#_dumb_protocol): fetch immutable objects by content address and walk their links from a known root. This is not the Git wire format. The local verified index holds links and the visited set, not file payloads, so shared objects are fetched once. No remote inventory, pack negotiation, rsync delta stream, or separate closure endpoint is needed.

Keep the source roots and their closure available for the transfer. Do not run collection against either store during a sync. Multiple writers may sync into one destination. The handler exposes every object under the configured store, not only one root. Put private stores behind access control; a digest is not an authorization token.

The client accepts encoded objects up to 4,294,967,295 octets. A file payload can therefore hold at most 4,294,967,279 octets with its 16-octet header. Each network read has a 30 s timeout. The client requests identity encoding and reads the raw HTTP stream in pieces of at most 64 KiB. Disk verification uses a 64 KiB buffer and a header of at most 400 octets. Payload memory does not grow with object size; index memory grows with the number of objects. Verification makes a second bounded pass over the temporary file. `Disk.checkout` still loads file payloads into memory. The origin opens one file per response, announces its length, and reads at most 64 KiB before each bounded write. It closes the file on success, a failed or interrupted send, a short read, and a suppressed body. The HTTP writer retains connection reuse, completion outcomes, write deadlines, and shutdown admission.

`http_check.bend`, called by `check.bend`, runs the actual handler and client on an OS-assigned loopback port. It checks partial and repeated transfers, shared objects, repair of a missing descendant, reconstruction after repair, invalid methods and paths, missing source objects, corrupt local objects, closed-server failures, and a tampered response that ingress refuses without writing it. Server-side connection events prove that three object GETs share one connection, and that successful, missing-object, and tampered-object syncs close it. `http_stream_check.bend` uses a bounded raw loopback origin on port 0. It checks a 17 MiB file, reconstruction of its root, truncated and tampered streams, and temporary-file cleanup.

The same checks transfer a 17 MiB object from the real file origin and reconstruct its root after shutdown. `http_origin_check.py` runs the origin alone against 17 MiB and 129 MiB objects. It verifies response hashes, checks descriptor counts after 24 reset connections, and samples only the origin process's RSS. Both runtime check scripts run it. See [bench/README.md](bench/README.md) for the isolated memory measurement.

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
| `digest_cmp_refl`, `digest_cmp_eq`, `digest_cmp_flip`, `digest_cmp_trans` | `Digest.cmp` is a total order whose `EQ` means equal digests, so the `index_` laws hold for the disk layer's index |

The laws take the facts they need as hypotheses: `eq` is sound (`eq(x, y)` gives `x == y`) and reflexive, and `H` is injective (`inj`). The `index_` laws take `cmp` as a total order whose `EQ` means equal (the facts `collections` uses for `OMap`) and `agree`: `eq(x, y)` is `Cmp.is_eq(cmp(x, y))`. The disk layer uses `Digest.cmp`, and the `digest_cmp_` laws prove these facts for it. The fixture laws check the same functions on `U32` digests with a toy hash.

## Trust boundary

The proofs cover the pure core. They do not cover hashing, the disk, or the copy between two stores.

- **Collision resistance.** The proofs assume that the object hash is injective. SHA-256 is not injective; the assumption is that no one finds two objects with one digest.
- **Native hashing.** `digest` and Blob construction call OpenSSL. The proofs assume it computes SHA-256 of the octets it receives. `commit` reuses a file's cached digest and repeats the shape of `objects` and `hash` in `IO`; the proofs cover `objects` and `hash`. Ingress computes the digest from received bytes and never trusts a peer's cached digest.
- **Encoding.** `decode` is the inverse of `encode` on the objects `commit` writes, and `Digest.read` is the inverse of `Digest.hex`. `check.bend` tests both; no law states them.
- **Filesystem.** Completed object and root writes sync file contents, atomically rename from `dir/tmp`, then sync the destination and temporary directories. HTTP ingress uses the same order. `Disk.init` syncs the store directories and their ancestors. `Disk.set_root` first verifies the complete object closure, syncs every referenced object file, and syncs the objects directory. It refuses missing or corrupt objects. This also fences objects left by an interrupted publication or an older store version. Both native and Bun lanes call `fsync` on files and directories. On macOS, each successful `fsync` is followed by `fcntl(F_FULLFSYNC)` on the same descriptor. This flushes file contents before rename and directory metadata after rename. A failed barrier returns its error; there is no weaker fallback. Stop collection and external changes during root publication. The contract requires atomic same-filesystem rename and working file and directory synchronization on one local mounted filesystem.
- **Crash model.** After a completed call, a process crash, OS crash, or power loss cannot lose its published contents or name if the filesystem and device honor the barriers. On Linux, the device must persist data and metadata on successful `fsync`. On macOS, use a local APFS or HFS+ volume with working file and directory `F_FULLFSYNC`, and a device and storage controller that honor cache-flush requests. Volatile caches are covered only if those requests drain them to persistent storage. Network filesystems, devices that ignore flushes, broken filesystems, disk corruption, and hostile external writers are outside this contract. An interrupted call can leave the old file, the complete new file, or an owned temporary file. An error after rename can leave the new file visible; do not interpret failure as rollback. A later successful root update fences earlier renamed object entries before it publishes the root. Collection deletions and restored working trees have no crash-durability guarantee. Fault checks include a failed full-sync barrier before rename, with the old root unchanged and a new root absent. They check ordering and error handling, not physical power-loss safety. Successful calls on a test volume do not certify a device or filesystem against real power loss.
- **Concurrent writers.** Object and root writes each own an exclusively created temporary file. Readers see complete published files. Concurrent root updates use last-rename-wins order. `Disk.commit`, `Disk.receive`, `Disk.set_root`, local `sync`, and HTTP `sync` hold shared store locks for the complete call. Local sync locks both stores. Writers may run together. Collection and temporary cleanup take exclusive locks before reading or deleting anything. Contention returns a host error immediately; the call does not wait.
- **Exclusive maintenance.** Coordination uses advisory `flock` locks on the store directory itself. Each call owns a separate close-on-exec descriptor, closed on success and error. Process termination releases its locks. Keep the directory inode stable; do not rename, replace, or remove the store during use. Use a local filesystem with working `flock`. `Disk.coordinated(A, dir, exclusive, action)` holds a lock while `action(Unit{})` runs. Do not nest exclusive scopes or call coordinated maintenance inside one. Low-level helpers such as `write`, `Disk.put`, `Disk.save`, and HTTP `download` do not acquire locks. Wrap custom writers in a shared scope. Until every caller cooperates, stop and join all writers and prevent new ones during maintenance. Never infer liveness from file age. Every file directly under `dir/tmp` is disposable only under this exclusion. Cleanup does not recurse or touch objects or roots. IO errors keep earlier deletions. Do not replace `dir/tmp` with a symbolic link. The retained root list must remain valid from its selection through collection; coordination is not a transaction between separate calls.
- **Trees on disk.** `snapshot` follows symbolic links and fails on other special files. A link cycle fails at the fuel limit.

## Limits

- `get` and `put` on an `Index` take O(log n) comparisons of digests. A comparison reads at most eight words. See [bench/README.md](bench/README.md).
- `Disk.load` reads and checks every object in the store. `Disk.checkout`, `sync`, and `Disk.collect` read only the objects their roots reach, so their cost grows with the closure, not with the store. `Disk.collect` also lists every file in `dir/objects`.
- A file is at most 4 GiB minus one octet, because `Blob.len` is a `U32`. A larger file fails before the read starts.

## Bench

`bench/` times a commit and a load of an artifact tree against the obvious loop over a library SHA-256 and a map in C, Rust, Python, and JavaScript. See [bench/README.md](bench/README.md).
