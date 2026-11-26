# Content-addressed object store: Merkle trees, sync plans, and reachability GC with proved laws. Source: https://github.com/paymog/bend-kit/tree/main/storage
import Base
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import bend-kit-files@0.4.0.1/files.bend as Files
import bend-kit-crypto@0.2.2.2/crypto.bend as Crypto
import bend-kit-collections@0.1.6.0/omap.bend as OMap
import ./pure.bend as P

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

def Disk.lock(dir: String, exclusive: U32) -> IO(Result<&1, &1, U32 & String, File>):
  import "./effs/coordination.c"
  import "./effs/coordination.js"

def Disk.lock.finish(-A: Type, lock: File, result: Result<&1, &1, U32 & String, A>) -> Run(A):
  do IO<Result<&1, &1, U32 & String, A>>:
    File.close(lock)
    return result

def Disk.coordinated(-A: Type, dir: String, exclusive: Bool, action: Unit -> Run(A)) -> Run(A):
  do Run<A>:
    lock : File <- Disk.lock(dir, Bool.pick(U32, exclusive, 2, 1))
    result : Result<&1, &1, U32 & String, A> <- Run.lift(Result<&1, &1, U32 & String, A>, action(Unit{}))
    Disk.lock.finish(A, lock, result)

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

# The SHA-256 of b.
def digest(b: Bytes.Bytes) -> Run(P.Digest):
  Bytes.Bytes{len, buf} = b
  do Run<P.Digest>:
    r : U32 & Array<U32> <- Crypto.sha256.words(len, buf)
    return P.digest.of(r)

def Blob.hash.words(len: U32, raw: Array<U32>) -> IO(Result<&1, &1, U32 & String, Array<U32> & (U32 & Array<U32>)>):
  import "./effs/storage.c"
  import "./effs/storage.js"

def Blob.of.hashed(+len: U32, buffers: Array<U32> & (U32 & Array<U32>)) -> P.Blob:
  (raw, hash) = buffers
  P.Blob.pack(P.digest.of(hash), Bytes.Bytes{len, raw})

# Hashes the packed input before it becomes a reusable word list.
def Blob.of(b: Bytes.Bytes) -> Run(P.Blob):
  Bytes.Bytes{+len, raw} = b
  do Run<P.Blob>:
    buffers : Array<U32> & (U32 & Array<U32>) <- Blob.hash.words(len, raw)
    return Blob.of.hashed(len, buffers)

def Blob.string(s: String) -> Run(P.Blob):
  Blob.of(Bytes.from_string(s))

def object.digest(o: P.Obj<P.Digest, P.Blob>) -> Run(P.Digest):
  match o:
    case P.OFile{P.Blob{len, ws, d}}:
      Run.pure(P.Digest, d)
    case P.OEnd{}:
      digest(P.encode(P.OEnd{}))
    case P.OItem{n, c, r}:
      digest(P.encode(P.OItem{n, c, r}))

def decode.two(bb: Bytes.Bytes & Bytes.Bytes) -> Run(Maybe<&2, P.Obj<P.Digest, P.Blob>>):
  (b, raw) = bb
  do Run<Maybe<&2, P.Obj<P.Digest, P.Blob>>>:
    d : P.Digest <- digest(raw)
    return P.decode.hashed(d, b)

# The object that encode wrote, or None for any other octets.
def decode(b: Bytes.Bytes) -> Run(Maybe<&2, P.Obj<P.Digest, P.Blob>>):
  decode.two(Bytes.clone(b))

def commit.done(+d: P.Digest, o: P.Obj<P.Digest, P.Blob>, xs: P.Store<P.Digest, P.Blob>) -> Run(P.Digest & P.Store<P.Digest, P.Blob>):
  Run.pure(P.Digest & P.Store<P.Digest, P.Blob>, (d, P.Store.cat(P.Digest, P.Blob, xs, P.StCon{d, o, P.StNil{}})))

def commit.node(+o: P.Obj<P.Digest, P.Blob>, xs: P.Store<P.Digest, P.Blob>) -> Run(P.Digest & P.Store<P.Digest, P.Blob>):
  do Run<P.Digest & P.Store<P.Digest, P.Blob>>:
    d : P.Digest <- object.digest(o)
    commit.done(d, o, xs)

