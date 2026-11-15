# migrate

Versioned records for one family: subscriptions. A record arrives as JSON in version 1, 2, or 3. `migrate` validates it, migrates it to the version you need, and encodes it again. The laws prove that each migration keeps what the record means to billing, and that decoding an encoded record gives it back.

```bend
import bend-kit-migrate@0.3.0.0/migrate.bend as M
```

It imports `bend-kit-json@0.7.0.0` and `bend-kit-bytes@0.3.3.0`. Everything is bytes: decode takes and encode gives UTF-8 `Bytes.Bytes`, and the text fields of a record (`plan` and the note) are `Bytes.Bytes` too. Convert to `String` only at the edge, to print.

The package is one worked family, not a schema language. To version another record family, copy this package and replace the types, the terms, and the migrations.

## Example

A billing job reads records that old writers stored, and bills them with v3 rules.

```bend
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-json@0.7.0.0/json.bend as Json
import bend-kit-migrate@0.3.0.0/migrate.bend as M

def bill(p: M.V3 & M.Dropped) -> String:
  (M.V3{i, plan, c, pe, s}, d) = p
  "#" ++ U32.show(i) ++ " " ++ Bytes.to_string(plan) ++ " " ++ U32.show(c) ++ " " ++ Bytes.to_string(M.Tag.bytes(M.Period.tag(pe)))

def read(r: Result<&1, &1, M.Error, M.Record>) -> String:
  match r:
    case Fail{e}:
      "rejected"
    case Done{x}:
      bill(M.Record.upgrade(x))

def main() -> IO(Unit):
  IO.print(read(M.decode(Json.utf8("{\"version\":1,\"id\":7,\"plan\":\"pro\",\"monthly_cents\":1200,\"active\":true}"))))
```

It prints `#7 pro 1200 monthly`. `Bytes.to_string` gives one `Char` per octet; decode UTF-8 with `bend-kit-encoding` when a plan can hold non-ASCII text, as [check.bend](check.bend) does. That file runs supported, malformed, unsupported, and lossy records through the same path, then checks that each error and each billed line is the expected one.

## The record family

| version | JSON fields | meaning |
|---|---|---|
| 1 | `version`, `id`, `plan`, `monthly_cents`, `active` | A monthly price. `active: false` means cancelled; v1 had no pause. |
| 2 | `version`, `id`, `plan`, `cents`, `period`?, `status`, `note`? | A price per period (`monthly` or `yearly`), a status (`active`, `paused`, or `cancelled`), and an optional support note. An absent `period` is `monthly`. An absent `note` is `None{}`, which differs from `Some{""}`. |
| 3 | `version`, `id`, `plan`, `cents`, `period`, `status` | v2 without the note. `period` is required. |

`Terms{id, plan, cents, period, status}` is what a record means to billing. `V1.terms`, `V2.terms`, and `V3.terms` give the terms of each version. The author chose these meanings, such as "an inactive v1 subscription is cancelled". A proof shows that migrations keep the terms; it cannot show that the terms are the right ones.

The business rules: `plan` is not empty, and `cents` is not zero. `Record.problem` names the first rule a record breaks, and gives the record back.

Records, `Terms`, `Dropped`, `Error`, and `Scalar` hold `Bytes`, so they are `Type`: use each value once, and write `Result<&1, &1, M.Error, …>`.

## Migrations

| def | from → to | kind |
|---|---|---|
| `V1.up(r) -> V2` | 1 → 2 | Total. Sets `period` to monthly, `status` to active or cancelled, and `note` to `None{}`. |
| `V2.down(r) -> Result<&1, &1, Error, V1>` | 2 → 1 | Partial. Succeeds exactly when the record is monthly, not paused, and has no note. Otherwise `NotInV1{key}`. |
| `V2.up(r) -> V3 & Dropped` | 2 → 3 | Lossy. Drops the note and returns it as `Dropped{note}`. |
| `V3.restore(r, d) -> V2` | 3 → 2 | Puts a dropped note back. |
| `V3.down(r) -> V2` | 3 → 2 | Total. The note is `None{}`. |
| `Record.upgrade(r) -> V3 & Dropped` | any → 3 | The chain: v1 goes through v2. |

## Wire contract

`decode(b)` reads one JSON object with `Json.parse.strict.bytes(b, 1)`. `decode.val(v)` reads one already-parsed `Json.Val`. Both return `Result<&1, &1, Error, Record>`, where `Record` is `R1{V1}`, `R2{V2}`, or `R3{V3}`: the record in the version it was written in.

Decode walks the object's fields once. It files each value under its `Key`, then the version picks which keys it allows. Keys and the `period` and `status` names are compared as a `Tag`: the length and the first four packed words of the bytes, against constants. Numbers keep their digit bytes until the record is built, then `u32.read` reads them.

