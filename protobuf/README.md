# protobuf

Pure proto3 messages over packed `Bytes`. The runtime checks bounds before each read. The `protoc` plugin generates typed Bend codecs from official descriptors.

```bend
import bend-kit-protobuf@0.1.0.0/protobuf.bend as P
import bend-kit-bytes@0.3.2.0/bytes.bend as B
import bend-kit-f64@0.1.0.0/f64.bend as F
```

Use those sibling versions when you pass bytes or doubles to the codec. A different hub version is a different type. `double` uses the published pure `F.F64`, not an `F32` or a host effect. Its two limbs hold the IEEE 754 bits. The codec preserves floating-point bits, including signed zero and NaN payloads.

## Wire API

`decode(bytes, max_size, depth)` returns `Result<&2, &1, Error, List<&1, Field>>`. `encode(fields, max_size, depth)` returns `Result<&2, &1, Error, B.Bytes>`.

A `Field` has a field number and a `Value`: `Varint`, `Fixed32`, `Fixed64`, `Blob`, or `Group`. Varints and fixed64 values use `Word64{hi, lo}`. Signed32 values are two's-complement `U32` bits. Signed64 values are two's-complement `Word64` bits. The `from_*` and `to_*` scalar helpers apply the protobuf representation, including signed varints and zigzag.

The wire codec accepts field numbers 1 through 536870911. The schema compiler reserves numbers 19000 through 19999, but a decoder retains unknown wire fields in that range. Wire types 0, 1, 2, 3, 4, and 5 are supported. Group end tags must match their start tags.

`max_size` bounds the input and output message. The protobuf limit of 2147483647 bytes also applies. Set a much smaller limit for untrusted input. `depth` bounds group nesting; generated codecs also bound embedded-message nesting.
This size limit does not bound peak memory while encoding a caller-constructed value. A flat message works at depth zero; each nested group or embedded message consumes one depth level.

Errors:

- `Incomplete`: the outer input ends inside a tag, value, length, blob, or group. A streaming caller may supply more bytes and retry.
- `Malformed`: an invalid field number, wire type, varint overflow, length beyond the protobuf limit, mismatched group, or invalid complete nested message or packed field.
- `Limit`: the configured size or depth limit was reached.
- `InvalidUtf8`: a string contains invalid UTF-8, or Bend text contains an invalid Unicode scalar.

Unknown fields retain their numbers, wire types, values, and order relative to other unknown fields. Re-encoding writes canonical varints. It does not promise byte-identical serialization or the original order between known and unknown fields. Protobuf does not define a canonical field order.

## Generate typed messages

Install `protoc` and the official Python Protobuf package. The plugin uses Python only at generation time. Generated encode and decode functions are pure Bend.

```sh
python3 -m venv /tmp/protobuf-venv
/tmp/protobuf-venv/bin/pip install protobuf
mkdir -p generated
PATH=/tmp/protobuf-venv/bin:$PATH protoc -I proto \
  --plugin=protoc-gen-bend=protobuf/protoc-gen-bend \
  --bend_out=generated proto/service.proto
```

The plugin reads a standard `CodeGeneratorRequest` from stdin and writes a `CodeGeneratorResponse` to stdout. It accepts proto3, including `optional`. It emits one `schema.bend` with all messages and enums in the request's import closure. Pass cooperating root files in one invocation. Separate invocations create separate Bend types for shared imports.

By default, generated code imports `bend-kit-protobuf@0.1.0.0/protobuf.bend`. To regenerate the checked-in examples against the local runtime:

```sh
PATH=/tmp/protobuf-venv/bin:$PATH protoc -I protobuf/examples \
  --plugin=protoc-gen-bend=protobuf/protoc-gen-bend \
  --bend_out=runtime_import=../protobuf.bend:protobuf/examples \
  protobuf/examples/common.proto protobuf/examples/fixture.proto
```

### Generated API

Message and enum names start with `PB_`. Package and nesting dots become `_`; original underscores become `_0`. This conversion keeps distinct legal schema names distinct. For example, `kit.common.Child` becomes `PB_kit_common_Child`. The prefix avoids collisions with private codec types. Field labels start with `f_`; oneof slots start with `o_`.

Each message provides `.empty()`, `encode_<type>(value, max_size, depth)`, and `decode_<type>(bytes, max_size, depth)`. Encoding consumes the message. Decoding consumes the input Bytes. Both return `Result<&2, &1, P.Error, ...>` and apply the runtime's size and nesting limits.

```bend
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as B
import ../protobuf.bend as P
import ./schema.bend as S

def child() -> Result<&2, &1, P.Error, B.Bytes>:
  S.encode_PB_kit_common_Child(
    S.PB_kit_common_Child{150, "from Bend", None{}, Nil{}}, 1024, 8n)
```

See [examples/construct.bend](examples/construct.bend) for the executable version and [examples/schema.bend](examples/schema.bend) for the generated record layout.

- Messages are affine records. Bytes fields and repeated lists are affine too. Every record ends with `unknown: List<&1, P.Field>`.
- Message fields always retain presence. Optional scalars use `Maybe`. Repeated fields use lists and accept packed or unpacked input for packable types.
- Oneofs use `Maybe` of a generated choice type. A later different case replaces the previous case. Repeated occurrences of the same message case merge.
- Enum values are Data wrappers around U32 number bits, including unknown numbers. Named values have functions such as `PB_kit_common_Status.READY()`.
- Maps use `Map<&1, <entry type>>`. The generated `map_insert_<entry type>(entry, map)` helper derives the canonical key. Duplicate keys replace earlier entries. Map order is not part of the wire contract.
- Duplicate scalar fields take the last value. Duplicate singular message fields merge, including explicit zero values. Unknown values in nested messages remain on those messages.
- Encoders omit implicit defaults and empty packed fields. Explicit optional defaults remain present. Negative zero and float/double NaN payload bits are retained.

## Checks

From the repository root:

```sh
scripts/check.sh protobuf
python3 protobuf/interop.py
python3 protobuf/bench/run.py
```

The interoperability runner needs `protoc` and the official Python `protobuf` package. It exchanges the full fixture with official Protobuf and checks typed signed limbs and IEEE payload bits independently of re-encoding. It also exercises distinct legal schema names and nested unknown-field order. The benchmark needs `protobuf-c`, `pkg-config`, Rust/Cargo, and Bun. See [bench/README.md](bench/README.md) for the fixed input and measured results.

`LAWS.bend` states concrete wire round trips and rejection fixtures. `PROOF.bend` proves them by reduction. These are fixture laws, not a universal proof of the protobuf specification. The Python plugin is outside those proofs.

References: [wire encoding](https://protobuf.dev/programming-guides/encoding/) and [standard plugin protocol](https://protobuf.dev/reference/cpp/api-docs/google.protobuf.compiler.plugin.pb/).

Out of scope: gRPC, protobuf JSON, and proto2 extensions.
