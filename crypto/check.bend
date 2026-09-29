import Base
import ./crypto.bend as C
import ../bytes/bytes.bend as Bytes
import ./aead_check.bend as AE

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

def pbkdf2.run(+alg: String, p: Bytes.Bytes, s: Bytes.Bytes, +iters: U32, +n: U32) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{+pn, pb} = p
  Bytes.Bytes{+sn, sb} = s
  C.pbkdf2.words(alg, pn, pb, sn, sb, iters, n)

def pbkdf2(+alg: String, +name: String, +want: String, p: Bytes.Bytes, s: Bytes.Bytes, +iters: U32, +n: U32) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- pbkdf2.run(alg, p, s, iters, n)
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
    u : Result<&1, &1, U32 & String, U32 & Array<U32>> <- pbkdf2.run("SHA256", txt("passwd"), txt("salt"), 0, 32)
    fails("pbkdf2 iters = 0", u)
    v : Result<&1, &1, U32 & String, U32 & Array<U32>> <- pbkdf2.run("SHA256", txt("passwd"), txt("salt"), 1, 0)
    fails("pbkdf2 n = 0", v)
    x : Result<&1, &1, U32 & String, U32 & Array<U32>> <- pbkdf2.run("NOPE", txt("passwd"), txt("salt"), 1, 32)
    fails("pbkdf2 unknown digest", x)

# RFC 7515 A.2 (RS256) and A.3 (ES256) keys, as PEM exported by Bun from the RFC's JWKs.
def pem.rsa.priv() -> Bytes.Bytes:
  txt("-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCh+BYK4uPJtGXO\njS1lYmM2K5J9vinh8CR3/BYlzJChNuOL2TSXxbbqY913EeZ8dCn5VrD7io8ImtxL\naYk8wTM/U+3QGbh3hCUv7JFP5IV3aVlL6kKA0ywPVb9ilE8TA5a8bpvfbr3SvaNn\njuygxmj3AbONv/s4yDQs4v5tJ/reSlpIdJed1LnPmt7Ex1sFhSwsD174pcF1A5L5\nROjtZMEQxrZHYJqkeDrrnGya11UxMFBji4NmXG9veoKjlnAqH2QbgtPr8jkiGUkf\ntoaHLFcW9Qr4NY2ai50Xw0Byj3+H2JoY2PyrZ62EWQwuz3WTOTY8BwNNb2BvniHg\nVFbK5emhAgMBAAECggEAEq5xpGnNCivDflJsRQBXHx1hdR1k6Ulwe2JZD50LpXyW\nPEAeP88vLNO97IjlA7/GQ5sLKMgvfTeXZx9SE+7YwVol2NXOoAJe46sui395IW/G\nO+pWJ1O0BkTGoVEn2bKVRUCgu+GjBVaYLU6f3l9kJfFNS3E0QbVdxzubSu3Mkqzj\nkn439X0M/V51gfpRLI9JYanrC4D4qAdGcopV/0ZHHzQlBjudU2QvXt4ehNYTCBr6\nXCLQUShb1juUO1ZdiYoFaFQT5Tw8bGUl/x/jTj3ccPDVZFD9pIuhLhBOneufuBiB\n4cS98l2SR/RQyGWSeWjnczT0QU91p1DhOVRuOopznQKBgQDgHMQQ60imZV1URk0K\npLttoLhyt3SmqdEf/kgHePDdtzEafpAu+cS191R2JiuoF2yzWXnwFDcqGigp5BNr\n0AHQfD8/Lk8l1Mk09jxxCfui5nYooNyac8YFjm3vItzVCVDnEd3BbVWG8qf6deqE\nlMGAg+C2V0L4oNXnP7LZcPAZRwKBgQC5A8R+CZW2MvRTLLHzwZkUXV866cff7tx6\nkqa0finGG0KgeqlaZPxgCZnFp7AeAcCMtiynVlJ7vMVgePsLq6XtON4tB5kP9jAP\nrq3rbAOal78eUH5OcED6eNuCV8ixEu1eWcPNCS/l1OW1EnXUEoEHKl54Xrrz2uNw\nkgMTP1FZ1wKBgAcCn1dwJKufzBWQxWQp1vsM5fggqPN1qGb5y0MAk3g7/Ls5bkUp\n5u9SN0Ai3Ya6hNnvWJMb7sXQX6U/zyO2M/hTip7tUeh7CXgwo59dkpN75gJLVds2\n9+DAncu3KXU4f2Fa+7bLNrur53k8KwPOq2bbuTG69QtV7Jr5MR0AHWKNAoGBAIf/\nevpitUf+4JYbLpvNXWcY052Mpz22aR84mY3nh3F2LF2mjMJDpTg7FmuyPcVw6EcG\nyoAe9fa65iNqCq+jdw6PVNGo2hxfjSiZ8IIzHdsPXI89//pMjZcQK9r+CCoRjaZj\nOYiIDktVWZzmevJuv6WywUqd57LE3Zar3dLSIkx1AoGAIYd7DHOhrWvxkwPQsRM2\ntOgrjbcrfvtQJipd+DlcxyVuuM9sQLdgjVk2oy26F0EmpScGLq2MowX7fhd/QJQ3\nydy5cY7YIBi87w93IKLEdfnbJtoOPLUW0ITrJReOgo1cq9SbsxYawBgfp/gh6A56\n03k2+ZQwVK0JKSHuLFkuQ3U=\n-----END PRIVATE KEY-----\n")

