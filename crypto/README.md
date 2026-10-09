# Cryptography

```bend
import bend-kit-crypto@0.2.2.1/crypto.bend as Crypto
```

`oauth2` and `sigv4` import `bend-kit-crypto@0.1.1.0`. `jwt` and `webhooks` import `0.2.0.0`. `multipart` and `websocket` import `0.1.0.0`. A digest from one version is not a value of another. Set `BEND_LIBCRYPTO` when `libcrypto.3` is not on the default path. `random.words` uses the OS generator and does not load libcrypto.


`crypto.bend` uses OpenSSL 3 libcrypto from `BEND_LIBCRYPTO` or the system search paths. The C and Bun effects use the same library. Inputs and outputs are packed octets: `(len, Array<U32>)`, with four octets per word in little-endian order. The `bytes` package can convert to and from this representation.

## Authenticated encryption

`aead.seal.words(alg, klen, key, nlen, nonce, alen, aad, dlen, plaintext)` returns ciphertext followed by a 16-octet authentication tag. `aead.open.words` takes that combined value and returns plaintext only after authentication succeeds. Both accept `"AES-256-GCM"` and `"CHACHA20-POLY1305"`. Both require a 32-octet key and 12-octet nonce; the AAD and plaintext may be empty. `open` requires at least a 16-octet tag. An invalid input, unsupported algorithm or failed authentication returns `Fail` with `EINVAL` (22); an unavailable OpenSSL 3 library returns `ENOENT` (2). Input lengths must fit OpenSSL's signed 32-bit API. No unauthenticated plaintext is returned on failure.

**Never reuse a key and nonce pair for encryption.** Choose a unique nonce for every seal under a key. Generate keys with `random.words` or derive them securely; do not substitute a password directly for a key. The caller is responsible for storing and transmitting the nonce alongside the ciphertext and for supplying exactly the same AAD on open. These effects do not generate or persist nonces.

`aead_check.bend` checks NIST AES-256-GCM and [RFC 8439 §2.8.2](https://www.rfc-editor.org/rfc/rfc8439#section-2.8.2) ChaCha20-Poly1305 vectors in both effects, including ciphertext, tag, nonce and AAD tampering. Run `../scripts/check.sh crypto`, then `bend aead_check.bend -o /tmp/aead-check && /tmp/aead-check` and `bend aead_check.bend -o /tmp/aead-check.js && bun /tmp/aead-check.js`. The cross-language throughput bench is in `bench/aead/`.

## Password key derivation

`scrypt.words(plen, password, slen, salt, N, r, p, maxmem, n)` derives `n` octets using [RFC 7914 scrypt](https://www.rfc-editor.org/rfc/rfc7914). `N` must be a power of two greater than one; `r`, `p` and `n` must be positive. `maxmem` is a required caller-supplied byte limit for the workspace **and output**. The effect rejects requests when `128 * r * (N + p + 2) + n` exceeds that limit, before deriving or allocating the output. OpenSSL also enforces `maxmem` internally. Invalid or over-budget requests return `Fail` with `EINVAL` (22); unavailable libcrypto returns `ENOENT` (2). Password and salt are arbitrary octets, including empty values for RFC test vectors.

Generate a fresh random salt for each password and store it with `N`, `r`, `p` and the derived key for later verification. Set costs and the memory limit from your application's security and latency budget; the test vectors use small costs and are not password-storage recommendations. Run `../scripts/check.sh crypto`, then check both lanes with `scrypt_check.bend`; `bench/scrypt/` compares OpenSSL, Python and Bend.
