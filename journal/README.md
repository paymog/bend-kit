# journal

An append-only journal: checksummed frames, fsync'd appends, and crash recovery of the committed prefix. Use one to keep local state durable, such as a task list, a queue's progress, or applied commands.

```bend
import bend-kit-journal@0.1.0.0/journal.bend as J
```

It imports `bend-kit-hash@0.1.0.0` and `bend-kit-bytes@0.3.0.0` (`0x49814d83de8f70993a43e1002be29ecd/bytes.bend`). Payloads are that version's `Bytes`.

## Example

A durable task list. Each record is `add <task>` or `done <task>`, and `open` folds them into the open tasks.

```bend
import Base
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import bend-kit-journal@0.1.0.0/journal.bend as J

def without(xs: List<&2, String>, +x: String) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      +rest = without(t, x)
      Bool.pick(List<&2, String>, String.eq(h, x), rest, Con{h, rest})

def task(ts: List<&2, String>, p: Bytes.Bytes) -> List<&2, String>:
  +open = ts
  +s = Bytes.to_string(p)
  Bool.pick(List<&2, String>, String.starts_with(s, "add "), List.append(&2, String, open, [String.drop(s, 4n)]),
    Bool.pick(List<&2, String>, String.starts_with(s, "done "), without(open, String.drop(s, 5n)), open))

def added(r: J.Journal & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match r:
    case (j, x):
      do IO<Unit>:
        J.close(j)
        u : Unit <- IO.try(Unit, IO.pure(Result<&1, &1, U32 & String, Unit>, x))
        return Unit{}

def opened(a: J.Journal & List<&2, String>) -> IO(Unit):
  match a:
    case (j, ts):
      do IO<Unit>:
        IO.print("open: " ++ String.join(ts, ", "))
        r : J.Journal & Result<&1, &1, U32 & String, Unit> <- J.append(j, Bytes.from_string("add write the docs"))
        added(r)

def main() -> IO(Unit):
  do IO<Unit>:
    a : J.Journal & List<&2, String> <- IO.try(J.Journal & List<&2, String>, J.open(~List<&2, String>, ~task, "tasks.journal", 1024, 16777216, Nil{}))
    opened(a)
```

Each run prints the open tasks and adds one. The record is on disk when `append` answers `Done`.

## API

| def | does |
|---|---|
| `open(~A, ~step, path, max, limit, acc)` | Opens or creates `path`, then folds `step` over its committed records from `acc`. Answers `Done{(journal, state)}`. |
| `append(j, p)` | Writes `p` as one frame, then fsyncs. Answers `Done` once the frame is durable. |
| `close(j)` | Closes the file. |
| `frame(p)` | The octets that `append(j, p)` writes. |
| `replay.bytes(~A, ~step, max, b, acc)` | The pure fold that `open` runs over a buffer. Answers `Replay{state, tail, Cur{b, end}}`. |

`max` caps a record's length in octets. `limit` caps the file size that `open` reads. `open` fails when:

- the file is larger than `limit`: `EFBIG`.
- a frame is corrupt: `EINVAL` (22), with the frame's offset and why. The file is not changed.

`append` fails without a write for a record over `max` (22), or when the file would reach 4 GiB (27). After any other failure, the journal refuses appends until you close and reopen it.

## Format

A frame is one record and one commit:

| octets | field |
|---|---|
| 0–3 | `len`, u32 little-endian |
| 4–7 | `U32.not(len)` |
| 8–11 | CRC-32 (ISO-HDLC, as zlib) of the payload |
| 12– | `len` payload octets |

Recovery reads frames from offset 0. Each one ends in one of four ways:

| ends with | tail | open does |
|---|---|---|
| no octets left | `Clean` | answers |
| fewer octets than the frame needs | `Torn` | truncates the file to the last whole frame, fsyncs, and answers |
| length fields that disagree, a length over `max`, or a CRC mismatch | `Corrupt{why}` | fails and leaves the file as it is |

