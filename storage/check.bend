import Base
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes
import bend-kit-files@0.4.0.2/files.bend as Files
import ./storage.bend as S
import ./pure.bend as P
import ./http_check.bend as HttpCheck
import ../process/process.bend as Proc
import ./root_check.bend as RootCheck

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

def blob.eq(a: P.Blob, b: P.Blob) -> Bool:
  P.Blob{+la, wa, da} = a
  P.Blob{+lb, wb, db} = b
  Bool.and(U32.is_eq(la, lb), Bool.and(words.eq(wa, wb), Cmp.is_eq(P.Digest.cmp(da, db))))

def same(a: P.Tree<P.Blob>, b: P.Tree<P.Blob>) -> Bool:
  match a b:
    case P.TFile{x} P.TFile{y}:
      blob.eq(x, y)
    case P.TEnd{} P.TEnd{}:
      True{}
    case P.TItem{n, c, r} P.TItem{m, d, t}:
      Bool.and(String.eq(n, m), Bool.and(same(c, d), same(r, t)))
    case _ _:
      False{}

def file(s: String) -> IO(P.Tree<P.Blob>):
  do IO<P.Tree<P.Blob>>:
    b : P.Blob <- IO.try(P.Blob, S.Blob.string(s))
    return P.TFile{b}

def item(+n: String, c: P.Tree<P.Blob>, r: P.Tree<P.Blob>) -> P.Tree<P.Blob>:
  P.TItem{n, c, r}

# A build output: bin/app, an empty cache directory, lib/libcore.a, and share/doc/README.
# Each listing is in name order, as list_dir gives it.
def build(app: String) -> IO(P.Tree<P.Blob>):
  do IO<P.Tree<P.Blob>>:
    a : P.Tree<P.Blob> <- file(app)
    b : P.Tree<P.Blob> <- file("archive\u{0}with\u{0}nul octets")
    c : P.Tree<P.Blob> <- file("read me\n")
    return item("bin", item("app", a, P.TEnd{}),
      item("cache", P.TEnd{},
      item("lib", item("libcore.a", b, P.TEnd{}),
      item("share", item("doc", item("README", c, P.TEnd{}), P.TEnd{}),
      P.TEnd{}))))

def docs() -> IO(P.Tree<P.Blob>):
  do IO<P.Tree<P.Blob>>:
    t : P.Tree<P.Blob> <- file("read me\n")
    return item("share", item("doc", item("README", t, P.TEnd{}), P.TEnd{}), P.TEnd{})

def decodes(b: Bytes.Bytes) -> IO(Bool):
  do IO<Bool>:
    m : Maybe<&2, P.Obj<P.Digest, P.Blob>> <- IO.try(Maybe<&2, P.Obj<P.Digest, P.Blob>>, S.decode(b))
    return Maybe.is_some(&2, P.Obj<P.Digest, P.Blob>, m)

def hexa() -> String:
  "48332fe667bc51ac4a51ba0efe734441c90def55c60a26d7db275ecbbcf42f15"

def item.bytes(+n: String) -> Bytes.Bytes:
  Bytes.from_string("item " ++ hexa() ++ " " ++ hexa() ++ " " ++ n ++ "\n")

def hex.back(m: Maybe<&2, P.Digest>) -> String:
  match m:
    case Some{d}:
      P.Digest.hex(d)
    case None{}:
      ""

def same.digest(a: P.Digest, b: P.Digest) -> Bool:
  Cmp.is_eq(P.Digest.cmp(a, b))

def file.back(+b: P.Blob, m: Maybe<&2, P.Obj<P.Digest, P.Blob>>) -> Bool:
  match m:
    case Some{P.OFile{x}}:
      blob.eq(x, b)
    case _:
      False{}

