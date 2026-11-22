import Base
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import bend-kit-files@0.4.0.1/files.bend as Files
import ./storage.bend as S
import ./http_check.bend as HttpCheck

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
  S.Blob{+la, wa, da} = a
  S.Blob{+lb, wb, db} = b
  Bool.and(U32.is_eq(la, lb), Bool.and(words.eq(wa, wb), Cmp.is_eq(S.Digest.cmp(da, db))))

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

def file(s: String) -> IO(S.Tree<S.Blob>):
  do IO<S.Tree<S.Blob>>:
    b : S.Blob <- IO.try(S.Blob, S.Blob.string(s))
    return S.TFile{b}

def item(+n: String, c: S.Tree<S.Blob>, r: S.Tree<S.Blob>) -> S.Tree<S.Blob>:
  S.TItem{n, c, r}

# A build output: bin/app, an empty cache directory, lib/libcore.a, and share/doc/README.
# Each listing is in name order, as list_dir gives it.
def build(app: String) -> IO(S.Tree<S.Blob>):
  do IO<S.Tree<S.Blob>>:
    a : S.Tree<S.Blob> <- file(app)
    b : S.Tree<S.Blob> <- file("archive\u{0}with\u{0}nul octets")
    c : S.Tree<S.Blob> <- file("read me\n")
    return item("bin", item("app", a, S.TEnd{}),
      item("cache", S.TEnd{},
      item("lib", item("libcore.a", b, S.TEnd{}),
      item("share", item("doc", item("README", c, S.TEnd{}), S.TEnd{}),
      S.TEnd{}))))

def docs() -> IO(S.Tree<S.Blob>):
  do IO<S.Tree<S.Blob>>:
    t : S.Tree<S.Blob> <- file("read me\n")
    return item("share", item("doc", item("README", t, S.TEnd{}), S.TEnd{}), S.TEnd{})

def decodes(b: Bytes.Bytes) -> IO(Bool):
  do IO<Bool>:
    m : Maybe<&2, S.Obj<S.Digest, S.Blob>> <- IO.try(Maybe<&2, S.Obj<S.Digest, S.Blob>>, S.decode(b))
    return Maybe.is_some(&2, S.Obj<S.Digest, S.Blob>, m)

def hexa() -> String:
  "48332fe667bc51ac4a51ba0efe734441c90def55c60a26d7db275ecbbcf42f15"

def item.bytes(+n: String) -> Bytes.Bytes:
  Bytes.from_string("item " ++ hexa() ++ " " ++ hexa() ++ " " ++ n ++ "\n")

def hex.back(m: Maybe<&2, S.Digest>) -> String:
  match m:
    case Some{d}:
      S.Digest.hex(d)
    case None{}:
      ""

def same.digest(a: S.Digest, b: S.Digest) -> Bool:
  Cmp.is_eq(S.Digest.cmp(a, b))

def file.back(+b: S.Blob, m: Maybe<&2, S.Obj<S.Digest, S.Blob>>) -> Bool:
  match m:
    case Some{S.OFile{x}}:
      blob.eq(x, b)
    case _:
      False{}

def file.roundtrip(s: String) -> IO(Bool):
  do IO<Bool>:
    +b : S.Blob <- IO.try(S.Blob, S.Blob.string(s))
    m : Maybe<&2, S.Obj<S.Digest, S.Blob>> <- IO.try(Maybe<&2, S.Obj<S.Digest, S.Blob>>, S.decode(S.encode(S.OFile{b})))
    d : S.Digest <- IO.try(S.Digest, S.digest(S.encode(S.OFile{b})))
    cached : S.Digest <- IO.try(S.Digest, S.object.digest(S.OFile{b}))
    return Bool.and(file.back(b, m), same.digest(d, cached))

def roundtrips(ss: List<&2, String>) -> IO(Bool):
  match ss:
    case Nil{}:
      IO.pure(Bool, True{})
    case Con{s, t}:
      do IO<Bool>:
        a : Bool <- file.roundtrip(s)
        b : Bool <- roundtrips(t)
        return Bool.and(a, b)

def decoded.all(bs: List<&1, Bytes.Bytes>, +want: Bool) -> IO(Bool):
  match bs:
    case Nil{}:
      IO.pure(Bool, True{})
    case Con{b, t}:
      do IO<Bool>:
        +actual : Bool <- decodes(b)
        rest : Bool <- decoded.all(t, want)
        return Bool.and(Bool.pick(Bool, want, actual, Bool.not(actual)), rest)

