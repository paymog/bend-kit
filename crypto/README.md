# Cryptography

`crypto.bend` uses OpenSSL 3 libcrypto from `BEND_LIBCRYPTO` or the system search paths. The C and Bun effects use the same library. Inputs and outputs are packed octets: `(len, Array<U32>)`, with four octets per word in little-endian order. The `bytes` package can convert to and from this representation.

## Authenticated encryption

`aead.seal.words(alg, klen, key, nlen, nonce, alen, aad, dlen, plaintext)` returns ciphertext followed by a 16-octet authentication tag. `aead.open.words` takes that combined value and returns plaintext only after authentication succeeds. Both accept `"AES-256-GCM"` and `"CHACHA20-POLY1305"`. Both require a 32-octet key and 12-octet nonce; the AAD and plaintext may be empty. `open` requires at least a 16-octet tag. An invalid input, unsupported algorithm or failed authentication returns `Fail` with `EINVAL` (22); an unavailable OpenSSL 3 library returns `ENOENT` (2). Input lengths must fit OpenSSL's signed 32-bit API. No unauthenticated plaintext is returned on failure.

**Never reuse a key and nonce pair for encryption.** Choose a unique nonce for every seal under a key. Generate keys with `random.words` or derive them securely; do not substitute a password directly for a key. The caller is responsible for storing and transmitting the nonce alongside the ciphertext and for supplying exactly the same AAD on open. These effects do not generate or persist nonces.

`aead_check.bend` checks NIST AES-256-GCM and [RFC 8439 §2.8.2](https://www.rfc-editor.org/rfc/rfc8439#section-2.8.2) ChaCha20-Poly1305 vectors in both effects, including ciphertext, tag, nonce and AAD tampering. Run `../scripts/check.sh crypto`, then `bend aead_check.bend -o /tmp/aead-check && /tmp/aead-check` and `bend aead_check.bend -o /tmp/aead-check.js && bun /tmp/aead-check.js`. The cross-language throughput bench is in `bench/aead/`.
