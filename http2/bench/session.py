from h2.connection import H2Connection
from h2.events import PingAckReceived

SETTINGS = bytes([0, 0, 0, 4, 0, 0, 0, 0, 0])
PING = bytes([0, 0, 8, 6, 1, 0, 0, 0, 0]) + b"12345678"


def main():
    connection = H2Connection()
    connection.initiate_connection()
    connection.receive_data(SETTINGS)
    checksum = 0
    for _ in range(10000):
        for event in connection.receive_data(PING):
            if isinstance(event, PingAckReceived):
                opaque = event.ping_data
                checksum = (
                    checksum
                    + int.from_bytes(opaque[:4], "big")
                    + int.from_bytes(opaque[4:], "big")
                ) & 0xFFFFFFFF
    print(checksum)


if __name__ == "__main__":
    main()
