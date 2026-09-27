import Base
import ./crypto.bend as C
import ../bytes/bytes.bend as Bytes

def hex.of(m: Maybe<&1, Bytes.Bytes>) -> Bytes.Bytes:
  match m:
    case None{}:
      Bytes.from_string("")
    case Some{b}:
      b

def hex(+s: String) -> Bytes.Bytes:
  hex.of(Bytes.from_hex(s))

def txt(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def ok(ok: Bool, +name: String, +got: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, name ++ " gave " ++ got)

def got(+name: String, +want: String, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, name ++ " failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{(+len, buf)}:
      +h = Bytes.to_hex(Bytes.Bytes{len, buf})
      ok(String.eq(h, want), name, h)

def fails(+name: String, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      ok(U32.is_eq(code, 22), name, U32.show(code) ++ " " ++ why)
    case Done{p}:
      IO.die(Unit, 1, name ++ " did not fail")

def dg(~eff: U32 -> Array<U32> -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>), +name: String, +want: String, b: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{+len, buf} = b
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- eff(len, buf)
    got(name, want, r)

def mac(+alg: String, +name: String, +want: String, k: Bytes.Bytes, d: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{+kn, kb} = k
  Bytes.Bytes{+dn, db} = d
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- C.hmac.words(alg, kn, kb, dn, db)
    got(name, want, r)

def kdf.run(+alg: String, s: Bytes.Bytes, k: Bytes.Bytes, i: Bytes.Bytes, +n: U32) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{+sn, sb} = s
  Bytes.Bytes{+kn, kb} = k
  Bytes.Bytes{+iln, ib} = i
  C.hkdf.words(alg, sn, sb, kn, kb, iln, ib, n)

def kdf(+alg: String, +name: String, +want: String, s: Bytes.Bytes, k: Bytes.Bytes, i: Bytes.Bytes, +n: U32) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- kdf.run(alg, s, k, i, n)
    got(name, want, r)

def eq(+name: String, +want: Bool, a: Bytes.Bytes, b: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{+an, ab} = a
  Bytes.Bytes{+bn, bb} = b
  do IO<Unit>:
    +r : Bool <- C.eq.ct.words(an, ab, bn, bb)
    ok(Bool.not(Bool.xor(r, want)), name, Bool.show(r))

def rnd.two(+n: U32, r: Result<&1, &1, U32 & String, U32 & Array<U32>>, s: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "random failed")
    case Done{(+an, ab)}:
      match s:
        case Fail{e}:
          IO.die(Unit, 1, "random failed")
        case Done{(+bn, bb)}:
          do IO<Unit>:
            ok(U32.is_eq(an, n), "random length", U32.show(an))
            eq("random draws differ", False{}, Bytes.Bytes{an, ab}, Bytes.Bytes{bn, bb})

def rnd(+n: U32) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- C.random.words(n)
    s : Result<&1, &1, U32 & String, U32 & Array<U32>> <- C.random.words(n)
    rnd.two(n, r, s)

def bad.alg(b: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{+len, buf} = b
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- C.digest.words("NOPE", len, buf)
    fails("unknown digest", r)

def bad.kdf() -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- kdf.run("SHA256", txt(""), hex(String.repeat("0b", 22n)), txt(""), 0)
    fails("hkdf n = 0", r)
    s : Result<&1, &1, U32 & String, U32 & Array<U32>> <- kdf.run("SHA256", txt(""), hex(String.repeat("0b", 22n)), txt(""), 8161)
    fails("hkdf n > 255 * 32", s)

def main() -> IO(Unit):
  do IO<Unit>:
    # NIST CAVP (FIPS 180-2 examples): one block, empty, and two blocks.
    dg(~C.sha1.words, "sha1 abc", "a9993e364706816aba3e25717850c26c9cd0d89d", txt("abc"))
    dg(~C.sha1.words, "sha1 empty", "da39a3ee5e6b4b0d3255bfef95601890afd80709", txt(""))
    dg(~C.sha1.words, "sha1 448", "84983e441c3bd26ebaae4aa1f95129e5e54670f1", txt("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"))
    dg(~C.sha256.words, "sha256 abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", txt("abc"))
    dg(~C.sha256.words, "sha256 empty", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", txt(""))
    dg(~C.sha256.words, "sha256 448", "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1", txt("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"))
    dg(~C.sha512.words, "sha512 abc", "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f", txt("abc"))
    dg(~C.sha512.words, "sha512 empty", "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e", txt(""))
    dg(~C.sha512.words, "sha512 896", "8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909", txt("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"))
    # RFC 4231 §4.2-4.8; case 5 truncates the output, so it is left out.
    mac("SHA256", "hmac256 case 1", "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7", hex(String.repeat("0b", 20n)), txt("Hi There"))
    mac("SHA512", "hmac512 case 1", "87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cdedaa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854", hex(String.repeat("0b", 20n)), txt("Hi There"))
    mac("SHA256", "hmac256 case 2", "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843", txt("Jefe"), txt("what do ya want for nothing?"))
    mac("SHA512", "hmac512 case 2", "164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea2505549758bf75c05a994a6d034f65f8f0e6fdcaeab1a34d4a6b4b636e070a38bce737", txt("Jefe"), txt("what do ya want for nothing?"))
    mac("SHA256", "hmac256 case 3", "773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe", hex(String.repeat("aa", 20n)), hex(String.repeat("dd", 50n)))
    mac("SHA512", "hmac512 case 3", "fa73b0089d56a284efb0f0756c890be9b1b5dbdd8ee81a3655f83e33b2279d39bf3e848279a722c806b485a47e67c807b946a337bee8942674278859e13292fb", hex(String.repeat("aa", 20n)), hex(String.repeat("dd", 50n)))
    mac("SHA256", "hmac256 case 4", "82558a389a443c0ea4cc819899f2083a85f0faa3e578f8077a2e3ff46729665b", hex("0102030405060708090a0b0c0d0e0f10111213141516171819"), hex(String.repeat("cd", 50n)))
    mac("SHA512", "hmac512 case 4", "b0ba465637458c6990e5a8c5f61d4af7e576d97ff94b872de76f8050361ee3dba91ca5c11aa25eb4d679275cc5788063a5f19741120c4f2de2adebeb10a298dd", hex("0102030405060708090a0b0c0d0e0f10111213141516171819"), hex(String.repeat("cd", 50n)))
    mac("SHA256", "hmac256 case 6", "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54", hex(String.repeat("aa", 131n)), txt("Test Using Larger Than Block-Size Key - Hash Key First"))
    mac("SHA512", "hmac512 case 6", "80b24263c7c1a3ebb71493c1dd7be8b49b46d1f41b4aeec1121b013783f8f3526b56d037e05f2598bd0fd2215d6a1e5295e64f73f63f0aec8b915a985d786598", hex(String.repeat("aa", 131n)), txt("Test Using Larger Than Block-Size Key - Hash Key First"))
    mac("SHA256", "hmac256 case 7", "9b09ffa71b942fcb27635fbcd5b0e944bfdc63644f0713938a7f51535c3a35e2", hex(String.repeat("aa", 131n)), txt("This is a test using a larger than block-size key and a larger than block-size data. The key needs to be hashed before being used by the HMAC algorithm."))
    mac("SHA512", "hmac512 case 7", "e37b6a775dc87dbaa4dfa9f96e5e3ffddebd71f8867289865df5a32d20cdc944b6022cac3c4982b10d5eeb55c3e4de15134676fb6de0446065c97440fa8c6a58", hex(String.repeat("aa", 131n)), txt("This is a test using a larger than block-size key and a larger than block-size data. The key needs to be hashed before being used by the HMAC algorithm."))
    # RFC 5869 A.1-A.4.
    kdf("SHA256", "hkdf case 1", "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865", hex("000102030405060708090a0b0c"), hex(String.repeat("0b", 22n)), hex("f0f1f2f3f4f5f6f7f8f9"), 42)
    kdf("SHA256", "hkdf case 2", "b11e398dc80327a1c8e7f78c596a49344f012eda2d4efad8a050cc4c19afa97c59045a99cac7827271cb41c65e590e09da3275600c2f09b8367793a9aca3db71cc30c58179ec3e87c14c01d5c1f3434f1d87", hex("606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeaf"), hex("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f"), hex("b0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff"), 82)
    kdf("SHA256", "hkdf case 3", "8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8", txt(""), hex(String.repeat("0b", 22n)), txt(""), 42)
    kdf("SHA1", "hkdf case 4", "085a01ea1b10f36933068b56efa5ad81a4f14b822f5b091568a9cdd4f155fda2c22e422478d305f3f896", hex("000102030405060708090a0b0c"), hex(String.repeat("0b", 11n)), hex("f0f1f2f3f4f5f6f7f8f9"), 42)
    bad.alg(txt("abc"))
    bad.kdf()
    eq("eq.ct same", True{}, txt("same mac"), txt("same mac"))
    eq("eq.ct differ", False{}, txt("same mac"), txt("same mad"))
    eq("eq.ct lengths", False{}, txt("abc"), txt("ab"))
    rnd(300)