def pem.rsa.priv.pkcs1() -> Bytes.Bytes:
  txt("-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAofgWCuLjybRlzo0tZWJjNiuSfb4p4fAkd/wWJcyQoTbji9k0\nl8W26mPddxHmfHQp+Vaw+4qPCJrcS2mJPMEzP1Pt0Bm4d4QlL+yRT+SFd2lZS+pC\ngNMsD1W/YpRPEwOWvG6b32690r2jZ47soMZo9wGzjb/7OMg0LOL+bSf63kpaSHSX\nndS5z5rexMdbBYUsLA9e+KXBdQOS+UTo7WTBEMa2R2CapHg665xsmtdVMTBQY4uD\nZlxvb3qCo5ZwKh9kG4LT6/I5IhlJH7aGhyxXFvUK+DWNmoudF8NAco9/h9iaGNj8\nq2ethFkMLs91kzk2PAcDTW9gb54h4FRWyuXpoQIDAQABAoIBABKucaRpzQorw35S\nbEUAVx8dYXUdZOlJcHtiWQ+dC6V8ljxAHj/PLyzTveyI5QO/xkObCyjIL303l2cf\nUhPu2MFaJdjVzqACXuOrLot/eSFvxjvqVidTtAZExqFRJ9mylUVAoLvhowVWmC1O\nn95fZCXxTUtxNEG1Xcc7m0rtzJKs45J+N/V9DP1edYH6USyPSWGp6wuA+KgHRnKK\nVf9GRx80JQY7nVNkL17eHoTWEwga+lwi0FEoW9Y7lDtWXYmKBWhUE+U8PGxlJf8f\n40493HDw1WRQ/aSLoS4QTp3rn7gYgeHEvfJdkkf0UMhlknlo53M09EFPdadQ4TlU\nbjqKc50CgYEA4BzEEOtIpmVdVEZNCqS7baC4crd0pqnRH/5IB3jw3bcxGn6QLvnE\ntfdUdiYrqBdss1l58BQ3KhooKeQTa9AB0Hw/Py5PJdTJNPY8cQn7ouZ2KKDcmnPG\nBY5t7yLc1QlQ5xHdwW1VhvKn+nXqhJTBgIPgtldC+KDV5z+y2XDwGUcCgYEAuQPE\nfgmVtjL0Uyyx88GZFF1fOunH3+7cepKmtH4pxhtCoHqpWmT8YAmZxaewHgHAjLYs\np1ZSe7zFYHj7C6ul7TjeLQeZD/YwD66t62wDmpe/HlB+TnBA+njbglfIsRLtXlnD\nzQkv5dTltRJ11BKBBypeeF6689rjcJIDEz9RWdcCgYAHAp9XcCSrn8wVkMVkKdb7\nDOX4IKjzdahm+ctDAJN4O/y7OW5FKebvUjdAIt2GuoTZ71iTG+7F0F+lP88jtjP4\nU4qe7VHoewl4MKOfXZKTe+YCS1XbNvfgwJ3Ltyl1OH9hWvu2yza7q+d5PCsDzqtm\n27kxuvULVeya+TEdAB1ijQKBgQCH/3r6YrVH/uCWGy6bzV1nGNOdjKc9tmkfOJmN\n54dxdixdpozCQ6U4OxZrsj3FcOhHBsqAHvX2uuYjagqvo3cOj1TRqNocX40omfCC\nMx3bD1yPPf/6TI2XECva/ggqEY2mYzmIiA5LVVmc5nrybr+lssFKneeyxN2Wq93S\n0iJMdQKBgCGHewxzoa1r8ZMD0LETNrToK423K377UCYqXfg5XMclbrjPbEC3YI1Z\nNqMtuhdBJqUnBi6tjKMF+34Xf0CUN8ncuXGO2CAYvO8PdyCixHX52ybaDjy1FtCE\n6yUXjoKNXKvUm7MWGsAYH6f4IegOetN5NvmUMFStCSkh7ixZLkN1\n-----END RSA PRIVATE KEY-----\n")

