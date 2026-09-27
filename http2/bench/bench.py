from hyperframe.frame import Frame, PingFrame

WIRE = bytes([0, 0, 8, 6, 1, 0, 0, 0, 0]) + b"12345678"


def main():
    checksum = 0
    for _ in range(10000):
        frame, length = Frame.parse_frame_header(memoryview(WIRE[:9]))
        frame.parse_body(memoryview(WIRE[9 : 9 + length]))
        assert isinstance(frame, PingFrame) and "ACK" in frame.flags
        payload = frame.opaque_data
        checksum = (
            checksum
            + int.from_bytes(payload[:4], "big")
            + int.from_bytes(payload[4:], "big")
        ) & 0xFFFFFFFF
    print(checksum)


if __name__ == "__main__":
    main()