def commit.item(+n: String, c: P.Digest & P.Store<P.Digest, P.Blob>, r: P.Digest & P.Store<P.Digest, P.Blob>) -> Run(P.Digest & P.Store<P.Digest, P.Blob>):
  (+dc, xs) = c
  (+dr, ys) = r
  do Run<P.Digest & P.Store<P.Digest, P.Blob>>:
    Run.check(P.name.ok(n), "invalid name " ++ n)
    commit.node(P.OItem{n, dc, dr}, P.Store.cat(P.Digest, P.Blob, xs, ys))

# hash and objects with H = SHA-256 of encode: the root digest and the objects, children first.
def commit(t: P.Tree<P.Blob>) -> Run(P.Digest & P.Store<P.Digest, P.Blob>):
  match t:
    case P.TFile{b}:
      commit.node(P.OFile{b}, P.StNil{})
    case P.TEnd{}:
      commit.node(P.OEnd{}, P.StNil{})
    case P.TItem{+n, c, r}:
      do Run<P.Digest & P.Store<P.Digest, P.Blob>>:
        x : P.Digest & P.Store<P.Digest, P.Blob> <- commit(c)
        y : P.Digest & P.Store<P.Digest, P.Blob> <- commit(r)
        commit.item(n, x, y)

def receive.two(+s: P.Index(P.Digest, P.Blob), +claimed: P.Digest, bb: Bytes.Bytes & Bytes.Bytes) -> Run(P.Index(P.Digest, P.Blob)):
  (b1, b2) = bb
  do Run<P.Index(P.Digest, P.Blob)>:
    +computed : P.Digest <- digest(b1)
    o : P.Obj<P.Digest, P.Blob> <- Run.some(P.Obj<P.Digest, P.Blob>, P.decode.hashed(computed, b2), "object " ++ P.Digest.hex(claimed) ++ " does not decode")
    Run.some(P.Index(P.Digest, P.Blob), P.Index.admit(~P.Digest, ~P.Blob, ~P.Digest.cmp, s, claimed, computed, o), "object " ++ P.Digest.hex(claimed) ++ " does not match its digest")

# Ingress: the store with the object that b encodes. Fails when b does not decode or its SHA-256 is not claimed.
def receive(+s: P.Index(P.Digest, P.Blob), +claimed: P.Digest, b: Bytes.Bytes) -> Run(P.Index(P.Digest, P.Blob)):
  receive.two(s, claimed, Bytes.clone(b))

# ---- A store on disk: dir/objects/<hex digest> holds each encoded object, dir/roots/<name> a root digest in hex.

def Disk.object(+dir: String, +d: P.Digest) -> String:
  dir ++ "/objects/" ++ P.Digest.hex(d)

def write.durable(tmp: String, path: String, fault: U32) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/storage.c"
  import "./effs/storage.js"

def Disk.init(+dir: String) -> Run(Unit):
  do Run<Unit>:
    Files.mkdir_all(dir ++ "/objects")
    Files.mkdir_all(dir ++ "/roots")
    Files.mkdir_all(dir ++ "/tmp")
    write.durable("", dir ++ "/objects", 0)
    write.durable("", dir ++ "/roots", 0)
    write.durable("", dir ++ "/tmp", 0)

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

def write.temp(prefix: String) -> IO(Result<&1, &1, U32 & String, String & File>):
  import "./effs/storage.c"
  import "./effs/storage.js"

def write.cleanup(+tmp: String, r: Result<&1, &1, U32 & String, Unit>) -> Run(Unit):
  match r:
    case Done{x}:
      Run.pure(Unit, x)
    case Fail{e}:
      do IO<Result<&1, &1, U32 & String, Unit>>:
        removed : Result<&1, &1, U32 & String, Unit> <- Files.remove(tmp)
        return Fail{e}

def write.publish(r: Result<&1, &1, U32 & String, Unit>, +tmp: String, path: String) -> Run(Unit):
  match r:
    case Fail{e}:
      write.cleanup(tmp, Fail{e})
    case Done{x}:
      do IO<Result<&1, &1, U32 & String, Unit>>:
        renamed : Result<&1, &1, U32 & String, Unit> <- write.durable(tmp, path, 0)
        write.cleanup(tmp, renamed)

