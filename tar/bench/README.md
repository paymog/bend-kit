# Tar benchmark

This times `Tar.decode` (Bytes to a list of entries) and `Tar.encode` (the entries back to Bytes) on one fixed archive, in Bend and in C, Rust, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py          # 3 runs per variant, median, 2,000 entries
python3 run.py 5        # 5 runs
python3 run.py 1 50     # 1 run on a 50-entry archive (small smoke run)
```

You need `bend`, `cc` with Homebrew `libarchive` in `/opt/homebrew/opt/libarchive`, `cargo`, `npm`, `bun`, `node`, and `python3`. On the first run, Cargo fetches the `tar` crate and `npm` installs `tar-stream` into `out/js`. Binaries go to `out/`, which git ignores. It exits non-zero if a build or a run fails, or if a checksum differs from the input's. `bench.bend` reads at most 16 MiB, so `run.py` refuses a bigger input.

## Input

`run.py` writes one fewer than the requested entry count to `out/input.tar` with Python's `tarfile` in PAX format (mtime 0, uid and gid 0), then appends one ustar prefix-split file. Every program, Bend included, decodes an archive written by an independent library. `run.py` prints its size and checksum on stderr. Entry `i` in the PAX portion is:

- every 20th entry, a directory `dirNNNN` (written as `dirNNNN/`)
- otherwise a regular file under the last directory, whose name cycles through
  - a short ASCII name, `dirNNNN/file{i}.txt`
  - a second ASCII name, `dirNNNN/fichier-{i}-ete-nihon.bin`
  - a name with one 130-byte component, which no ustar prefix split can hold, so it needs a PAX `path` record
  - a deeper ASCII path, `dirNNNN/deep/a/b/c/{i}`
- with a payload of 0, 1, 511, 512, 513, or 1024 bytes, or `(i * 7919) % 8192` bytes, cycling on `i % 7`, so payloads end before, on, and after the 512-byte block boundary. Entries with 513 bytes carry a PAX `size` record; their ustar header size is changed to zero and its checksum recalculated, so readers must apply the PAX override. Payload bytes run through all 256 values, NUL included.

The final `nested/` path has 15 components and a ustar prefix field; its data is `prefix`. The runner keeps the requested entry count when it adds this file.

Every program decodes the file into its library's entries, then encodes those entries. Only the two calls are timed. Each program rejects any entry that is not a regular file or a directory.

Names are ASCII. On macOS, libarchive rewrites UTF-8 PAX paths to Unicode NFD as it reads them (`archive_string.c`, the `__APPLE__` branch that sets `SCONV_NORMALIZATION_D`), so a non-ASCII name would reach the C program with different bytes and no checksum could match. Bend's byte-exact UTF-8 names are covered by the codec's own checks.

The checksum is taken over entries, not archive bytes, because each library writes its own headers (tarfile and tar-stream use PAX, libarchive restricted PAX, the Rust `tar` crate a GNU long-name entry). Over the entries in order, with `fold(x)` meaning `h = h*31 + x` (u32, wrapping): fold the kind (1 file, 2 directory), fold each name byte, fold the name length, and for a file fold each data byte and the data length. A directory name drops one trailing `/`. Finally add the entry count. `decode` prints the checksum of the entries read from `input.tar`; `encode` prints the checksum of the entries read back from the program's own archive (untimed). Both must equal the checksum `run.py` computes from the entries it wrote. A dropped, reordered, renamed, or truncated entry changes it.

## Results

M4 Pro, macOS 26.6.2, 2026-09-28. `python3 run.py 5`: 2,000 entries, 3,891,200 archive bytes, checksum `2676630000` for both operations in all six variants. Times are ms, median of five runs; ratios compare with the fastest variant for that operation.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| decode | 3.1 (2.9x) | 1.9 (1.8x) | 10.9 (10.3x) | 14.7 (13.9x) | 26.3 (24.8x) | 1.1 (1.0x) |
| encode | 3.5 (2.7x) | 1.3 (1.0x) | 9.5 (7.4x) | 13.7 (10.7x) | 29.3 (22.9x) | 2.4 (1.9x) |

Versions: Bend 2.0.32, Apple clang 17.0.0 with libarchive 3.8.2, rustc 1.91.0 with tar 0.4, Bun 1.3.14 and Node 24.0.1 with tar-stream 3.2.1, Python 3.14.6.

Bend uses `Time.mono` for sub-millisecond timing.

## The calls

| language | decode | encode |
|---|---|---|
| Bend | `Tar.decode` | `Tar.encode` |
| C | libarchive `archive_read_open_memory` + `archive_read_next_header` / `archive_read_data` | `archive_write_set_format_pax_restricted` + `archive_write_open_memory` / `archive_write_header` / `archive_write_data` |
| Rust | `tar::Archive::entries` (`path_bytes`, `read_to_end`) | `tar::Builder::append_data` with `Header::new_gnu` |
| JavaScript | tar-stream `extract` | tar-stream `pack` |
| Python | `tarfile.open(mode="r:")` + `extractfile` | `tarfile.open(mode="w", format=PAX_FORMAT)` + `addfile` |
