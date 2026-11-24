#!/usr/bin/env python3
"""Run with python3 runner/migrate-test.py. Bend checks actual pre-recovery replay."""

from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import migrate

ROOT = Path(__file__).resolve().parent


def q(n):
    return struct.pack("<Q", n)


def words(*ns):
    return b"".join(migrate.u32(n) for n in ns)


def payload(text, legacy):
    return text.encode("utf-16-le" if legacy else "utf-8")


def ticket(i, text, legacy):
    data = payload(text, legacy)
    return q(i) + q(100 + i) + words(len(data)) + data


def breaker(key, kind, values, legacy):
    target = key.encode("utf-32-le" if legacy else "utf-8")
    size = len(key) if legacy else len(target)
    state = words(kind, len(values)) if kind == 0 else words(kind)
    return words(size) + target + state + b"".join(q(v) for v in values)


BREAKERS = [("café", 0, [11, 12]), ("東京", 1, [900]), ("🚀", 2, [3]), ("", 0, [])]


def snapshot(legacy):
    heap = words(1) + q(1) + ticket(2, "pending λ", legacy) + words(0, 0)
    running = words(1) + ticket(1, "running λ", legacy) + words(0)
    tries = (words(1, 2) + q(1) + q(4) + q(101) + words(0, 1, 1)
             + q(2) + q(5) + q(102) + words(0, 0))
    dead = (words(1, 0, 1) + q(0) + ticket(0, "dead λ", legacy)
            + words(3) + q(200) + words(0))
    breakers = b"".join(words(1) + breaker(*b, legacy) for b in BREAKERS) + words(0)
    return words(7 if legacy else 14) + q(3) + heap + running + tries + dead + breakers


def operations(legacy):
    def small(tag, a=0, b=0):
        return words(tag) + q(a) + q(b)
    records = [words(1) + q(100 + i) + payload(text, legacy)
               for i, text in enumerate(["dead λ", "running λ", "pending λ"])]
    records += [small(2, 100), small(8, 0, 3) + q(200), small(2, 101)]
    records += [words(10 if legacy else 13) + breaker(*b, legacy) for b in BREAKERS]
    return records


def journal(records):
    return b"".join(migrate.frame(r) for r in records)


def decode(data):
    return data.decode("utf-16-le")


def encode(value):
    return value.encode("utf-8")


