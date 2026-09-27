import Base
import ./regex.bend as R

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
  {ok("(?i)a") == False{} : Bool}
