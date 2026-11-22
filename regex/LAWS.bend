import Base
import ./regex.bend as R
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes

def found(r: Maybe<&2, R.Regex>, s: String) -> Maybe<&2, List<&2, Maybe<&2, R.Span>>>:
  match r:
    case None{}:
      None{}
    case Some{re}:
      R.find(re, s)

# Compile pat and find its leftmost match in s.
def m(+pat: String, s: String) -> Maybe<&2, List<&2, Maybe<&2, R.Span>>>:
  found(R.compile(pat), s)

def sp(a: U32, b: U32) -> Maybe<&2, R.Span>:
  Some{R.Span{a, b}}

def ok(+pat: String) -> Bool:
  Maybe.is_some(&2, R.Regex, R.compile(pat))

def hit(r: Maybe<&2, R.Regex>, s: String) -> Bool:
  match r:
    case None{}:
      False{}
    case Some{re}:
      R.is_match(re, s)

# is_match on both paths: the bit NFA (None when the program does not allow it), then the Pike VM.
def both(r: Maybe<&2, R.Regex>, +s: String) -> Maybe<&2, Bool> & Bool:
  match r:
    case None{}:
      (None{}, False{})
    case Some{+re}:
      (R.is_match.bits(re, s), R.is_match.vm(re, s))

def yes() -> Maybe<&2, Bool> & Bool:
  (Some{True{}}, True{})

def no() -> Maybe<&2, Bool> & Bool:
  (Some{False{}}, False{})

def found.bytes(p: Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, R.Span>>>) -> Maybe<&2, List<&2, Maybe<&2, R.Span>>>:
  (b, x) = p
  x

def fb(r: Maybe<&2, R.Regex>, +s: String) -> Maybe<&2, List<&2, Maybe<&2, R.Span>>>:
  match r:
    case None{}:
      None{}
    case Some{re}:
      found.bytes(R.find.bytes(re, Bytes.from_string(s)))

# Compile pat and find its leftmost match in s, a byte string (one Char per octet) read as UTF-8.
def mb(+pat: String, +s: String) -> Maybe<&2, List<&2, Maybe<&2, R.Span>>>:
  fb(R.compile(pat), s)

def hb(p: Bytes.Bytes & Bool) -> Bool:
  (b, x) = p
  x

def hbm(p: Bytes.Bytes & Maybe<&2, Bool>) -> Maybe<&2, Bool>:
  (b, x) = p
  x

# is_match over bytes on both paths, as both does over a String.
def bboth(r: Maybe<&2, R.Regex>, +s: String) -> Maybe<&2, Bool> & Bool:
  match r:
    case None{}:
      (None{}, False{})
    case Some{+re}:
      (hbm(R.is_match.bytes.bits(re, Bytes.from_string(s))), hb(R.is_match.bytes.vm(re, Bytes.from_string(s))))

def same.pos(s: R.Spin) -> U32:
  R.Spin{a, tab, i} = s
  i

def same.bytes(b: Bytes.Bytes) -> U32:
  Bytes.Bytes{+len, a} = b
  tab = Array.set(R.Tr, Array.new(R.Tr, 7n, R.TrNo{}), 120, R.TrSame{})
  same.pos(R.spin(64n, R.spin.state(R.spin.byte(Bool.not(U32.is_lt(1, len)), a, 0), tab, 0, 0, 1), len, 0, 1))

def same(+s: String) -> U32:
  same.bytes(Bytes.from_string(s))

# The Need a pattern's literal prefilter uses: over a String, and over Bytes.
def nd.of(r: Maybe<&2, R.Regex>) -> Maybe<&2, R.Need>:
  match r:
    case None{}:
      None{}
    case Some{re}:
      R.Regex{prog, fuel, slots, start, lead, bits, asc, plain, must, reverse, need, needb, gate} = re
      need

def ndb.of(r: Maybe<&2, R.Regex>) -> Maybe<&2, R.Need>:
  match r:
    case None{}:
      None{}
    case Some{re}:
      R.Regex{prog, fuel, slots, start, lead, bits, asc, plain, must, reverse, need, needb, gate} = re
      needb

def nd(+pat: String) -> Maybe<&2, R.Need>:
  nd.of(R.compile(pat))

def ndb(+pat: String) -> Maybe<&2, R.Need>:
  ndb.of(R.compile(pat))

# Whether a pattern's String search uses its literals.
def gt.of(r: Maybe<&2, R.Regex>) -> Bool:
  match r:
    case None{}:
      False{}
    case Some{re}:
      R.Regex{prog, fuel, slots, start, lead, bits, asc, plain, must, reverse, need, needb, gate} = re
      gate

def gt(+pat: String) -> Bool:
  gt.of(R.compile(pat))

# far and the length of the shortest literal, of a Need.
def nfar(m: Maybe<&2, R.Need>) -> Maybe<&2, Maybe<&2, U32>> & U32:
  match m:
    case None{}:
      (None{}, 0)
    case Some{R.Need{+lits, far}}:
      (Some{far}, R.lits.short(lits, 4294967295))

