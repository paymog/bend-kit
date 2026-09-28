# Hashes, HMAC, HKDF, and secure random bytes through OpenSSL 3 libcrypto. Source: https://github.com/paymog/bend-kit/tree/main/crypto
import Base

# Bytes travel as (len, words): len octets, four to a U32 word, low byte first, as Wire.recv.words gives them.
# The libcrypto effects fail with ENOENT when libcrypto.3 does not load; set BEND_LIBCRYPTO to its path.

# alg is an OpenSSL digest name, such as "SHA256" or "SHA3-256". Fails with EINVAL for an unknown name.
def digest.words(alg: String, len: U32, words: Array<U32>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/crypto.c"
  import "./effs/crypto.js"

def sha256.words(len: U32, words: Array<U32>) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  digest.words("SHA256", len, words)

def sha512.words(len: U32, words: Array<U32>) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  digest.words("SHA512", len, words)

# Legacy: SHA-1 is broken for collisions. Use it only where a protocol needs it, such as the WebSocket handshake.
def sha1.words(len: U32, words: Array<U32>) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  digest.words("SHA1", len, words)

# HMAC (RFC 2104) of data under key, with the digest alg.
def hmac.words(alg: String, klen: U32, key: Array<U32>, dlen: U32, data: Array<U32>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/crypto.c"
  import "./effs/crypto.js"

# HKDF (RFC 5869): n octets from ikm, salt, and info. Fails with EINVAL when n is 0 or more than 255 digest lengths.
def hkdf.words(alg: String, slen: U32, salt: Array<U32>, klen: U32, ikm: Array<U32>, ilen: U32, info: Array<U32>, n: U32) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/crypto.c"
  import "./effs/crypto.js"

# PBKDF2 (RFC 8018 §5.2) with HMAC over alg: n octets from pass and salt. Fails with EINVAL when iters or n is 0.
def pbkdf2.words(alg: String, plen: U32, pass: Array<U32>, slen: U32, salt: Array<U32>, iters: U32, n: U32) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/crypto.c"
  import "./effs/crypto.js"

# n octets from the OS secure random source (getentropy, crypto.getRandomValues). Needs no libcrypto.
def random.words(n: U32) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/crypto.c"
  import "./effs/crypto.js"

# Equal octets, in time that depends only on the lengths. Use it to compare MACs.
def eq.ct.words(alen: U32, a: Array<U32>, blen: U32, b: Array<U32>) -> IO(Bool):
  import "./effs/crypto.c"
  import "./effs/crypto.js"
