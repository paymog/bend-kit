# migrate

Versioned records for one family: subscriptions. A record arrives as JSON in version 1, 2, or 3. `migrate` validates it, migrates it to the version you need, and encodes it again. The laws prove that each migration keeps what the record means to billing.

```bend
import bend-kit-migrate@0.1.0.0/migrate.bend as M
```

It imports `bend-kit-json@0.6.1.1`, `bend-kit-bytes@0.3.2.0`, and `bend-kit-encoding@0.4.0.0`. Decode takes and encode gives UTF-8 `Bytes.Bytes`.

The package is one worked family, not a schema language. To version another record family, copy this package and replace the types, the terms, and the migrations.

## Example

A billing job reads records that old writers stored, and bills them with v3 rules.

```bend
import Base
import bend-kit-json@0.6.1.1/json.bend as Json
import bend-kit-migrate@0.1.0.0/migrate.bend as M

def bill(p: M.V3 & M.Dropped) -> String:
  (M.V3{i, plan, c, pe, s}, d) = p
  "#" ++ U32.show(i) ++ " " ++ plan ++ " " ++ U32.show(c) ++ " " ++ M.Period.name(pe) ++ " " ++ M.Status.name(s)

def read(r: Result<&2, &2, M.Error, M.Record>) -> String:
  match r:
    case Fail{e}:
      "rejected"
    case Done{x}:
      bill(M.Record.upgrade(x))

def main() -> IO(Unit):
  IO.print(read(M.decode(Json.utf8("{\"version\":1,\"id\":7,\"plan\":\"pro\",\"monthly_cents\":1200,\"active\":true}"))))
```

It prints `#7 pro 1200 monthly active`. [check.bend](check.bend) runs supported, malformed, unsupported, and lossy records through the same path, then checks that each error and each billed line is the expected one.

## The record family

| version | JSON fields | meaning |
|---|---|---|
| 1 | `version`, `id`, `plan`, `monthly_cents`, `active` | A monthly price. `active: false` means cancelled; v1 had no pause. |
| 2 | `version`, `id`, `plan`, `cents`, `period`?, `status`, `note`? | A price per period (`monthly` or `yearly`), a status (`active`, `paused`, or `cancelled`), and a free-text support note. `period` defaults to `monthly`; `note` defaults to `""`. |
| 3 | `version`, `id`, `plan`, `cents`, `period`, `status` | v2 without the note. `period` is required. |

`Terms{id, plan, cents, period, status}` is what a record means to billing. `V1.terms`, `V2.terms`, and `V3.terms` give the terms of each version. The author chose these meanings, such as "an inactive v1 subscription is cancelled". A proof shows that migrations keep the terms; it cannot show that the terms are the right ones.

The business rules: `plan` is not empty, and `cents` is not zero. `Terms.problem` names the first rule a record breaks.

## Migrations

| def | from → to | kind |
|---|---|---|
| `V1.up(r) -> V2` | 1 → 2 | Total. Sets `period` to monthly, `status` to active or cancelled, and `note` to `""`. |
| `V2.down(r) -> Result<&2, &2, Error, V1>` | 2 → 1 | Partial. Succeeds exactly when the record is monthly, not paused, and has no note. Otherwise `NotInV1{field}`. |
| `V2.up(r) -> V3 & Dropped` | 2 → 3 | Lossy. Drops the note and returns it as `Dropped{note}`. |
| `V3.restore(r, d) -> V2` | 3 → 2 | Puts a dropped note back. |
| `V3.down(r) -> V2` | 3 → 2 | Total. The note is `""`. |
| `Record.upgrade(r) -> V3 & Dropped` | any → 3 | The chain: v1 goes through v2. |

## Wire contract

`decode(b)` reads one JSON object with `Json.parse.strict.bytes(b, 1)`. `decode.val(v)` reads one already-parsed `Json.Val`. Both return `Result<&2, &2, Error, Record>`, where `Record` is `R1{V1}`, `R2{V2}`, or `R3{V3}`: the record in the version it was written in.

| input | error |
|---|---|
| Not JSON, invalid UTF-8, not an object, or a field nested more than one level | `Malformed{}` |
| No `version` | `Missing{"version"}` |
| A `version` other than 1, 2, or 3 | `Unsupported{version}` |
| A field the version does not define | `Unknown{field}` |
| A field that appears twice | `Duplicate{field}` |
| A required field missing | `Missing{field}` |
| A wrong JSON type, a number that is not a whole `U32`, or an unknown `period` or `status` | `BadField{field}` |
| An empty `plan` or a zero price | `Invalid{field}` |

Unknown fields are errors, not ignored: every version's fields are known, so an extra field means a writer bug, and ignoring it would drop data without a trace. Decode checks the fields first, then the business rules.

`encode(r)` writes the record in its own version, with fields in the order of the table above. v2 always writes `period` and `note`.

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
| `up_down3` | `V2.up(V3.down(r))` is `r`, with an empty note dropped. |

Equality in the laws is equality of the record values: the same `U32`s, the same strings code point by code point, and the same constructors.

## Trust boundary

- **Meaning.** The terms are the author's claim about what each version means. The laws cover only what the terms say.
- **Codec.** The laws about decode prove that only valid records come out. They do not prove that decode reads the right fields, or that `decode(encode(r))` is `r`. `check.bend` tests those at runtime, and the JSON parser and encoder are `bend-kit-json`'s.
- **Strings.** Keys and string values are UTF-8 decoded with `bend-kit-encoding`. The strict parser has already rejected invalid UTF-8.
- **Numbers.** `id` and the price are whole `U32`s. A larger number, a fraction, or a negative number is `BadField`.

## Checks

`bend PROOF.bend --check-only` proves the laws. `bend check.bend` decodes 24 JSON records, upgrades each to v3, and has a billing consumer print what it does with each. It checks:

- v1, v2 (with and without defaults, yearly, paused, with a note and with UTF-8 text), and v3 records bill as their meaning says, and the dropped note is reported;
- malformed JSON, a non-object, nesting, missing and unknown fields, a duplicate key, wrong types, and out-of-range numbers fail with the expected error;
- an empty plan and a zero price fail as invalid; versions 0 and 4 are unsupported;
- each version encodes, decodes, and encodes to the same bytes;
- a v3 record downgrades to v1 when v1 can hold it, and fails with the field that v1 cannot hold otherwise.

`bench/` times decode, upgrade, and encode of 20,000 records against C, Rust, JavaScript, and Python. See [bench/README.md](bench/README.md).
