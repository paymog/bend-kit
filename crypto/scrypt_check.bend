import Base
import ./crypto.bend as C
import ../bytes/bytes.bend as Bytes

def derive(pw: Bytes.Bytes, salt: Bytes.Bytes, N: U32, r: U32, p: U32, budget: U32, n: U32) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{pn, pb} = pw
  Bytes.Bytes{sn, sb} = salt
  C.scrypt.words(pn, pb, sn, sb, N, r, p, budget, n)

def check.hex(ok: Bool, name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, name ++ " wrong derived key")

def check.code(ok: Bool, name: String, code: U32) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, name ++ " returned " ++ U32.show(code))

def matches(name: String, want: String, res: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match res:
    case Fail{(code, why)}:
      IO.die(Unit, 1, name ++ " failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{(len, words)}:
      check.hex(String.eq(Bytes.to_hex(Bytes.Bytes{len, words}), want), name)

def rejects(name: String, res: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match res:
    case Fail{(+code, why)}:
      check.code(U32.is_eq(code, 22), name, code)
    case Done{(len, words)}:
      IO.die(Unit, 1, name ++ " accepted invalid parameters")

def compare(a: Result<&1, &1, U32 & String, U32 & Array<U32>>,
  b: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match a:
    case Fail{error}:
      IO.die(Unit, 1, "first repeated scrypt failed")
    case Done{(an, aw)}:
      match b:
        case Fail{error}:
          IO.die(Unit, 1, "second repeated scrypt failed")
        case Done{(bn, bw)}:
          check.hex(String.eq(Bytes.to_hex(Bytes.Bytes{an, aw}), Bytes.to_hex(Bytes.Bytes{bn, bw})), "repeated input")

def run() -> IO(Unit):
  do IO<Unit>:
    # RFC 7914 section 12 cases 1–3. Case 4 needs over 1 GiB, so it is not run here.
    first : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(Bytes.from_string(""), Bytes.from_string(""), 16, 1, 1, 1048576, 64)
    matches("RFC 7914 empty", "77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906", first)
    second : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(Bytes.from_string("password"), Bytes.from_string("NaCl"), 1024, 8, 16, 16777216, 64)
    matches("RFC 7914 password", "fdbabe1c9d3472007856e7190d01e9fe7c6ad7cbc8237830e77376634b3731622eaf30d92e22a3886ff109279d9830dac727afb94a83ee6d8360cbdfa2cc0640", second)
    third : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(Bytes.from_string("pleaseletmein"), Bytes.from_string("SodiumChloride"), 16384, 8, 1, 67108864, 64)
    matches("RFC 7914 memory hard", "7023bdcb3afd7348461c06cd81fd38ebfda8fbba904f8e3ea9b543f6545da1f2d5432955613f0fcf62d49705242a9af9e61e85dc0d651e40dfcf017b45575887", third)
    left : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(Bytes.from_string("password"), Bytes.from_string("NaCl"), 1024, 8, 1, 16777216, 32)
    right : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(Bytes.from_string("password"), Bytes.from_string("NaCl"), 1024, 8, 1, 16777216, 32)
    compare(left, right)
    bad_n : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(Bytes.from_string("pw"), Bytes.from_string("salt"), 15, 8, 1, 1048576, 32)
    rejects("N not power of two", bad_n)
    small_n : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(Bytes.from_string("pw"), Bytes.from_string("salt"), 1, 8, 1, 1048576, 32)
    rejects("N below two", small_n)
    bad_r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(Bytes.from_string("pw"), Bytes.from_string("salt"), 16, 0, 1, 1048576, 32)
    rejects("r zero", bad_r)
    bad_p : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(Bytes.from_string("pw"), Bytes.from_string("salt"), 16, 8, 0, 1048576, 32)
    rejects("p zero", bad_p)
    bad_out : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(Bytes.from_string("pw"), Bytes.from_string("salt"), 16, 8, 1, 1048576, 0)
    rejects("output zero", bad_out)
    no_limit : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(Bytes.from_string("pw"), Bytes.from_string("salt"), 16, 8, 1, 0, 32)
    rejects("missing memory limit", no_limit)
    too_small : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(Bytes.from_string("pw"), Bytes.from_string("salt"), 16384, 8, 1, 4096, 32)
    rejects("memory budget exceeded", too_small)
    over_output : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(Bytes.from_string("pw"), Bytes.from_string("salt"), 16, 1, 1, 4096, 4096)
    rejects("output exceeds budget", over_output)
    overflow : Result<&1, &1, U32 & String, U32 & Array<U32>> <- derive(Bytes.from_string("pw"), Bytes.from_string("salt"), 2147483648, 2147483648, 2147483648, 4096, 32)
    rejects("cost multiplication overflow", overflow)
    malformed : Result<&1, &1, U32 & String, U32 & Array<U32>> <- C.scrypt.words(9, Array.new(U32, 1n, 0), 0, Array.new(U32, 0n, 0), 16, 1, 1, 1048576, 32)
    rejects("password words shorter than length", malformed)

def main() -> IO(Unit):
  run()
