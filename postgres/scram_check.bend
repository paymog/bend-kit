import Base
import ./scram.bend as Scram

# SCRAM-SHA-256 on the native runtime through libcrypto: the RFC 7677 §3 example
# (user "user", password "pencil"), then each rejection of a bad server message.

def ok(good: Bool, +name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, name)

def die(+what: String, e: U32 & String) -> IO(Unit):
  (+code, why) = e
  IO.die(Unit, 1, what ++ ": " ++ U32.show(code) ++ " " ++ why)

def cnonce() -> String:
  "rOprNGfwEbeRWgbNEkqO"

def sfirst() -> String:
  "r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096"

def cfinal() -> String:
  "c=biws,r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,p=dHzbZapWIk4jUhN+Ute9ytag9zjfMHgsqmmiz7AndVQ="

def sfinal() -> String:
  "v=6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4="

def state(p: Scram.First & String) -> Scram.First:
  (st, msg) = p
  st

def message(p: Scram.First & String) -> String:
  (st, msg) = p
  msg

def rfc() -> Scram.First:
  state(Scram.first.with("user", cnonce()))

def unit.is(r: Result<&1, &1, U32 & String, Unit>, +code: U32, +name: String) -> IO(Unit):
  match r:
    case Done{u}:
      ok(U32.is_eq(code, 0), name)
    case Fail{(+c, why)}:
      ok(U32.is_eq(c, code), name ++ " (" ++ why ++ ")")

def fails(r: Result<&1, &1, U32 & String, Scram.Final & String>, +code: U32, +name: String) -> IO(Unit):
  match r:
    case Done{x}:
      IO.die(Unit, 1, name ++ ": accepted")
    case Fail{(+c, why)}:
      ok(U32.is_eq(c, code), name ++ " (" ++ why ++ ")")

def reject(+sf: String, +code: U32, +name: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, Scram.Final & String> <- Scram.respond(rfc(), sf, "pencil")
    fails(r, code, name)

def finals(+fin: Scram.Final) -> IO(Unit):
  do IO<Unit>:
    a : Result<&1, &1, U32 & String, Unit> <- Scram.verify(fin, sfinal())
    unit.is(a, 0, "RFC 7677 server-final verifies")
    b : Result<&1, &1, U32 & String, Unit> <- Scram.verify(fin, sfinal() ++ ",x=ext")
    unit.is(b, 0, "server-final extension ignored")
    c : Result<&1, &1, U32 & String, Unit> <- Scram.verify(fin, "v=7rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4=")
    unit.is(c, 13, "wrong server signature")
    d : Result<&1, &1, U32 & String, Unit> <- Scram.verify(fin, "v=6rriTRBi23WpRRAA")
    unit.is(d, 13, "short server signature")
    e : Result<&1, &1, U32 & String, Unit> <- Scram.verify(fin, "e=invalid-proof")
    unit.is(e, 13, "server error reply")
    f : Result<&1, &1, U32 & String, Unit> <- Scram.verify(fin, "v=!!!!")
    unit.is(f, 22, "server signature not base64")
    g : Result<&1, &1, U32 & String, Unit> <- Scram.verify(fin, "")
    unit.is(g, 22, "empty server-final")

def responded(r: Result<&1, &1, U32 & String, Scram.Final & String>) -> IO(Unit):
  match r:
    case Fail{e}:
      die("respond", e)
    case Done{(+fin, +msg)}:
      do IO<Unit>:
        ok(String.eq(msg, cfinal()), "RFC 7677 client-final-message")
        finals(fin)

def fresh(r: Result<&1, &1, U32 & String, Scram.First & String>) -> IO(Unit):
  match r:
    case Fail{e}:
      die("first", e)
    case Done{(st, +msg)}:
      ok(Nat.is_eq(String.length(msg), 36n), "random client-first " ++ msg)

def main() -> IO(Unit):
  +msg = message(Scram.first.with("user", cnonce()))
  +esc = message(Scram.first.with("a=b,c", "x"))
  do IO<Unit>:
    ok(String.eq(msg, "n,,n=user,r=rOprNGfwEbeRWgbNEkqO"), "RFC 7677 client-first-message")
    ok(String.eq(esc, "n,,n=a=3Db=2Cc,r=x"), "saslname escapes = and ,")
    f : Result<&1, &1, U32 & String, Scram.First & String> <- Scram.first("user")
    fresh(f)
    r : Result<&1, &1, U32 & String, Scram.Final & String> <- Scram.respond(rfc(), sfirst(), "pencil")
    responded(r)
    reject("r=rOprNGfwEbeRWgbNEkqO,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096", 22, "server nonce equal to client nonce")
    reject("r=XOprNGfwEbeRWgbNEkqO%hv,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096", 22, "server nonce with another prefix")
    reject("r=rOprNGfwEbeRWgbNEkqO\u{7f},s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096", 22, "server nonce not printable")
    reject("r=rOprNGfwEbeRWgbNEkqO%hv,s=W22ZaJ0SNY7soEsUEjb6gQ=,i=4096", 22, "salt not base64")
    reject("r=rOprNGfwEbeRWgbNEkqO%hv,s=,i=4096", 22, "empty salt")
    reject("r=rOprNGfwEbeRWgbNEkqO%hv,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=0", 22, "zero iterations")
    reject("r=rOprNGfwEbeRWgbNEkqO%hv,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4x", 22, "iterations not decimal")
    reject("r=rOprNGfwEbeRWgbNEkqO%hv,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4294967296", 22, "iterations past U32")
    reject("r=rOprNGfwEbeRWgbNEkqO%hv,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=", 22, "empty iterations")
    reject("m=ext,r=rOprNGfwEbeRWgbNEkqO%hv,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096", 22, "mandatory extension")
    reject("r=rOprNGfwEbeRWgbNEkqO%hv,i=4096", 22, "missing salt")
    reject("e=other-error", 22, "server-first error")
