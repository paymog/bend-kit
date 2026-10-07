# ZIP reader

```bend
import bend-kit-archive@0.2.0.0/archive.bend as Archive
```

`archive.bend` imports `bend-kit-zlib@0.1.6.0` for DEFLATE, not `zlib@0.2.0.0`. It imports `bend-kit-hash@0.1.0.0` for CRC-32. Pass `Bytes` from the bytes module the entry file imports. DEFLATE needs `libz` (`BEND_LIBZ`).


`Archive.read(max, input)` reads a ZIP archive from `Bytes.Bytes`. It returns entries in central-directory order. Each `Archive.Entry` holds the raw byte name, decoded byte data, compression method, and CRC-32. It never extracts paths or writes files.

The reader supports stored (0) and DEFLATE (8) entries. It checks central-directory and local-header bounds, the decoded size, and CRC-32. `max` limits the total decoded data across entries. An archive above the limit fails with code 27; malformed or unsupported ZIP features fail with code 22 and a reason. ZIP64, encryption, and multi-disk archives are not supported.

`Archive.crc32` uses `bend-kit-hash` for the ZIP CRC-32. It accepts the same local `Bytes.Bytes` type as `Archive.read`.

`Archive.headers(input)` is a pure metadata-only check. It returns the input buffer and validated headers. It does not decode entry data. `Archive.read` is an IO operation because DEFLATE uses libz through the existing zlib package; libz must be available on the host.

Run `../scripts/check.sh archive` for the proof and runtime fixtures. Run `python3 bench/run.py` from this directory to compare checksums and throughput with C and Python.
