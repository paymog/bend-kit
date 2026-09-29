# AEAD benchmark: 4,096 chained seals of 4 KiB with AES-256-GCM and ChaCha20-Poly1305 (see README.md).
import Base
import ../../../time/time.bend as Time
import ../../crypto.bend as C
import ../../../bytes/bytes.bend as Bytes

def N() -> Nat:
  4096n

def M() -> U32:
  4096

# 32 octets of 0x42. An Array is not copyable and seal takes it, so each seal builds its own key.
def key() -> Array<U32>:
  Array.new(U32, 3n, 1111638594)

# 12 octets: i little-endian, then 8 zeros, so no two seals share a nonce.
def nonce(+i: U32) -> Array<U32>:
  Array.set(U32, Array.new(U32, 2n, 0), 0, i)

# Seal i encrypts the first M octets of seal i-1's output, its ciphertext without the tag. No AAD.
def loop(n: Nat, +alg: String, +i: U32, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  match n:
    case 0n:
      IO.pure(Result<&1, &1, U32 & String, U32 & Array<U32>>, r)
    case 1n+p:
      match r:
        case Fail{e}:
          IO.pure(Result<&1, &1, U32 & String, U32 & Array<U32>>, Fail{e})
        case Done{(+len, buf)}:
          do IO<Result<&1, &1, U32 & String, U32 & Array<U32>>>:
            s : Result<&1, &1, U32 & String, U32 & Array<U32>> <- C.aead.seal.words(alg, 32, key(), 12, nonce(i), 0, Array.new(U32, 0n, 0), M(), buf)
            loop(p, alg, (i + 1 : U32), s)

def lap(+op: String, t0: Time.Duration, t1: Time.Duration, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, op ++ " failed: " ++ why)
    case Done{(+len, buf)}:
      IO.print(op ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ Bytes.to_hex(Bytes.Bytes{len, buf}))

# Checksum: SHA-256 of the last seal's output (ciphertext and tag), taken after the timer stops.
def report(+op: String, t0: Time.Duration, t1: Time.Duration, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, op ++ " failed: " ++ why)
    case Done{(+len, buf)}:
      do IO<Unit>:
        h : Result<&1, &1, U32 & String, U32 & Array<U32>> <- C.sha256.words(len, buf)
        lap(op, t0, t1, h)

def run(+op: String, +alg: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- loop(N(), alg, 0, Done{(M(), Bytes.alloc(M()))})
    t1 : Time.Duration <- Time.mono()
    report(op, t0, t1, r)

def main() -> IO(Unit):
  do IO<Unit>:
    run("aes-256-gcm", "AES-256-GCM")
    run("chacha20-poly1305", "CHACHA20-POLY1305")
