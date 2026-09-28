# Crypto benchmark

This times one SHA-256 and one PBKDF2-HMAC-SHA-256 of fixed inputs in Bend, C, Rust, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `cargo`, `bun`, `node`, `python3`, and OpenSSL 3. `run.py` builds C against `/opt/homebrew/opt/openssl@3`; set `OPENSSL_PREFIX` for another install. The binaries go to `out/`, which git ignores. The run takes about seven seconds. It exits non-zero if a build fails or if two languages print different outputs.

## Input

**sha256**: **N = 16,777,216** zero bytes (16 MiB), made in memory before the timer starts. The digest does not depend on the content, so zeros keep every program to one line of setup.

**pbkdf2**: password `password`, salt `salt`, **100,000** iterations, 32 output octets.

Each timed op is one call:

- **Bend**: `Crypto.sha256.words`, which calls `EVP_Q_digest` in libcrypto, and `Crypto.pbkdf2.words`, which calls `PKCS5_PBKDF2_HMAC`. The times include the copy from Bend words to octets.
- **C**: `EVP_Digest` and `PKCS5_PBKDF2_HMAC` in OpenSSL 3 libcrypto. The C standard library has no hashes.
- **Rust**: `Sha256::digest` from the `sha2` crate and `pbkdf2_hmac::<Sha256>` from the `pbkdf2` crate, default features. The Rust standard library has no hashes.
- **Bun and Node**: `createHash("sha256")` and `pbkdf2Sync` from `node:crypto`.
- **Python**: `hashlib.sha256` and `hashlib.pbkdf2_hmac`.

Each program prints the hex output of each op as its checksum. Expected:

- sha256: **080acf35a507ac9849cfcba47dc2ad83e01b75663a516279c8b9d243b719643e**
- pbkdf2: **0394a2ede332c9a13eb82e9b24631604c31df978b4e2f0fbd2c549944f9d79a5**

Bend peak RSS was about **38 MB**.

## Results

M4 Pro, macOS 26.6.2, arm64, 2026-09-27. Median of three runs (`python3 run.py`). Times are in ms.

| variant | sha256 ms | MB/s | vs fastest | pbkdf2 ms | vs fastest |
|---:|---:|---:|---:|---:|---:|
| C | 7.3 | 2,285 | 1.3x | 8.5 | 1.3x |
| Rust | 35.1 | 478 | 6.1x | 23.9 | 3.8x |
| Bun | 5.9 | 2,829 | 1.0x | 6.3 | 1.0x |
| Node | 6.6 | 2,556 | 1.1x | 14.1 | 2.2x |
| Python | 5.8 | 2,902 | 1.0x | 8.1 | 1.3x |
| Bend | 20.6 | 814 | 3.6x | 8.3 | 1.3x |

C, Bun, Node, Python, and Bend all run OpenSSL's SHA-256 and PBKDF2, so they differ only in setup. Bend's extra sha256 time is the copy of 16 MiB from words to octets; the pbkdf2 inputs are small, so Bend matches C there. Rust's `sha2` and `pbkdf2` are their own implementations, not OpenSSL's.

Versions: Bend 2.0.32, OpenSSL 3.6.3, Apple clang 17.0.0, Rust 1.91.0 (`sha2` 0.10.9, `pbkdf2` 0.12.2), Bun 1.3.14, Node 24.0.1, Python 3.14.6.