# n octets that differ from their neighbours.
def octets(n: Nat, +i: U32) -> String:
  match n:
    case 0n:
      SNil{}
    case 1n+p:
      SCon{Chr{((i * 37 + 11) .&. 255 : U32)}, octets(p, (i + 1 : U32))}

def pure() -> IO(Unit):
  do IO<Unit>:
    short : Bool <- roundtrips(["", "x", "four", "five!", "a\nb\u{0}c"])
    ok(short, "file objects decode and cached digests equal SHA-256 of encode")
    headers : Bool <- roundtrips([octets(10n, 0), octets(100n, 0), octets(1000n, 0), octets(4097n, 0)])
    ok(headers, "file hashes and decoding agree for every header length modulo 4")
    good : Bool <- decoded.all([S.encode(S.OEnd{}), item.bytes("a b")], True{})
    ok(good, "end and item objects decode")
    names : Bool <- decoded.all([item.bytes(".."), item.bytes("a/b"), item.bytes(""), item.bytes(".")], False{})
    ok(names, "decode refuses names that would leave a restored directory")
    bad : Bool <- decoded.all([Bytes.from_string("item abc " ++ hexa() ++ " x\n"), Bytes.from_string("end\nx"), Bytes.from_string("file 01\nx"), Bytes.from_string("file 2\nx")], False{})
    ok(bad, "decode refuses bad digests, trailing octets, and wrong lengths")
    ok(String.eq(hex.back(S.Digest.read(hexa())), hexa()) && Bool.not(Maybe.is_some(&2, S.Digest, S.Digest.read("48332FE667BC51AC4A51BA0EFE734441C90DEF55C60A26D7DB275ECBBCF42F15"))) && Bool.not(Maybe.is_some(&2, S.Digest, S.Digest.read("48332fe6"))), "a digest reads back from its hex, and only 64 lowercase hex characters read")

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

def valid.objects(xs: S.Store<S.Digest, S.Blob>) -> IO(Bool):
  match xs:
    case S.StNil{}:
      IO.pure(Bool, True{})
    case S.StCon{d, o, r}:
      do IO<Bool>:
        actual : S.Digest <- IO.try(S.Digest, S.digest(S.encode(o)))
        rest : Bool <- valid.objects(r)
        return Bool.and(same.digest(d, actual), rest)

def digest.checked(r: S.Digest & S.Store<S.Digest, S.Blob>) -> IO(S.Digest):
  (d, objects) = r
  do IO<S.Digest>:
    valid : Bool <- valid.objects(objects)
    ok(valid, "every committed object key equals SHA-256 of its encoding")
    return d

def digest.of(t: S.Tree<S.Blob>) -> IO(S.Digest):
  do IO<S.Digest>:
    r : S.Digest & S.Store<S.Digest, S.Blob> <- run(S.Digest & S.Store<S.Digest, S.Blob>, S.commit(t))
    digest.checked(r)

def raw(+path: String, +s: String) -> IO(Unit):
  run(Unit, S.write.file(path, Bytes.from_string(s)))

def resend.of(+dir: String, +s: S.Index(S.Digest, S.Blob), +d: S.Digest, m: Maybe<&2, S.Obj<S.Digest, S.Blob>>) -> IO(Bool):
  match m:
    case None{}:
      IO.pure(Bool, False{})
    case Some{o}:
      do IO<Bool>:
        u : S.Index(S.Digest, S.Blob) <- run(S.Index(S.Digest, S.Blob), S.Disk.receive(dir, s, d, S.encode(o)))
        return U32.is_eq(S.Index.size(S.Digest, S.Blob, u), S.Index.size(S.Digest, S.Blob, s))

# Sends the object under d to the store at dir a second time.
def resend(+dir: String, +s: S.Index(S.Digest, S.Blob), +d: S.Digest) -> IO(Bool):
  resend.of(dir, s, d, S.Index.get(~S.Digest, ~S.Blob, ~S.Digest.cmp, s, d))

def loads.same(x: Maybe<&2, S.Tree<S.Blob>>, y: Maybe<&2, S.Tree<S.Blob>>) -> Bool:
  match x y:
    case Some{a} Some{b}:
      same(a, b)
    case _ _:
      False{}

def load.in(+s: S.Index(S.Digest, S.Blob), +d: S.Digest) -> Maybe<&2, S.Tree<S.Blob>>:
  S.Index.load(~S.Digest, ~S.Blob, ~S.Digest.cmp, S.limit(), s, d)

# A valid digest that names no object of the build.
def junk() -> S.Digest:
  S.Digest{[1, 2, 3, 4, 5, 6, 7, 8]}