def write.opened(pair: String & File, path: String, b: Bytes.Bytes) -> Run(Unit):
  (+tmp, f) = pair
  do IO<Result<&1, &1, U32 & String, Unit>>:
    r : File & Result<&1, &1, U32 & String, Unit> <- Files.write_bytes(f, b)
    closed : Result<&1, &1, U32 & String, Unit> <- write.close(r)
    write.publish(closed, tmp, path)

# Each write owns its exclusively created temporary file until publication or cleanup.
def write(+dir: String, name: String, path: String, b: Bytes.Bytes) -> Run(Unit):
  do Run<Unit>:
    pair : String & File <- write.temp(dir ++ "/tmp/" ++ name)
    write.opened(pair, path, b)

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

def info.size(i: Files.Info) -> Run(U32):
  Files.Info{k, (hi, lo), t} = i
  do Run<U32>:
    Run.check(U32.is_eq(hi, 0), "file exceeds the 32-bit Bytes length limit")
    return lo

def read.sized(+path: String, +size: U32) -> Run(Bytes.Bytes):
  do Run<Bytes.Bytes>:
    f : File <- File.open(path, "r")
    b : Bytes.Bytes <- read.go(U32.to_nat((size / 1048576 + 1 : U32)), (f, Bytes.new(0)), Bytes.new(0))
    read.check(size, b)

# The whole file at path.
def read(+path: String) -> Run(Bytes.Bytes):
  do Run<Bytes.Bytes>:
    info : Files.Info <- Files.stat(path)
    size : U32 <- info.size(info)
    read.sized(path, size)


def Disk.put.if(there: Bool, +dir: String, +d: P.Digest, +path: String, b: Bytes.Bytes) -> Run(Unit):
  match there:
    case True{}:
      Run.pure(Unit, Unit{})
    case False{}:
      write(dir, P.Digest.hex(d), path, b)

# Writes the encoded object under its digest unless the file exists. Objects never change.
def Disk.put(+dir: String, +d: P.Digest, b: Bytes.Bytes) -> Run(Unit):
  +path = Disk.object(dir, d)
  do Run<Unit>:
    there : Bool <- Run.lift(Bool, Files.exists(path))
    Disk.put.if(there, dir, d, path, b)

def Disk.save(+dir: String, xs: P.Store<P.Digest, P.Blob>) -> Run(Unit):
  match xs:
    case P.StNil{}:
      Run.pure(Unit, Unit{})
    case P.StCon{+d, o, r}:
      do Run<Unit>:
        Disk.put(dir, d, P.encode(o))
        Disk.save(dir, r)

# Ingress into the store at dir: receive, then write the octets under their digest.
def Disk.receive.two(+dir: String, +s: P.Index(P.Digest, P.Blob), +claimed: P.Digest, bb: Bytes.Bytes & Bytes.Bytes) -> Run(P.Index(P.Digest, P.Blob)):
  (b1, b2) = bb
  do Run<P.Index(P.Digest, P.Blob)>:
    t : P.Index(P.Digest, P.Blob) <- receive(s, claimed, b1)
    Disk.put(dir, claimed, b2)
    return t

def Disk.receive(+dir: String, +s: P.Index(P.Digest, P.Blob), +claimed: P.Digest, b: Bytes.Bytes) -> Run(P.Index(P.Digest, P.Blob)):
  Disk.coordinated(P.Index(P.Digest, P.Blob), dir, False{}, u => Disk.receive.two(dir, s, claimed, Bytes.clone(b)))

# The object in file objects/n, checked against the digest that n names.
def Disk.load.one(+dir: String, +n: String, m: Maybe<&2, P.Digest>, +s: P.Index(P.Digest, P.Blob)) -> Run(P.Index(P.Digest, P.Blob)):
  match m:
    case None{}:
      Run.fail(P.Index(P.Digest, P.Blob), (22, "storage: object " ++ n ++ " is not a digest"))
    case Some{+d}:
      do Run<P.Index(P.Digest, P.Blob)>:
        b : Bytes.Bytes <- read(Disk.object(dir, d))
        receive(s, d, b)

