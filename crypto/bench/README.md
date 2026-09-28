# Crypto benchmark

This times one SHA-256 of a fixed input in Bend, C, Rust, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `cargo`, `bun`, `node`, `python3`, and OpenSSL 3. `run.py` builds C against `/opt/homebrew/opt/openssl@3`; set `OPENSSL_PREFIX` for another install. The binaries go to `out/`, which git ignores. The run takes about five seconds. It exits non-zero if a build fails or if two languages print different digests.

## Input

**N = 16,777,216** zero bytes (16 MiB), made in memory before the timer starts. The digest does not depend on the content, so zeros keep every program to one line of setup.

The timed op is one SHA-256 of the whole input:

- **Bend**: `Crypto.sha256.words`, which calls `EVP_Q_digest` in libcrypto. The time includes the copy from Bend words to octets.
- **C**: `EVP_Digest` in OpenSSL 3 libcrypto. The C standard library has no hashes.
- **Rust**: `Sha256::digest` from the `sha2` crate, default features. The Rust standard library has no hashes.
- **Bun and Node**: `createHash("sha256")` from `node:crypto`.
- **Python**: `hashlib.sha256`.

Each program prints the hex digest as its checksum. Expected: **080acf35a507ac9849cfcba47dc2ad83e01b75663a516279c8b9d243b719643e**.

Bend peak RSS was about **38 MB**.

## Results

M4 Pro, macOS 26.6.2, arm64, 2026-09-27. Median of three runs (`python3 run.py`). Times are in ms.

| variant | sha256 ms | MB/s | vs fastest |
|---:|---:|---:|---:|
| C | 7.0 | 2,388 | 1.1x |
| Rust | 30.2 | 556 | 4.8x |
| Bun | 6.3 | 2,679 | 1.0x |
| Node | 6.6 | 2,538 | 1.1x |
| Python | 6.4 | 2,632 | 1.0x |
| Bend | 13.0 | 1,290 | 2.1x |

C, Bun, Node, Python, and Bend all hash in OpenSSL's SHA-256, so they differ only in setup. Bend's extra time is the copy from words to octets. Rust's `sha2` is its own implementation, not OpenSSL's.

Versions: Bend 2.0.31, OpenSSL 3.6.3, Apple clang 17.0.0, Rust 1.91.0 (`sha2` 0.10.9), Bun 1.3.14, Node 24.0.1, Python 3.14.6.