def pem.rsa.pub() -> Bytes.Bytes:
  txt("-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAofgWCuLjybRlzo0tZWJj\nNiuSfb4p4fAkd/wWJcyQoTbji9k0l8W26mPddxHmfHQp+Vaw+4qPCJrcS2mJPMEz\nP1Pt0Bm4d4QlL+yRT+SFd2lZS+pCgNMsD1W/YpRPEwOWvG6b32690r2jZ47soMZo\n9wGzjb/7OMg0LOL+bSf63kpaSHSXndS5z5rexMdbBYUsLA9e+KXBdQOS+UTo7WTB\nEMa2R2CapHg665xsmtdVMTBQY4uDZlxvb3qCo5ZwKh9kG4LT6/I5IhlJH7aGhyxX\nFvUK+DWNmoudF8NAco9/h9iaGNj8q2ethFkMLs91kzk2PAcDTW9gb54h4FRWyuXp\noQIDAQAB\n-----END PUBLIC KEY-----\n")

def pem.ec.priv() -> Bytes.Bytes:
  txt("-----BEGIN PRIVATE KEY-----\nMIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgjpsQnnGQmL+YBIff\nH1136cspYG6+0iY7X1fCE9+E9LKhRANCAAR/zc4ncPbEXUGDy+5v20t7WAczNXvp\n7xO6z248e9FURcfxRM0bvZt+hyzf7bnuufSzaV1uqQskrYpGIyiFiOWt\n-----END PRIVATE KEY-----\n")

def pem.ec.pub() -> Bytes.Bytes:
  txt("-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEf83OJ3D2xF1Bg8vub9tLe1gHMzV7\n6e8Tus9uPHvRVEXH8UTNG72bfocs3+257rn0s2ldbqkLJK2KRiMohYjlrQ==\n-----END PUBLIC KEY-----\n")

def pem.small.pub() -> Bytes.Bytes:
  txt("-----BEGIN PUBLIC KEY-----\nMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDIn5LzIy9+Ybo8wo0UVuja0SBB\nzjbFo/mxu8K63xLJG4ntbPPnTLeFYZWl364gDaCacBXYgZePMytjnfJtaXED5HLK\n2NBRw7+6IIM74GQTQUvNCxwDIVVD3G50biVmTCvVpv0OO0xL76euFA6E7HKH2HYb\nFRuCAy5DvPFXqr9g7wIDAQAB\n-----END PUBLIC KEY-----\n")

def vec.n() -> Bytes.Bytes:
  hex("a1f8160ae2e3c9b465ce8d2d656263362b927dbe29e1f02477fc1625cc90a136e38bd93497c5b6ea63dd7711e67c7429f956b0fb8a8f089adc4b69893cc1333f53edd019b87784252fec914fe4857769594bea4280d32c0f55bf62944f130396bc6e9bdf6ebdd2bda3678eeca0c668f701b38dbffb38c8342ce2fe6d27fade4a5a4874979dd4b9cf9adec4c75b05852c2c0f5ef8a5c1750392f944e8ed64c110c6b647609aa4783aeb9c6c9ad755313050638b83665c6f6f7a82a396702a1f641b82d3ebf2392219491fb686872c5716f50af8358d9a8b9d17c340728f7f87d89a18d8fcab67ad84590c2ecf759339363c07034d6f606f9e21e05456cae5e9a1")

def vec.e() -> Bytes.Bytes:
  hex("010001")

def vec.x() -> Bytes.Bytes:
  hex("7fcdce2770f6c45d4183cbee6fdb4b7b580733357be9ef13bacf6e3c7bd15445")

