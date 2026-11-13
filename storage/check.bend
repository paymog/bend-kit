import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-files@0.3.1.0/files.bend as Files
import bend-kit-collections@0.1.5.0/order.bend as Order
import ./storage.bend as S

def ok(good: Bool, +name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad " ++ name)

def words.eq(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{x, xs} Con{y, ys}:
      Bool.and(U32.is_eq(x, y), words.eq(xs, ys))
    case Nil{} Con{y, ys}:
      False{}
    case Con{x, xs} Nil{}:
      False{}

def blob.eq(a: S.Blob, b: S.Blob) -> Bool:
  S.Blob{+la, wa} = a
  S.Blob{+lb, wb} = b
  Bool.and(U32.is_eq(la, lb), words.eq(wa, wb))

def same(a: S.Tree<S.Blob>, b: S.Tree<S.Blob>) -> Bool:
  match a b:
    case S.TFile{x} S.TFile{y}:
      blob.eq(x, y)
    case S.TEnd{} S.TEnd{}:
      True{}
    case S.TItem{n, c, r} S.TItem{m, d, t}:
      Bool.and(String.eq(n, m), Bool.and(same(c, d), same(r, t)))
    case _ _:
      False{}

def file(+s: String) -> S.Tree<S.Blob>:
  S.TFile{S.Blob.string(s)}

def item(+n: String, c: S.Tree<S.Blob>, r: S.Tree<S.Blob>) -> S.Tree<S.Blob>:
  S.TItem{n, c, r}

# A build output: bin/app, an empty cache directory, lib/libcore.a, and share/doc/README.
# Each listing is in name order, as list_dir gives it.
def build(+app: String) -> S.Tree<S.Blob>:
  item("bin", item("app", file(app), S.TEnd{}),
  item("cache", S.TEnd{},
  item("lib", item("libcore.a", file("archive\u{0}with\u{0}nul octets"), S.TEnd{}),
  item("share", item("doc", item("README", file("read me\n"), S.TEnd{}), S.TEnd{}),
  S.TEnd{}))))

def docs() -> S.Tree<S.Blob>:
  item("share", item("doc", item("README", file("read me\n"), S.TEnd{}), S.TEnd{}), S.TEnd{})

def decodes(b: Bytes.Bytes) -> Bool:
  Maybe.is_some(&2, S.Obj<String, S.Blob>, S.decode(b))

def hexa() -> String:
  "48332fe667bc51ac4a51ba0efe734441c90def55c60a26d7db275ecbbcf42f15"

def item.bytes(+n: String) -> Bytes.Bytes:
  S.encode(S.OItem{n, hexa(), hexa()})

def file.back(+b: S.Blob, m: Maybe<&2, S.Obj<String, S.Blob>>) -> Bool:
  match m:
    case Some{S.OFile{x}}:
      blob.eq(x, b)
    case _:
      False{}

def file.roundtrip(+s: String) -> Bool:
  +b = S.Blob.string(s)
  file.back(b, S.decode(S.encode(S.OFile{b})))

# n octets that differ from their neighbours.
def octets(n: Nat, +i: U32) -> String:
  match n:
    case 0n:
      SNil{}
    case 1n+p:
      SCon{Chr{((i * 37 + 11) .&. 255 : U32)}, octets(p, (i + 1 : U32))}

def pure() -> IO(Unit):
  do IO<Unit>:
    ok(file.roundtrip("") && file.roundtrip("x") && file.roundtrip("four") && file.roundtrip("five!") && file.roundtrip("a\nb\u{0}c"), "file objects decode to themselves, newlines and NULs included")
    ok(file.roundtrip(octets(10n, 0)) && file.roundtrip(octets(100n, 0)) && file.roundtrip(octets(1000n, 0)) && file.roundtrip(octets(4097n, 0)), "file objects decode for every header length modulo 4")
    ok(decodes(S.encode(S.OEnd{})) && decodes(item.bytes("a b")), "end and item objects decode")
    ok(Bool.not(decodes(item.bytes(".."))) && Bool.not(decodes(item.bytes("a/b"))) && Bool.not(decodes(item.bytes(""))) && Bool.not(decodes(item.bytes("."))), "decode refuses names that would leave a restored directory")
    ok(Bool.not(decodes(Bytes.from_string("item abc " ++ hexa() ++ " x\n"))) && Bool.not(decodes(Bytes.from_string("end\nx"))) && Bool.not(decodes(Bytes.from_string("file 01\nx"))) && Bool.not(decodes(Bytes.from_string("file 2\nx"))), "decode refuses bad digests, trailing octets, and wrong lengths")

def expect.fail(-A: Type, r: Result<&1, &1, U32 & String, A>, +want: String) -> Bool:
  match r:
    case Done{x}:
      False{}
    case Fail{(c, m)}:
      String.starts_with(m, want)

def run(-A: Type, m: S.Run(A)) -> IO(A):
  IO.try(A, m)

def tries(-A: Type, m: S.Run(A)) -> IO(Result<&1, &1, U32 & String, A>):
  m

def count(+dir: String) -> IO(U32):
  do IO<U32>:
    ns : List<&2, String> <- IO.try(List<&2, String>, Files.list_dir(dir ++ "/objects"))
    return U32.from_nat(List.length(&2, String, ns))

def digest.fst(r: String & S.Store<String, S.Blob>) -> String:
  (d, xs) = r
  d

def digest.of(t: S.Tree<S.Blob>) -> IO(String):
  do IO<String>:
    r : String & S.Store<String, S.Blob> <- run(String & S.Store<String, S.Blob>, S.commit(t))
    return digest.fst(r)

def raw(+path: String, +s: String) -> IO(Unit):
  run(Unit, S.write.file(path, Bytes.from_string(s)))

def resend.of(+dir: String, +s: S.Index(String, S.Blob), +d: String, m: Maybe<&2, S.Obj<String, S.Blob>>) -> IO(Bool):
  match m:
    case None{}:
      IO.pure(Bool, False{})
    case Some{o}:
      do IO<Bool>:
        u : S.Index(String, S.Blob) <- run(S.Index(String, S.Blob), S.Disk.receive(dir, s, d, S.encode(o)))
        return U32.is_eq(S.Index.size(String, S.Blob, u), S.Index.size(String, S.Blob, s))

# Sends the object under d to the store at dir a second time.
def resend(+dir: String, +s: S.Index(String, S.Blob), +d: String) -> IO(Bool):
  resend.of(dir, s, d, S.Index.get(~String, ~S.Blob, ~Order.string, s, d))

# v2 changes bin/app; collection keeps only v2.
def collect(+a: String, +v1: String, +abc: String, +v2: String) -> IO(Unit):
  do IO<Unit>:
    run(Unit, S.Disk.set_root(a, "v2", v2))
    na2 : U32 <- count(a)
    ok(U32.is_eq(na2, 15), "v2 adds three objects: the new file and the two entries above it")
    refused : Result<&1, &1, U32 & String, U32> <- tries(U32, S.Disk.collect(a, [v2, abc]))
    na3 : U32 <- count(a)
    ok(expect.fail(U32, refused, "storage: a retained root does not load") && U32.is_eq(na3, 15), "collection with a root that does not load deletes nothing")
    dropped : U32 <- run(U32, S.Disk.collect(a, [v2]))
    ok(U32.is_eq(dropped, 3), "collection deletes the three objects only v1 reaches")
    t3 : S.Tree<S.Blob> <- run(S.Tree<S.Blob>, S.Disk.checkout(a, v2))
    ok(same(t3, build("v2 binary")), "the retained root survives collection")
    gone : Result<&1, &1, U32 & String, S.Tree<S.Blob>> <- tries(S.Tree<S.Blob>, S.Disk.checkout(a, v1))
    ok(expect.fail(S.Tree<S.Blob>, gone, "storage: root " ++ v1 ++ " does not load"), "the collected root no longer loads")
    roots : List<&2, String> <- run(List<&2, String>, S.Disk.roots(a))
    ok(Nat.is_eq(List.length(&2, String, roots), 2n), "roots lists both named roots")

# A third store gets everything, then loses one object to tampering and then to deletion.
def damage(+a: String, +c: String, +v1: String) -> IO(Unit):
  do IO<Unit>:
    sent : U32 <- run(U32, S.sync(a, c, v1))
    ok(U32.is_eq(sent, 12), "a sync into an empty store sends every object")
    raw(S.Disk.object(c, v1), "end\n")
    tampered : Result<&1, &1, U32 & String, S.Tree<S.Blob>> <- tries(S.Tree<S.Blob>, S.Disk.checkout(c, v1))
    ok(expect.fail(S.Tree<S.Blob>, tampered, "storage: object " ++ v1 ++ " does not match its digest"), "a tampered object fails the load")
    run(Unit, Files.remove(S.Disk.object(c, v1)))
    missing : Result<&1, &1, U32 & String, S.Tree<S.Blob>> <- tries(S.Tree<S.Blob>, S.Disk.checkout(c, v1))
    ok(expect.fail(S.Tree<S.Blob>, missing, "storage: root " ++ v1 ++ " does not load"), "a missing object fails the checkout")

def restored(+dir: String, +tb: S.Tree<S.Blob>) -> IO(Unit):
  do IO<Unit>:
    ok(same(tb, build("v1 binary")), "the destination reconstructs the root")
    run(Unit, S.restore(tb, dir ++ "/out"))
    t2 : S.Tree<S.Blob> <- run(S.Tree<S.Blob>, S.snapshot(dir ++ "/out"))
    ok(same(t2, build("v1 binary")), "a restored checkout matches the original directory")

# b already holds share/doc/README, which v1 also contains.
def transfer(+dir: String, +a: String, +b: String, +v1: String, +abc: String) -> IO(Unit):
  do IO<Unit>:
    seeded : String <- run(String, S.Disk.commit(b, docs()))
    nb : U32 <- count(b)
    sent : U32 <- run(U32, S.sync(a, b, v1))
    ok(U32.is_eq(sent, 7) && U32.is_eq(nb, 5), "sync sends only the 7 objects the destination lacks")
    again : U32 <- run(U32, S.sync(a, b, v1))
    ok(U32.is_eq(again, 0), "a second sync sends nothing")
    nb2 : U32 <- count(b)
    ok(U32.is_eq(nb2, 12), "the destination holds its own objects and the sent ones")
    sb : S.Index(String, S.Blob) <- run(S.Index(String, S.Blob), S.Disk.load(b))
    twice : Bool <- resend(b, sb, v1)
    ok(twice, "receiving an object the store holds leaves the store unchanged")
    tb : S.Tree<S.Blob> <- run(S.Tree<S.Blob>, S.Disk.checkout(b, v1))
    restored(dir, tb)
    dup : Result<&1, &1, U32 & String, S.Index(String, S.Blob)> <- tries(S.Index(String, S.Blob), S.Disk.receive(b, S.Index.new(String, S.Blob), abc, Bytes.from_string("end\n")))
    ok(expect.fail(S.Index(String, S.Blob), dup, "storage: object " ++ abc ++ " does not match its digest"), "ingress refuses an object whose digest is not the claimed one")

def committed(+dir: String, +a: String, +abc: String, +v1: String) -> IO(Unit):
  do IO<Unit>:
    run(Unit, S.Disk.set_root(a, "v1", v1))
    na : U32 <- count(a)
    ok(U32.is_eq(na, 12), "a commit stores each distinct object once: six listings share one end object")
    d1 : String <- digest.of(build("v1 binary"))
    ok(String.eq(v1, d1), "the root digest depends only on content")
    transfer(dir, a, dir ++ "/b", v1, abc)
    damage(a, dir ++ "/c", v1)
    v2 : String <- run(String, S.Disk.commit(a, build("v2 binary")))
    collect(a, v1, abc, v2)

def scenario(+dir: String, +abc: String) -> IO(Unit):
  +a = dir ++ "/a"
  do IO<Unit>:
    ok(String.eq(abc, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"), "digest is SHA-256")
    run(Unit, S.restore(build("v1 binary"), dir ++ "/build"))
    t1 : S.Tree<S.Blob> <- run(S.Tree<S.Blob>, S.snapshot(dir ++ "/build"))
    ok(same(t1, build("v1 binary")), "snapshot reads back the artifact directory that restore wrote")
    run(Unit, S.Disk.init(a))
    run(Unit, S.Disk.init(dir ++ "/b"))
    run(Unit, S.Disk.init(dir ++ "/c"))
    v1 : String <- run(String, S.Disk.commit(a, build("v1 binary")))
    committed(dir, a, abc, v1)

def main() -> IO(Unit):
  do IO<Unit>:
    pure()
    dir : String <- IO.try(String, Files.temp_dir())
    abc : String <- run(String, S.digest(Bytes.from_string("abc")))
    scenario(dir, abc)