def Disk.load.go(+dir: String, names: List<&2, String>, +s: P.Index(P.Digest, P.Blob)) -> Run(P.Index(P.Digest, P.Blob)):
  match names:
    case Nil{}:
      Run.pure(P.Index(P.Digest, P.Blob), s)
    case Con{+n, t}:
      do Run<P.Index(P.Digest, P.Blob)>:
        u : P.Index(P.Digest, P.Blob) <- Disk.load.one(dir, n, P.Digest.read(n), s)
        Disk.load.go(dir, t, u)

# Every object at dir, each checked against its file name. A tampered or undecodable object fails the load.
def Disk.load(+dir: String) -> Run(P.Index(P.Digest, P.Blob)):
  do Run<P.Index(P.Digest, P.Blob)>:
    names : List<&2, String> <- Files.list_dir(dir ++ "/objects")
    Disk.load.go(dir, names, P.Index.new(P.Digest, P.Blob))

# One step of Disk.fetch.go.
type Fetch is Data:
  Want{d: P.Digest}
  Have{d: P.Digest, held: Bool}
  Read{d: P.Digest, there: Bool}
  Got{d: P.Digest}
  Seen{m: Maybe<&2, P.Obj<P.Digest, P.Blob>>}

# Adds to s every object that a Want reaches at dir, each read and checked through receive once.
# A missing object is left out, so a load of the root then fails.
def Disk.fetch.go(fuel: Nat, +dir: String, step: Fetch, +s: P.Index(P.Digest, P.Blob)) -> Run(P.Index(P.Digest, P.Blob)):
  match fuel step:
    case 0n _:
      Run.pure(P.Index(P.Digest, P.Blob), s)
    case 1n+p Want{+d}:
      Disk.fetch.go(p, dir, Have{d, P.Index.has(~P.Digest, ~P.Blob, ~P.Digest.cmp, s, d)}, s)
    case 1n+p Have{d, True{}}:
      Run.pure(P.Index(P.Digest, P.Blob), s)
    case 1n+p Have{+d, False{}}:
      Run.bind(Bool, P.Index(P.Digest, P.Blob), Run.lift(Bool, Files.exists(Disk.object(dir, d))), e => Disk.fetch.go(p, dir, Read{d, e}, s))
    case 1n+p Read{d, False{}}:
      Run.pure(P.Index(P.Digest, P.Blob), s)
    case 1n+(+p) Read{+d, True{}}:
      do Run<P.Index(P.Digest, P.Blob)>:
        b : Bytes.Bytes <- read(Disk.object(dir, d))
        u : P.Index(P.Digest, P.Blob) <- receive(s, d, b)
        Disk.fetch.go(p, dir, Got{d}, u)
    case 1n+p Got{+d}:
      Disk.fetch.go(p, dir, Seen{P.Index.get(~P.Digest, ~P.Blob, ~P.Digest.cmp, s, d)}, s)
    case 1n+(+p) Seen{Some{P.OItem{n, +c, +r}}}:
      do Run<P.Index(P.Digest, P.Blob)>:
        u : P.Index(P.Digest, P.Blob) <- Disk.fetch.go(p, dir, Want{c}, s)
        Disk.fetch.go(p, dir, Want{r}, u)
    case 1n+p Seen{_}:
      Run.pure(P.Index(P.Digest, P.Blob), s)

# Five steps per level, so a fetch goes as deep as a load with limit().
def fetch.fuel() -> Nat:
  Nat.mul(5n, P.limit())

# The index of the objects that root reaches at dir. Other objects are not read.
def Disk.fetch(+dir: String, +root: P.Digest) -> Run(P.Index(P.Digest, P.Blob)):
  Disk.fetch.go(fetch.fuel(), dir, Want{root}, P.Index.new(P.Digest, P.Blob))


def inspect(path: String, digest: String) -> IO(Result<&1, &1, U32 & String, U32 & String>):
  import "./effs/verify.c"
  import "./effs/verify.js"

def metadata.file(valid: Bool) -> Maybe<&2, P.Obj<P.Digest, Unit>>:
  match valid:
    case True{}:
      Some{P.OFile{Unit{}}}
    case False{}:
      None{}