def fetched.same(+v1: S.Digest, +f: S.Index(S.Digest, S.Blob), +full: S.Index(S.Digest, S.Blob)) -> IO(Unit):
  do IO<Unit>:
    ok(U32.is_eq(S.Index.size(S.Digest, S.Blob, f), 12) && U32.is_eq(S.Index.size(S.Digest, S.Blob, full), 15), "a fetch of v1 reads its 12 objects of the 15 in the store")
    ok(loads.same(load.in(f, v1), load.in(full, v1)), "the fetched index loads v1 as the full index does")

# a holds 15 objects; v1 reaches 12 of them.
def fetched(+a: String, +v1: S.Digest) -> IO(Unit):
  do IO<Unit>:
    f : S.Index(S.Digest, S.Blob) <- run(S.Index(S.Digest, S.Blob), S.Disk.fetch(a, v1))
    full : S.Index(S.Digest, S.Blob) <- run(S.Index(S.Digest, S.Blob), S.Disk.load(a))
    fetched.same(v1, f, full)

# v2 changes bin/app; collection keeps only v2.
def collect(+a: String, +v1: S.Digest, +abc: S.Digest, +v2: S.Digest) -> IO(Unit):
  do IO<Unit>:
    run(Unit, S.Disk.set_root(a, "v2", v2))
    na2 : U32 <- count(a)
    ok(U32.is_eq(na2, 15), "v2 adds three objects: the new file and the two entries above it")
    fetched(a, v1)
    raw(S.Disk.object(a, junk()), "not an object")
    refused : Result<&1, &1, U32 & String, U32> <- tries(U32, S.Disk.collect(a, [v2, abc]))
    na3 : U32 <- count(a)
    ok(expect.fail(U32, refused, "storage: a retained root does not load") && U32.is_eq(na3, 16), "collection with a root that does not load deletes nothing")
    dropped : U32 <- run(U32, S.Disk.collect(a, [v2]))
    ok(U32.is_eq(dropped, 4), "collection deletes the three objects only v1 reaches and a broken object it does not read")
    t3 : S.Tree<S.Blob> <- run(S.Tree<S.Blob>, S.Disk.checkout(a, v2))
    expected : S.Tree<S.Blob> <- build("v2 binary")
    ok(same(t3, expected), "the retained root survives collection")
    gone : Result<&1, &1, U32 & String, S.Tree<S.Blob>> <- tries(S.Tree<S.Blob>, S.Disk.checkout(a, v1))
    ok(expect.fail(S.Tree<S.Blob>, gone, "storage: root " ++ S.Digest.hex(v1) ++ " does not load"), "the collected root no longer loads")
    roots : List<&2, S.Digest> <- run(List<&2, S.Digest>, S.Disk.roots(a))
    ok(Nat.is_eq(List.length(&2, S.Digest, roots), 2n), "roots lists both named roots")

# A third store gets everything, then loses one object to tampering and then to deletion.
def damage(+a: String, +c: String, +v1: S.Digest) -> IO(Unit):
  do IO<Unit>:
    sent : U32 <- run(U32, S.sync(a, c, v1))
    ok(U32.is_eq(sent, 12), "a sync into an empty store sends every object")
    raw(S.Disk.object(c, v1), "end\n")
    tampered : Result<&1, &1, U32 & String, S.Tree<S.Blob>> <- tries(S.Tree<S.Blob>, S.Disk.checkout(c, v1))
    ok(expect.fail(S.Tree<S.Blob>, tampered, "storage: object " ++ S.Digest.hex(v1) ++ " does not match its digest"), "a tampered object fails the load")
    run(Unit, Files.remove(S.Disk.object(c, v1)))
    missing : Result<&1, &1, U32 & String, S.Tree<S.Blob>> <- tries(S.Tree<S.Blob>, S.Disk.checkout(c, v1))
    ok(expect.fail(S.Tree<S.Blob>, missing, "storage: root " ++ S.Digest.hex(v1) ++ " does not load"), "a missing object fails the checkout")

def restored(+dir: String, +tb: S.Tree<S.Blob>) -> IO(Unit):
  do IO<Unit>:
    +expected : S.Tree<S.Blob> <- build("v1 binary")
    ok(same(tb, expected), "the destination reconstructs the root")
    run(Unit, S.restore(tb, dir ++ "/out"))
    t2 : S.Tree<S.Blob> <- run(S.Tree<S.Blob>, S.snapshot(dir ++ "/out"))
    ok(same(t2, expected), "a restored checkout matches the original directory")

