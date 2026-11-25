# Storage benchmark

This times the hot path of a content-addressed store: commit an artifact tree (encode every object and take its SHA-256), put the objects in a store, and load the root back. It compares `storage` with the obvious loop over a standard SHA-256 and a standard map in C, Rust, Python, and JavaScript.

## HTTP connection reuse

`http.bend` runs the port-0 loopback checks and times the first sync. The fixed closure has two directory entries that share one 14-byte file, plus the end object. The destination already has the file, so three GETs fetch the two entries and the end. The timer includes local ingress checks and object writes, but not fixture setup or server startup.

From `storage/bench/`:

```sh
bend http.bend -o out/http
for run in 1 2 3; do out/http; done
```

Apple M4 Pro, macOS arm64, Bend 2.0.40, 2026-11-24. Three native runs:

| client | GETs | connections | elapsed ms | median ms |
|---|---:|---:|---|---:|
| before, `origin/main` at `1b7aaae` | 3 | 3 | 5.952, 4.608, 4.205 | 4.608 |
| pooled walk | 3 | 1 | 4.917, 4.367, 3.941 | 4.367 |

For the baseline, use the transport from `1b7aaae` with the same check harness. Change only the expected first connection events from `orrrc` to `orcorcorc`: `o` is an accepted connection, `r` is a request, and `c` is EOF at the server. Both versions pass the missing-object and tampered-object closure checks. This small local sample proves reuse; its timing does not predict WAN throughput.

## HTTP streaming memory

`stream.bend` transfers one 17 MiB file from a port-0 loopback origin. Both ends use 64 KiB pieces. It verifies the published digest and checks temporary-file cleanup. It does not run `Disk.checkout`, which loads the whole payload.

From the repo root:

```sh
mkdir -p storage/bench/out
bend storage/bench/stream.bend -o storage/bench/out/stream
/usr/bin/time -l storage/bench/out/stream
```

Apple M4 Pro, macOS arm64, Bend 2.0.40, 2026-11-24: 0.19 s elapsed and 6,356,992 bytes maximum resident set size. The process includes the streaming origin and client. The encoded response is 17,825,806 bytes. Its root is `89c9109ce931e20ac63a1729d6f6a9db03dee9401161eb8a3fbd35c4a09a9528`. This single measurement is not a throughput comparison. The fixed network and verifier buffers bound payload memory; the visited index still grows with object count.

### File-backed origin

The origin-only check creates encoded 17 MiB and 129 MiB files outside the server process. It reads and hashes each response in the Python client. The server never checks out a tree. It then resets 24 connections during their responses and requires its file/socket descriptor count to return to the warmed baseline. Both package check scripts run this check.

```sh
mkdir -p storage/bench/out
bend storage/http_origin.bend -o storage/bench/out/origin
python3 storage/http_origin_check.py storage/bench/out/origin
bend storage/http_origin.bend -o storage/bench/out/origin.js
python3 storage/http_origin_check.py bun storage/bench/out/origin.js
```

Apple M4 Pro, macOS arm64, Bend 2.0.40, 2026-11-25. One process per size and runtime, three complete transfers and 24 reset connections per process:

| runtime | payload MiB | peak sampled origin RSS, bytes | descriptors before / after |
|---|---:|---:|---:|
| native | 17 | 3,047,424 | 6 / 6 |
| native | 129 | 3,145,728 | 6 / 6 |
| Bun | 17 | 83,623,936 | 5 / 5 |
| Bun | 129 | 98,549,760 | 5 / 5 |

RSS is sampled with `ps` every 20 ms, not the OS high-water counter. Bun includes its VM, heap, and collection overhead. A 112 MiB payload increase adds about 96 KiB native RSS and 14.2 MiB Bun RSS in this sample. The regression permits less than 32 MiB of growth. This is a bounded-buffer check, not a throughput comparison or a claim that runtime overhead stays constant.




## Run

Run these commands from `storage/bench/`.