class Migration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory()
        cls.binary = Path(cls.build.name) / "migration-check"
        subprocess.run(["bend", str(ROOT / "migration-check.bend"), "-o", str(cls.binary)], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.build.cleanup()

    def test_replay_and_source_unchanged(self):
        for legacy, current in [([snapshot(True)], [snapshot(False)]),
                                (operations(True), operations(False)),
                                ([snapshot(True)] + operations(True)[-4:],
                                 [snapshot(False)] + operations(False)[-4:])]:
            with self.subTest(snapshot=len(legacy) == 1), tempfile.TemporaryDirectory() as directory:
                old, new, expected = [Path(directory) / n for n in ("old", "new", "expected")]
                original = journal(legacy)
                old.write_bytes(original)
                expected.write_bytes(journal(current))
                migrate.migrate(old, new, decode, encode, 1048576)
                self.assertEqual(old.read_bytes(), original)
                self.assertEqual(new.read_bytes(), expected.read_bytes())
                subprocess.run([str(self.binary), str(new), str(expected)], check=True)

    def test_small_records(self):
        for tag in (2, 3, 4, 5, 6, 9, 11, 12):
            record = words(tag) + q(4) + q(9)
            self.assertEqual(migrate.Record(record, decode, encode).convert(), record)

    def test_cli_with_caller_codec(self):
        with tempfile.TemporaryDirectory() as directory:
            old, new, codec = [Path(directory) / n for n in ("old", "new", "codec.py")]
            old.write_bytes(journal(operations(True)))
            codec.write_text("def decode(data):\n return data.decode('utf-16-le')\ndef encode(value):\n return value.encode('utf-8')\n")
            subprocess.run(["python3", str(ROOT / "migrate.py"), str(old), str(new),
                            "--codec", str(codec), "--max-record", "1048576"], check=True)
            self.assertEqual(new.read_bytes(), journal(operations(False)))

    def test_invalid_input_never_publishes(self):
        valid = journal(operations(True))
        bad_crc = bytearray(valid)
        bad_crc[8] ^= 1
        bad_length = bytearray(valid)
        bad_length[4] ^= 1
        invalid = [valid[:-1], valid + b"x", bytes(bad_crc), bytes(bad_length),
                   migrate.frame(words(10) + words(1, 0xD800, 1) + q(3)),
                   migrate.frame(words(10) + breaker("a", 1, [3], True) + b"x"),
                   migrate.frame(words(99)), migrate.frame(snapshot(True)[:-1])]
        with tempfile.TemporaryDirectory() as directory:
            old, new = [Path(directory) / n for n in ("old", "new")]
            for data in invalid:
                with self.subTest(data=data[:16]):
                    old.write_bytes(data)
                    with self.assertRaises((ValueError, UnicodeError)):
                        migrate.migrate(old, new, decode, encode, 1048576)
                    self.assertFalse(new.exists())
                    self.assertEqual(old.read_bytes(), data)
                    self.assertEqual(sorted(p.name for p in Path(directory).iterdir()), ["old"])

    def test_limits_and_codec_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            old, new = [Path(directory) / n for n in ("old", "new")]
            old.write_bytes(journal(operations(True)))
            for limit, decoder, encoder in [(1, decode, encode), (0, decode, encode),
                                             (1048576, lambda b: 1 / 0, encode),
                                             (1048576, decode, lambda s: "not bytes"),
                                             (128, decode, lambda s: b"x" * 129)]:
                with self.assertRaises((ValueError, ZeroDivisionError)):
                    migrate.migrate(old, new, decoder, encoder, limit)
                self.assertFalse(new.exists())

    def test_existing_paths_and_publish_race(self):
        with tempfile.TemporaryDirectory() as directory:
            old, new = [Path(directory) / n for n in ("old", "new")]
            original = journal(operations(True))
            old.write_bytes(original)
            with self.assertRaises(FileExistsError):
                migrate.migrate(old, old, decode, encode, 1048576)
            new.symlink_to(old)
            with self.assertRaises(FileExistsError):
                migrate.migrate(old, new, decode, encode, 1048576)
            new.unlink()
            link = migrate.os.link
            def race(source, destination):
                Path(destination).write_bytes(b"other writer")
                link(source, destination)
            with patch.object(migrate.os, "link", race), self.assertRaises(FileExistsError):
                migrate.migrate(old, new, decode, encode, 1048576)
            self.assertEqual(new.read_bytes(), b"other writer")
            self.assertEqual(old.read_bytes(), original)

    def test_interrupted_conversion(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            old, new, codec = [directory / n for n in ("old", "new", "codec.py")]
            original = journal(operations(True))
            old.write_bytes(original)
            codec.write_text("import time\ndef decode(data):\n print('ready', flush=True)\n time.sleep(60)\ndef encode(value):\n return b''\n")
            process = subprocess.Popen(["python3", str(ROOT / "migrate.py"), str(old), str(new),
                                        "--codec", str(codec), "--max-record", "1048576"],
                                       stdout=subprocess.PIPE, text=True)
            try:
                self.assertEqual(process.stdout.readline().strip(), "ready")
                self.assertFalse(new.exists())
            finally:
                process.kill()
                process.wait()
                process.stdout.close()
            self.assertFalse(new.exists())
            self.assertEqual(old.read_bytes(), original)
            migrate.migrate(old, new, decode, encode, 1048576)
            self.assertEqual(new.read_bytes(), journal(operations(False)))


if __name__ == "__main__":
    unittest.main()