# b already holds share/doc/README, which v1 also contains.
def transfer(+dir: String, +a: String, +b: String, +v1: S.Digest, +abc: S.Digest) -> IO(Unit):
  do IO<Unit>:
    t : S.Tree<S.Blob> <- docs()
    seeded : S.Digest <- run(S.Digest, S.Disk.commit(b, t))
    nb : U32 <- count(b)
    sent : U32 <- run(U32, S.sync(a, b, v1))
    ok(U32.is_eq(sent, 7) && U32.is_eq(nb, 5), "sync sends only the 7 objects the destination lacks")
    nb2 : U32 <- count(b)
    ok(U32.is_eq(nb2, 12), "the destination holds its own objects and the sent ones")
    sb : S.Index(S.Digest, S.Blob) <- run(S.Index(S.Digest, S.Blob), S.Disk.load(b))
    twice : Bool <- resend(b, sb, v1)
    ok(twice, "receiving an object the store holds leaves the store unchanged")
    raw(S.Disk.object(b, junk()), "not an object")
    again : U32 <- run(U32, S.sync(a, b, v1))
    ok(U32.is_eq(again, 0), "a second sync sends nothing and does not read objects outside the closure")
    tb : S.Tree<S.Blob> <- run(S.Tree<S.Blob>, S.Disk.checkout(b, v1))
    restored(dir, tb)
    dup : Result<&1, &1, U32 & String, S.Index(S.Digest, S.Blob)> <- tries(S.Index(S.Digest, S.Blob), S.Disk.receive(b, S.Index.new(S.Digest, S.Blob), abc, Bytes.from_string("end\n")))
    ok(expect.fail(S.Index(S.Digest, S.Blob), dup, "storage: object " ++ S.Digest.hex(abc) ++ " does not match its digest"), "ingress refuses an object whose digest is not the claimed one")

def committed(+dir: String, +a: String, +abc: S.Digest, +v1: S.Digest) -> IO(Unit):
  do IO<Unit>:
    run(Unit, S.Disk.set_root(a, "v1", v1))
    na : U32 <- count(a)
    ok(U32.is_eq(na, 12), "a commit stores each distinct object once: six listings share one end object")
    t1 : S.Tree<S.Blob> <- build("v1 binary")
    d1 : S.Digest <- digest.of(t1)
    ok(same.digest(v1, d1), "the root digest depends only on content")
    transfer(dir, a, dir ++ "/b", v1, abc)
    damage(a, dir ++ "/c", v1)
    t2 : S.Tree<S.Blob> <- build("v2 binary")
    v2 : S.Digest <- run(S.Digest, S.Disk.commit(a, t2))
    collect(a, v1, abc, v2)