# The anchor places a scan picks, one per literal of a Need, over a String or over Bytes.
def anc.offs(xs: List<&2, R.Anc>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{R.Anc{o, set, l, tail}, t}:
      o <> anc.offs(t)

def anc.of(m: Maybe<&2, R.Need>, +bytes: Bool) -> List<&2, U32>:
  match m:
    case None{}:
      Nil{}
    case Some{R.Need{ls, far}}:
      anc.offs(R.lits.ancs(ls, bytes))

def an(+pat: String) -> List<&2, U32>:
  anc.of(nd(pat), False{})

def anb(+pat: String) -> List<&2, U32>:
  anc.of(ndb(pat), True{})

# Where a search over Bytes starts after the literal scan: the first byte the automata may start
# at, or None when the text has no match.
def stb.of(r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&2, U32>:
  (b, x) = r
  x

def stb(+pat: String, +s: String) -> Maybe<&2, U32>:
  stb.of(R.need.atb(ndb(pat), Bytes.from_string(s)))

# Where a search over a String starts after the literal scan: the text from there on, empty when
# it has no match.
def sts.of(m: Maybe<&2, R.Need>, +s: String) -> String:
  match m:
    case None{}:
      s
    case Some{R.Need{ls, far}}:
      R.lits.find.start(s, ls)

def sts(+pat: String, +s: String) -> String:
  sts.of(nd(pat), s)

# Matches and captures. The expected spans are what Go's regexp (RE2) answers.
law literal:
  {m("b", "abc") == Some{[sp(1, 2)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law no_match:
  {m("x", "abc") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law empty_pattern:
  {m("", "abc") == Some{[sp(0, 0)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law leftmost_first:
  {m("a|ab", "ab") == Some{[sp(0, 1)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law leftmost_start:
  {m("b+|a", "xab") == Some{[sp(1, 2)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law greedy_star:
  {m("a*", "aaa") == Some{[sp(0, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law lazy_star:
  {m("a*?", "aaa") == Some{[sp(0, 0)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law lazy_plus:
  {m("a+?b", "aaab") == Some{[sp(0, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law quest:
  {m("colou?r", "color") == Some{[sp(0, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law count_exact:
  {m("a{3}", "aaaa") == Some{[sp(0, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law count_range:
  {m("a{2,3}", "aaaa") == Some{[sp(0, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law count_open:
  {m("a{2,}", "aaaaa") == Some{[sp(0, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law count_lazy:
  {m("a{2,3}?", "aaaa") == Some{[sp(0, 2)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law brace_literal:
  {m("a{,2}", "a{,2}") == Some{[sp(0, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law captures:
  {m("(a+)(b+)", "xaabbby") == Some{[sp(1, 6), sp(1, 3), sp(3, 6)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law capture_unset:
  {m("(a)|(b)", "b") == Some{[sp(0, 1), None{}, sp(0, 1)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law capture_last_iteration:
  {m("(a|b)+", "ab") == Some{[sp(0, 2), sp(1, 2)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law capture_nested:
  {m("((a)b)", "ab") == Some{[sp(0, 2), sp(0, 2), sp(0, 1)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law capture_alternatives:
  {m("(a|ab)(c|bcd)(d*)", "abcd") == Some{[sp(0, 4), sp(0, 1), sp(1, 4), sp(4, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law noncapturing:
  {m("(?:ab)+(c)", "ababc") == Some{[sp(0, 5), sp(4, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# An empty iteration cannot loop: x* runs as (x+)?, as in RE2.
law empty_loop:
  {m("(|a)*", "aa") == Some{[sp(0, 0), sp(0, 0)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law anchor_start:
  {m("^b", "ab") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law anchor_end:
  {m("a$", "aba") == Some{[sp(2, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law anchor_text:
  {m("\\Aab\\z", "abc") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law word_boundary:
  {m("\\bcat\\b", "concat cat") == Some{[sp(7, 10)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law not_word_boundary:
  {m("\\Bcat", "cat concat") == Some{[sp(7, 10)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dot_no_newline:
  {m("a.c", "a\nc abc") == Some{[sp(4, 7)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law escape_meta:
  {m("\\.\\*", "a.*b") == Some{[sp(1, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law class_range:
  {m("[a-c]+", "xxbcay") == Some{[sp(2, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law class_negated:
  {m("[^a-c]+", "abxyc") == Some{[sp(2, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law class_bracket_dash:
  {m("[]a-]+", "x]-a") == Some{[sp(1, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law perl_digit:
  {m("\\d+", "ab123c") == Some{[sp(2, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law perl_word:
  {m("\\w+", "  foo_1 ") == Some{[sp(2, 7)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law perl_in_class:
  {m("[^\\d\\s]+", "1 ab2") == Some{[sp(2, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# Positions count code points: "é" is one.
law unicode_letter:
  {m("\\p{L}+", "12héllo!") == Some{[sp(2, 7)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law unicode_short:
  {m("\\pN", "x\u{663}") == Some{[sp(1, 2)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law unicode_negated:
  {m("\\P{L}+", "ab12cd") == Some{[sp(2, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law unicode_in_class:
  {m("[\\p{Lu}\\d]+", "abC1Dx") == Some{[sp(2, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# A backtracker takes exponential time here; the Pike VM steps each char once.
law pathological:
  {m("(a*)*b", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law pathological_hit:
  {m("(a*)*b", "aaab") == Some{[sp(0, 4), sp(0, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law is_match_hit:
  {hit(R.compile("b+"), "abbc") == True{} : Bool}

law is_match_miss:
  {hit(R.compile("^b+"), "abbc") == False{} : Bool}

# The matcher skips chars that cannot start a match; these check the skip keeps the leftmost-first answer.
law literal_prefix:
  {m("abc", "ababcabc") == Some{[sp(2, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law literal_prefix_end:
  {m("ab", "xxxa") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law negated_start:
  {m("[^x]y", "xxzy") == Some{[sp(2, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# A pattern that matches the empty string may start at any char.
law empty_start:
  {m("b*", "aab") == Some{[sp(0, 0)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# The bit NFA and the Pike VM agree on is_match.
law bits_hit:
  {both(R.compile("b+"), "abbc") == yes() : Maybe<&2, Bool> & Bool}

law bits_miss:
  {both(R.compile("x"), "abc") == no() : Maybe<&2, Bool> & Bool}

law bits_start:
  {both(R.compile("^b"), "ab") == no() : Maybe<&2, Bool> & Bool}

law bits_start_hit:
  {both(R.compile("^a"), "ab") == yes() : Maybe<&2, Bool> & Bool}

law bits_end:
  {both(R.compile("a$"), "aba") == yes() : Maybe<&2, Bool> & Bool}

law bits_end_miss:
  {both(R.compile("b$"), "aba") == no() : Maybe<&2, Bool> & Bool}

law bits_empty_text:
  {both(R.compile("^$"), "") == yes() : Maybe<&2, Bool> & Bool}

law bits_empty_at_end:
  {both(R.compile("$"), "abc") == yes() : Maybe<&2, Bool> & Bool}

law bits_text_anchors:
  {both(R.compile("\\Aab\\z"), "abc") == no() : Maybe<&2, Bool> & Bool}

law bits_start_inside:
  {both(R.compile("a^b"), "ab") == no() : Maybe<&2, Bool> & Bool}

law bits_loop:
  {both(R.compile("(a|b)+c"), "ababc") == yes() : Maybe<&2, Bool> & Bool}

law bits_loop_miss:
  {both(R.compile("(a|b)+c"), "abab") == no() : Maybe<&2, Bool> & Bool}

law bits_pathological:
  {both(R.compile("(a*)*b"), "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") == no() : Maybe<&2, Bool> & Bool}

law bits_negated:
  {both(R.compile("[^a-c]"), "abc") == no() : Maybe<&2, Bool> & Bool}

law bits_unicode:
  {both(R.compile("\\p{L}+"), "12é") == yes() : Maybe<&2, Bool> & Bool}

# Word boundaries and programs over 32 instructions use only the Pike VM.
law bits_word_boundary:
  {both(R.compile("\\bcat"), "concat cat") == (None{}, True{}) : Maybe<&2, Bool> & Bool}

law bits_large:
  {both(R.compile("a{40}"), "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") == (None{}, True{}) : Maybe<&2, Bool> & Bool}

# Over Bytes, positions are byte offsets into the UTF-8 text, as Go's regexp gives them.
law bytes_literal:
  {mb("b", "abc") == Some{[sp(1, 2)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_no_match:
  {mb("x", "abc") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_utf8_offsets:
  {mb("l+", "h\u{c3}\u{a9}llo") == Some{[sp(3, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_unicode_class:
  {mb("\\p{L}+", "12h\u{c3}\u{a9}llo!") == Some{[sp(2, 8)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_dot_multibyte:
  {mb("h.l", "h\u{c3}\u{a9}llo") == Some{[sp(0, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_four_byte:
  {mb("a.b", "a\u{f0}\u{9f}\u{98}\u{80}b") == Some{[sp(0, 6)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# An invalid byte is one U+FFFD, as in RE2.
law bytes_invalid:
  {mb(".a", "\u{ff}a") == Some{[sp(0, 2)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_truncated:
  {mb("\\p{L}", "\u{c3}") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_overlong:
  {mb("..", "\u{c0}\u{af}") == Some{[sp(0, 2)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_captures:
  {mb("(a+)(b+)", "xaabbby") == Some{[sp(1, 6), sp(1, 3), sp(3, 6)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_leftmost_first:
  {mb("a|ab", "ab") == Some{[sp(0, 1)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_literal_prefix:
  {mb("abc", "ababcabc") == Some{[sp(2, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_skip_multibyte:
  {mb("abc", "\u{c3}\u{a9}xabc") == Some{[sp(3, 6)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_empty_start:
  {mb("b*", "aab") == Some{[sp(0, 0)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_empty_text:
  {mb("", "") == Some{[sp(0, 0)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_anchor_end:
  {mb("a$", "aba") == Some{[sp(2, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_word_boundary:
  {mb("\\bcat\\b", "concat cat") == Some{[sp(7, 10)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law bytes_pathological:
  {mb("(a*)*b", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# is_match over Bytes: the bit NFA and the Pike VM agree.
law bytes_bits_hit:
  {bboth(R.compile("b+"), "abbc") == yes() : Maybe<&2, Bool> & Bool}

law bytes_bits_miss:
  {bboth(R.compile("x"), "abc") == no() : Maybe<&2, Bool> & Bool}

law bytes_bits_start:
  {bboth(R.compile("^b"), "ab") == no() : Maybe<&2, Bool> & Bool}

law bytes_bits_empty_at_end:
  {bboth(R.compile("$"), "abc") == yes() : Maybe<&2, Bool> & Bool}

law bytes_bits_empty_text:
  {bboth(R.compile("^$"), "") == yes() : Maybe<&2, Bool> & Bool}

law bytes_bits_skip_miss:
  {bboth(R.compile("xy"), "xxxxx") == no() : Maybe<&2, Bool> & Bool}

law bytes_bits_skip_hit:
  {bboth(R.compile("xy"), "xxxxy") == yes() : Maybe<&2, Bool> & Bool}

law bytes_bits_utf8:
  {bboth(R.compile("\\p{L}"), "12\u{c3}\u{a9}") == yes() : Maybe<&2, Bool> & Bool}

law bytes_bits_skip_multibyte:
  {bboth(R.compile("abc"), "\u{c3}\u{a9}abc") == yes() : Maybe<&2, Bool> & Bool}

law bytes_bits_word_boundary:
  {bboth(R.compile("\\bcat"), "concat cat") == (None{}, True{}) : Maybe<&2, Bool> & Bool}

# The lazy DFA runs find.bytes on patterns without word boundaries. A text repeats a match
# so that later chars replay learned transitions; the String Pike VM is the reference.
law dfa_captures_replay:
  {mb("(a+)(b+)", "xaabbbyaabb") == Some{[sp(1, 6), sp(1, 3), sp(3, 6)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_capture_alternatives:
  {mb("(a|ab)(c|bcd)(d*)", "xxabcdxx") == Some{[sp(2, 6), sp(2, 3), sp(3, 6), sp(6, 6)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_capture_last_iteration:
  {mb("(a|b)+", "xxababab") == Some{[sp(2, 8), sp(7, 8)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_capture_unset:
  {mb("x(a)|x(b)", "xxxb") == Some{[sp(2, 4), None{}, sp(3, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_email:
  {mb("(\\w+)@(\\w+)\\.com", "xx user@host.com xx") == Some{[sp(3, 16), sp(3, 7), sp(8, 12)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_lazy:
  {mb("a+?b", "xaaab") == Some{[sp(1, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_leftmost_first:
  {mb("a|ab", "xxab") == Some{[sp(2, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_anchored:
  {mb("^(a+)$", "aaaa") == Some{[sp(0, 4), sp(0, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_anchored_miss:
  {mb("^a+$", "aaab") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_empty_loop:
  {mb("(|a)*", "aaaa") == m("(|a)*", "aaaa") : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_pathological_hit:
  {mb("(a*)*b", "aaaaaab") == m("(a*)*b", "aaaaaab") : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_nested:
  {mb("((a)b)+c", "xababababc") == m("((a)b)+c", "xababababc") : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# A short text caches at most 8 states; this pattern needs more, so the rest take the plain step.
law dfa_cache_full:
  {mb("(x?){12}(y)", "xxxxxxxxxxxxy") == m("(x?){12}(y)", "xxxxxxxxxxxxy") : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law required_absent:
  {mb("x+@z", "xxxxxxxx") == m("x+@z", "xxxxxxxx") : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law required_overlap:
  {mb("ab+a", "abbabba") == m("ab+a", "abbabba") : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law required_repeated:
  {mb("(ab)+", "zabab") == m("(ab)+", "zabab") : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law required_optional:
  {mb("a?b", "b") == m("a?b", "b") : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law required_positive:
  {mb("(ab)+c", "zababc") == m("(ab)+c", "zababc") : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law required_candidates:
  {mb("(ab)+c", "zabcabc") == m("(ab)+c", "zabcabc") : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law required_alternatives:
  {mb("ab(c|d)ef", "zabcef") == m("ab(c|d)ef", "zabcef") : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law required_priority:
  {mb("(a|aa)+b", "aab") == m("(a|aa)+b", "aab") : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}


law required_non_ascii:
  {mb("a.*c", "a\u{c3}\u{a9}c") == m("a.*c", "a\u{c3}\u{a9}c") : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law required_dense:
  {mb("(ab)+c", "ababcababcababcababcababcababcababcababc") == m("(ab)+c", "ababcababcababcababcababcababcababcababc") : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}



# Non-ASCII chars take the plain step between cached ones.
law dfa_non_ascii:
  {mb("(a+)\u{e9}(b+)", "xaa\u{c3}\u{a9}bbaa\u{c3}\u{a9}b") == Some{[sp(1, 7), sp(1, 3), sp(5, 7)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_same_run:
  {mb("(\\w+)@(\\w+)\\.com", "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx user@host.com") == Some{[sp(33, 46), sp(33, 37), sp(38, 42)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_same_non_ascii:
  {mb("(\\w+)@(\\w+)\\.com", "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\u{c3}\u{a9} user@host.com") == Some{[sp(35, 48), sp(35, 39), sp(40, 44)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_same_last_byte:
  {mb("(a+)b", "aaaaaaaaaaaaaaaab") == Some{[sp(0, 17), sp(0, 16)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_spin_run:
  {same("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxy") == 32 : U32}

law dfa_spin_non_ascii:
  {same("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\u{c3}\u{a9}y") == 32 : U32}

law dfa_spin_last_byte:
  {same("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx") == 31 : U32}

# is_match.bytes on a program over 32 instructions: the DFA with no captures.
law dfa_any_large_hit:
  {bboth(R.compile("a{40}"), "baaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab") == (None{}, True{}) : Maybe<&2, Bool> & Bool}

law dfa_any_large_miss:
  {bboth(R.compile("a{40}"), "baaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab") == (None{}, False{}) : Maybe<&2, Bool> & Bool}

# Syntax errors.
law bad_unclosed:
  {ok("(a") == False{} : Bool}

law bad_close:
  {ok("a)") == False{} : Bool}

law bad_repeat_nothing:
  {ok("*a") == False{} : Bool}

law bad_repeat_repeat:
  {ok("a**") == False{} : Bool}

law bad_class:
  {ok("[a") == False{} : Bool}

law bad_range:
  {ok("[z-a]") == False{} : Bool}

law bad_escape:
  {ok("\\q") == False{} : Bool}

law bad_trailing_escape:
  {ok("a\\") == False{} : Bool}

law bad_property:
  {ok("\\p{Xx}") == False{} : Bool}

law bad_count:
  {ok("a{1001}") == False{} : Bool}

law bad_count_order:
  {ok("a{3,2}") == False{} : Bool}

law bad_flags:
  {ok("(?s)a") == False{} : Bool}

# A leading (?i) is the only flag. Go accepts the rest; this package refuses them.
law flag_leading:
  {ok("(?i)a") == True{} : Bool}

law bad_flag_inside:
  {ok("a(?i)b") == False{} : Bool}

law bad_flag_group:
  {ok("(?i:a)") == False{} : Bool}

law bad_flag_twice:
  {ok("(?i)(?i)a") == False{} : Bool}

# (?i): Unicode simple case folding, as in RE2. The expected spans are what Go's regexp answers.
# U+212A (Kelvin sign) folds with k, U+017F (long s) with s; \w and [a-z] take them in, \W leaves them out.
law fold_literal:
  {m("(?i)hello", "say HeLLo") == Some{[sp(4, 9)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_off_by_default:
  {m("hello", "say HeLLo") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_empty:
  {m("(?i)", "abc") == Some{[sp(0, 0)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_class_range:
  {m("(?i)[a-c]+", "xxABcz") == Some{[sp(2, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_class_range_non_ascii:
  {m("(?i)[a-z]+", "\u{17f}\u{212a}!") == Some{[sp(0, 2)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_negated_class:
  {m("(?i)[^a]+", "aAAbB") == Some{[sp(3, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_negated_class_non_ascii:
  {m("(?i)[^k]", "\u{212a}x") == Some{[sp(1, 2)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_word:
  {m("(?i)\\w", "\u{212a}") == Some{[sp(0, 1)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law word_no_fold:
  {m("\\w", "\u{212a}") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_not_word:
  {m("(?i)\\W", "\u{212a}x!") == Some{[sp(2, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_not_word_in_class:
  {m("(?i)[\\W]", "\u{212a}x!") == Some{[sp(2, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_digit:
  {m("(?i)\\d+", "a12") == Some{[sp(1, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_upper:
  {m("(?i)\\p{Lu}+", "abC1") == Some{[sp(0, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_not_upper:
  {m("(?i)\\P{Lu}", "aB1") == Some{[sp(2, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_kelvin:
  {m("(?i)k", "\u{212a}") == Some{[sp(0, 1)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_long_s:
  {m("(?i)S", "\u{17f}") == Some{[sp(0, 1)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_sigma:
  {m("(?i)\u{3c3}+", "\u{3a3}\u{3c2}") == Some{[sp(0, 2)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_accent:
  {m("(?i)\u{e9}", "x\u{c9}") == Some{[sp(1, 2)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_simple_only:
  {m("(?i)ss", "\u{df}") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_sharp_s:
  {m("(?i)\u{df}", "\u{1e9e}") == Some{[sp(0, 1)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_captures:
  {m("(?i)(a+)(B+)", "xAabBy") == Some{[sp(1, 5), sp(1, 3), sp(3, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_word_boundary:
  {m("(?i)\\bK\\b", "ak k b") == Some{[sp(3, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_bytes_kelvin:
  {mb("(?i)k", "\u{e2}\u{84}\u{aa}") == Some{[sp(0, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_bytes_literal:
  {mb("(?i)fold_unit", "xx FOLD_UNIT yy") == Some{[sp(3, 12)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_bytes_not_word:
  {mb("(?i)\\W+", "\u{e2}\u{84}\u{aa}\u{c5}\u{bf}-") == Some{[sp(5, 6)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law fold_bits:
  {both(R.compile("(?i)abc"), "xABC") == yes() : Maybe<&2, Bool> & Bool}

law fold_bits_not_word:
  {both(R.compile("(?i)\\W"), "\u{212a}") == no() : Maybe<&2, Bool> & Bool}

law fold_bits_bytes:
  {bboth(R.compile("(?i)[k]"), "\u{e2}\u{84}\u{aa}") == yes() : Maybe<&2, Bool> & Bool}

# A pattern led by an assertion still skips: a char outside the sets past the assertions starts
# no match. The seed after a skip sees the char before it, so \b and \B still hold. Spans from Go's regexp.
law lead_boundary:
  {m("\\bfoo\\b", "xfoo, foo") == Some{[sp(6, 9)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law lead_boundary_bytes:
  {mb("\\bfoo\\b", "xfoo, foo") == Some{[sp(6, 9)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law lead_boundary_after_wide:
  {m("\\bfoo", "\u{e9}foo") == Some{[sp(1, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law lead_boundary_after_wide_bytes:
  {mb("\\bfoo", "\u{c3}\u{a9}foo") == Some{[sp(2, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law lead_not_boundary:
  {m("\\Bfoo", "foo xfoo") == Some{[sp(5, 8)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law lead_not_boundary_bytes:
  {mb("\\Bfoo", "foo xfoo") == Some{[sp(5, 8)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law lead_start:
  {m("^b", "ab") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law lead_start_bytes:
  {mb("^b", "ab") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law lead_digits:
  {m("\\b\\d+\\b", "a1 22b 333") == Some{[sp(7, 10)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law lead_digits_bytes:
  {mb("\\b\\d+\\b", "a1 22b 333") == Some{[sp(7, 10)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law lead_fold_boundary:
  {m("(?i)\\bk", "xk \u{212a}") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law lead_fold_boundary_bytes:
  {mb("(?i)\\bk", "xk \u{e2}\u{84}\u{aa}") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# The capture-free DFA: its cache filling, the idle point it hands to the Pike VM, wide chars,
# and is_match by the DFA alone. Spans from Go's regexp.

# A text under 4096 chars caches 8 states; this pattern needs more, so the Pike VM takes over from the idle point.
law dfa_full:
  {m("[ab]*a[ab]{3}x", String.repeat("abba", 40n) ++ "aabbx" ++ String.repeat("ab", 10n)) == Some{[sp(0, 165)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_full_bytes:
  {mb("[ab]*a[ab]{3}x", String.repeat("abba", 40n) ++ "aabbx" ++ String.repeat("ab", 10n)) == Some{[sp(0, 165)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_full_none:
  {m("[ab]*a[ab]{3}x", String.repeat("ab", 50n)) == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_full_none_bytes:
  {mb("[ab]*a[ab]{3}x", String.repeat("ab", 50n)) == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# The Pike VM starts at an idle point and must see the char before it.
law dfa_idle_prev:
  {m("\\bab", "xab ab") == Some{[sp(4, 6)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_idle_prev_bytes:
  {mb("\\bab", "xab ab") == Some{[sp(4, 6)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# Steps on wide chars are not cached.
law dfa_wide:
  {m("[^a]+b", "a\u{4e2d}\u{6587}b") == Some{[sp(1, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_wide_bytes:
  {mb("[^a]+b", "a\u{e4}\u{b8}\u{ad}\u{e6}\u{96}\u{87}b") == Some{[sp(1, 8)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_wide_lit:
  {m("\u{e9}+x", "a\u{e9}\u{e9}x") == Some{[sp(1, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_wide_lit_bytes:
  {mb("\u{e9}+x", "a\u{c3}\u{a9}\u{c3}\u{a9}x") == Some{[sp(1, 6)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# Captures come from the Pike VM after the DFA finds a match.
law dfa_groups:
  {m("(a+)(b+)", "xxaab") == Some{[sp(2, 5), sp(2, 4), sp(4, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_groups_bytes:
  {mb("(a+)(b+)", "xxaab") == Some{[sp(2, 5), sp(2, 4), sp(4, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# A match seen only at the end of the text.
law dfa_end:
  {m("a$", "ba") == Some{[sp(1, 2)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_end_bytes:
  {mb("a$", "ba") == Some{[sp(1, 2)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_empty_text:
  {m("x*", "") == Some{[sp(0, 0)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_empty_text_bytes:
  {mb("x*", "") == Some{[sp(0, 0)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# A wide char outside lead is skipped by its sets, not by the ASCII table.
law dfa_fold_wide:
  {m("(?i)\\w+@\\w+", "\u{4e2d} a@b") == Some{[sp(2, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law dfa_fold_wide_bytes:
  {mb("(?i)\\w+@\\w+", "\u{e4}\u{b8}\u{ad} a@b") == Some{[sp(4, 7)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# is_match through the DFA alone, where the bit NFA does not apply.
law dfa_hit_boundary:
  {both(R.compile("\\bk\\b"), "xk k") == (None{}, True{}) : Maybe<&2, Bool> & Bool}

law dfa_hit_boundary_bytes:
  {bboth(R.compile("\\bk\\b"), "xk k") == (None{}, True{}) : Maybe<&2, Bool> & Bool}

law dfa_miss_boundary:
  {both(R.compile("(?i)\\bK"), "xk") == (None{}, False{}) : Maybe<&2, Bool> & Bool}

law dfa_miss_boundary_bytes:
  {bboth(R.compile("(?i)\\bK"), "xk") == (None{}, False{}) : Maybe<&2, Bool> & Bool}

# Required literals. Every match holds one of the literals the parsed pattern requires, so a text
# without them has no match, and neither find nor is_match runs an automaton on it. With one, the
# automata start no earlier than its first occurrence less far, the most chars (bytes, over Bytes)
# from a match's start to the literal. Over Bytes that is always so; over a String only where the
# gate laws below say, and the String laws hold as answers either way. The laws are instances of
# that claim; the expected spans are what Go's regexp answers.

# Guarantees: a text that holds only prefixes of the literal has no match, on every path.
# Why it matters: the shortcut answers without an automaton, so a literal found where it is not
#   would turn into a missed match, and one missed where it is would cost nothing but speed.
law need_absent:
  {m("zqxjv_nomatch", "the zqxjv_nomatc quick zqxjv_ brown") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_absent_bytes:
  {mb("zqxjv_nomatch", "the zqxjv_nomatc quick zqxjv_ brown") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_absent_hit:
  {both(R.compile("zqxjv"), "zqxj zqxv") == no() : Maybe<&2, Bool> & Bool}

law need_absent_hit_bytes:
  {bboth(R.compile("zqxjv"), "zqxj zqxv") == no() : Maybe<&2, Bool> & Bool}

# Guarantees: the literal occurs, but in no match, and the answer is still no match; when one of
#   its later occurrences does match, that match is found.
# Why it matters: a found literal only moves the start; the automata decide the match.
law need_no_match:
  {m("\\bfoo\\d+bar\\b", "xfoo1bar foo22baz foo3barx") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_no_match_bytes:
  {mb("\\bfoo\\d+bar\\b", "xfoo1bar foo22baz foo3barx") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_late:
  {m("\\bfoo\\d+bar\\b", "xfoo1bar foo22baz foo3bar.") == Some{[sp(18, 25)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_late_bytes:
  {mb("\\bfoo\\d+bar\\b", "xfoo1bar foo22baz foo3bar.") == Some{[sp(18, 25)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_far:
  {m("foo\\d+", "foo foo foo 12 foo7") == Some{[sp(15, 19)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_far_bytes:
  {mb("foo\\d+", "foo foo foo 12 foo7") == Some{[sp(15, 19)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# Guarantees: a match whose literal lies the full far from its start is found: the start is
#   the first occurrence less far, not one char later.
# Why it matters: a start one char late drops the leftmost match.
law need_distance:
  {m("\\w{2}foo", "xx abfoo") == Some{[sp(3, 8)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_distance_bytes:
  {mb("\\w{2}foo", "xx abfoo") == Some{[sp(3, 8)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# Guarantees: where the automata start mid-text, \b and ^ see the char before the start, not the
#   start of the text.
# Why it matters: taking the start for the start of the text makes \b hold between two word chars
#   and ^ hold mid-text, so a match appears that Go does not report.
law need_landing_boundary:
  {m("\\b\\w{2}foo", "xabfoo zzfoo") == Some{[sp(7, 12)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_landing_boundary_bytes:
  {mb("\\b\\w{2}foo", "xabfoo zzfoo") == Some{[sp(7, 12)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_landing_boundary_hit:
  {both(R.compile("\\b\\w{2}foo"), "xabfoo") == (None{}, False{}) : Maybe<&2, Bool> & Bool}

law need_landing_boundary_hit_bytes:
  {bboth(R.compile("\\b\\w{2}foo"), "xabfoo") == (None{}, False{}) : Maybe<&2, Bool> & Bool}

law need_landing_prev:
  {m("\\bfoo", "xfoo foo") == Some{[sp(5, 8)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_landing_prev_bytes:
  {mb("\\bfoo", "xfoo foo") == Some{[sp(5, 8)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_landing_prev_hit:
  {both(R.compile("\\bfoo"), "xfoo") == (None{}, False{}) : Maybe<&2, Bool> & Bool}

law need_landing_prev_hit_bytes:
  {bboth(R.compile("\\bfoo"), "xfoo") == (None{}, False{}) : Maybe<&2, Bool> & Bool}

law need_landing_start:
  {both(R.compile("^foo"), "xfoo") == no() : Maybe<&2, Bool> & Bool}

law need_landing_start_bytes:
  {bboth(R.compile("^foo"), "xfoo") == no() : Maybe<&2, Bool> & Bool}

# Guarantees: under (?i) a literal is searched by its whole simple-folding class: k, K and the
#   Kelvin sign; s, S and the long s; sigma in its three forms.
# Why it matters: a search for k alone finds no literal in a text spelled with the Kelvin sign, and
#   the shortcut would answer no match where Go finds one.
law need_fold_kelvin:
  {m("(?i)kelvin", "xx\u{212a}ELVIN") == Some{[sp(2, 8)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_fold_kelvin_bytes:
  {mb("(?i)kelvin", "xx\u{e2}\u{84}\u{aa}ELVIN") == Some{[sp(2, 10)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_fold_long_s:
  {m("(?i)sks", "xx\u{17f}\u{212a}S") == Some{[sp(2, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_fold_long_s_bytes:
  {mb("(?i)sks", "xx\u{c5}\u{bf}\u{e2}\u{84}\u{aa}S") == Some{[sp(2, 8)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_fold_sigma:
  {m("(?i)\u{3c3}\u{3c2}", "x\u{3a3}\u{3c3}") == Some{[sp(1, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_fold_sigma_bytes:
  {mb("(?i)\u{3c3}\u{3c2}", "x\u{ce}\u{a3}\u{cf}\u{83}") == Some{[sp(1, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_fold_case:
  {m("(?i)zqxjv", "ZQXJ zQxJv") == Some{[sp(5, 10)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_fold_case_hit:
  {both(R.compile("(?i)zqxjv"), "ZQXJ zQxJv") == yes() : Maybe<&2, Bool> & Bool}

law need_fold_case_hit_bytes:
  {bboth(R.compile("(?i)zqxjv"), "ZQXJ zQxJv") == yes() : Maybe<&2, Bool> & Bool}

# Guarantees: over Bytes, far counts bytes, a wide char up to four, and the start moves back to
#   the char that holds it; U+FFFD, which also matches an invalid byte, is never a required byte.
# Why it matters: far counted in chars starts past a match before multibyte chars; a start inside
#   a char reads its tail as U+FFFD and can match there, where Go sees one char.
law need_wide_before:
  {m(".{2}foo", "abcd\u{e9}\u{4e2d}foo") == Some{[sp(4, 9)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_wide_before_bytes:
  {mb(".{2}foo", "abcd\u{c3}\u{a9}\u{e4}\u{b8}\u{ad}foo") == Some{[sp(4, 12)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_wide_boundary:
  {m("\\bfoo\\b", "\u{e9}\u{e9}foo foo") == Some{[sp(2, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_wide_boundary_bytes:
  {mb("\\bfoo\\b", "\u{c3}\u{a9}\u{c3}\u{a9}foo foo") == Some{[sp(4, 7)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_wide_class:
  {m("[^ ]foo", "\u{4e2d}\u{4e2d}foo") == Some{[sp(1, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_wide_class_bytes:
  {mb("[^ ]foo", "\u{e4}\u{b8}\u{ad}\u{e4}\u{b8}\u{ad}foo") == Some{[sp(3, 9)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_wide_letters:
  {m("\\p{L}{2}foo", "x\u{4e2d}\u{4e2d}foo") == Some{[sp(1, 6)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_wide_letters_bytes:
  {mb("\\p{L}{2}foo", "x\u{e4}\u{b8}\u{ad}\u{e4}\u{b8}\u{ad}foo") == Some{[sp(1, 10)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_wide_align_bytes:
  {mb("\u{fffd}foo", "\u{f0}\u{9f}\u{98}\u{80}foo") == None{} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_wide_invalid_bytes:
  {mb("\u{fffd}foo", "\u{ff}foo") == Some{[sp(0, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# Guarantees: an alternation requires one literal per branch, and the earliest of any of them
#   bounds the start; a text with none has no match.
# Why it matters: searching for one branch's literal alone would miss the matches of the others.
law need_alt:
  {m("fold_unitx|zq9q|qqq7", "qqq zq9 qqq7 zq9q") == Some{[sp(8, 12)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_alt_bytes:
  {mb("fold_unitx|zq9q|qqq7", "qqq zq9 qqq7 zq9q") == Some{[sp(8, 12)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_alt_absent:
  {both(R.compile("fold_unitx|zq9q|qqq7"), "qqq zq9 qq7 zq9") == no() : Maybe<&2, Bool> & Bool}

law need_alt_absent_bytes:
  {bboth(R.compile("fold_unitx|zq9q|qqq7"), "qqq zq9 qq7 zq9") == no() : Maybe<&2, Bool> & Bool}

# far is the most over the branches, not the first branch's.
law need_alt_far:
  {m("foo|\\w{2}bar", "xxbar foo") == Some{[sp(0, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_alt_far_bytes:
  {mb("foo|\\w{2}bar", "xxbar foo") == Some{[sp(0, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_alt_fold:
  {m("(?i)fold_unitx|zq9q|qqq7", "xx FOLD_UNITX") == Some{[sp(3, 13)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_alt_fold_bytes:
  {mb("(?i)fold_unitx|zq9q|qqq7", "xx FOLD_UNITX") == Some{[sp(3, 13)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# Guarantees: with far unbounded, a found literal starts the automata at the text's start.
# Why it matters: a start at the literal would skip the match that runs up to it.
law need_unbounded:
  {m("a\\d*foo", "foo a1foo") == Some{[sp(4, 9)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_unbounded_bytes:
  {mb("a\\d*foo", "foo a1foo") == Some{[sp(4, 9)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# What the parsed pattern requires: the literals, as sets of code points (bytes over Bytes), and far.

# Guarantees: the longest literal wins, and a bounded far wins a tie; an assertion takes no chars.
# Why it matters: these pin the choice the speed depends on; the spans above pin its soundness.
law need_of_cat:
  {nd("\\bfoo\\d+bar\\b") == Some{R.Need{[[[102], [111], [111]]], Some{0}}} : Maybe<&2, R.Need>}

# Guarantees: one literal per branch; a branch that can match without one leaves none to require.
# Why it matters: a required literal for a|b* would refuse its empty matches.
law need_of_alt:
  {nd("ab|cd") == Some{R.Need{[[[97], [98]], [[99], [100]]], Some{0}}} : Maybe<&2, R.Need>}

law need_of_optional:
  {nd("a|b*") == None{} : Maybe<&2, R.Need>}

# Guarantees: a repetition without bound makes far unbounded; a bounded one adds its most.
# Why it matters: an unbounded far may only shortcut, never move the start.
law need_of_unbounded:
  {nd(".*foo") == Some{R.Need{[[[102], [111], [111]]], None{}}} : Maybe<&2, R.Need>}

law need_of_far:
  {nd(".{2}foo") == Some{R.Need{[[[102], [111], [111]]], Some{2}}} : Maybe<&2, R.Need>}

law need_of_far_bytes:
  {ndb(".{2}foo") == Some{R.Need{[[[102], [111], [111]]], Some{8}}} : Maybe<&2, R.Need>}

# Guarantees: under (?i), a String literal keeps the folded k; over Bytes the Kelvin sign has no one
#   byte form, so the literal is the rest, three bytes on.
# Why it matters: these pin the fold rule: a literal set holds every equivalent, or it is no literal.
law need_of_fold:
  {nfar(nd("(?i)kelvin")) == (Some{Some{0}}, 6) : Maybe<&2, Maybe<&2, U32>> & U32}

law need_of_fold_bytes:
  {nfar(ndb("(?i)kelvin")) == (Some{Some{3}}, 5) : Maybe<&2, Maybe<&2, U32>> & U32}

law need_of_utf8_bytes:
  {ndb("\u{e9}") == Some{R.Need{[[[195], [169]]], Some{0}}} : Maybe<&2, R.Need>}

law need_of_fffd:
  {nd("\u{fffd}foo") == Some{R.Need{[[[65533], [102], [111], [111]]], Some{0}}} : Maybe<&2, R.Need>}

law need_of_fffd_bytes:
  {ndb("\u{fffd}foo") == Some{R.Need{[[[102], [111], [111]]], Some{3}}} : Maybe<&2, R.Need>}

# Guarantees: a String search uses the literals when every match starts at one and the pattern has
#   no word boundary, under (?i) and for an alternation too; not with a word boundary, a bounded
#   far or an unbounded one.
# Why it matters: over a String the scan to a literal costs about what the DFA's own skip to it
#   does, so it pays only when the DFA then starts at the literal with nothing more to do. With far,
#   the DFA would start over from the text's start, or after a walk back, on top of the scan; with a
#   word boundary it would need the char before the literal, which the scan does not keep, and
#   reading none there makes \b hold between two word chars.
law need_gate_on:
  {gt("zqxjv") == True{} : Bool}

law need_gate_on_alt:
  {gt("(?i)fold_unitx|zq9q|qqq7") == True{} : Bool}

law need_gate_boundary:
  {gt("\\bfoo\\d+bar\\b") == False{} : Bool}

law need_gate_far:
  {gt(".{2}foo") == False{} : Bool}

law need_gate_unbounded:
  {gt("a\\d*foo") == False{} : Bool}

# Anchors: the scan looks for each literal's rarest set and checks the literal around it.

# Guarantees: a literal's anchor is its rarest set, the first of the rarest on a tie: @ in
#   x@host.org, q (not y) in yq, and z, the first of z q j, in zqxjv; under (?i) a set ranks as its
#   most common member, so e|E loses to the sigma set; over Bytes a char's lead byte can anchor.
# Why it matters: these pin the choice the speed depends on: anchored on x, a text of x's stops
#   the scan at every byte; the spans below pin its soundness.
law need_anchor_rare:
  {an("x@host\\.org") == [1] : List<&2, U32>}

law need_anchor_first_on_tie:
  {an("zqxjv") == [0] : List<&2, U32>}

law need_anchor_alt_places:
  {an("b@|ab@|yq") == [1, 2, 1] : List<&2, U32>}

law need_anchor_fold:
  {an("(?i)e\u{3c3}") == [1] : List<&2, U32>}

law need_anchor_wide_bytes:
  {anb("a\u{e9}b") == [1] : List<&2, U32>}

# Guarantees: with the anchor inside the literal, the search finds the match that starts before
#   it, and a text where the anchor occurs only in near misses has no match.
# Why it matters: a scan that checked the literal from the anchor, not from its start, would
#   match user@host.com, or start past the x.
law need_anchor_inside:
  {m("x@host\\.org", "xxxxuser@host.comxxxx@host.org") == Some{[sp(20, 30)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_anchor_inside_bytes:
  {mb("x@host\\.org", "xxxxuser@host.comxxxx@host.org") == Some{[sp(20, 30)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_anchor_inside_absent:
  {both(R.compile("x@host\\.org"), "xxxxuser@host.comxxxx") == no() : Maybe<&2, Bool> & Bool}

law need_anchor_inside_absent_bytes:
  {bboth(R.compile("x@host\\.org"), "xxxxuser@host.comxxxx") == no() : Maybe<&2, Bool> & Bool}

# Guarantees: the search starts at the first anchor place that holds a literal, less the largest
#   anchor place of any literal: x@host.org found at 20 by its @ at 21; b@ found by its @ at 3
#   starts the search at 1, where ab@ starts.
# Why it matters: starting at the literal found (b@, at 2) would miss ab@, which starts at 1 and
#   holds a match there: Go answers 1:4.
law need_anchor_start_bytes:
  {stb("x@host\\.org", "xxxxuser@host.comxxxx@host.org") == Some{20} : Maybe<&2, U32>}

law need_anchor_start_none_bytes:
  {stb("x@host\\.org", "xxxxuser@host.comxxxx") == None{} : Maybe<&2, U32>}

law need_anchor_back_start_bytes:
  {stb("b@|ab@", "xab@") == Some{1} : Maybe<&2, U32>}

law need_anchor_back_start:
  {sts("b@|ab@", "xab@") == "ab@" : String}

law need_anchor_back:
  {m("b@|ab@", "xab@") == Some{[sp(1, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_anchor_back_bytes:
  {mb("b@|ab@", "xab@") == Some{[sp(1, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_anchor_back_order:
  {m("ab@|b@", "xab@") == Some{[sp(1, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_anchor_back_order_bytes:
  {mb("ab@|b@", "xab@") == Some{[sp(1, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

# Guarantees: a place where only the anchor and what follows it match is no hit: the literal is
#   checked from its start.
# Why it matters: y@host.org would start the automata at 0 and leave them the near miss to read.
law need_anchor_prefix_start:
  {sts("x@host\\.org", "y@host.orgx@host.org") == "x@host.org" : String}

law need_anchor_prefix_start_bytes:
  {stb("x@host\\.org", "y@host.orgx@host.org") == Some{10} : Maybe<&2, U32>}

# Guarantees: a literal found before the largest anchor place starts the search at the text's
#   start, not below it.
# Why it matters: an offset that wrapped below 0 would start past the end and miss the match.
law need_anchor_clamp:
  {m("q|abcd@", "q") == Some{[sp(0, 1)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_anchor_clamp_bytes:
  {mb("q|abcd@", "q") == Some{[sp(0, 1)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_anchor_clamp_start:
  {sts("q|abcd@", "zq") == "zq" : String}

law need_anchor_clamp_start_bytes:
  {stb("q|abcd@", "zq") == Some{0} : Maybe<&2, U32>}

# Guarantees: under (?i) the anchor set holds every case form; for a non-ASCII set over a String
#   the anchor is a code point, and over Bytes a lead byte; with far, the start moves back by far
#   on top of the anchor place.
# Why it matters: an anchor that missed a case form, a byte of a wide char, or far would skip the
#   match.
law need_anchor_fold_hit:
  {m("(?i)x@host\\.org", "xxX@HOST.ORG") == Some{[sp(2, 12)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_anchor_fold_hit_bytes:
  {mb("(?i)x@host\\.org", "xxX@HOST.ORG") == Some{[sp(2, 12)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_anchor_fold_wide:
  {m("(?i)e\u{3c3}", "xE\u{3c2}") == Some{[sp(1, 3)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_anchor_fold_wide_bytes:
  {mb("(?i)e\u{3c3}", "xE\u{cf}\u{82}") == Some{[sp(1, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_anchor_wide:
  {m("a\u{e9}b", "aa\u{e9}b") == Some{[sp(1, 4)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_anchor_wide_hit_bytes:
  {mb("a\u{e9}b", "aa\u{c3}\u{a9}b") == Some{[sp(1, 5)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_anchor_far:
  {m("x.{0,4}x@host\\.org", "xxxxxxxx@host.org") == Some{[sp(2, 17)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}

law need_anchor_far_bytes:
  {mb("x.{0,4}x@host\\.org", "xxxxxxxx@host.org") == Some{[sp(2, 17)]} : Maybe<&2, List<&2, Maybe<&2, R.Span>>>}
