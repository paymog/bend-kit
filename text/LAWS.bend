import Base
import ./text.bend as T
import bend-kit-tty@0.1.0.1/text.bend as Tty

# Every edit that is not Same.
def changes(-A: Data, es: List<&2, T.Edit<A>>) -> Nat:
  match es:
    case Nil{}:
      0n
    case Con{T.Same{_, _}, t}:
      changes(A, t)
    case Con{_, t}:
      1n+changes(A, t)

def fits.go(ls: List<&2, String>, +width: U32) -> Bool:
  match ls:
    case Nil{}:
      True{}
    case Con{l, t}:
      U32.is_le(Tty.width(l), width) && fits.go(t, width)

def fits(ls: List<&2, String>, +width: U32) -> Bool:
  fits.go(ls, width)

# ---- diff: any replay of moves gives both inputs back, so every diff does.
law walk_before:
  for ~A: Data
  for ms: List<&2, T.Move>
  for +a: List<&2, A>
  for b: List<&2, A>
  {T.before(A, T.walk(A, ms, a, b)) == a : List<&2, A>}

law walk_after:
  for ~A: Data
  for ms: List<&2, T.Move>
  for a: List<&2, A>
  for +b: List<&2, A>
  {T.after(A, T.walk(A, ms, a, b)) == b : List<&2, A>}

law diff_before:
  for ~A: Data
  for ~eq: A -> A -> Bool
  for +a: List<&2, A>
  for +b: List<&2, A>
  {T.before(A, T.diff(~A, ~eq, a, b)) == a : List<&2, A>}

# Applying a diff reproduces the target.
law diff_after:
  for ~A: Data
  for ~eq: A -> A -> Bool
  for +a: List<&2, A>
  for +b: List<&2, A>
  {T.after(A, T.diff(~A, ~eq, a, b)) == b : List<&2, A>}

law diff_lines_after:
  for a: String
  for +b: String
  {T.after(String, T.diff_lines(a, b)) == T.lines(b) : List<&2, String>}

# The example from Myers' paper: the shortest script has 5 edits.
law myers_paper:
  {changes(Char, T.diff_chars("ABCABBA", "CBABAC")) == 5n : Nat}

law diff_same:
  {changes(String, T.diff_lines("a\nb\nc\n", "a\nb\nc\n")) == 0n : Nat}

law lines_final_newline:
  {T.lines("a\nb\n") == ["a", "b"] : List<&2, String>}

law lines_no_final_newline:
  {T.lines("a\n\nb") == ["a", "", "b"] : List<&2, String>}

law lines_empty:
  {T.lines("") == [] : List<&2, String>}

# ---- unified output, checked against diff -U
law unified_two_hunks:
  {T.unified("a", "b", T.diff_lines("1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n", "1\n2\nx\n4\n5\n6\n7\n8\n9\n10\n11\n"), 2)
   == "--- a\n+++ b\n@@ -1,5 +1,5 @@\n 1\n 2\n-3\n+x\n 4\n 5\n@@ -9,2 +9,3 @@\n 9\n 10\n+11\n" : String}

law unified_zero_context:
  {T.unified("a", "b", T.diff_lines("1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n", "1\n2\nx\n4\n5\n6\n7\n8\n9\n10\n11\n"), 0)
   == "--- a\n+++ b\n@@ -3 +3 @@\n-3\n+x\n@@ -10,0 +11 @@\n+11\n" : String}

# Two changes merge into one hunk when at most 2*ctx unchanged lines separate them.
law unified_merge:
  {T.unified("a", "b", T.diff_lines("1\n2\n3\n4\n", "x\n2\n3\ny\n"), 1)
   == "--- a\n+++ b\n@@ -1,4 +1,4 @@\n-1\n+x\n 2\n 3\n-4\n+y\n" : String}

law unified_split:
  {T.unified("a", "b", T.diff_lines("1\n2\n3\n4\n5\n", "x\n2\n3\n4\ny\n"), 1)
   == "--- a\n+++ b\n@@ -1,2 +1,2 @@\n-1\n+x\n 2\n@@ -4,2 +4,2 @@\n 4\n-5\n+y\n" : String}

law unified_from_empty:
  {T.unified("e", "c", T.diff_lines("", "x\n"), 3) == "--- e\n+++ c\n@@ -0,0 +1 @@\n+x\n" : String}

law unified_to_empty:
  {T.unified("c", "e", T.diff_lines("x\n", ""), 3) == "--- c\n+++ e\n@@ -1 +0,0 @@\n-x\n" : String}

law unified_no_change:
  {T.unified("a", "b", T.diff_lines("x\ny\n", "x\ny\n"), 3) == "" : String}

# ---- Levenshtein
law distance_kitten:
  {T.distance("kitten", "sitting") == 3 : U32}

law distance_flaw:
  {T.distance("flaw", "lawn") == 2 : U32}

law distance_gumbo:
  {T.distance("gumbo", "gambol") == 2 : U32}

law distance_from_empty:
  {T.distance("", "abc") == 3 : U32}

law distance_to_empty:
  {T.distance("abc", "") == 3 : U32}

law distance_same:
  {T.distance("same", "same") == 0 : U32}

law distance_code_points:
  {T.distance("café", "cafe") == 1 : U32}

# ---- wrap
law wrap_words:
  {T.wrap("The quick  brown fox jumps over the lazy dog", 10)
   == ["The quick", "brown fox", "jumps over", "the lazy", "dog"] : List<&2, String>}

law wrap_long_word:
  {T.wrap("a supercalifragilistic b", 10) == ["a", "supercalif", "ragilistic", "b"] : List<&2, String>}

law wrap_wide:
  {T.wrap("日本語の文章", 5) == ["日本", "語の", "文章"] : List<&2, String>}

law wrap_empty:
  {T.wrap(" \n\t ", 10) == [] : List<&2, String>}

law wrap_fits_words:
  {fits(T.wrap("The quick  brown fox jumps over the lazy dog", 10), 10) == True{} : Bool}

law wrap_fits_long_word:
  {fits(T.wrap("a supercalifragilistic b", 4), 4) == True{} : Bool}

law wrap_fits_wide:
  {fits(T.wrap("日本語 の 文章です", 3), 3) == True{} : Bool}

law wrap_fits_combining:
  {fits(T.wrap("e\u{301}e\u{301}e\u{301}e\u{301} x", 2), 2) == True{} : Bool}
