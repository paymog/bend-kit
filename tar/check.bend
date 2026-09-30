import Base
import ./tar.bend as Tar
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes

def entries(xs: List<&1, Tar.Entry>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{Tar.File{name, data}, rest}:
      "F:" ++ Bytes.to_string(name) ++ ":" ++ Bytes.to_hex(data) ++ ";" ++ entries(rest)
    case Con{Tar.Dir{name}, rest}:
      "D:" ++ Bytes.to_string(name) ++ ";" ++ entries(rest)

def decoded(m: Maybe<&1, List<&1, Tar.Entry>>) -> String:
  match m:
    case None{}:
      "invalid"
    case Some{xs}:
      entries(xs)

def encoded(m: Maybe<&1, Bytes.Bytes>) -> String:
  match m:
    case None{}:
      "invalid"
    case Some{buf}:
      decoded(Tar.decode(buf))

def corrupt(m: Maybe<&1, Bytes.Bytes>) -> String:
  match m:
    case None{}:
      "invalid"
    case Some{buf}:
      decoded(Tar.decode(Bytes.set(buf, 0, 121)))

def sliced(r: Bytes.Bytes & Bytes.Bytes) -> String:
  (buf, part) = r
  decoded(Tar.decode(part))

def truncated(m: Maybe<&1, Bytes.Bytes>) -> String:
  match m:
    case None{}:
      "invalid"
    case Some{buf}:
      sliced(Bytes.slice(buf, 0, 520))

def expect.if(ok: Bool, +label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print(label ++ " ok")
    case False{}:
      IO.die(Unit, 1, label ++ " failed")

def expect(+label: String, +actual: String, +wanted: String) -> IO(Unit):
  expect.if(String.eq(actual, wanted), label)

def long_name() -> String:
  "deep/" ++ "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"


def utf_name.of(m: Maybe<&1, Bytes.Bytes>) -> Bytes.Bytes:
  match m:
    case Some{b}:
      b
    case None{}:
      Bytes.new(0)

def utf_name() -> Bytes.Bytes:
  utf_name.of(Bytes.from_hex("6ec3a9f09f9880"))

# A zero-byte local PAX header is valid and leaves the next entry unchanged.
def empty.pax() -> Bytes.Bytes:
  h = Bytes.set(Bytes.new(512), 0, 120)
  h1 = Bytes.set(h, 156, 120)
  h2 = Bytes.set(h1, 148, 48)
  h3 = Bytes.set(h2, 149, 48)
  h4 = Bytes.set(h3, 150, 48)
  h5 = Bytes.set(h4, 151, 55)
  h6 = Bytes.set(h5, 152, 54)
  h7 = Bytes.set(h6, 153, 48)
  Bytes.append(Bytes.set(h7, 155, 32), Bytes.new(1024))

def pax.header.done(r: Array<U32> & Bytes.Bytes) -> Bytes.Bytes:
  (a, h) = r
  h

def pax.header(+size: U32, name: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+n, a} = name
  pax.header.done(Tar.hdr(a, n, 420, size, 120))

def pax.archive(body: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+n, a} = body
  padding = Bytes.set(Tar.blk(Bytes.Bytes{n, a}), 511, 10)
  Bytes.append(Bytes.append(pax.header(n, Bytes.from_string("pax")), padding), Bytes.new(1024))

def file.header.of(name: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{n, a} = name
  pax.header.done(Tar.hdr(a, n, 420, 0, 48))

def file.header() -> Bytes.Bytes:
  file.header.of(Bytes.from_string("raw"))

def file.bad(h: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{n, a} = h
  spaces = Tar.put.str("        ", Bytes.poke(a, 124, 120), 148)
  Bytes.Bytes{512, Tar.hdr.ck(Tar.bsum(spaces, 0))}

def file.header.if(bad: Bool, h: Bytes.Bytes) -> Bytes.Bytes:
  match bad:
    case True{}:
      file.bad(h)
    case False{}:
      h

def pax.file(body: Bytes.Bytes, bad: Bool) -> Bytes.Bytes:
  Bytes.Bytes{+n, a} = body
  prefix = Bytes.append(pax.header(n, Bytes.from_string("pax")), Tar.blk(Bytes.Bytes{n, a}))
  Bytes.append(Bytes.append(prefix, file.header.if(bad, file.header())), Bytes.new(1024))

def main() -> IO(Unit):
  do IO<Unit>:
    expect("order and block boundary", encoded(Tar.encode([Tar.Dir{Bytes.from_string("dir/")}, Tar.File{Bytes.from_string("dir/f"), Bytes.from_string("abc")}, Tar.File{Bytes.from_string("end"), Bytes.new(512)}])), "D:dir/;F:dir/f:616263;F:end:" ++ Bytes.to_hex(Bytes.new(512)) ++ ";")
    expect("PAX path", encoded(Tar.encode([Tar.File{Bytes.from_string(long_name()), Bytes.from_string("x")}])), "F:" ++ long_name() ++ ":78;")
    expect("UTF-8 name bytes", encoded(Tar.encode([Tar.File{utf_name(), Bytes.from_string("ok")}])), "F:" ++ Bytes.to_string(utf_name()) ++ ":6f6b;")
    expect("empty PAX header", decoded(Tar.decode(empty.pax())), "")
    expect("unknown PAX body", decoded(Tar.decode(pax.archive(Bytes.from_string("4 x\n")))), "")
    expect("PAX record cannot consume padding", decoded(Tar.decode(pax.archive(Bytes.from_string("512 x=\n")))), "invalid")
    expect("PAX size zero boundary", decoded(Tar.decode(pax.file(Bytes.from_string("9 size=0\n"), False{}))), "F:raw:;")
    expect("PAX size overrides malformed header", decoded(Tar.decode(pax.file(Bytes.from_string("11 path=xy\n9 size=0\n"), True{}))), "F:xy:;")
    expect("PAX empty size", decoded(Tar.decode(pax.file(Bytes.from_string("8 size=\n"), False{}))), "invalid")
    expect("PAX size suffix", decoded(Tar.decode(pax.file(Bytes.from_string("11 size=0x\n"), False{}))), "invalid")
    expect("PAX size overflow", decoded(Tar.decode(pax.file(Bytes.from_string("19 size=4294967296\n"), False{}))), "invalid")
    expect("PAX path reset", decoded(Tar.decode(pax.file(Bytes.from_string("11 path=xy\n8 path=\n9 size=0\n"), False{}))), "F:raw:;")
    expect("checksum", corrupt(Tar.encode([Tar.File{Bytes.from_string("x"), Bytes.from_string("abc")}])), "invalid")
    expect("truncation", truncated(Tar.encode([Tar.File{Bytes.from_string("x"), Bytes.from_string("abc")}])), "invalid")
