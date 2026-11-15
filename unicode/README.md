# unicode

Unicode **17.0.0** in pure Bend: general category, canonical combining class, NFC and NFD (UAX #15), full case folding, and extended grapheme clusters (UAX #29).

```bend
import bend-kit-unicode@0.1.0.0/unicode.bend as U

U.category('A')                # "Lu"
U.nfc("e\u{301}")              # "é"
U.nfd("é")                     # "e\u{301}"
U.fold("Straße")               # "strasse"
U.graphemes("e\u{301}x")       # ["e\u{301}", "x"]
```

Text is a `String` of code points. For octets, decode with `encoding`'s `utf8.decode` first and encode the result with `utf8.encode`.

`category` returns the two-letter UCD alias (`"Cn"` when unassigned). `fold` uses the C and F statuses of `CaseFolding.txt`. It does not apply the Turkic mappings.

| Def | Result | Use |
|---|---|---|
| `ccc(c: Char)` | `U32` | Return the canonical combining class. A starter has class zero. |

## Tables

`tables.bend` is generated. Each property is a balanced tree of comparisons, one def per node, so a lookup costs about 12 comparisons. To move to another Unicode version, change `VERSION` in `gen.py` and run:

```sh
python3 unicode/gen.py          # downloads the UCD to unicode/ucd/ and writes tables.bend
python3 unicode/conformance.py  # the official tests, in a native build (about a minute)
```

`conformance.py` runs every line of `NormalizationTest.txt` for NFC and NFD. It also checks code points not listed in Part 1: each must be its own NFC and NFD. It runs every line of `GraphemeBreakTest.txt`. On 17.0.0 all three report 0 failures. `LAWS.bend` holds a sample of those lines.