def file.roundtrip(s: String) -> IO(Bool):
  do IO<Bool>:
    +b : P.Blob <- IO.try(P.Blob, S.Blob.string(s))
    m : Maybe<&2, P.Obj<P.Digest, P.Blob>> <- IO.try(Maybe<&2, P.Obj<P.Digest, P.Blob>>, S.decode(P.encode(P.OFile{b})))
    d : P.Digest <- IO.try(P.Digest, S.digest(P.encode(P.OFile{b})))
    cached : P.Digest <- IO.try(P.Digest, S.object.digest(P.OFile{b}))
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
    good : Bool <- decoded.all([P.encode(P.OEnd{}), item.bytes("a b")], True{})
    ok(good, "end and item objects decode")
    names : Bool <- decoded.all([item.bytes(".."), item.bytes("a/b"), item.bytes(""), item.bytes(".")], False{})
    ok(names, "decode refuses names that would leave a restored directory")
    bad : Bool <- decoded.all([Bytes.from_string("item abc " ++ hexa() ++ " x\n"), Bytes.from_string("end\nx"), Bytes.from_string("file 01\nx"), Bytes.from_string("file 2\nx")], False{})
    ok(bad, "decode refuses bad digests, trailing octets, and wrong lengths")
    ok(String.eq(hex.back(P.Digest.read(hexa())), hexa()) && Bool.not(Maybe.is_some(&2, P.Digest, P.Digest.read("48332FE667BC51AC4A51BA0EFE734441C90DEF55C60A26D7DB275ECBBCF42F15"))) && Bool.not(Maybe.is_some(&2, P.Digest, P.Digest.read("48332fe6"))), "a digest reads back from its hex, and only 64 lowercase hex characters read")

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

def valid.objects(xs: P.Store<P.Digest, P.Blob>) -> IO(Bool):
  match xs:
    case P.StNil{}:
      IO.pure(Bool, True{})
    case P.StCon{d, o, r}:
      do IO<Bool>:
        actual : P.Digest <- IO.try(P.Digest, S.digest(P.encode(o)))
        rest : Bool <- valid.objects(r)
        return Bool.and(same.digest(d, actual), rest)

def digest.checked(r: P.Digest & P.Store<P.Digest, P.Blob>) -> IO(P.Digest):
  (d, objects) = r
  do IO<P.Digest>:
    valid : Bool <- valid.objects(objects)
    ok(valid, "every committed object key equals SHA-256 of its encoding")
    return d

def digest.of(t: P.Tree<P.Blob>) -> IO(P.Digest):
  do IO<P.Digest>:
    r : P.Digest & P.Store<P.Digest, P.Blob> <- run(P.Digest & P.Store<P.Digest, P.Blob>, S.commit(t))
    digest.checked(r)

def raw(+path: String, +s: String) -> IO(Unit):
  run(Unit, S.write.file(path, Bytes.from_string(s)))

def resend.of(+dir: String, +s: P.Index(P.Digest, P.Blob), +d: P.Digest, m: Maybe<&2, P.Obj<P.Digest, P.Blob>>) -> IO(Bool):
  match m:
    case None{}:
      IO.pure(Bool, False{})
    case Some{o}:
      do IO<Bool>:
        u : P.Index(P.Digest, P.Blob) <- run(P.Index(P.Digest, P.Blob), S.Disk.receive(dir, s, d, P.encode(o)))
        return U32.is_eq(P.Index.size(P.Digest, P.Blob, u), P.Index.size(P.Digest, P.Blob, s))

# Sends the object under d to the store at dir a second time.
def resend(+dir: String, +s: P.Index(P.Digest, P.Blob), +d: P.Digest) -> IO(Bool):
  resend.of(dir, s, d, P.Index.get(~P.Digest, ~P.Blob, ~P.Digest.cmp, s, d))

def loads.same(x: Maybe<&2, P.Tree<P.Blob>>, y: Maybe<&2, P.Tree<P.Blob>>) -> Bool:
  match x y:
    case Some{a} Some{b}:
      same(a, b)
    case _ _:
      False{}

def load.in(+s: P.Index(P.Digest, P.Blob), +d: P.Digest) -> Maybe<&2, P.Tree<P.Blob>>:
  P.Index.load(~P.Digest, ~P.Blob, ~P.Digest.cmp, P.limit(), s, d)

# A valid digest that names no object of the build.
def junk() -> P.Digest:
  P.Digest{[1, 2, 3, 4, 5, 6, 7, 8]}

