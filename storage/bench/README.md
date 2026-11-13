# Storage benchmark

This times the hot path of a content-addressed store: commit an artifact tree (encode every object and take its SHA-256), put the objects in a store, and load the root back. It compares `storage` with the obvious loop over a standard SHA-256 and a standard map in C, Rust, Python, and JavaScript.

## Run

Run these commands from `storage/bench/`.

```sh
python3 run.py          # 3 runs per variant, median, K = 16
python3 run.py 3 32     # 3 runs, K = 32
```

You need `bend`, `clang` with OpenSSL 3 from Homebrew (`brew install openssl@3`), `cargo`, `bun`, `node`, and `python3`. Cargo fetches `sha2` 0.10. Binaries go to `out/`, which git ignores. The script exits non-zero if a build fails, a program prints no result, or two programs disagree on the root digest or the octet count.

## Input

The tree has K directories `d00`, `d01`, … at the top. Each directory holds K files `f00`, `f01`, … of 4096 octets. Octet `j` of file `(d, f)` is `(d * 31 + f * 7 + j) & 255`. Each program builds the tree before the timer starts.

The timed region encodes every object in the format of [../README.md](../README.md#encoding), takes its SHA-256, puts it in a store keyed by the hex digest (the first object under a digest stays), and then walks the store from the root and counts the file octets. Each program prints the root digest and that count.

| language | digest | store |
|---|---|---|
| Bend | `Crypto.sha256.words` through `S.commit` | `S.Index.of`, then `S.Index.load` |
| C | OpenSSL 3 `SHA256` | POSIX `hsearch` |
| Rust | `sha2` 0.10.9 | `std::collections::HashMap` |
| Python | `hashlib.sha256` | `dict` |
| JavaScript | `createHash("sha256")` from `node:crypto` | `Map` |

## Results

Apple M4 Pro, macOS 26.7.2 arm64, 2026-11-13. Three runs (`python3 run.py 3 32`), median, in ms. K = 32: 1,024 files and 4 MiB. Files whose seed `(d * 31 + f * 7) & 255` is equal hold the same octets, so the store holds 1,313 distinct objects. `Nx` is the multiple of the fastest variant.

Versions: Bend 2.0.38, Apple clang 21.0.0 with OpenSSL 3.6.5, rustc 1.91.0 with sha2 0.10.9, Bun 1.4.4, Node 24.0.1, Python 3.14.6.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| commit and load | 5.1 (1.8x) | 9.2 (3.2x) | 4.0 (1.4x) | 6.1 (2.1x) | 2.9 (1.0x) | 50.8 (17.8x) |

Every program prints root `29cc4de74d186c77f13fdfc2781365c186a6823091cdf974614aebe811a53202` and `4194304` octets.

## Reading it

- The store is an ordered map keyed by digest (`S.Index`), so `put` and `get` take O(log n) comparisons. One run each of native Bend: K = 16 (469 objects) took 14 ms, K = 32 (1,313 objects) 57 ms, and K = 48 (2,609 objects) 132 ms. The list store of storage 0.1.0.0 took 21, 175, and 708 ms on the same inputs.
- Bend copies each file between `Blob`, a word list, and `Bytes` when it encodes the object, and each map step compares two 64-character digest `String`s. The other programs hash their buffers in place and hash each digest once per lookup. This bench does not split the remaining gap between these costs.
- Python is fastest here because `hashlib` and `dict` run in C, and each object costs one call to each.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock. It reads K from argv, so the work cannot run before the clock starts.
- One machine, one tree shape, one thread.
- No standard or popular library writes this object format. Git's tree format differs, so a git library would print a different root. The C, Rust, Python, and JavaScript programs are the obvious loop over a library SHA-256 and a library map. They are not a second `storage`: they have no sync plan, collection, or ingress checks.
