# regex

Regular expressions in pure Bend, with matching in linear time. It uses RE2 syntax and a Pike VM (a Thompson NFA with capture slots). It does not backtrack, so a pattern cannot cause ReDoS.

```bend
import bend-kit-regex@0.9.0.3/regex.bend as Re

# Re.compile(pat) is Some{re}, or None for a syntax error.
# Re.find(re, s) gives the leftmost match: the span of group 0, then one entry per group.
Re.find(re, "xaabbby")         # re = "(a+)(b+)": Some{[Some{Span{1, 6}}, Some{Span{1, 3}}, Some{Span{3, 6}}]}
Re.is_match(re, "abc")         # Bool

# Over a UTF-8 Bytes buffer (bend-kit-bytes). Each hands the buffer back; spans are byte offsets.
Re.find.bytes(re, b)           # Bytes & Maybe<List<Maybe<Span>>>
Re.is_match.bytes(re, b)       # Bytes & Bool
```

This package imports `bend-kit-bytes@0.3.3.3` and `bend-kit-unicode@0.1.0.0`. Import those versions for the byte buffer and Unicode APIs.

With a `String`, positions count its code points, not octets. With `Bytes`, the matcher decodes UTF-8 as it goes and positions are byte offsets, as in RE2 and Go; an invalid byte matches as one U+FFFD. While no match is in progress, both paths skip chars that cannot start one, looking past leading assertions such as `\b` and `^`. The `Bytes` path is still the faster one. A group that did not take part in the match is `None`. The semantics are leftmost-first, as in RE2 and Perl: `a|ab` against `ab` matches `a`.

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
| Case folding | a leading `(?i)`, for the whole pattern |

These are syntax errors, not silent mismatches: any flag but a leading `(?i)` (so `a(?i)b`, `(?i:a)` and `(?s)`), named groups, `\x` hex escapes, POSIX classes such as `[:alpha:]`, backreferences, and a repetition of a repetition (`a**`). The `LAWS.bend` fixtures, and 600 random patterns, give the same spans as Go's `regexp`, which implements RE2.

## Case folding

`(?i)` uses Unicode's simple case folding, as RE2 does: two code points match each other when `CaseFolding.txt` (statuses C and S) folds them to the same code point. So `(?i)k` matches `k`, `K` and the Kelvin sign U+212A, and `(?i)σ` matches `σ`, `ς` and `Σ`. There is no full folding: `(?i)ss` does not match `ß`. A class takes in every code point equivalent to one of its members, before `[^...]` negates it: `(?i)\w` and `(?i)[a-z]` match U+017F and U+212A, and `(?i)\W` and `(?i)\P{Lu}` match neither the folded nor the original members. `\d`, `\s`, `.` and `\b` are unchanged.

`fold.bend` holds the classes, generated from UCD 17.0 by `python3 regex/fold.py`. They equal Go's `unicode.SimpleFold` for every code point. A folded class reads the table only for a char that misses the class itself; a folded literal is a set of its equivalents, built when the pattern compiles.

## Cost

Matching takes O(n·m·log m) steps for n chars and m instructions. Each char advances every live thread once. The program and the set of visited states are binary tries keyed by pc, so each step costs O(log pc). `(a*)*b` against n a's, which a backtracker takes exponential time to reject, in a native build on an Apple M-series Mac:

| n | 25 000 | 50 000 | 100 000 | 200 000 |
|---|---|---|---|---|
| ms | 33 | 67 | 133 | 267 |

Which matcher runs depends on the call and the program. `is_match` on a program of at most 32 instructions with no `\b` or `\B` runs only a bit-parallel NFA, O(n·k) steps for k character sets, from where the required-literal scan below starts it; no DFA runs. Every other call runs a DFA that keeps no captures, then, for `find`, the Pike VM. The one exception is over `Bytes`, when the required-byte scan at the end of this section finds where a match can start: the Pike VM runs from there without the DFA. The table above times `find`.

The DFA's state is the set of live threads' pcs and the kind of the char before (none, a word char, or another char), so `\b`, `\B`, `^` and `$` need no special case. Steps on ASCII chars are learned once into a table indexed by state and char; steps on wider chars run uncached. A state with no thread but the seed is idle: no earlier start is still alive and no match has ended, so the Pike VM started there, given the char before, finds the same leftmost-first match. `is_match` takes the DFA's answer. `find` runs the Pike VM from the last idle point once the DFA sees a match, so captures cost time only near the match. Texts under 4096 chars cache 8 states, under 65 536 chars 64 states, longer ones 1024 (a 1 MiB table); when the cache fills, the Pike VM runs from the last idle point.

From the idle point, over `Bytes`, a program without `\b` or `\B` can run as a lazy DFA: each Pike VM step on an ASCII char is learned once per state, with the capture slots it saves, and replayed from a table after that. Non-ASCII chars, the last char, and states past the cache's size take the plain step. Short texts with large programs use the plain VM instead of learning states they rarely revisit. Other short texts use eight states; long texts use 256 for small programs or 2048 for large programs (a 2 MiB transition table). State keys use a hash-indexed trie with collision checks.

Before any automaton runs, the matcher looks for the pattern's required literals: one of them is in every match. A literal is a run of chars, each from a set of at most four code points (under `(?i)`, every case form of the char); an alternation requires one literal per branch, up to eight. With them comes far, the most chars a match can take before its literal (bytes, over `Bytes`), or unbounded. The scan looks for each literal's anchor, its rarest set by a fixed table of how common each ASCII char is in text (`@` and `Q` are rare, `e` and space common; a set ranks as its most common member, the first of the rarest wins a tie), and checks the whole literal around each place that holds one. So `x@host\.org` over a text of `x`s stops only at each `@`. Over `Bytes`, `find` and `is_match` scan four bytes at a step. A buffer without a literal has no match, and no automaton runs. Otherwise the automata start at the first place where a literal's anchor holds, less the largest anchor place in any literal (an earlier literal has its anchor there or later), less far, moved back to the start of its char; or at the start of the buffer when that goes below it or far is unbounded. A set of several non-ASCII code points is not a literal over `Bytes`, and neither is U+FFFD, which also matches an invalid byte. Over a `String` the scan reads one char at a step, which costs about as much as the DFA's own skip to the same char. So a `String` search uses the literals only when finding one adds nothing: every match starts at its literal (far is 0), and the pattern has no `\b` or `\B`, so the automata can start at or just before the literal without the char before it. When an anchor is not its literal's first set, the scan keeps a second place in the text, at most the largest anchor place behind, and moves it up only where an anchor and what follows it match. Other patterns run over a `String` as they did before.

When the literal scan leaves the start at byte 0 (the pattern has no required literal, or far is unbounded), the `Bytes` matcher next looks for a required ASCII byte and skips text without it. For a program of at most 32 reverse instructions with no assertions, a bitset DFA scans backward from each occurrence to find possible starts. A forward pass then preserves leftmost-first order and captures. If a reverse scan encounters non-ASCII bytes, exceeds 4096 bytes, or sees too many candidates, the normal matcher takes over.