def metadata.node(node: Maybe<&2, P.Obj<P.Digest, P.Blob>>) -> Maybe<&2, P.Obj<P.Digest, Unit>>:
  match node:
    case Some{P.OEnd{}}:
      Some{P.OEnd{}}
    case Some{P.OItem{n, c, r}}:
      Some{P.OItem{n, c, r}}
    case _:
      None{}

def metadata.of(file: Bool, +size: U32, +head: String, +d: P.Digest) -> Maybe<&2, P.Obj<P.Digest, Unit>>:
  match file:
    case True{}:
      +digits = String.drop(head, 5n)
      +length = U32.from_nat(String.length(head ++ "\n"))
      metadata.file(Bool.and(U32.is_le(length, size), String.eq(digits, U32.show((size - length : U32)))))
    case False{}:
      metadata.node(P.decode.hashed(d, Bytes.from_string(head ++ "\n")))

def verified.pair(+d: P.Digest, pair: U32 & String) -> Run(P.Obj<P.Digest, Unit>):
  (+size, +head) = pair
  Run.some(P.Obj<P.Digest, Unit>, metadata.of(String.starts_with(head, "file "), size, head, d), "object " ++ P.Digest.hex(d) ++ " does not decode")

def verified(+path: String, +d: P.Digest) -> Run(P.Obj<P.Digest, Unit>):
  do Run<P.Obj<P.Digest, Unit>>:
    pair : U32 & String <- inspect(path, P.Digest.hex(d))
    verified.pair(d, pair)

def write.sync(path: String) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/storage.c"
  import "./effs/storage.js"

def verified.sync(+path: String, +d: P.Digest) -> Run(P.Obj<P.Digest, Unit>):
  do Run<P.Obj<P.Digest, Unit>>:
    node : P.Obj<P.Digest, Unit> <- verified(path, d)
    write.sync(path)
    return node

type Fence is Data:
  FenceWant{digest: P.Digest}
  FenceHeld{digest: P.Digest, seen: Bool}
  FenceChildren{object: P.Obj<P.Digest, Unit>}

def Disk.walk.go(~visit: @+path:String -> @+d:P.Digest -> Run(P.Obj<P.Digest, Unit>), fuel: Nat, +dir: String, step: Fence, +seen: P.Index(P.Digest, Unit)) -> Run(P.Index(P.Digest, Unit)):
  match fuel step:
    case 0n _:
      Run.fail(P.Index(P.Digest, Unit), (36, "storage: root tree is too deep"))
    case 1n+p FenceWant{+d}:
      Disk.walk.go(~visit, p, dir, FenceHeld{d, P.Index.has(~P.Digest, ~Unit, ~P.Digest.cmp, seen, d)}, seen)
    case 1n+p FenceHeld{d, True{}}:
      Run.pure(P.Index(P.Digest, Unit), seen)
    case 1n+p FenceHeld{+d, False{}}:
      do Run<P.Index(P.Digest, Unit)>:
        +node : P.Obj<P.Digest, Unit> <- visit(Disk.object(dir, d), d)
        Disk.walk.go(~visit, p, dir, FenceChildren{node}, P.Index.put(~P.Digest, ~Unit, ~P.Digest.cmp, seen, d, node))
    case 1n+(+p) FenceChildren{P.OItem{n, c, r}}:
      do Run<P.Index(P.Digest, Unit)>:
        next : P.Index(P.Digest, Unit) <- Disk.walk.go(~visit, p, dir, FenceWant{c}, seen)
        Disk.walk.go(~visit, p, dir, FenceWant{r}, next)
    case 1n+p FenceChildren{_}:
      Run.pure(P.Index(P.Digest, Unit), seen)

def Disk.walk.all(+dir: String, roots: List<&2, P.Digest>, +seen: P.Index(P.Digest, Unit)) -> Run(P.Index(P.Digest, Unit)):
  match roots:
    case Nil{}:
      Run.pure(P.Index(P.Digest, Unit), seen)
    case Con{root, rest}:
      do Run<P.Index(P.Digest, Unit)>:
        next : P.Index(P.Digest, Unit) <- Disk.walk.go(~verified, Nat.mul(3n, P.limit()), dir, FenceWant{root}, seen)
        Disk.walk.all(dir, rest, next)