Both length fields are checked before the payload is awaited. So a damaged length is `Corrupt`, not a torn tail that would cut off the frames after it.

## Laws

`LAWS.bend` states these over a list model of the decoder. `PROOF.bend` proves them.

| law | claim |
|---|---|
| `roundtrip` | Recovering the frames of any records, each at most `max`, gives those records and `Clean`. |
| `torn` | Records, then any proper nonempty prefix of one more frame: recovery gives exactly the records, `Torn`, and the cut frame as rest. The cut record is never applied. |
| `bad_sum` | A whole frame whose payload fails its CRC is `Corrupt` at its offset, whatever follows it. |
| `bad_len` | Length fields that disagree are `Corrupt` at their offset, whatever follows them. |
| `over_max` | A length over `max` is `Corrupt` at its offset, whatever follows it. |
| `slices` | For every input, the input is each recovered record after a header, in order, then rest. Recovery keeps order and invents nothing. |
| `replay` | For every input, `replay` equals a left fold of `step` over the recovered records. It ends with the same tail and rest. |

The model and `Bytes` run the same generic decoder, `next`, with different input operations. They differ in two ways, and the proofs do not cover either:

- A model header field is four cells: the value, then three zeros. `Bytes` reads four little-endian octets with `Bytes.get.u32le`. Offsets agree. `check.bend` tests the octet layout.
- The model's checksum is a bitwise CRC-32 over a list. `Bytes` uses `Hash.crc32`. `check.bend` tests that they agree on the CRC-32 check value. The proofs use no property of the checksum except that a value equals itself.

## Trust boundary

- **Failure model.** A crash leaves a prefix of the octets written. Appends land at the end of the file (`O_APPEND`) and are not reordered. Under that model, a crash during an append gives `Torn`, and every frame before it is whole. A file system that leaves garbage or zeros after a crash (ext4 `data=writeback`, for example) can give `Corrupt` instead. `open` then refuses the file rather than guess. Zeros are `Corrupt`, because `len` 0 needs `U32.not(0)` beside it.
- **Durability.** `append` answers `Done` only after `fsync` returns. The C lane uses `F_FULLFSYNC` on macOS and falls back to `fsync` when the file system refuses it. The JS lane (`bend file.bend`, `-o x.js`) calls `fsync`, which on macOS does not flush the drive's cache. `open` fsyncs the file's directory, so a new file's name is durable too. A device or file system that lies about `fsync` breaks the guarantee.
- **What the tests show.** `check.bend` restarts the process, cuts a real file, and reopens it. That shows recovery and truncation, not power-loss durability. Power-loss durability rests on `fsync` and the device.
- **Checksums.** CRC-32 detects accidental damage: every burst of up to 32 bits, and other errors with probability about 1 − 2⁻³². It does not resist a deliberate change. Anyone who can write the file can forge a frame.
- **After a failed append.** The frame may be partly or wholly on disk, so it may or may not come back at the next open. The journal refuses appends until it is reopened. Then recovery decides: a whole frame is kept, and a torn frame is cut off.
- **One writer.** Nothing locks the file. Two processes appending to one journal can interleave frames.
- **Size.** Offsets are `U32`, so a journal stays under 4 GiB. `open` reads the whole file into memory.

## Checks

`bend check.bend` runs the pure checks and the file scenario on the JS lane. `scripts/native-check.sh journal` runs the same file natively. The pure checks:

- every cut of a 3-record log, at all 50 offsets, recovers exactly its committed prefix;
- damaged payloads, damaged lengths, lengths over `max`, and zero-filled tails are each `Corrupt`;
- frame octets match the format above.

The file scenario appends and reopens the task list, adds a torn append by hand, then reopens and appends again. It then overwrites the file with a corrupt frame and confirms that `open` refuses it twice with the same error. `bench/` times recovery against C, Rust, Python, and JavaScript. See [bench/README.md](bench/README.md).
