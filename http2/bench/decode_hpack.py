from hpack import Decoder

BLOCK = bytes.fromhex("828684410f7777772e6578616d706c652e636f6d")


def main():
    decoder = Decoder()
    checksum = 0
    for _ in range(1000):
        for name, value in decoder.decode(BLOCK, raw=True):
            checksum += sum(name) + sum(value)
    print(checksum)


if __name__ == "__main__":
    main()
