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
| Bend | `Crypto.sha256.words` through `S.commit` | `S.Store.apply`, then `S.load` |
| C | OpenSSL 3 `SHA256` | POSIX `hsearch` |
| Rust | `sha2` 0.10.9 | `std::collections::HashMap` |
| Python | `hashlib.sha256` | `dict` |
| JavaScript | `createHash("sha256")` from `node:crypto` | `Map` |

## Results

Apple M4 Pro, macOS 26.6.2 arm64, 2026-11-02. Three runs (`python3 run.py 3 32`), median, in ms. K = 32: 1,024 files and 4 MiB. Files whose seed `(d * 31 + f * 7) & 255` is equal hold the same octets, so the store holds 1,313 distinct objects. `Nx` is the multiple of the fastest variant.

Versions: Bend 2.0.38, Apple clang 17.0.0 with OpenSSL 3.6.5, rustc 1.91.0 with sha2 0.10.9, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| commit and load | 5.0 (1.8x) | 8.9 (3.3x) | 4.4 (1.6x) | 5.9 (2.2x) | 2.7 (1.0x) | 175.8 (65.0x) |

Every program prints root `29cc4de74d186c77f13fdfc2781365c186a6823091cdf974614aebe811a53202` and `4194304` octets.

## Reading it

- The store is a list, so `put` and `get` walk it (the ponytail note on `Store` in `storage.bend`). The cost grows with the square of the object count. One run each of native Bend: K = 16 (469 objects) took 21 ms, K = 32 (1,313 objects) 175 ms, and K = 48 (2,609 objects) 708 ms. The other programs hash the same octets with the same kind of library SHA-256, so most of Bend's gap is the list store.
- Bend also copies each file between `Blob`, a word list, and `Bytes` when it encodes the object. The other programs hash their buffers in place.
- Python is fastest here because `hashlib` and `dict` run in C, and each object costs one call to each.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock. It reads K from argv, so the work cannot run before the clock starts.
- One machine, one tree shape, one thread.
- No standard or popular library writes this object format. Git's tree format differs, so a git library would print a different root. The C, Rust, Python, and JavaScript programs are the obvious loop over a library SHA-256 and a library map. They are not a second `storage`: they have no sync plan, collection, or ingress checks.