def Disk.set_root(+dir: String, +name: String, +d: P.Digest) -> Run(Unit):
  Disk.coordinated(Unit, dir, False{}, u => do Run<Unit>:
    Run.check(P.name.ok(name), "invalid root " ++ name)
    seen : P.Index(P.Digest, Unit) <- Disk.walk.go(~verified.sync, Nat.mul(3n, P.limit()), dir, FenceWant{d}, P.Index.new(P.Digest, Unit))
    write.durable("", dir ++ "/objects", 0)
    write(dir, "root", dir ++ "/roots/" ++ name, Bytes.from_string(P.Digest.hex(d))))

def Disk.root(+dir: String, +name: String) -> Run(P.Digest):
  do Run<P.Digest>:
    b : Bytes.Bytes <- read(dir ++ "/roots/" ++ name)
    Run.some(P.Digest, P.Digest.read(Bytes.to_string(b)), "root " ++ name ++ " is not a digest")

def Disk.roots.go(+dir: String, names: List<&2, String>) -> Run(List<&2, P.Digest>):
  match names:
    case Nil{}:
      Run.pure(List<&2, P.Digest>, Nil{})
    case Con{+n, t}:
      do Run<List<&2, P.Digest>>:
        d : P.Digest <- Disk.root(dir, n)
        ds : List<&2, P.Digest> <- Disk.roots.go(dir, t)
        return Con{d, ds}

# The digest of every named root.
def Disk.roots(+dir: String) -> Run(List<&2, P.Digest>):
  do Run<List<&2, P.Digest>>:
    names : List<&2, String> <- Files.list_dir(dir ++ "/roots")
    Disk.roots.go(dir, names)

def Disk.drop.one(live: Bool, +dir: String, +d: P.Digest) -> Run(U32):
  match live:
    case True{}:
      Run.pure(U32, 0)
    case False{}:
      do Run<U32>:
        Files.remove(Disk.object(dir, d))
        return 1

def Disk.drop(+dir: String, ds: List<&2, P.Digest>, +live: P.Index(P.Digest, Unit), +n: U32) -> Run(U32):
  match ds:
    case Nil{}:
      Run.pure(U32, n)
    case Con{+d, r}:
      do Run<U32>:
        k : U32 <- Disk.drop.one(P.Index.has(~P.Digest, ~Unit, ~P.Digest.cmp, live, d), dir, d)
        Disk.drop(dir, r, live, (n + k : U32))

def Disk.walk.checked(result: Result<&1, &1, U32 & String, P.Index(P.Digest, Unit)>, why: String) -> Run(P.Index(P.Digest, Unit)):
  match result:
    case Done{seen}:
      Run.pure(P.Index(P.Digest, Unit), seen)
    case Fail{(+code, message)}:
      Run.fail(P.Index(P.Digest, Unit), (code, Bool.pick(String, U32.is_eq(code, 2), "storage: " ++ why, message)))

def Disk.collect.retained(+dir: String, retained: List<&2, P.Digest>) -> Run(U32):
  do Run<U32>:
    result : Result<&1, &1, U32 & String, P.Index(P.Digest, Unit)> <- Run.lift(Result<&1, &1, U32 & String, P.Index(P.Digest, Unit)>, Disk.walk.all(dir, retained, P.Index.new(P.Digest, Unit)))
    live : P.Index(P.Digest, Unit) <- Disk.walk.checked(result, "a retained root does not load")
    names : List<&2, String> <- Files.list_dir(dir ++ "/objects")
    Disk.drop(dir, P.digests(names), live, 0)

# Keeps explicit roots selected by an external retention policy.
def Disk.collect(+dir: String, retained: List<&2, P.Digest>) -> Run(U32):
  Disk.coordinated(U32, dir, True{}, u => Disk.collect.retained(dir, retained))

# Selects named roots and collects their closure under one exclusive lock.
def Disk.collect_named(+dir: String) -> Run(U32):
  Disk.coordinated(U32, dir, True{}, u => do Run<U32>:
    retained : List<&2, P.Digest> <- Disk.roots(dir)
    Disk.collect.retained(dir, retained))