def fetched.same(+v1: P.Digest, +f: P.Index(P.Digest, P.Blob), +full: P.Index(P.Digest, P.Blob)) -> IO(Unit):
  do IO<Unit>:
    ok(U32.is_eq(P.Index.size(P.Digest, P.Blob, f), 12) && U32.is_eq(P.Index.size(P.Digest, P.Blob, full), 15), "a fetch of v1 reads its 12 objects of the 15 in the store")
    ok(loads.same(load.in(f, v1), load.in(full, v1)), "the fetched index loads v1 as the full index does")

# a holds 15 objects; v1 reaches 12 of them.
def fetched(+a: String, +v1: P.Digest) -> IO(Unit):
  do IO<Unit>:
    f : P.Index(P.Digest, P.Blob) <- run(P.Index(P.Digest, P.Blob), S.Disk.fetch(a, v1))
    full : P.Index(P.Digest, P.Blob) <- run(P.Index(P.Digest, P.Blob), S.Disk.load(a))
    fetched.same(v1, f, full)

# v2 changes bin/app; collection keeps only v2.
def collect(+a: String, +v1: P.Digest, +abc: P.Digest, +v2: P.Digest) -> IO(Unit):
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
    t3 : P.Tree<P.Blob> <- run(P.Tree<P.Blob>, S.Disk.checkout(a, v2))
    expected : P.Tree<P.Blob> <- build("v2 binary")
    ok(same(t3, expected), "the retained root survives collection")
    gone : Result<&1, &1, U32 & String, P.Tree<P.Blob>> <- tries(P.Tree<P.Blob>, S.Disk.checkout(a, v1))
    ok(expect.fail(P.Tree<P.Blob>, gone, "storage: root " ++ P.Digest.hex(v1) ++ " does not load"), "the collected root no longer loads")
    roots : List<&2, P.Digest> <- run(List<&2, P.Digest>, S.Disk.roots(a))
    ok(Nat.is_eq(List.length(&2, P.Digest, roots), 2n), "roots lists both named roots")

# A third store gets everything, then loses one object to tampering and then to deletion.
def damage(+a: String, +c: String, +v1: P.Digest) -> IO(Unit):
  do IO<Unit>:
    sent : U32 <- run(U32, S.sync(a, c, v1))
    ok(U32.is_eq(sent, 12), "a sync into an empty store sends every object")
    raw(S.Disk.object(c, v1), "end\n")
    tampered : Result<&1, &1, U32 & String, P.Tree<P.Blob>> <- tries(P.Tree<P.Blob>, S.Disk.checkout(c, v1))
    ok(expect.fail(P.Tree<P.Blob>, tampered, "storage: object " ++ P.Digest.hex(v1) ++ " does not match its digest"), "a tampered object fails the load")
    run(Unit, Files.remove(S.Disk.object(c, v1)))
    missing : Result<&1, &1, U32 & String, P.Tree<P.Blob>> <- tries(P.Tree<P.Blob>, S.Disk.checkout(c, v1))
    ok(expect.fail(P.Tree<P.Blob>, missing, "storage: root " ++ P.Digest.hex(v1) ++ " does not load"), "a missing object fails the checkout")

def restored(+dir: String, +tb: P.Tree<P.Blob>) -> IO(Unit):
  do IO<Unit>:
    +expected : P.Tree<P.Blob> <- build("v1 binary")
    ok(same(tb, expected), "the destination reconstructs the root")
    run(Unit, S.restore(tb, dir ++ "/out"))
    t2 : P.Tree<P.Blob> <- run(P.Tree<P.Blob>, S.snapshot(dir ++ "/out"))
    ok(same(t2, expected), "a restored checkout matches the original directory")