def vec.y() -> Bytes.Bytes:
  hex("c7f144cd1bbd9b7e872cdfedb9eeb9f4b3695d6ea90b24ad8a4623288588e5ad")

def vec.rs.sig() -> Bytes.Bytes:
  hex("702e218943e88fd11eb5d82dbf7845f34106ae1b81fff7731116add1717d83656d420afd3c96eedd73a2663e5166687b000b87226e0187ed1073f945e582adfcef16d85a798ee8c66ddb3db8975b17d09402beedd5d9d97007108db28160d5f8040ca7445762b81fbe7ff9d92e0ae76f24f25b33bbe6f44ae61eb1040acb20044d3ef9128ed40130795bd4bd3b41eecad066ab651981fde48df77f372dc38b9fafdd3befb18b5da3cc3c2eb02f9e3a41d612caad15911273a05f23b9e838faaf849d698429ef5a1e88798236c3d40e604522a544c8f27a7a2db80663d16cf7caea56de405cb2215a45b2c25566b55ac1a748a070dfc8a32a469543d019eefb47")

def vec.es.sig() -> Bytes.Bytes:
  hex("0ed1215379636c483c2f7f155807d402a3b228033af97c7e17819ac3169ea665c50a07d38c3c70e5d8f12daf084a5480a66590c5f293509a8f3f7f8a83a354d5")

def rs.in() -> Bytes.Bytes:
  txt("eyJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFtcGxlLmNvbS9pc19yb290Ijp0cnVlfQ")

def es.in() -> Bytes.Bytes:
  txt("eyJhbGciOiJFUzI1NiJ9.eyJpc3MiOiJqb2UiLA0KICJleHAiOjEzMDA4MTkzODAsDQogImh0dHA6Ly9leGFtcGxlLmNvbS9pc19yb290Ijp0cnVlfQ")

