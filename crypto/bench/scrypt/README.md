# scrypt benchmark

This times one scrypt derivation of a 32-octet key in Bend, C, Python, and Node.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `node`, `python3`, and OpenSSL 3. `run.py` builds C against `/opt/homebrew/opt/openssl@3`; set `OPENSSL_PREFIX` for another install. It builds Bend once, natively. The binaries go to `out/`, which git ignores. It runs one process at a time, so only one 16 MiB scrypt workspace is live. It exits non-zero if a build or run fails, or if any run prints a key other than the expected one.

## Input

RFC 7914 §12 test vector 3, cut to 32 octets:

- Password: `pleaseletmein` (13 octets). Salt: `SodiumChloride` (14 octets).
- **N = 16,384**, **r = 8**, **p = 1**, so the workspace is 128 · r · N = 16 MiB.
- maxmem: 64 MiB (67,108,864 octets). Output: 32 octets.

Each timed op is one derivation. The password and salt are made before the timer starts.

- **Bend**: `Crypto.scrypt.words`, which calls `EVP_PBE_scrypt` in libcrypto. The time includes the copies between Bend words and octets.
- **C**: `EVP_PBE_scrypt` in OpenSSL 3 libcrypto.
- **Python**: `hashlib.scrypt`, which also calls OpenSSL's `EVP_PBE_scrypt`.
- **Node**: `scryptSync` from `node:crypto`, which uses the OpenSSL build bundled with Node.

Each program prints the derived key in hex as its checksum. Expected, the first 32 octets of the RFC 7914 vector:

**7023bdcb3afd7348461c06cd81fd38ebfda8fbba904f8e3ea9b543f6545da1f2**

## Results

Apple M4 Pro (arm64), macOS 26.6.2, 2026-09-28 CDT. Three runs per variant; median, serial execution.

| variant | scrypt ms | vs fastest |
|---:|---:|---:|
| C | 27.7 | 1.4x |
| Python | 23.6 | 1.2x |
| Node | 19.9 | 1.0x |
| Bend | 26.3 | 1.3x |

Versions: Bend 2.0.32; Apple clang 17.0.0; Python 3.14.6; Node 24.0.1; Homebrew OpenSSL 3.6.4 (C and Bend), system OpenSSL 4.0.2 (`openssl version`). Each variant produced the expected checksum.
