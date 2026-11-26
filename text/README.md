# text

Myers diff with unified output, Levenshtein distance, and word wrap by display width. Pure Bend.

```bend
import bend-kit-text@0.2.2.3/text.bend as Text
```

`text.bend` imports `bend-kit-unicode@0.1.0.0/unicode.bend`, `bend-kit-tty@0.1.0.2/text.bend`, and `bend-kit-bytes@0.3.3.2/bytes.bend`.

```bend
def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Text.unified("old.txt", "new.txt", Text.diff_lines("a\nb\nc\n", "a\nB\nc\n"), 3))
    IO.print(U32.show(Text.distance("kitten", "sitting")))
    IO.print(String.join(Text.wrap("The quick brown fox jumps over the lazy dog.", 16), "\n"))
```

## Diff

`diff(~A, ~eq, a, b)` returns a shortest edit script from list `a` to list `b`, as a `List<&2, Edit<A>>`. `eq` decides which items match. It copies both lists into arrays, strips the common prefix and suffix, then runs Myers' O(ND) algorithm with his linear-space refinement: it finds the middle of a shortest path from both ends and splits there. Time grows with the input length times the number of edits D, and memory with the input length alone. Two unrelated 10,000-line lists of strings (D = 20,000) take about 2 s and 7 MB natively. In each run of changes, deletes come before inserts.

An `Edit<A>` is `Same{old, new}`, `Del{old}`, or `Ins{new}`. `Same` holds both items, so an `eq` that matches unequal items loses nothing. `before(A, es)` gives the old list back and `after(A, es)` gives the new list. `PROOF.bend` proves `before(diff(a, b)) == a` and `after(diff(a, b)) == b` for every `eq`, `a`, and `b`. `check.bend` compares the script length with a dynamic-programming bound on 3,000 random pairs.

`diff_by(~A, ~eq, ~key, a, b)` gives a script of the same length, faster. Myers compares the `U32` keys of the items. Then `eq` checks every pair that the script matches. If two unequal items share a key and get matched, `diff_by` runs `diff` instead. Equal items must have equal keys. Use it when `eq` is slow, as it is for strings: an item read from the array is shared, so `String.eq` pays a reference count for each char it reads. The two unrelated 10,000-line lists take 0.17 s with `diff_by(~String, ~String.eq, ~fnv, a, b)`. `fnv(s)` is the 32-bit FNV-1a hash of a string.

`diff_lines(a, b)` is `diff_by` over the lines of two strings, keyed by `fnv`. `diff_chars(a, b)` diffs their code points. `lines(s)` keeps each line's `"\n"`, so only the last line can lack one: `"a\nb"` is `["a\n", "b"]`. Joining the lines gives `s` back, and `PROOF.bend` proves that joining the new side of `diff_lines(a, b)` gives `b`. A line that gains or loses its final newline is a changed line.

`unified(old_name, new_name, es, ctx)` prints `diff -U<ctx>` text for a line script: the `---` and `+++` headers, then each hunk with `ctx` lines of context. Two changes share a hunk when at most `2 * ctx` unchanged lines separate them. A line without `"\n"` gets `\ No newline at end of file` after it. It returns `""` when nothing changed. The headers have no timestamps. Pass a script whose lines end with `"\n"` except the last, as `diff_lines` makes.

### Packed input and byte ranges

`diff_bytes(old, new)` consumes two `Bytes.Bytes` buffers and returns
`Bytes.Bytes & Bytes.Bytes & List<&2, Edit<ByteRange>>`. The first two values
are the unchanged owned old and new buffers. `ByteRange{offset, length, key}`
uses zero-based byte offsets and byte lengths. Its key is 32-bit FNV-1a over
the line's octets. `Same{old, new}` keeps a range into each respective buffer.
`Del` refers to the old buffer, and `Ins` refers to the new buffer.
Keep each buffer until you finish reading its ranges.

The scan reads packed bytes by index. It creates one range and hash per line,
not one String cell per character. Myers compares the hashes, then the byte
ranges verify every match. A hash collision falls back to exact packed-word
lists and a new Myers run. Each list includes the byte length and partial word.
The result is a shortest line script, with deletes before inserts.
The String API and its laws do not change.

