# regex

Regular expressions in pure Bend, with matching in linear time. It uses RE2 syntax and a Pike VM (a Thompson NFA with capture slots). It does not backtrack, so a pattern cannot cause ReDoS.

```bend
import ./regex/regex.bend as Re

# Re.compile(pat) is Some{re}, or None for a syntax error.
# Re.find(re, s) gives the leftmost match: the span of group 0, then one entry per group.
Re.find(re, "xaabbby")         # re = "(a+)(b+)": Some{[Some{Span{1, 6}}, Some{Span{1, 3}}, Some{Span{3, 6}}]}
Re.is_match(re, "abc")         # Bool

# Over a UTF-8 Bytes buffer (bend-kit-bytes). Each hands the buffer back; spans are byte offsets.
Re.find.bytes(re, b)           # Bytes & Maybe<List<Maybe<Span>>>
Re.is_match.bytes(re, b)       # Bytes & Bool
```

With a `String`, positions count its code points, not octets. With `Bytes`, the matcher decodes UTF-8 as it goes and positions are byte offsets, as in RE2 and Go; an invalid byte matches as one U+FFFD. The `Bytes` path is the fast one: while no match is in progress it skips bytes that cannot start one. A group that did not take part in the match is `None`. The semantics are leftmost-first, as in RE2 and Perl: `a|ab` against `ab` matches `a`.

## Syntax

| | |
|---|---|
| Literals | `a`, `\.`, `\n \t \r \f \v` |
| Any char but `\n` | `.` |
| Classes | `[abc]`, `[a-z]`, `[^a-z]`, `[]a]`, `[a-]` |
| Perl classes (ASCII) | `\d \D \w \W \s \S`, also inside `[...]` |
| Unicode categories | `\pL`, `\p{Lu}`, `\PL`, `\P{Nd}`, also inside `[...]` |
| Alternation | `a\|b` |
| Repetition | `* + ? {n} {n,} {n,m}`, lazy with a trailing `?`; counts go up to 1000 |
| Groups | `(a)` captures, `(?:a)` does not |
| Anchors | `^ \A` start of text, `$ \z` end of text, `\b \B` word boundary |

These are syntax errors, not silent mismatches: flags such as `(?i)`, named groups, `\x` hex escapes, POSIX classes such as `[:alpha:]`, backreferences, and a repetition of a repetition (`a**`). The `LAWS.bend` fixtures, and 600 random patterns, give the same spans as Go's `regexp`, which implements RE2.

## Cost

Matching takes O(n·m·log m) steps for n chars and m instructions. Each char advances every live thread once. The program and the set of visited states are binary tries keyed by pc, so each step costs O(log pc). `(a*)*b` against n a's, which a backtracker takes exponential time to reject, in a native build on an Apple M-series Mac:

| n | 25 000 | 50 000 | 100 000 | 200 000 |
|---|---|---|---|---|
| ms | 33 | 67 | 133 | 267 |

`is_match` on a program of at most 32 instructions with no `\b` or `\B` runs as a bit-parallel NFA instead: O(n·k) steps for k character sets. The table above times `find`.

Over `Bytes`, a program with no `\b` or `\B` runs as a lazy DFA: each Pike VM step on an ASCII char is learned once per state, with the capture slots it saves, and replayed from a table after that. Non-ASCII chars, the last char, and states past the cache's size take the plain step.