```sh
python3 run.py          # 3 runs per variant, median, K = 16
python3 run.py 3 32     # 3 runs, K = 32
```

You need `bend`, `clang` with OpenSSL 3 from Homebrew (`brew install openssl@3`), `cargo`, `bun`, `node`, and `python3`. Cargo fetches `sha2` 0.10. Binaries go to `out/`, which git ignores. The script exits non-zero if a build fails, a program prints no result, or two programs disagree on the root digest or the octet count.

## Input

The tree has K directories `d00`, `d01`, … at the top. Each directory holds K files `f00`, `f01`, … of 4096 octets. Octet `j` of file `(d, f)` is `(d * 31 + f * 7 + j) & 255`. Each program builds the tree before the timer starts.

The timed region converts the packed file inputs to reusable Blobs, hashes every canonical object, puts the objects in a store keyed by the digest, and loads the root back to count the file octets. Blob construction now hashes files, so it must stay inside the timer. The other programs build their file buffers before the timer and hash them inside it. Each program prints the root digest in hex and that count. Bend keys its store by `S.Digest`, the 32 octets packed into eight `U32`s; the other programs key theirs by the hex string.

| language | digest | store |
|---|---|---|
| Bend | `Crypto.sha256.words` through `S.commit` | `S.Index.of`, then `S.Index.load`, ordered by `S.Digest.cmp` |
| C | OpenSSL 3 `SHA256` | POSIX `hsearch` |
| Rust | `sha2` 0.10.9 | `std::collections::HashMap` |
| Python | `hashlib.sha256` | `dict` |
| JavaScript | `createHash("sha256")` from `node:crypto` | `Map` |

## Results

Apple M4 Pro, macOS 26.7.2 arm64, 2026-11-13. Three runs (`python3 run.py 3 32`), median, in ms. K = 32: 1,024 files and 4 MiB. Files whose seed `(d * 31 + f * 7) & 255` is equal hold the same octets, so the store holds 1,313 distinct objects. `Nx` is the multiple of the fastest variant.

Versions: Bend 2.0.38, Apple clang 21.0.0 with OpenSSL 3.6.5, rustc 1.91.0 with sha2 0.10.9, Bun 1.4.4, Node 24.0.1, Python 3.14.6.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| commit and load | 5.1 (1.7x) | 9.1 (3.1x) | 3.9 (1.3x) | 6.6 (2.3x) | 2.9 (1.0x) | 34.3 (11.7x) |

Every program prints root `29cc4de74d186c77f13fdfc2781365c186a6823091cdf974614aebe811a53202` and `4194304` octets.

### Packed file digest cache

Apple M4 Pro, macOS 26.7.2 arm64, 2026-11-21. Three runs at K = 32, median, in ms. Bend 2.0.40; the other versions are unchanged. Every program still prints the root and octet count above.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| prepare, commit, and load | 4.9 | 8.9 | 3.7 | 5.7 | 2.6 | 30.5 |

The unmodified `origin/main` baseline (`7a57643`, storage 0.4.1.0) took 28.0 ms with the old timer, which excluded Blob construction. For a like-for-like comparison, the baseline used the same prebuilt packed `Input` tree as the new harness. Its pure preparation mapped each file through the old `Blob.of`, inside the timer. The three baseline times were 35.81, 34.81, and 35.60 ms. The median fell from 35.60 to 30.5 ms, about 14%. The new timer includes file hashing and Blob construction; it does not hide this work before the clock.

`split.bend` now also times SHA-256 on pre-encoded buffers and builds the same object-list shape with fixed digests. Three runs, median, in ms:

| stage | storage 0.4.1.0 | storage 0.5.0.0 |
|---|---:|---:|
| Blob preparation, including file SHA-256 in 0.5.0.0 | outside old timer | 11.65 |
| `S.commit` | 14.43 | 4.25 |
| `S.Index.of` | 3.51 | 3.76 |
| `S.Index.load` | 2.37 | 2.55 |
| `S.encode` alone | 5.80 | 8.10 |
| SHA-256 of pre-encoded objects | not measured | 3.45 |
| object-list construction and `Store.cat`, fixed digests | not measured | 0.67 |