def Disk.clean_tmp.go(+dir: String, names: List<&2, String>, +n: U32) -> Run(U32):
  match names:
    case Nil{}:
      Run.pure(U32, n)
    case Con{name, rest}:
      do Run<U32>:
        Files.remove(dir ++ "/tmp/" ++ name)
        Disk.clean_tmp.go(dir, rest, (n + 1 : U32))

# Rejects maintenance while a cooperating writer or maintenance holder is active.
def Disk.clean_tmp(+dir: String) -> Run(U32):
  Disk.coordinated(U32, dir, True{}, u => do Run<U32>:
    names : List<&2, String> <- Files.list_dir(dir ++ "/tmp")
    Disk.clean_tmp.go(dir, names, 0))

def copy.into(path: String, file: File) -> IO(File & Result<&1, &1, U32 & String, Unit>):
  import "./effs/storage.c"
  import "./effs/storage.js"

def copy.verified(+tmp: String, +d: P.Digest) -> Run(Unit):
  do Run<Unit>:
    node : P.Obj<P.Digest, Unit> <- verified(tmp, d)
    return Unit{}

def copy.opened(pair: String & File, src: String, +dst: String, +d: P.Digest) -> Run(Unit):
  (+tmp, file) = pair
  do IO<Result<&1, &1, U32 & String, Unit>>:
    copied : File & Result<&1, &1, U32 & String, Unit> <- copy.into(Disk.object(src, d), file)
    closed : Result<&1, &1, U32 & String, Unit> <- write.close(copied)
    checked : Result<&1, &1, U32 & String, Unit> <- Run.bind(Unit, Unit, IO.pure(Result<&1, &1, U32 & String, Unit>, closed), u => copy.verified(tmp, d))
    write.publish(checked, tmp, Disk.object(dst, d))

def sync.send(+src: String, +dst: String, ds: List<&2, P.Digest>, +n: U32) -> Run(U32):
  match ds:
    case Nil{}:
      Run.pure(U32, n)
    case Con{+d, rest}:
      do Run<U32>:
        pair : String & File <- write.temp(dst ++ "/tmp/" ++ P.Digest.hex(d))
        copy.opened(pair, src, dst, d)
        sync.send(src, dst, rest, (n + 1 : U32))

def sync.probe.one(there: Bool, +dst: String, +d: P.Digest) -> Run(List<&2, P.Digest>):
  match there:
    case False{}:
      Run.pure(List<&2, P.Digest>, [d])
    case True{}:
      do Run<List<&2, P.Digest>>:
        node : P.Obj<P.Digest, Unit> <- verified(Disk.object(dst, d), d)
        return Nil{}

def sync.probe(+dst: String, ds: List<&2, P.Digest>) -> Run(List<&2, P.Digest>):
  match ds:
    case Nil{}:
      Run.pure(List<&2, P.Digest>, Nil{})
    case Con{+d, rest}:
      do Run<List<&2, P.Digest>>:
        there : Bool <- Run.lift(Bool, Files.exists(Disk.object(dst, d)))
        missing : List<&2, P.Digest> <- sync.probe.one(there, dst, d)
        tail : List<&2, P.Digest> <- sync.probe(dst, rest)
        return List.append(&2, P.Digest, missing, tail)

# Reads each reachable digest once, verifies existing destinations, then streams missing objects.
def sync(+src: String, +dst: String, +root: P.Digest) -> Run(U32):
  Disk.coordinated(U32, src, False{}, u =>
    Disk.coordinated(U32, dst, False{}, v => do Run<U32>:
      result : Result<&1, &1, U32 & String, P.Index(P.Digest, Unit)> <- Run.lift(Result<&1, &1, U32 & String, P.Index(P.Digest, Unit)>, Disk.walk.all(src, [root], P.Index.new(P.Digest, Unit)))
      seen : P.Index(P.Digest, Unit) <- Disk.walk.checked(result, "the source cannot load " ++ P.Digest.hex(root))
      missing : List<&2, P.Digest> <- sync.probe(dst, OMap.OMap.keys(P.Digest, P.Obj<P.Digest, Unit>, seen))
      sync.send(src, dst, missing, 0)))

