#!/usr/bin/env python3
"""Convert a stopped runner's legacy journal without changing its source."""

import argparse
import runpy
import os
from pathlib import Path
import struct
import tempfile
import zlib


def u32(n):
    return struct.pack("<I", n)


class Record:
    def __init__(self, data, decode, encode):
        self.data = data
        self.at = 0
        self.out = bytearray()
        self.decode = decode
        self.encode = encode

    def take(self, n):
        end = self.at + n
        if end > len(self.data):
            raise ValueError("truncated runner record")
        value = self.data[self.at:end]
        self.at = end
        return value

    def word(self):
        return struct.unpack("<I", self.take(4))[0]

    def copy(self, n):
        self.out.extend(self.take(n))

    def flag(self):
        flag = self.word()
        if flag not in (0, 1):
            raise ValueError("invalid snapshot flag")
        self.out.extend(u32(flag))
        return flag

    def payload(self, n, sized):
        value = self.encode(self.decode(self.take(n)))
        if not isinstance(value, bytes):
            raise ValueError("payload encode must return bytes")
        if sized:
            self.out.extend(u32(len(value)))
        self.out.extend(value)

    def ticket(self):
        self.copy(16)
        self.payload(self.word(), True)

    def tree(self, kind):
        # An explicit stack also accepts deeply nested legacy snapshots.
        todo = 1
        while todo:
            todo -= 1
            if self.flag():
                if kind == "heap":
                    self.copy(8)
                    self.ticket()
                else:
                    self.copy(28)
                todo += 2

    def graves(self):
        todo = 1
        while todo:
            todo -= 1
            kind = self.word()
            self.out.extend(u32(kind))
            if kind == 2:
                todo += 2
            elif kind == 1:
                self.copy(4)
                while self.flag():
                    self.copy(8)
                    self.ticket()
                    why = self.word()
                    if why > 3:
                        raise ValueError("invalid dead-ticket reason")
                    self.out.extend(u32(why))
                    self.copy(8)
            elif kind != 0:
                raise ValueError("invalid dead-ticket trie kind")

    def breaker(self):
        count = self.word()
        key = self.take(count * 4).decode("utf-32-le").encode("utf-8")
        self.out.extend(u32(len(key)))
        self.out.extend(key)
        kind = self.word()
        self.out.extend(u32(kind))
        if kind == 0:
            count = self.word()
            self.out.extend(u32(count))
            self.copy(count * 8)
        elif kind in (1, 2):
            self.copy(8)
        else:
            raise ValueError("invalid breaker state")

    def convert(self):
        tag = self.word()
        self.out.extend(u32({7: 14, 10: 13}.get(tag, tag)))
        if tag == 1:
            self.copy(8)
            self.payload(len(self.data) - self.at, False)
        elif tag == 10:
            self.breaker()
        elif tag == 7:
            self.copy(8)
            self.tree("heap")
            while self.flag():
                self.ticket()
            self.tree("tries")
            self.graves()
            while self.flag():
                self.breaker()
        elif tag == 8:
            self.copy(8)
            why = struct.unpack("<Q", self.take(8))[0]
            if why > 3:
                raise ValueError("invalid abandon reason")
            self.out.extend(struct.pack("<Q", why))
            self.copy(8)
        elif tag in (2, 3, 4, 5, 6, 9, 11, 12):
            self.copy(16)
        else:
            raise ValueError(f"not a legacy runner tag: {tag}")
        if self.at != len(self.data):
            raise ValueError("trailing runner record bytes")
        return bytes(self.out)


def frames(source, max_record):
    while header := source.read(12):
        if len(header) != 12:
            raise ValueError("torn journal header; recover with the old runner first")
        size, inverse, crc = struct.unpack("<III", header)
        if size ^ inverse != 0xFFFFFFFF:
            raise ValueError("journal length check mismatch")
        if size > max_record:
            raise ValueError("journal record exceeds --max-record")
        data = source.read(size)
        if len(data) != size:
            raise ValueError("torn journal frame; recover with the old runner first")
        if zlib.crc32(data) != crc:
            raise ValueError("journal checksum mismatch")
        yield data


def frame(data):
    size = len(data)
    return struct.pack("<III", size, size ^ 0xFFFFFFFF, zlib.crc32(data)) + data


def migrate(source, destination, decode, encode, max_record):
    destination = Path(destination)
    if not 0 < max_record <= 0xFFFFFFFF:
        raise ValueError("--max-record must be between 1 and 4294967295")
    if os.path.lexists(destination):
        raise FileExistsError(f"destination already exists: {destination}")
    temporary = None
    try:
        with open(source, "rb") as old:
            fd, temporary = tempfile.mkstemp(prefix=destination.name + ".migrate-", dir=destination.parent)
            with os.fdopen(fd, "wb") as new:
                for data in frames(old, max_record):
                    converted = Record(data, decode, encode).convert()
                    if len(converted) > max_record:
                        raise ValueError("converted record exceeds --max-record")
                    new.write(frame(converted))
                new.flush()
                os.fsync(new.fileno())
            # Link publishes the complete file atomically and refuses an existing path.
            os.link(temporary, destination)
            directory = os.open(destination.parent, os.O_RDONLY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)
    finally:
        if temporary is not None:
            os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--codec", type=Path, required=True,
                        help="trusted Python file with decode(bytes) and encode(value) -> bytes")
    parser.add_argument("--max-record", type=int, required=True,
                        help="cap in octets for both input and output records, including snapshots")
    args = parser.parse_args()
    codec = runpy.run_path(str(args.codec))
    migrate(args.source, args.destination, codec["decode"], codec["encode"], args.max_record)


if __name__ == "__main__":
    main()