def scenario(+dir: String, +abc: S.Digest) -> IO(Unit):
  +a = dir ++ "/a"
  do IO<Unit>:
    ok(String.eq(S.Digest.hex(abc), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"), "digest is SHA-256")
    +expected : S.Tree<S.Blob> <- build("v1 binary")
    run(Unit, S.restore(expected, dir ++ "/build"))
    t1 : S.Tree<S.Blob> <- run(S.Tree<S.Blob>, S.snapshot(dir ++ "/build"))
    ok(same(t1, expected), "snapshot reads back the artifact directory that restore wrote")
    run(Unit, S.Disk.init(a))
    run(Unit, S.Disk.init(dir ++ "/b"))
    run(Unit, S.Disk.init(dir ++ "/c"))
    v1 : S.Digest <- run(S.Digest, S.Disk.commit(a, expected))
    committed(dir, a, abc, v1)

def wrote(pair: File & Result<&1, &1, U32 & String, Unit>) -> IO(File):
  (f, r) = pair
  do IO<File>:
    IO.try(Unit, IO.pure(Result<&1, &1, U32 & String, Unit>, r))
    return f

def interleave.ready(pa: String & File, pb: String & File, +path: String, +first: String, +head: String, +tail: String) -> IO(Unit):
  (+ta, fa) = pa
  (+tb, fb) = pb
  do IO<Unit>:
    ok(Bool.not(String.eq(ta, tb)), "writers of one name own different temporary files")
    run(Unit, S.write.opened((ta, fa), path, Bytes.from_string(first)))
    piece : File & Result<&1, &1, U32 & String, Unit> <- Files.write_bytes(fb, Bytes.from_string(head))
    fb : File <- wrote(piece)
    before : Bytes.Bytes <- run(Bytes.Bytes, S.read(path))
    ok(String.eq(Bytes.to_string(before), first), "a partial second write cannot change the published file")
    written : File & Result<&1, &1, U32 & String, Unit> <- Files.write_bytes(fb, Bytes.from_string(tail))
    closed : Result<&1, &1, U32 & String, Unit> <- S.write.close(written)
    run(Unit, S.write.publish(closed, tb, path))
    after : Bytes.Bytes <- run(Bytes.Bytes, S.read(path))
    ok(String.eq(Bytes.to_string(after), head ++ tail), "both writers publish without shared-temp ENOENT")

def interleave(+dir: String, +name: String, path: String, first: String, head: String, tail: String) -> IO(Unit):
  do IO<Unit>:
    pa : String & File <- run(String & File, S.write.temp(dir ++ "/tmp/" ++ name))
    pb : String & File <- run(String & File, S.write.temp(dir ++ "/tmp/" ++ name))
    interleave.ready(pa, pb, path, first, head, tail)

def failed.owned(pair: String & File, path: String, b: Bytes.Bytes, held: String) -> IO(Unit):
  (+tmp, f) = pair
  do IO<Unit>:
    failed : Result<&1, &1, U32 & String, Unit> <- S.write.opened((tmp, f), path, b)
    exists : Bool <- Files.exists(tmp)
    owned : Bool <- Files.exists(held)
    ok(expect.fail(Unit, failed, "") && Bool.not(exists) && owned, "failure removes only its owned temporary file")

def failures(pair: String & File, +dir: String) -> IO(Unit):
  (+held, fh) = pair
  do IO<Unit>:
    bad : String & File <- run(String & File, S.write.temp(dir ++ "/tmp/held"))
    failed.owned(bad, dir ++ "/objects/bad", Bytes.Bytes{5, [0 : U32*1n]}, held)
    bad : String & File <- run(String & File, S.write.temp(dir ++ "/tmp/held"))
    failed.owned(bad, dir ++ "/absent/object", Bytes.from_string("end\n"), held)
    run(Unit, S.write.opened((held, fh), dir ++ "/roots/held", Bytes.from_string("held")))
    missing : Result<&1, &1, U32 & String, String & File> <- S.write.temp(dir ++ "/absent/temp")
    ok(expect.fail(String & File, missing, ""), "temporary creation fails without touching another path")
    nul : Result<&1, &1, U32 & String, String & File> <- S.write.temp(dir ++ "/tmp/nul\u{0}suffix")
    ok(expect.fail(String & File, nul, ""), "temporary creation refuses NUL paths")
    names : List<&2, String> <- run(List<&2, String>, Files.list_dir(dir ++ "/tmp"))
    ok(List.is_empty(&2, String, names), "successful and failed writes leave no owned temporary files")

def concurrent(+dir: String) -> IO(Unit):
  do IO<Unit>:
    run(Unit, S.Disk.init(dir))
    +d : S.Digest <- run(S.Digest, S.digest(Bytes.from_string("end\n")))
    interleave(dir, S.Digest.hex(d), S.Disk.object(dir, d), "end\n", "en", "d\n")
    interleave(dir, "root", dir ++ "/roots/release", S.Digest.hex(d),
      "11111111111111111111111111111111", "11111111111111111111111111111111")
    final : S.Digest <- run(S.Digest, S.Disk.root(dir, "release"))
    ok(String.eq(S.Digest.hex(final), "1111111111111111111111111111111111111111111111111111111111111111"), "root updates use last-rename-wins order")
    +long : String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    run(Unit, S.Disk.set_root(dir, long, d))
    longest : S.Digest <- run(S.Digest, S.Disk.root(dir, long))
    ok(same.digest(longest, d), "temporary suffixes do not limit valid root names")
    held : String & File <- run(String & File, S.write.temp(dir ++ "/tmp/held"))
    failures(held, dir)

def main() -> IO(Unit):
  do IO<Unit>:
    pure()
    invalid : Result<&1, &1, U32 & String, Array<U32> & (U32 & Array<U32>)> <- S.Blob.hash.words(5, [0 : U32*1n])
    ok(expect.fail(Array<U32> & (U32 & Array<U32>), invalid, ""), "file hashing refuses a length beyond the packed input")
    oversized : Result<&1, &1, U32 & String, U32> <-
      S.info.size(Files.Info{Files.Regular{}, (1, 1073741824), (0, 0)})
    ok(expect.fail(U32, oversized, "storage: file exceeds the 32-bit Bytes length limit"),
      "a file over 4 GiB fails before its size is truncated")
    small : U32 <- run(U32, S.info.size(Files.Info{Files.Regular{}, (0, 3), (0, 0)}))
    ok(U32.is_eq(small, 3), "a small file keeps its size")
    +dir : String <- IO.try(String, Files.temp_dir())
    abc : S.Digest <- run(S.Digest, S.digest(Bytes.from_string("abc")))
    scenario(dir, abc)
    concurrent(dir ++ "/concurrent")
    HttpCheck.run()