# b already holds share/doc/README, which v1 also contains.
def transfer(+dir: String, +a: String, +b: String, +v1: P.Digest, +abc: P.Digest) -> IO(Unit):
  do IO<Unit>:
    t : P.Tree<P.Blob> <- docs()
    seeded : P.Digest <- run(P.Digest, S.Disk.commit(b, t))
    nb : U32 <- count(b)
    sent : U32 <- run(U32, S.sync(a, b, v1))
    ok(U32.is_eq(sent, 7) && U32.is_eq(nb, 5), "sync sends only the 7 objects the destination lacks")
    nb2 : U32 <- count(b)
    ok(U32.is_eq(nb2, 12), "the destination holds its own objects and the sent ones")
    sb : P.Index(P.Digest, P.Blob) <- run(P.Index(P.Digest, P.Blob), S.Disk.load(b))
    twice : Bool <- resend(b, sb, v1)
    ok(twice, "receiving an object the store holds leaves the store unchanged")
    raw(S.Disk.object(b, junk()), "not an object")
    again : U32 <- run(U32, S.sync(a, b, v1))
    ok(U32.is_eq(again, 0), "a second sync sends nothing and does not read objects outside the closure")
    tb : P.Tree<P.Blob> <- run(P.Tree<P.Blob>, S.Disk.checkout(b, v1))
    restored(dir, tb)
    dup : Result<&1, &1, U32 & String, P.Index(P.Digest, P.Blob)> <- tries(P.Index(P.Digest, P.Blob), S.Disk.receive(b, P.Index.new(P.Digest, P.Blob), abc, Bytes.from_string("end\n")))
    ok(expect.fail(P.Index(P.Digest, P.Blob), dup, "storage: object " ++ P.Digest.hex(abc) ++ " does not match its digest"), "ingress refuses an object whose digest is not the claimed one")

def committed(+dir: String, +a: String, +abc: P.Digest, +v1: P.Digest) -> IO(Unit):
  do IO<Unit>:
    run(Unit, S.Disk.set_root(a, "v1", v1))
    na : U32 <- count(a)
    ok(U32.is_eq(na, 12), "a commit stores each distinct object once: six listings share one end object")
    t1 : P.Tree<P.Blob> <- build("v1 binary")
    d1 : P.Digest <- digest.of(t1)
    ok(same.digest(v1, d1), "the root digest depends only on content")
    transfer(dir, a, dir ++ "/b", v1, abc)
    damage(a, dir ++ "/c", v1)
    t2 : P.Tree<P.Blob> <- build("v2 binary")
    v2 : P.Digest <- run(P.Digest, S.Disk.commit(a, t2))
    collect(a, v1, abc, v2)

