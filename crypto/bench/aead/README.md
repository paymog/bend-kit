# AEAD benchmark

This times 4,096 AES-256-GCM seals and 4,096 ChaCha20-Poly1305 seals of 4 KiB each in Bend, C, and Node.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `node`, `python3`, and OpenSSL 3. `run.py` builds C against `/opt/homebrew/opt/openssl@3`; set `OPENSSL_PREFIX` for another install. It builds Bend once, natively. The binaries go to `out/`, which git ignores. It exits non-zero if a build or run fails, or if two languages print different outputs.

## Input

Per algorithm: **N = 4,096** seals of **M = 4,096** octets (16 MiB in all), no AAD.

- Key: 32 octets of `0x42`, the same for every seal.
- Nonce for seal i (i = 0 to 4,095): i as 4 octets little-endian, then 8 zero octets. No two seals share a (key, nonce) pair; reusing one breaks both ciphers.
- Plaintext: seal 0 takes 4,096 zero octets. Seal i takes the first 4,096 octets of seal i-1's output, its ciphertext without the 16-octet tag. The chain makes each output depend on every seal before it.

Each timed op is the whole chain of 4,096 seals. The key, nonce, and first plaintext are made before the timer starts, except in Bend, which builds each seal's key and nonce inside the loop because a Bend array is not copyable.

- **Bend**: `Crypto.aead.seal.words`, which per seal fetches the cipher, makes a context, and runs `EVP_CipherInit_ex2`, `EVP_CipherUpdate`, `EVP_CipherFinal_ex`, and `EVP_CTRL_AEAD_GET_TAG` in libcrypto. The times include the copies between Bend words and octets.
- **C**: `EVP_EncryptInit_ex2`, `EVP_EncryptUpdate`, `EVP_EncryptFinal_ex`, and `EVP_CTRL_AEAD_GET_TAG` in OpenSSL 3 libcrypto, with one cipher and one context made once and reused across seals.
- **Node**: `createCipheriv` with `authTagLength: 16`, then `update`, `final`, and `getAuthTag` from `node:crypto`, per seal.

Each program prints, as its checksum, the SHA-256 of the last seal's output (ciphertext and tag), taken after the timer stops. Expected:

- aes-256-gcm: **0f82c061410d110d94cfe56cc2b70443f5816cadb69c92e6e55e25bb6dc13992**
- chacha20-poly1305: **bd50c4d9d7d7c46a3db4e63040dd081e2a28755384af9d674fb063dc96a9f834**

## Results

Apple M4 Pro, macOS 26.6.2, arm64, 2026-09-29. Median of three runs (`python3 run.py`). Times are in ms.

| variant | aes-256-gcm ms | MB/s | vs fastest | chacha20-poly1305 ms | MB/s | vs fastest |
|---:|---:|---:|---:|---:|---:|---:|
| C | 2.7 | 6,302 | 1.0x | 9.3 | 1,802 | 1.0x |
| Node | 14.3 | 1,174 | 5.4x | 16.1 | 1,044 | 1.7x |
| Bend | 43.5 | 386 | 16.3x | 40.7 | 412 | 4.4x |

Versions: Bend 2.0.32, OpenSSL 3.6.4 (`/opt/homebrew/opt/openssl@3`), Apple clang 17.0.0, Node 24.0.1.
