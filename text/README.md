# text

Myers diff with unified output, Levenshtein distance, and word wrap by display width. Pure Bend.

```bend
import bend-kit-text@0.1.0.0/text.bend as Text
```

`text.bend` imports `bend-kit-unicode@0.1.0.0/unicode.bend` and `bend-kit-tty@0.1.0.1/text.bend`.

```bend
def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Text.unified("old.txt", "new.txt", Text.diff_lines("a\nb\nc\n", "a\nB\nc\n"), 3))
    IO.print(U32.show(Text.distance("kitten", "sitting")))
    IO.print(String.join(Text.wrap("The quick brown fox jumps over the lazy dog.", 16), "\n"))
```

## Diff

`diff(~A, ~eq, a, b)` returns a shortest edit script from list `a` to list `b`, as a `List<&2, Edit<A>>`. It is Myers' O(ND) algorithm: time grows with the input length times the number of edits. `eq` decides which items match.

An `Edit<A>` is `Same{old, new}`, `Del{old}`, or `Ins{new}`. `Same` holds both items, so an `eq` that matches unequal items loses nothing. `before(A, es)` gives the old list back and `after(A, es)` gives the new list. `PROOF.bend` proves `before(diff(a, b)) == a` and `after(diff(a, b)) == b` for every `eq`, `a`, and `b`.

`diff_lines(a, b)` diffs the lines of two strings, and `diff_chars(a, b)` diffs their code points. `lines(s)` splits on `"\n"`. A final `"\n"` ends the last line, so `"a\n"` and `"a"` are both `["a"]`.

`unified(old_name, new_name, es, ctx)` prints `diff -U<ctx>` text for a line script: the `---` and `+++` headers, then each hunk with `ctx` lines of context. Two changes share a hunk when at most `2 * ctx` unchanged lines separate them. It returns `""` when nothing changed. Lines carry no newline, so the output has no `\ No newline at end of file` marker. The headers have no timestamps.

## Distance

`distance(a, b)` is the Levenshtein distance by code point: the fewest inserts, deletes, and substitutions that turn `a` into `b`. `edit_distance(~A, ~eq, a, b)` does the same for any list. It takes O(len(a) × len(b)) time and O(len(b)) space. A command line can rank its "did you mean" suggestions by it.

## Wrap

`wrap(text, width)` breaks text into lines of at most `width` display columns, greedily. Runs of whitespace separate words, and a line joins its words with one space. A word wider than `width` breaks between grapheme clusters. A line is wider than `width` only when one grapheme cluster is wider than `width`, such as a wide CJK character with `width` 1.

Display width comes from `tty`: East Asian Wide and Fullwidth clusters take 2 columns, combining marks 0, and Ambiguous characters 1. Escape sequences are not stripped, so wrap text before you style it.

| def | returns |
|---|---|
| `diff(~A, ~eq, a, b)` | A shortest edit script from `a` to `b`. |
| `diff_lines(a: String, b: String)` | The line script, as `List<&2, Edit<String>>`. |
| `diff_chars(a: String, b: String)` | The code point script, as `List<&2, Edit<Char>>`. |
| `before(A, es)`, `after(A, es)` | The old or new list of a script. |
| `unified(old_name, new_name, es, ctx: U32)` | Unified diff text. |
| `lines(s: String)` | The lines of `s`, without newlines. |
| `distance(a: String, b: String)` | The Levenshtein distance, as `U32`. |
| `edit_distance(~A, ~eq, a, b)` | The Levenshtein distance of two lists. |
| `wrap(text: String, width: U32)` | The wrapped lines, as `List<&2, String>`. |

## Laws

`PROOF.bend` proves the diff round trip for every input. Fixtures pin the Myers paper example (5 edits), unified output checked against `diff -U`, Levenshtein values, and wrapped lines. The wrap width bound is checked on fixtures, not proved for every input.

`../scripts/check.sh text` runs the laws and `check.bend`. `bench/README.md` has timings.