def scenario(+dir: String, +abc: P.Digest) -> IO(Unit):
  +a = dir ++ "/a"
  do IO<Unit>:
    ok(String.eq(P.Digest.hex(abc), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"), "digest is SHA-256")
    +expected : P.Tree<P.Blob> <- build("v1 binary")
    run(Unit, S.restore(expected, dir ++ "/build"))
    t1 : P.Tree<P.Blob> <- run(P.Tree<P.Blob>, S.snapshot(dir ++ "/build"))
    ok(same(t1, expected), "snapshot reads back the artifact directory that restore wrote")
    run(Unit, S.Disk.init(a))
    run(Unit, S.Disk.init(dir ++ "/b"))
    run(Unit, S.Disk.init(dir ++ "/c"))
    v1 : P.Digest <- run(P.Digest, S.Disk.commit(a, expected))
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
    +d : P.Digest <- run(P.Digest, S.digest(Bytes.from_string("end\n")))
    interleave(dir, P.Digest.hex(d), S.Disk.object(dir, d), "end\n", "en", "d\n")
    interleave(dir, "root", dir ++ "/roots/release", P.Digest.hex(d),
      "11111111111111111111111111111111", "11111111111111111111111111111111")
    final : P.Digest <- run(P.Digest, S.Disk.root(dir, "release"))
    ok(String.eq(P.Digest.hex(final), "1111111111111111111111111111111111111111111111111111111111111111"), "root updates use last-rename-wins order")
    +long : String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    run(Unit, S.Disk.set_root(dir, long, d))
    longest : P.Digest <- run(P.Digest, S.Disk.root(dir, long))
    ok(same.digest(longest, d), "temporary suffixes do not limit valid root names")
    held : String & File <- run(String & File, S.write.temp(dir ++ "/tmp/held"))
    failures(held, dir)

def terminated(r: U32 & (String & String)) -> IO(Unit):
  (status, output) = r
  ok(U32.is_ne(status, 0), "the temporary writer terminates before publication")

def abandon(pair: String & File, +partial: Bool) -> IO(Unit):
  (+tmp, f) = pair
  do IO<Unit>:
    File.close(f)
    r : U32 & (String & String) <- run(U32 & (String & String),
      Process.run("python3", ["-c",
        "import os,signal,sys; f=os.open(sys.argv[1],os.O_WRONLY); os.write(f,sys.argv[2].encode()); os.kill(os.getpid(),signal.SIGKILL)",
        tmp, Bool.pick(String, partial, "partial", "")], "", 1024, 5000))
    terminated(r)
    exists : Bool <- Files.exists(tmp)
    ok(exists, "a terminated writer leaves its temporary file")
    contents : Bytes.Bytes <- run(Bytes.Bytes, S.read(tmp))
    ok(String.eq(Bytes.to_string(contents), Bool.pick(String, partial, "partial", "")),
      "the abandoned temporary file has the expected interrupted contents")

def maintenance(+dir: String) -> IO(Unit):
  do IO<Unit>:
    run(Unit, S.Disk.init(dir))
    +t : P.Tree<P.Blob> <- file("retained")
    +d : P.Digest <- run(P.Digest, S.Disk.commit(dir, t))
    run(Unit, S.Disk.set_root(dir, "release", d))
    created : String & File <- run(String & File, S.write.temp(dir ++ "/tmp/object"))
    abandon(created, False{})
    partial : String & File <- run(String & File, S.write.temp(dir ++ "/tmp/root"))
    abandon(partial, True{})
    removed : U32 <- run(U32, S.Disk.clean_tmp(dir))
    ok(U32.is_eq(removed, 2), "exclusive maintenance removes fresh abandoned temporary files")
    names : List<&2, String> <- run(List<&2, String>, Files.list_dir(dir ++ "/tmp"))
    ok(List.is_empty(&2, String, names), "exclusive maintenance empties only the temporary directory")
    root : P.Digest <- run(P.Digest, S.Disk.root(dir, "release"))
    after : P.Tree<P.Blob> <- run(P.Tree<P.Blob>, S.Disk.checkout(dir, d))
    ok(same.digest(root, d) && same(after, t), "maintenance preserves named roots and their objects")
    again : U32 <- run(U32, S.Disk.clean_tmp(dir))
    ok(U32.is_eq(again, 0), "maintenance on an empty temporary directory removes nothing")
    run(Unit, S.write(dir, "after", dir ++ "/roots/after", Bytes.from_string("published")))
    published : Bytes.Bytes <- run(Bytes.Bytes, S.read(dir ++ "/roots/after"))
    ok(String.eq(Bytes.to_string(published), "published"), "writers can resume after exclusive maintenance")

def durability.fault(+dir: String, +path: String, +stage: U32) -> IO(Unit):
  do IO<Unit>:
    run(Unit, S.write(dir, "old", path, Bytes.from_string("old")))
    run(Unit, S.write.file(dir ++ "/tmp/injected", Bytes.from_string("new")))
    result : Result<&1, &1, U32 & String, Unit> <- S.write.durable(dir ++ "/tmp/injected", path, stage)
    ok(expect.fail(Unit, result, ""), "each publication boundary reports an injected failure")
    bytes : Bytes.Bytes <- run(Bytes.Bytes, S.read(path))
    ok(String.eq(Bytes.to_string(bytes), Bool.pick(String, U32.is_lt(stage, 4) || U32.is_eq(stage, 7), "old", "new")),
      "a failed publication exposes only the complete old or new file")
    +pending : Bool <- Files.exists(dir ++ "/tmp/injected")
    ok(Bool.pick(Bool, U32.is_lt(stage, 4) || U32.is_eq(stage, 7), pending, Bool.not(pending)),
      "the rename boundary determines temporary-file ownership")
    cleaned : Result<&1, &1, U32 & String, Unit> <- S.write.cleanup(dir ++ "/tmp/injected", Fail{(5, "injected")})
    ok(expect.fail(Unit, cleaned, "injected"), "cleanup keeps the publication failure")

def durability.steps(n: Nat, +dir: String, +stage: U32) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        durability.fault(dir, dir ++ "/objects/fault", stage)
        durability.fault(dir, dir ++ "/roots/fault", stage)
        durability.steps(p, dir, (stage + 1 : U32))

def durability(+dir: String) -> IO(Unit):
  do IO<Unit>:
    run(Unit, S.Disk.init(dir))
    durability.steps(7n, dir, 1)
    run(Unit, S.write.file(dir ++ "/tmp/fullsync", Bytes.from_string("new")))
    fullsync : Result<&1, &1, U32 & String, Unit> <- S.write.durable(dir ++ "/tmp/fullsync", dir ++ "/roots/fullsync", 7)
    ok(expect.fail(Unit, fullsync, ""), "a failed full-sync barrier returns an error")
    published : Bool <- Files.exists(dir ++ "/roots/fullsync")
    ok(Bool.not(published), "a failed full-sync barrier cannot publish a new root")
    run(Unit, Files.remove(dir ++ "/tmp/fullsync"))
    +end : P.Digest <- run(P.Digest, S.digest(Bytes.from_string("end\n")))
    run(Unit, S.write.file(dir ++ "/tmp/interrupted", Bytes.from_string("end\n")))
    interrupted : Result<&1, &1, U32 & String, Unit> <- S.write.durable(dir ++ "/tmp/interrupted", S.Disk.object(dir, end), 4)
    ok(expect.fail(Unit, interrupted, ""), "an interrupted object publication can leave a renamed object")
    run(Unit, S.Disk.set_root(dir, "recovered", end))
    recovered : P.Digest <- run(P.Digest, S.Disk.root(dir, "recovered"))
    ok(same.digest(recovered, end), "root publication fences an object left after rename")
    +t : P.Tree<P.Blob> <- file("durable")
    +child : P.Digest <- run(P.Digest, S.Disk.commit(dir, t))
    +d : P.Digest <- run(P.Digest, S.Disk.commit(dir, P.TItem{"file", t, P.TEnd{}}))
    run(Unit, S.Disk.set_root(dir, "release", d))
    +missing : P.Digest <- run(P.Digest, S.digest(Bytes.from_string("missing")))
    failed : Result<&1, &1, U32 & String, Unit> <- S.Disk.set_root(dir, "release", missing)
    ok(expect.fail(Unit, failed, ""), "a missing closure cannot replace a durable root")
    root : P.Digest <- run(P.Digest, S.Disk.root(dir, "release"))
    ok(same.digest(root, d), "a refused root leaves the prior root unchanged")
    run(Unit, Files.remove(S.Disk.object(dir, child)))
    failed : Result<&1, &1, U32 & String, Unit> <- S.Disk.set_root(dir, "absent", d)
    ok(expect.fail(Unit, failed, ""), "root publication refuses an incomplete object closure")
    exists : Bool <- Files.exists(dir ++ "/roots/absent")
    ok(Bool.not(exists), "a failed closure check does not publish a root")
    run(Unit, S.write.file(S.Disk.object(dir, child), Bytes.from_string("corrupt")))
    corrupt : Result<&1, &1, U32 & String, Unit> <- S.Disk.set_root(dir, "corrupt", d)
    ok(expect.fail(Unit, corrupt, ""), "root publication refuses a corrupt descendant")
    exists : Bool <- Files.exists(dir ++ "/roots/corrupt")
    ok(Bool.not(exists), "a corrupt closure cannot publish a root")

def coordination.writer(r: Result<&1, &1, U32 & String, P.Digest>, exclusive: Bool) -> IO(Unit):
  match r exclusive:
    case Fail{e} True{}:
      ok(True{}, "exclusive maintenance rejects new cooperating writers")
    case Done{d} False{}:
      ok(True{}, "shared writer locks admit other writers")
    case _ _:
      ok(False{}, "writer admission matches the held lock")

def coordination.ready(pair: File & Result<&1, &1, U32 & String, String>) -> IO(File):
  (output, result) = pair
  do IO<File>:
    text : String <- IO.try(String, IO.pure(Result<&1, &1, U32 & String, String>, result))
    ok(String.eq(text, "ready\n"), "a separate process holds the store lock")
    return output

def coordination.opened(child: U32 & File & File & File, +dir: String, +d: P.Digest, +mode: U32) -> IO(Unit):
  (+pid, input, output, errors) = child
  do IO<Unit>:
    ready : File & Result<&1, &1, U32 & String, String> <- File.read(output, 6)
    output : File <- coordination.ready(ready)
    clean : Result<&1, &1, U32 & String, U32> <- S.Disk.clean_tmp(dir)
    collect : Result<&1, &1, U32 & String, U32> <- S.Disk.collect(dir, [])
    named : Result<&1, &1, U32 & String, U32> <- S.Disk.collect_named(dir)
    ok(expect.fail(U32, named, "storage: store coordination"), "named collection rejects a live lock holder")
    ok(expect.fail(U32, clean, "storage: store coordination") && expect.fail(U32, collect, "storage: store coordination"), "live holders reject cleanup and collection")
    root : P.Digest <- run(P.Digest, S.Disk.root(dir, "release"))
    tree : P.Tree<P.Blob> <- run(P.Tree<P.Blob>, S.Disk.checkout(dir, d))
    ok(same.digest(root, d) && same(tree, P.TEnd{}), "rejected maintenance preserves objects and named roots")
    pending : Bool <- Files.exists(dir ++ "/tmp/pending")
    ok(pending, "rejected maintenance preserves live temporary files")
    attempt : Result<&1, &1, U32 & String, P.Digest> <- S.Disk.commit(dir, P.TEnd{})
    update : Result<&1, &1, U32 & String, Unit> <- S.Disk.set_root(dir, "release", d)
    +denied : Bool = expect.fail(Unit, update, "storage: store coordination")
    ok(Bool.pick(Bool, U32.is_eq(mode, 2), denied, Bool.not(denied)), "root writer admission matches the held lock")
    coordination.writer(attempt, U32.is_eq(mode, 2))
    run(Unit, Proc.kill(pid, 9))
    status : U32 <- run(U32, Proc.wait(pid))
    File.close(input)
    File.close(output)
    File.close(errors)
    ok(U32.is_eq(status, 137), "the lock holder terminates without explicit unlock")
    resumed : P.Digest <- run(P.Digest, S.Disk.commit(dir, P.TEnd{}))
    removed : U32 <- run(U32, S.Disk.clean_tmp(dir))
    ok(same.digest(resumed, d) && U32.is_eq(removed, 1), "termination releases the lock for writers and maintenance")

def coordination.held(+dir: String, +d: P.Digest, +mode: U32) -> IO(Unit):
  do IO<Unit>:
    child : U32 & File & File & File <- run(U32 & File & File & File, Proc.spawn("/usr/bin/python3", ["-c",
      "import fcntl,os,sys; f=os.open(sys.argv[1],os.O_RDONLY); fcntl.flock(f,int(sys.argv[2])); print('ready',flush=True); sys.stdin.read()",
      dir, U32.show(mode)], [], "."))
    coordination.opened(child, dir, d, mode)

def coordination.probed(r: U32 & (String & String)) -> IO(Unit):
  (code, text) = r
  ok(U32.is_eq(code, 0), "a Bend-owned scope excludes a separate maintenance process")

def coordination.probe(+dir: String) -> S.Run(Unit):
  do S.Run<Unit>:
    r : U32 & (String & String) <- Process.run("/usr/bin/python3", ["-c",
      "import fcntl,os,sys; f=os.open(sys.argv[1],os.O_RDONLY)\ntry: fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)\nexcept BlockingIOError: sys.exit(0)\nsys.exit(1)",
      dir], "", 1024, 5000)
    S.Run.lift(Unit, coordination.probed(r))

def coordination(+dir: String) -> IO(Unit):
  do IO<Unit>:
    run(Unit, S.Disk.init(dir))
    +d : P.Digest <- run(P.Digest, S.Disk.commit(dir, P.TEnd{}))
    run(Unit, S.Disk.set_root(dir, "release", d))
    raw(dir ++ "/tmp/pending", "live")
    coordination.held(dir, d, 1)
    raw(dir ++ "/tmp/pending", "live")
    coordination.held(dir, d, 2)
    run(Unit, S.Disk.coordinated(Unit, dir, False{}, u => coordination.probe(dir)))
    failed : Result<&1, &1, U32 & String, Unit> <- S.Disk.coordinated(Unit, dir, True{}, u => S.Run.fail(Unit, (5, "expected")))
    ok(expect.fail(Unit, failed, "expected"), "an action failure retains its error")
    removed : U32 <- run(U32, S.Disk.clean_tmp(dir))
    ok(U32.is_eq(removed, 0), "an action failure releases its exclusive lock")

def named.scope(+dir: String, +d: P.Digest) -> S.Run(U32):
  do S.Run<U32>:
    roots : List<&2, P.Digest> <- S.Disk.roots(dir)
    writer : Result<&1, &1, U32 & String, Unit> <- S.Run.lift(Result<&1, &1, U32 & String, Unit>, S.Disk.set_root(dir, "release", d))
    S.Run.lift(Unit, ok(expect.fail(Unit, writer, "storage: store coordination"), "a root writer cannot enter between selection and deletion"))
    S.Disk.collect.retained(dir, roots)

def named.collect(+dir: String) -> IO(Unit):
  do IO<Unit>:
    run(Unit, S.Disk.init(dir))
    +kept : P.Digest <- run(P.Digest, S.Disk.commit(dir, P.TEnd{}))
    +blob : P.Blob <- run(P.Blob, S.Blob.string("retained"))
    +other : P.Digest <- run(P.Digest, S.Disk.commit(dir, P.TFile{blob}))
    orphan : P.Tree<P.Blob> <- file("unretained")
    unused : P.Digest <- run(P.Digest, S.Disk.commit(dir, orphan))
    run(Unit, S.Disk.set_root(dir, "release", kept))
    run(Unit, S.Disk.set_root(dir, "other", other))
    raw(dir ++ "/roots/bad", "not a digest")
    malformed : Result<&1, &1, U32 & String, U32> <- S.Disk.collect_named(dir)
    n : U32 <- count(dir)
    ok(expect.fail(U32, malformed, "storage: root bad is not a digest") && U32.is_eq(n, 3), "an invalid named root causes no deletion")
    raw(dir ++ "/roots/bad", P.Digest.hex(junk()))
    missing : Result<&1, &1, U32 & String, U32> <- S.Disk.collect_named(dir)
    n : U32 <- count(dir)
    ok(expect.fail(U32, missing, "storage: a retained root does not load") && U32.is_eq(n, 3), "a missing named closure causes no deletion")
    run(Unit, Files.remove(dir ++ "/roots/bad"))
    raw(S.Disk.object(dir, other), "corrupt")
    corrupt : Result<&1, &1, U32 & String, U32> <- S.Disk.collect_named(dir)
    n : U32 <- count(dir)
    ok(expect.fail(U32, corrupt, "") && U32.is_eq(n, 3), "a corrupt named closure causes no deletion")
    run(Unit, Files.remove(S.Disk.object(dir, other)))
    repaired : P.Digest <- run(P.Digest, S.Disk.commit(dir, P.TFile{blob}))
    removed : U32 <- run(U32, S.Disk.collect_named(dir))
    n : U32 <- count(dir)
    ok(U32.is_eq(removed, 1) && U32.is_eq(n, 2), "named collection retains both roots and deletes only the orphan")
    tree : P.Tree<P.Blob> <- run(P.Tree<P.Blob>, S.Disk.checkout(dir, other))
    ok(same(tree, P.TFile{blob}), "named collection preserves the retained tree")
    removed : U32 <- run(U32, S.Disk.coordinated(U32, dir, True{}, u => named.scope(dir, kept)))
    ok(U32.is_eq(removed, 0), "one exclusive scope covers root selection and collection")
    run(Unit, Files.remove(dir ++ "/roots/release"))
    run(Unit, Files.remove(dir ++ "/roots/other"))
    removed : U32 <- run(U32, S.Disk.collect_named(dir))
    ok(U32.is_eq(removed, 2), "named collection with no roots deletes every object")

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
    abc : P.Digest <- run(P.Digest, S.digest(Bytes.from_string("abc")))
    scenario(dir, abc)
    concurrent(dir ++ "/concurrent")
    maintenance(dir ++ "/maintenance")
    coordination(dir ++ "/coordination")
    named.collect(dir ++ "/named")
    durability(dir ++ "/durability")
    RootCheck.main()
    HttpCheck.run()