Empty input has no lines. LF (byte 10) ends a line and stays in its range.
Repeated LFs produce separate lines. A final LF does not add an empty line.
CR is an ordinary byte, so CRLF stays intact. A missing final LF changes that
line. UTF-8 is not decoded or normalized. Invalid UTF-8, NUL, and all other
octets are preserved. Convert Unicode text to UTF-8 before calling this API;
`Bytes.from_string` in this example treats each character as one octet.

This complete caller materializes only the first old line:

```bend
import Base
import bend-kit-text@0.2.2.3/text.bend as Text
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes

def print_part(r: Bytes.Bytes & Bytes.Bytes) -> IO(Unit):
  (old, part) = r
  IO.print(Bytes.to_string(part))

def print_first(rs: List<&2, Text.ByteRange>, old: Bytes.Bytes) -> IO(Unit):
  match rs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{Text.ByteRange{offset, length, _}, _}:
      print_part(Bytes.slice(old, offset, length))

def show_old(r: Bytes.Bytes & Bytes.Bytes & List<&2, Text.Edit<Text.ByteRange>>) -> IO(Unit):
  (old, new, edits) = r
  print_first(Text.before(Text.ByteRange, edits), old)

def main() -> IO(Unit):
  show_old(Text.diff_bytes(Bytes.from_string("a\nb\n"), Bytes.from_string("a\nB\n")))
```

The benchmark reports conversion, packed diff, and optional full
materialization separately. The packed result does not satisfy the separate
String benchmark target in issue #820.


## Distance

`distance(a, b)` is the Levenshtein distance by code point: the fewest inserts, deletes, and substitutions that turn `a` into `b`. `edit_distance(~A, ~eq, a, b)` does the same for any list. It takes O(len(a) × len(b)) time and O(len(b)) space. A command line can rank its "did you mean" suggestions by it.

## Wrap

`wrap(text, width)` breaks text into lines of at most `width` display columns, greedily. Runs of whitespace separate words, and a line joins its words with one space. A cluster that spans a join counts right: a space followed by VS16 is one 2-column cluster. A word wider than `width` breaks between grapheme clusters. A cluster wider than `width`, such as a wide CJK character with `width` 1, stays whole on its own line.

`wrap` adds a word's width to the line's width when a cluster boundary falls between the line and the joining space. Only a line that ends in a Prepend character, such as U+0600, lacks one; then `wrap` measures the candidate line whole. A printable ASCII word after a printable ASCII line needs no segmentation: its width is its length. Then `wrap` checks every line. If one is too wide, it wraps again and measures every candidate line whole, as `wrap.slow` does. `check.bend` compares the two on 3,000 random texts of combining marks, VS16, ZWJ, wide, Prepend, and spacing-mark characters.

Display width comes from `tty`: East Asian Wide and Fullwidth clusters take 2 columns, combining marks 0, and Ambiguous characters 1. Escape sequences are not stripped, so wrap text before you style it.

| def | returns |
|---|---|
| `diff(~A, ~eq, a, b)` | A shortest edit script from `a` to `b`. |
| `diff_by(~A, ~eq, ~key, a, b)` | The same, comparing `U32` keys first. |
| `fnv(s: String)` | The 32-bit FNV-1a hash of `s`, as `U32`. |
| `diff_lines(a: String, b: String)` | The line script, as `List<&2, Edit<String>>`. |
| `diff_chars(a: String, b: String)` | The code point script, as `List<&2, Edit<Char>>`. |
| `diff_bytes(a: Bytes.Bytes, b: Bytes.Bytes)` | Both owned buffers and a line script of `ByteRange` values. |
| `before(A, es)`, `after(A, es)` | The old or new list of a script. |
| `unified(old_name, new_name, es, ctx: U32)` | Unified diff text. |
| `lines(s: String)` | The lines of `s`, each with its `"\n"`. |
| `distance(a: String, b: String)` | The Levenshtein distance, as `U32`. |
| `edit_distance(~A, ~eq, a, b)` | The Levenshtein distance of two lists. |
| `wrap(text: String, width: U32)` | The wrapped lines, as `List<&2, String>`. |

## Laws

`PROOF.bend` proves, for every input, the diff round trip, that the lines of a string join back to it, and that every line of `wrap(text, width)` fits in `width` columns or is one grapheme cluster. Fixtures pin the Myers paper example (5 edits), unified output checked against `diff -U`, Levenshtein values, and wrapped lines.

`../scripts/check.sh text` runs the laws and `check.bend`. `bench/README.md` has timings.