# The tree under root at dir. Fails when an object is missing or tampered, or the tree is too deep.
# It reads only the objects root reaches.
def Disk.checkout(+dir: String, +root: P.Digest) -> Run(P.Tree<P.Blob>):
  do Run<P.Tree<P.Blob>>:
    s : P.Index(P.Digest, P.Blob) <- Disk.fetch(dir, root)
    Run.some(P.Tree<P.Blob>, P.Index.load(~P.Digest, ~P.Blob, ~P.Digest.cmp, P.limit(), s, root), "root " ++ P.Digest.hex(root) ++ " does not load")

def Disk.commit.save(+dir: String, r: P.Digest & P.Store<P.Digest, P.Blob>) -> Run(P.Digest):
  (+d, xs) = r
  do Run<P.Digest>:
    Disk.save(dir, xs)
    return d

# Commits t to the store at dir and answers its root digest.
def Disk.commit(+dir: String, t: P.Tree<P.Blob>) -> Run(P.Digest):
  Disk.coordinated(P.Digest, dir, False{}, u => do Run<P.Digest>:
    r : P.Digest & P.Store<P.Digest, P.Blob> <- commit(t)
    Disk.commit.save(dir, r))

# ---- Artifact trees: a directory on disk as a Tree.

type Step is Data:
  Stat{}
  Statted{info: Files.Info}
  Listing{names: List<&2, String>}

# The tree at path. Regular files become TFile and directories become TItem chains in name order.
def snap(fuel: Nat, +path: String, step: Step) -> Run(P.Tree<P.Blob>):
  match fuel step:
    case 0n _:
      Run.fail(P.Tree<P.Blob>, (36, "storage: " ++ path ++ " is too deep"))
    case 1n+p Stat{}:
      Run.bind(Files.Info, P.Tree<P.Blob>, Files.stat(path), i => snap(p, path, Statted{i}))
    case 1n+p Statted{Files.Info{Files.Regular{}, s, t}}:
      do Run<P.Tree<P.Blob>>:
        b : Bytes.Bytes <- read(path)
        blob : P.Blob <- Blob.of(b)
        return P.TFile{blob}
    case 1n+p Statted{Files.Info{Files.Directory{}, s, t}}:
      Run.bind(List<&2, String>, P.Tree<P.Blob>, Files.list_dir(path), ns => snap(p, path, Listing{ns}))
    case 1n+p Statted{Files.Info{Files.Other{}, s, t}}:
      Run.fail(P.Tree<P.Blob>, (22, "storage: " ++ path ++ " is not a file or a directory"))
    case 1n+p Listing{Nil{}}:
      Run.pure(P.Tree<P.Blob>, P.TEnd{})
    case 1n+(+p) Listing{Con{+n, ns}}:
      do Run<P.Tree<P.Blob>>:
        Run.check(P.name.ok(n), "invalid name " ++ n)
        c : P.Tree<P.Blob> <- snap(p, path ++ "/" ++ n, Stat{})
        r : P.Tree<P.Blob> <- snap(p, path, Listing{ns})
        return P.TItem{n, c, r}

def snapshot(+path: String) -> Run(P.Tree<P.Blob>):
  snap(P.limit(), path, Stat{})

# Writes t at path. chain is True when t is the rest of the listing of directory path.
def restore.go(t: P.Tree<P.Blob>, +path: String, chain: Bool) -> Run(Unit):
  match t chain:
    case P.TFile{b} False{}:
      write.file(path, P.Blob.bytes(b))
    case P.TEnd{} False{}:
      Files.mkdir(path)
    case P.TItem{+n, c, r} False{}:
      do Run<Unit>:
        Files.mkdir(path)
        Run.check(P.name.ok(n), "invalid name " ++ n)
        restore.go(c, path ++ "/" ++ n, False{})
        restore.go(r, path, True{})
    case P.TEnd{} True{}:
      Run.pure(Unit, Unit{})
    case P.TItem{+n, c, r} True{}:
      do Run<Unit>:
        Run.check(P.name.ok(n), "invalid name " ++ n)
        restore.go(c, path ++ "/" ++ n, False{})
        restore.go(r, path, True{})
    case P.TFile{b} True{}:
      Run.fail(Unit, (22, "storage: a file stands in the listing of " ++ path))

# Writes t as a new file or directory at path. Fails if path exists.
def restore(t: P.Tree<P.Blob>, +path: String) -> Run(Unit):
  restore.go(t, path, False{})
