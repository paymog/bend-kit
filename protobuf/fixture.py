"""Shared official Protobuf fixtures for interoperability and benchmarks."""


def fixture(module):
    m = module.Fixture(
        count=150, wide=0xffffffffffffffff, signed_count=-2, signed_wide=-3,
        zigzag=-2147483648, zigzag_wide=-9223372036854775808,
        word=0x12345678, long_word=0xfedcba9876543210,
        signed_word=-2147483648, signed_long_word=-9223372036854775808,
        enabled=True, single=1.5, precise=1.0 / 3.0,
        title="Bend \u03bb \U0001f642", payload=b"\x00\x80\xffprotobuf",
        samples=[0, 1, 127, 128, 4294967295],
        deltas=[-1, 0, 1, -9223372036854775808, 9223372036854775807],
        status=-1, present=0, names=["", "one", "\u00e9"],
        weights=[0.0, -0.0, 1.5], measures=[0.0, -0.0, 1.0 / 3.0],
        optional_payload=b"", optional_title="", optional_enabled=False, optional_status=0,
        chunks=[b"", b"\x00\xff"], statuses=[0, 1, -1, 1234],
    )
    m.child.id = 7
    m.child.label = "nested"
    m.child.next.id = 8
    m.children.add(id=1, label="first")
    m.children.add(id=2, label="second")
    m.labels["b"] = 2
    m.labels["a"] = 1
    m.selected.id = 9
    m.selected.label = "oneof"
    m.detail.value = 42
    m.indexed[-1].id = 3
    m.indexed[2].label = "map message"
    m.switches[False] = "off"
    m.switches[True] = "on"
    m.buffers[0xffffffffffffffff] = b"\x00\xff"
    m.buffers[0] = b""
    m.entries.add(key="duplicate", value=1)
    m.entries.add(key="duplicate", value=2)
    m.peer.owner.count = 3
    return m


def sample(module):
    return module.Sample(count=150, title="protobuf fixture", samples=list(range(64)),
                         precise=1.0 / 3.0, payload=bytes(range(256)))