The SHA-only checksum is `1634831564`. Both list paths produce 2,113 entries before index deduplication. Encoding produces 4,351,460 octets. These are independent timings, not additive parts of one run. SHA-only includes the native input conversion and eight-word digest conversion. List-only includes tree traversal and object allocation, not just `Store.cat`. The new encode-only measurement retains the objects for the later SHA-only measurement; the old one consumed its last reference.

A Blob now caches the SHA-256 of `"file <len>\n"` and its octets. A native effect hashes the packed input and returns the same input buffer to build the reusable word list. It does not rebuild that list for hashing. `S.commit` reuses the digest. The remaining commit time hashes directory objects and builds their lists. A first prototype used `Bytes.clone` and `Bytes.append`; its comparable total was 38.0 ms. Reusing the source during a packed Bend copy took 37.3 ms. The native input-preserving effect reduced that total to 30.5 ms.

`hash` has no SHA-256 implementation, so a pure cached constructor is not available. The existing OpenSSL effect consumes its input. Blob construction and `decode` therefore now return `Run`; the specialized effect retains the packed input instead of making a second Bend buffer. The generic laws and the `Data` kinds of `Tree` and `Obj` do not change.


## Reading it

- The store is an ordered map keyed by digest (`S.Index`), so `put` and `get` take O(log n) comparisons. One run each of native Bend: K = 16 (469 objects) took 9 ms, K = 32 (1,313 objects) 33 ms, and K = 48 (2,609 objects) 76 ms. The list store of storage 0.1.0.0 took 21, 175, and 708 ms on the same inputs.
- `split.bend` times each stage of the Bend side alone. Build it with `bend split.bend -o out/split` and run `out/split 32`. Three runs at K = 32, in ms:

| stage | storage 0.2.0.0 | storage 0.2.0.1 | storage 0.3.0.0 |
|---|---:|---:|---:|
| `S.commit`: encode, SHA-256, and object list | 21 to 35 | 18 to 19 | 16 to 17 |
| `S.Index.of` on 1,313 objects | 12 | 12 | 6 |
| `S.Index.load` of the root | 8 | 8 | 4 |
| `S.encode` of every object, alone | 12 | 6 | 6 |

  In 0.2.0.1, `encode` began to write a file's words once, shifted by the header length, in place of a copy into `Bytes` and an append one octet at a time. In 0.3.0.0, the index keys are packed digests: a comparison reads at most eight words, and copying a key copies eight words, not 64 `Char`s. What is left of `encode` is the walk of the `Blob` word list.
- Python is fastest here because `hashlib` and `dict` run in C, and each object costs one call to each.

## Checkout of a small root

`checkout.bend` measures what `Disk.checkout` reads. It commits the K = 32 tree and a three-object root (`note`, one 11-octet file) to one store on disk, 1,316 objects in all. Then it times `S.Disk.checkout` of the small root, which reads only the objects that root reaches, and `S.Disk.load` of the whole store followed by `S.Index.load`, which is what `Disk.checkout` did before storage 0.3.1.0. Only Bend runs it; the other programs have no store on disk.

```sh
bend checkout.bend -o out/checkout && out/checkout 32
```

Three runs, in ms. Both print 11 octets.

| op | run 1 | run 2 | run 3 |
|---|---:|---:|---:|
| `Disk.checkout` of the small root | 0.8 | 0.5 | 0.6 |
| `Disk.load`, then `Index.load` | 151 | 138 | 160 |

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock. It reads K from argv, so the work cannot run before the clock starts.
- One machine, one tree shape, one thread.
- No standard or popular library writes this object format. Git's tree format differs, so a git library would print a different root. The C, Rust, Python, and JavaScript programs are the obvious loop over a library SHA-256 and a library map. They are not a second `storage`: they have no sync plan, collection, or ingress checks.
