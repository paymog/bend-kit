# Packed file IO benchmark

Run `python3 bench/run.py` from `files/`. The runner generates a 262,144-byte binary file (`byte[i] = (73*i + 255) mod 256`), builds Bend for C and JS, and builds the C and Rust comparisons. It deletes the fixture afterward. Every reader uses 16,384-byte chunks and computes FNV-1a 32. The Bend program reads the same file twice: once through `Fs.read_bytes` (packed `Bytes`) and once through Base `File.read_bytes` (octet list). All six executables and both Bend paths must print checksum `515677637`; a mismatch fails the runner. Packed reads do not construct an octet list.

Example on arm64 macOS 25.6.0, Bend 2.0.32, Apple clang 17.0.0, rustc 1.91.0, Python 3.14.6, Bun 1.3.14. Median of three runs; process wall time includes startup and both reads for Bend. The indented Bend numbers are elapsed milliseconds inside the process, including each read and checksum.

| Reader | Process ms | In-process ms | Checksum |
|---|---:|---:|---:|
| Bend native (packed + Base) | 37.36 | packed 15; Base 3 | 515677637 |
| Bend JS (packed + Base) | 73.06 | packed 25; Base 18 | 515677637 |
| C | 4.15 | — | 515677637 |
| Rust | 7.62 | — | 515677637 |
| Python | 55.41 | — | 515677637 |
| JavaScript (Bun) | 32.93 | — | 515677637 |

One run is not a performance claim: OS cache, startup, and millisecond clock resolution affect these numbers. The benchmark guards byte-for-byte equivalence of the packed and Base read paths on a larger binary file.
