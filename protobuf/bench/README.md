# protobuf benchmark

Run from the repository root:

```sh
python3 -m venv /tmp/protobuf-venv
/tmp/protobuf-venv/bin/pip install protobuf
PATH=/tmp/protobuf-venv/bin:$PATH /tmp/protobuf-venv/bin/python protobuf/bench/run.py
```

Install `protoc`, `protobuf-c`, `pkg-config`, Rust/Cargo, a C compiler, and Bun first. On macOS, `brew install protobuf protobuf-c pkg-config rust` supplies the native tools. The runner installs `protobufjs` in the ignored `out/` folder and builds Rust with `prost`. It does not publish a Bend package.

`bench.proto` defines one message with uint32, a UTF-8 string, packed repeated uint32, double, and bytes. The fixed input has count 150, title `protobuf fixture`, samples 0 through 63, double 1/3, and payload octets 0 through 255. Official Python Protobuf produces the 355-byte fixture.

Each implementation performs 100 decode/encode pairs and sums every encoded octet. The checksum is **3761800**. Bend uses the generated typed codec, not just the untyped wire reader. Its affine loop passes each encoded buffer to the next decode; the other implementations decode the fixed input each time. This fixture has the same encoding in every iteration.

The table is the median of three runs on an Apple M4 Pro, macOS arm64. The clock surrounds the loop and checksum, not process startup, schema loading, file reading, or compilation.

| Implementation | Median loop ms | Checksum |
|---|---:|---:|
| Bend | 2.594 | 3761800 |
| C, protobuf-c | 0.103 | 3761800 |
| Rust, prost | 0.093 | 3761800 |
| Python, official Protobuf | 0.133 | 3761800 |
| JavaScript, protobufjs on Bun | 4.110 | 3761800 |

Versions: Bend 2.0.35; protoc 36.2; Apple clang 17.0.0 (`-O2`); rustc 1.91.0 with prost 0.14.4 (Cargo release build); Python 3.14.6 with protobuf 7.36.2; Bun 1.3.14 with protobufjs 7.6.6; protobuf-c 1.5.2. `Cargo.lock` and `package.json` pin the benchmark libraries.

These are small-fixture timings, not a claim about arbitrary message sizes or map workloads. The packed codec is pure Bend. Official native codecs remain faster on sequential byte work.

## Duplicate-child merge scaling

The native interoperability program receives `8201022001` repeated N times. Each fragment merges one unknown varint into the same singular Child. The table reports median whole-process wall time from three sequential runs, including startup.

| Fragments | Before, ms | After, ms | Encoded bytes |
|---:|---:|---:|---:|
| 256 | 3.112 | 3.251 | 516 |
| 2048 | 9.079 | 3.792 | 4100 |
| 8192 | 108.534 | 6.832 | 16389 |

The decoder now retains reverse accumulators through duplicate merges and finalizes the retained message tree once. The interoperability checks also verify varying unknown values in singular, repeated, map, and recursive children.
