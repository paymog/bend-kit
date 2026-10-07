#!/usr/bin/env python3
"""Exercise generated pure Bend messages against official Python Protobuf."""
import os
from pathlib import Path
import subprocess
import struct
import sys

from fixture import fixture

HERE = Path(__file__).resolve().parent
EXAMPLES = HERE / "examples"
OUT = HERE / "bench" / "out" / "interop"
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}


def command(argv, cwd=HERE):
    result = subprocess.run(list(map(str, argv)), cwd=cwd, env=ENV,
                            text=True, capture_output=True)
    if result.returncode:
        sys.exit(f"{argv[0]} failed:\n{result.stdout}\n{result.stderr}")
    return result.stdout.strip()


def varint(n):
    out = bytearray()
    while n > 127:
        out.append((n & 127) | 128)
        n >>= 7
    out.append(n)
    return bytes(out)


def field(number, payload):
    return varint(number * 8 + 2) + varint(len(payload)) + payload


def main():
    if not __debug__:
        raise SystemExit('Run without -O; assertions are the checks')
    OUT.mkdir(parents=True, exist_ok=True)
    command(["protoc", f"-I{EXAMPLES}", f"--python_out={OUT}", "common.proto", "fixture.proto"])
    command(["protoc", f"-I{EXAMPLES}", f"--plugin=protoc-gen-bend={HERE / 'protoc-gen-bend'}",
             f"--bend_out=runtime_import=../protobuf.bend:{EXAMPLES}", "common.proto", "fixture.proto"])
    sys.path.insert(0, str(OUT))
    import fixture_pb2
    import common_pb2
    command(["bend", EXAMPLES / "roundtrip.bend", "-o", OUT / "roundtrip"])

    def run(raw, size=1048576, depth=64):
        return command([OUT / "roundtrip", raw.hex(), size, depth])

    checked = 0
    command(["bend", EXAMPLES / "construct.bend", "-o", OUT / "construct"])
    constructed = common_pb2.Child.FromString(bytes.fromhex(command([OUT / "construct"])))
    assert constructed == common_pb2.Child(id=150, label="from Bend")
    checked += 1
    command(["bend", EXAMPLES / "scalars.bend", "-o", OUT / "scalars"])

    def float32(bits):
        return struct.unpack("<f", struct.pack("<I", bits))[0]

    def float64(bits):
        return struct.unpack("<d", struct.pack("<Q", bits))[0]

    def single_bits(value):
        return struct.unpack("<I", struct.pack("<f", value))[0]

    def double_bits(value):
        return struct.unpack("<Q", struct.pack("<d", value))[0]

    def limbs(value):
        bits = value & 0xffffffffffffffff
        return [bits >> 32, bits & 0xffffffff]

    # These observations come directly from the typed U32, Word64, F32 and
    # F64 fields in Bend, independently of its encoder.
    scalar_cases = [
        (-2**31, -123456789, -2**63, -0x123456789abcdef, 2**64 - 1,
         0xc1234567, 0xc0123456789abcde),
        (2**31 - 1, -2**31, 2**63 - 1, -2**63, 0x123456789abcdef0,
         1, 1),
        (-1, 123456789, -1, 0x123456789abcdef, 0,
         0x80000000, 0x8000000000000000),
        (0, 0, 0, 0, 1, 0x7fc01234, 0x7ff8000000001234),
    ]
    for i32, z32, i64, z64, u64, single, precise in scalar_cases:
        value = fixture_pb2.Scalars(i32=i32, z32=z32, i64=i64, z64=z64, u64=u64,
                                   single=float32(single), precise=float64(precise))
        observed = list(map(int, command([OUT / "scalars", "decode",
                                         value.SerializeToString().hex()]).splitlines()))
        expected = [i32 & 0xffffffff, z32 & 0xffffffff,
                    *limbs(i64), *limbs(z64), *limbs(u64), single, *limbs(precise)]
        assert observed == expected, f"typed scalar values: {observed} != {expected}"
        checked += 1

    value = fixture_pb2.Scalars.FromString(
        bytes.fromhex(command([OUT / "scalars", "construct"])))
    assert (value.i32, value.z32, value.i64, value.z64, value.u64) == (
        -2**31, -123456789, -2**63, -0x123456789abcdef, 2**64 - 1)
    assert single_bits(value.single) == 0xc1234567
    assert double_bits(value.precise) == 0xc0123456789abcde
    checked += 1

    first, second = command([OUT / "scalars", "collision"]).splitlines()
    assert fixture_pb2.A_.FromString(bytes.fromhex(first)) == fixture_pb2.A_(
        x=fixture_pb2.A_.B(n=150))
    assert fixture_pb2.A.FromString(bytes.fromhex(second)) == fixture_pb2.A(
        x=fixture_pb2.A._B(s="distinct string child"))
    checked += 2

    def roundtrip(raw, label):
        nonlocal checked
        expected = fixture_pb2.Fixture.FromString(raw)
        encoded = run(raw)
        try:
            actual = fixture_pb2.Fixture.FromString(bytes.fromhex(encoded))
        except ValueError as e:
            raise AssertionError(f"{label}: Bend returned {encoded}") from e
        assert actual == expected, f"{label}:\nexpected {expected}\nactual {actual}"
        checked += 1
        return bytes.fromhex(encoded)

    raw = fixture(fixture_pb2).SerializeToString(deterministic=True)
    roundtrip(raw, "all proto3 features")
    roundtrip(b"", "empty message")
    unknown = varint(127 * 8) + varint(150) + field(128, b"future")
    unknown += varint(536870911 * 8) + varint(0xffffffffffffffff)
    unknown += varint(129 * 8 + 3) + b"\x08\x07" + varint(129 * 8 + 4)
    out = roundtrip(raw + unknown, "unknown varint/blob/group/max-field preservation")
    stripped = fixture_pb2.Fixture.FromString(out)
    before = stripped.SerializeToString()
    stripped.DiscardUnknownFields()
    assert stripped.SerializeToString() != before, "unknown fields were discarded"
    roundtrip(raw + b"\x08\x07", "duplicate scalar last wins")
    roundtrip(field(16, b"\x08\x05") + field(16, b"\x12\x01x"), "singular message merges")
    roundtrip(field(22, b"\x08\x09") + field(22, b"\x12\x01x"), "same oneof message merges")
    roundtrip(field(16, b"\x08\x05\x12\x01x") + field(16, b"\x08\x00"),
              "duplicate child explicit zero replaces previous value")
    roundtrip(field(22, b"\x08\x09\x12\x01x") + field(22, b"\x08\x00"),
              "duplicate oneof child explicit zero replaces previous value")
    roundtrip(field(22, b"\x08\x09") + field(21, b"last"), "oneof switches")
    roundtrip(field(21, b"first") + field(22, b"\x08\x09"), "oneof switches to message")
    roundtrip(field(19, b"\x0a\x01a\x10\x01") + field(19, b"\x0a\x01a\x10\x02"),
              "map duplicate keys last wins")
    roundtrip(varint(17 * 8) + b"\x01" + field(17, b"\x02\x03") + varint(17 * 8) + b"\x04",
              "mixed packed/unpacked append order")
    roundtrip(field(18, b"\x01\x02") + varint(18 * 8) + b"\x03", "unpacked declaration accepts packed")
    roundtrip(varint(20 * 8) + varint(1234), "open enum value")
    roundtrip(varint(24 * 8) + b"\x00", "optional zero presence")
    roundtrip(field(1, b"unknown wrong wire"), "known number with unknown wire type")
    roundtrip(varint(16 * 8 + 3) + b"\x08\x05" + varint(16 * 8 + 4),
              "known message number with unknown group wire type")
    roundtrip(field(16, b""), "present empty message")
    for single, double in [(0x80000000, 0x8000000000000000),
                           (0x7f800000, 0x7ff0000000000000),
                           (0xff800000, 0xfff0000000000000),
                           (1, 1), (0x7fc01234, 0x7ff8000000001234),
                           (0x7f801234, 0x7ff0000000001234)]:
        bits = b"\x65" + struct.pack("<I", single) + b"\x69" + struct.pack("<Q", double)
        assert bytes.fromhex(run(bits)) == bits, "floating-point payload bits changed"
        checked += 1
    roundtrip(field(19, b""), "map default key/value")
    roundtrip(field(28, b""), "message map default value")


    # Different unknown values expose reversal, duplicate finalization and
    # dropped values; identical repetitions would hide ordering bugs.
    def child_unknowns(values):
        return b"".join(varint(4 * 8) + varint(value) for value in values)

    values = list(range(64))
    duplicate_children = b"".join(field(16, child_unknowns([value])) for value in values)
    out = roundtrip(duplicate_children, "duplicate child varying unknown retention")
    assert out == field(16, child_unknowns(values)), "merged child unknown order changed"

    repeated_children = b"".join(field(25, child_unknowns(pair))
                                 for pair in [(9, 2), (7, 1), (6, 3)])
    assert roundtrip(repeated_children, "repeated child unknown ordering") == repeated_children

    map_children = b"".join(field(28, b"\x08" + varint(key) + field(2, child_unknowns(pair)))
                            for key, pair in [(1, (9, 2)), (2, (7, 1))])
    assert roundtrip(map_children, "map child unknown ordering") == map_children

    tree = child_unknowns([6, 3])
    tree = field(3, tree) + child_unknowns([7, 1])
    tree = field(3, tree) + child_unknowns([9, 2])
    recursive_tree = field(16, tree)
    assert roundtrip(recursive_tree, "recursive child unknown ordering") == recursive_tree
    bad = {
        "truncated tag": (b"\x80", "incomplete"),
        "truncated varint": (b"\x08\x80", "incomplete"),
        "overflowing tag": (b"\xff\xff\xff\xff\x10", "malformed"),
        "overflowing varint": (b"\x08" + b"\xff" * 9 + b"\x02", "malformed"),
        "eleven-byte varint": (b"\x08" + b"\x80" * 10 + b"\x00", "malformed"),
        "six-byte tag": (bytes.fromhex("88808080800001"), "malformed"),
        "six-byte length": (bytes.fromhex("7281808080800078"), "malformed"),
        "zero field": (b"\x00\x00", "malformed"),
        "wire type six": (b"\x0e", "malformed"),
        "wire type seven": (b"\x0f", "malformed"),
        "truncated fixed32": (b"\x3d\x01", "incomplete"),
        "truncated fixed64": (b"\x41\x01", "incomplete"),
        "truncated length": (b"\x72\x80", "incomplete"),
        "truncated blob": (b"\x72\x02x", "incomplete"),
        "overflowing length": (b"\x72\x80\x80\x80\x80\x10", "malformed"),
        "length beyond protobuf limit": (b"\x72\x80\x80\x80\x80\x08", "malformed"),
        "unmatched end group": (b"\x0c", "malformed"),
        "mismatched group": (b"\x0b\x14", "malformed"),
        "unfinished group": (b"\x0b", "incomplete"),
        "malformed complete child": (field(16, b"\x08\x80"), "malformed"),
        "partial packed value": (field(17, b"\x80"), "malformed"),
        "partial packed fixed32": (field(29, b"\x00"), "malformed"),
        "partial packed fixed64": (field(30, b"\x00"), "malformed"),
        "invalid utf8": (field(14, b"\xc0\xaf"), "utf8"),
        "surrogate utf8": (field(14, b"\xed\xa0\x80"), "utf8"),
        "beyond unicode": (field(14, b"\xf4\x90\x80\x80"), "utf8"),
    }
    for label, (value, error) in bad.items():
        actual = run(value)
        assert actual == error, f"{label}: expected {error}, got {actual}"
        checked += 1
    assert run(raw, size=len(raw) - 1) == "limit"
    assert run(field(16, field(3, b"\x08\x01")), depth=1) == "limit"
    assert run(b"\x0b\x13\x14\x0c", depth=1) == "limit"
    print(f"{checked + 3} official Protobuf interoperability and malformed-input checks passed")


if __name__ == "__main__":
    main()