def sig.rsa(+alg: String, k: Bytes.Bytes, d: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{+kn, kb} = k
  Bytes.Bytes{+dn, db} = d
  C.rsa.sign.words(alg, kn, kb, dn, db)

def sig.ec(+alg: String, k: Bytes.Bytes, d: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{+kn, kb} = k
  Bytes.Bytes{+dn, db} = d
  C.ecdsa.sign.words(alg, kn, kb, dn, db)

def sig.run(pick: Bool, +alg: String, k: Bytes.Bytes, d: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  match pick:
    case True{}:
      sig.rsa(alg, k, d)
    case False{}:
      sig.ec(alg, k, d)

def ver.rsa(+alg: String, k: Bytes.Bytes, d: Bytes.Bytes, s: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bool>):
  Bytes.Bytes{+kn, kb} = k
  Bytes.Bytes{+dn, db} = d
  Bytes.Bytes{+sn, sb} = s
  C.rsa.verify.words(alg, kn, kb, dn, db, sn, sb)

def ver.ec(+alg: String, k: Bytes.Bytes, d: Bytes.Bytes, s: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bool>):
  Bytes.Bytes{+kn, kb} = k
  Bytes.Bytes{+dn, db} = d
  Bytes.Bytes{+sn, sb} = s
  C.ecdsa.verify.words(alg, kn, kb, dn, db, sn, sb)

def ver.run(pick: Bool, +alg: String, k: Bytes.Bytes, d: Bytes.Bytes, s: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bool>):
  match pick:
    case True{}:
      ver.rsa(alg, k, d, s)
    case False{}:
      ver.ec(alg, k, d, s)

def jwk.rsa(+alg: String, a: Bytes.Bytes, b: Bytes.Bytes, d: Bytes.Bytes, s: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bool>):
  Bytes.Bytes{+an, ab} = a
  Bytes.Bytes{+bn, bb} = b
  Bytes.Bytes{+dn, db} = d
  Bytes.Bytes{+sn, sb} = s
  C.rsa.verify.jwk.words(alg, an, ab, bn, bb, dn, db, sn, sb)

def jwk.ec(+alg: String, a: Bytes.Bytes, b: Bytes.Bytes, d: Bytes.Bytes, s: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bool>):
  Bytes.Bytes{+an, ab} = a
  Bytes.Bytes{+bn, bb} = b
  Bytes.Bytes{+dn, db} = d
  Bytes.Bytes{+sn, sb} = s
  C.ecdsa.verify.jwk.words(alg, an, ab, bn, bb, dn, db, sn, sb)

def jwk.run(pick: Bool, +alg: String, a: Bytes.Bytes, b: Bytes.Bytes, d: Bytes.Bytes, s: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bool>):
  match pick:
    case True{}:
      jwk.rsa(alg, a, b, d, s)
    case False{}:
      jwk.ec(alg, a, b, d, s)

def verify.is(+name: String, +want: Bool, r: Result<&1, &1, U32 & String, Bool>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, name ++ " failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{+b}:
      ok(Bool.not(Bool.xor(b, want)), name, Bool.show(b))

def rejects(+name: String, r: Result<&1, &1, U32 & String, Bool>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      ok(U32.is_eq(code, 22), name, U32.show(code) ++ " " ++ why)
    case Done{b}:
      IO.die(Unit, 1, name ++ " did not fail")

# ECDSA signs with a fresh nonce, so check the length and that each signature verifies, not the octets.
# Two signatures, one per verify, as each Array is used once; shaped like rnd.two.
def es.round(+name: String, r: Result<&1, &1, U32 & String, U32 & Array<U32>>, s: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, name ++ " failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{(+an, ab)}:
      match s:
        case Fail{(+code, why)}:
          IO.die(Unit, 1, name ++ " failed: " ++ U32.show(code) ++ " " ++ why)
        case Done{(+bn, bb)}:
          do IO<Unit>:
            ok(U32.is_eq(an, 64), name ++ " length", U32.show(an))
            v : Result<&1, &1, U32 & String, Bool> <- ver.run(False{}, "SHA256", pem.ec.pub(), es.in(), Bytes.Bytes{an, ab})
            verify.is(name ++ " verifies", True{}, v)
            w : Result<&1, &1, U32 & String, Bool> <- ver.run(False{}, "SHA256", pem.ec.pub(), rs.in(), Bytes.Bytes{bn, bb})
            verify.is(name ++ " other data", False{}, w)

def sigs() -> IO(Unit):
  do IO<Unit>:
    # RFC 7515 A.2: PKCS#1 v1.5 is deterministic, so the signature must match octet for octet.
    a : Result<&1, &1, U32 & String, U32 & Array<U32>> <- sig.run(True{}, "SHA256", pem.rsa.priv(), rs.in())
    got("rs256 sign pkcs8", Bytes.to_hex(vec.rs.sig()), a)
    b : Result<&1, &1, U32 & String, U32 & Array<U32>> <- sig.run(True{}, "SHA256", pem.rsa.priv.pkcs1(), rs.in())
    got("rs256 sign pkcs1", Bytes.to_hex(vec.rs.sig()), b)
    c : Result<&1, &1, U32 & String, Bool> <- ver.run(True{}, "SHA256", pem.rsa.pub(), rs.in(), vec.rs.sig())
    verify.is("rs256 verify", True{}, c)
    d : Result<&1, &1, U32 & String, Bool> <- jwk.run(True{}, "SHA256", vec.n(), vec.e(), rs.in(), vec.rs.sig())
    verify.is("rs256 verify jwk", True{}, d)
    e : Result<&1, &1, U32 & String, Bool> <- ver.run(True{}, "SHA256", pem.rsa.pub(), es.in(), vec.rs.sig())
    verify.is("rs256 other data", False{}, e)
    f : Result<&1, &1, U32 & String, Bool> <- jwk.run(True{}, "SHA256", vec.n(), vec.e(), rs.in(), hex(String.repeat("00", 256n)))
    verify.is("rs256 zero signature", False{}, f)
    g : Result<&1, &1, U32 & String, Bool> <- ver.run(True{}, "SHA256", pem.rsa.pub(), rs.in(), vec.es.sig())
    verify.is("rs256 short signature", False{}, g)
    h : Result<&1, &1, U32 & String, Bool> <- ver.run(True{}, "SHA512", pem.rsa.pub(), rs.in(), vec.rs.sig())
    verify.is("rs256 signature as rs512", False{}, h)
    # RFC 7515 A.3: the raw r || s signature verifies from the JWK and from PEM.
    i : Result<&1, &1, U32 & String, Bool> <- jwk.run(False{}, "SHA256", vec.x(), vec.y(), es.in(), vec.es.sig())
    verify.is("es256 verify jwk", True{}, i)
    j : Result<&1, &1, U32 & String, Bool> <- ver.run(False{}, "SHA256", pem.ec.pub(), es.in(), vec.es.sig())
    verify.is("es256 verify", True{}, j)
    k : Result<&1, &1, U32 & String, Bool> <- ver.run(False{}, "SHA256", pem.ec.pub(), rs.in(), vec.es.sig())
    verify.is("es256 other data", False{}, k)
    l : Result<&1, &1, U32 & String, Bool> <- ver.run(False{}, "SHA256", pem.ec.pub(), es.in(), hex(String.repeat("00", 64n)))
    verify.is("es256 zero signature", False{}, l)
    m : Result<&1, &1, U32 & String, Bool> <- ver.run(False{}, "SHA256", pem.ec.pub(), es.in(), vec.rs.sig())
    verify.is("es256 long signature", False{}, m)
    n : Result<&1, &1, U32 & String, U32 & Array<U32>> <- sig.run(False{}, "SHA256", pem.ec.priv(), es.in())
    n2 : Result<&1, &1, U32 & String, U32 & Array<U32>> <- sig.run(False{}, "SHA256", pem.ec.priv(), es.in())
    es.round("es256 sign", n, n2)
    # Wrong alg, wrong key type, weak keys, and keys of the wrong kind fail rather than verify.
    o : Result<&1, &1, U32 & String, Bool> <- ver.run(True{}, "SHA256", pem.ec.pub(), rs.in(), vec.rs.sig())
    rejects("rsa verify with ec key", o)
    p : Result<&1, &1, U32 & String, Bool> <- ver.run(False{}, "SHA256", pem.rsa.pub(), es.in(), vec.es.sig())
    rejects("ecdsa verify with rsa key", p)
    q : Result<&1, &1, U32 & String, Bool> <- ver.run(False{}, "SHA384", pem.ec.pub(), es.in(), vec.es.sig())
    rejects("ecdsa alg SHA384", q)
    r : Result<&1, &1, U32 & String, Bool> <- ver.run(True{}, "SHA1", pem.rsa.pub(), rs.in(), vec.rs.sig())
    rejects("rsa alg SHA1", r)
    s : Result<&1, &1, U32 & String, Bool> <- ver.run(True{}, "SHA256", pem.small.pub(), rs.in(), vec.rs.sig())
    rejects("rsa 1024-bit key", s)
    t : Result<&1, &1, U32 & String, Bool> <- ver.run(True{}, "SHA256", pem.rsa.priv(), rs.in(), vec.rs.sig())
    rejects("rsa verify with private pem", t)
    u : Result<&1, &1, U32 & String, Bool> <- jwk.run(True{}, "SHA256", vec.n(), hex("01"), rs.in(), vec.rs.sig())
    rejects("rsa jwk e = 1", u)
    w : Result<&1, &1, U32 & String, Bool> <- jwk.run(False{}, "SHA256", vec.x(), vec.x(), es.in(), vec.es.sig())
    rejects("ec jwk point off curve", w)
    x : Result<&1, &1, U32 & String, U32 & Array<U32>> <- sig.run(True{}, "SHA256", pem.rsa.pub(), rs.in())
    fails("rsa sign with public pem", x)
    y : Result<&1, &1, U32 & String, U32 & Array<U32>> <- sig.run(False{}, "SHA256", pem.rsa.priv(), es.in())
    fails("ecdsa sign with rsa key", y)
    z : Result<&1, &1, U32 & String, U32 & Array<U32>> <- sig.run(True{}, "SHA256", txt("not a key"), rs.in())
    fails("rsa sign with junk key", z)

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
    # RFC 7914 §11 (PBKDF2-HMAC-SHA-256) and RFC 6070 §2 case 2 (SHA-1, 4096 iterations, as SCRAM uses).
    pbkdf2("SHA256", "pbkdf2 sha256 c=1", "55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783", txt("passwd"), txt("salt"), 1, 64)
    pbkdf2("SHA256", "pbkdf2 sha256 c=80000", "4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d", txt("Password"), txt("NaCl"), 80000, 64)
    pbkdf2("SHA1", "pbkdf2 sha1 c=4096", "4b007901b765489abead49d926f721d065a429c1", txt("password"), txt("salt"), 4096, 20)
    bad.alg(txt("abc"))
    bad.kdf()
    eq("eq.ct same", True{}, txt("same mac"), txt("same mac"))
    eq("eq.ct differ", False{}, txt("same mac"), txt("same mad"))
    eq("eq.ct lengths", False{}, txt("abc"), txt("ab"))
    rnd(300)
    sigs()
    AE.run()