| input | error |
|---|---|
| Not JSON, invalid UTF-8, not an object, or a field nested more than one level | `Malformed{}` |
| A key that no version defines | `Unknown{key}`, with the key's bytes |
| A key that appears twice | `Duplicate{key}` |
| No `version` | `Missing{KVersion{}}` |
| A `version` other than 1, 2, or 3 | `Unsupported{version}` |
| A key that another version defines | `Unexpected{key}` |
| A required field missing | `Missing{key}` |
| A wrong JSON type, a number that is not a whole `U32`, or an unknown `period` or `status` | `BadField{key}` |
| An empty `plan` or a zero price | `Invalid{key}` |

Unknown and unexpected fields are errors, not ignored: every version's fields are known, so an extra field means a writer bug, and ignoring it would drop data without a trace.

`encode(r)` writes the record in its own version, with fields in the order of the table above. v2 always writes `period`, and writes `note` only when it is `Some`. `u32.text(n)` writes a number as decimal digit bytes.

## Laws

`LAWS.bend` states these for every record. `PROOF.bend` proves them.

| law | claim |
|---|---|
| `up1_terms`, `up2_terms`, `down3_terms` | `V1.up`, `V2.up`, and `V3.down` keep the terms. |
| `down2_terms` | When `V2.down` succeeds, the v1 record has the same terms. |
| `upgrade_terms` | `Record.upgrade` keeps the terms of a record of any version. |
| `upgrade_valid` | A valid record of any version upgrades to a valid v3 record. |
| `decode_valid`, `decode_val_valid` | Decode returns an error or a valid record, for every input. |
| `chain_v1` | v1 through v2 to v3 equals the direct v1 meaning (monthly; active or cancelled), and drops nothing. |
| `chain_v2`, `chain_v3` | `upgrade` of v2 is `V2.up`; `upgrade` of v3 is the record itself, with nothing dropped. |
| `down_up1` | `V2.down(V1.up(r))` is `r` for every v1 record. |
| `up_down2` | When `V2.down(r)` gives `s`, `V1.up(s)` is `r`. |
| `down2_domain` | `V2.down` succeeds exactly on monthly, unpaused records with no note. |
| `up2_restore`, `up2_dropped` | `V2.up` drops exactly the note: with it, `V3.restore` gives the v2 record back. |
| `up2_forgets_note` | Two v2 records that differ only in their notes upgrade to the same v3 record, so v2 to v3 is not reversible. |
| `up_down3` | `V2.up(V3.down(r))` is `r`, with no note dropped. |
| `key_roundtrip`, `period_roundtrip`, `status_roundtrip` | Every key and name the encoder writes is the one the decoder finds. |
| `shape_roundtrip` | `decode.shape(Record.json(r))` is `Done{r}` for every record of every version. |
| `val_roundtrip` | `decode.val(Record.json(r))` is `Done{r}` for every valid record. |

Equality in the laws is equality of the record values: the same `U32`s, the same `Bytes` values, and the same constructors.

`shape_roundtrip` and `val_roundtrip` take one hypothesis: the decimal codec gives every `U32` back, `u32.read(u32.text(n)) == Some{n}`. The laws prove everything else about the round trip: keys, versions, field order, defaults, the unknown, duplicate, and unexpected checks, strings, flags, periods, and statuses.

## Trust boundary

- **Meaning.** The terms are the author's claim about what each version means. The laws cover only what the terms say.
- **Decimal digits.** No law proves `u32.read(u32.text(n)) == Some{n}` for every `n`. Bend has no laws yet for `U32` division and bit shifts, or for `Bytes` with a length that is not a constant. `check.bend` writes and reads back every `n` below 20,000, the 10,000 values below `2^32`, and the values on each side of 10^5 and 10^9.
- **JSON text.** The laws work on `Json.Val`. Parsing and printing JSON text is `bend-kit-json`'s, and `check.bend` tests `decode(encode(r))` on bytes for each version.
- **Key constants.** The `Tag` constants are the packed words of the key names. `key_roundtrip` proves the encoder and the decoder agree; `check.bend` proves that they match the JSON text other writers produce.

## Checks

`bend PROOF.bend --check-only` proves the laws. `bend check.bend` decodes 26 JSON records, upgrades each to v3, and has a billing consumer print what it does with each. It checks:

- v1, v2 (with and without defaults, yearly, paused, with a note, with an empty note, and with UTF-8 text), and v3 records bill as their meaning says, and the dropped note is reported;
- malformed JSON, a non-object, nesting, missing, unknown, and unexpected fields, a duplicate key, wrong types, and out-of-range numbers fail with the expected error;
- an empty plan and a zero price fail as invalid; versions 0 and 4 are unsupported;
- each version encodes, decodes, and encodes to the same bytes;
- a v3 record downgrades to v1 when v1 can hold it, and fails with the field that v1 cannot hold otherwise;
- `u32.read` rejects an empty string, a leading zero, a sign, a letter, and values of `2^32` and above, and reads back what `u32.text` writes over the ranges above.

`bench/` times decode, upgrade, and encode of 20,000 records against C, Rust, JavaScript, and Python. See [bench/README.md](bench/README.md).
