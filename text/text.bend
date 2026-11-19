# Text utilities: Myers diff with unified output, Levenshtein distance, and word wrap by display width.
import Base
import bend-kit-unicode@0.1.0.0/unicode.bend as Unicode
import bend-kit-tty@0.1.0.1/text.bend as Tty

# ---- edit scripts

# Same pairs an old item with the new item it matched; before keeps old items, after keeps new ones.
type Edit<-A: Data> is Data:
  Same{old: A, new: A}
  Del{old: A}
  Ins{new: A}

type Move is Data:
  MSame{}
  MDel{}
  MIns{}

def before(-A: Data, es: List<&2, Edit<A>>) -> List<&2, A>:
  match es:
    case Nil{}:
      Nil{}
    case Con{Same{o, n}, t}:
      o <> before(A, t)
    case Con{Del{o}, t}:
      o <> before(A, t)
    case Con{Ins{n}, t}:
      before(A, t)

def after(-A: Data, es: List<&2, Edit<A>>) -> List<&2, A>:
  match es:
    case Nil{}:
      Nil{}
    case Con{Same{o, n}, t}:
      n <> after(A, t)
    case Con{Del{o}, t}:
      after(A, t)
    case Con{Ins{n}, t}:
      n <> after(A, t)

def walk.ins(-A: Data, b: List<&2, A>) -> List<&2, Edit<A>>:
  match b:
    case Nil{}:
      Nil{}
    case Con{y, t}:
      Ins{y} <> walk.ins(A, t)

def walk.rest(-A: Data, a: List<&2, A>, b: List<&2, A>) -> List<&2, Edit<A>>:
  match a:
    case Nil{}:
      walk.ins(A, b)
    case Con{x, t}:
      Del{x} <> walk.rest(A, t, b)

# Replays moves over a and b. A move that does not fit is skipped, and leftovers become Del then Ins,
# so before and after give a and b back for any moves.
def walk(-A: Data, ms: List<&2, Move>, a: List<&2, A>, b: List<&2, A>) -> List<&2, Edit<A>>:
  match ms a b:
    case Nil{} _ _:
      walk.rest(A, a, b)
    case Con{MSame{}, t} Con{x, xs} Con{y, ys}:
      Same{x, y} <> walk(A, t, xs, ys)
    case Con{MDel{}, t} Con{x, xs} _:
      Del{x} <> walk(A, t, xs, b)
    case Con{MIns{}, t} _ Con{y, ys}:
      Ins{y} <> walk(A, t, a, ys)
    case Con{_, t} _ _:
      walk(A, t, a, b)

# ---- Myers O(ND) diff

# One furthest-reaching path on a diagonal: x old items consumed, a and b the rest, path newest first.
type Tip<-A: Data> is Data:
  Dead{}
  Tip{x: U32, a: List<&2, A>, b: List<&2, A>, path: List<&2, Move>}

def heads(~A: Data, ~eq: A -> A -> Bool, +a: List<&2, A>, +b: List<&2, A>) -> Bool:
  match a b:
    case Con{x, _} Con{y, _}:
      eq(x, y)
    case _ _:
      False{}

# more says whether the heads of a and b match.
def snake(~A: Data, ~eq: A -> A -> Bool, a: List<&2, A>, more: Bool, b: List<&2, A>, +x: U32, p: List<&2, Move>) -> Tip<A>:
  match a more b:
    case Con{_, +t} True{} Con{_, +u}:
      snake(~A, ~eq, t, heads(~A, ~eq, t, u), u, (x + 1 : U32), MSame{} <> p)
    case _ _ _:
      Tip{x, a, b, p}

def slide(~A: Data, ~eq: A -> A -> Bool, tip: Tip<A>) -> Tip<A>:
  match tip:
    case Dead{}:
      Dead{}
    case Tip{x, +a, +b, p}:
      snake(~A, ~eq, a, heads(~A, ~eq, a, b), b, x, p)

def tip.del(-A: Data, tip: Tip<A>) -> Tip<A>:
  match tip:
    case Tip{x, Con{_, t}, b, p}:
      Tip{(x + 1 : U32), t, b, MDel{} <> p}
    case _:
      Dead{}

def tip.ins(-A: Data, tip: Tip<A>) -> Tip<A>:
  match tip:
    case Tip{x, a, Con{_, u}, p}:
      Tip{x, a, u, MIns{} <> p}
    case _:
      Dead{}

def choose.pick(-A: Data, right: Bool, l: Tip<A>, r: Tip<A>) -> Tip<A>:
  match right:
    case True{}:
      r
    case False{}:
      l

# Myers' rule: go down from k+1 when V[k-1] < V[k+1]; l is already one step right of V[k-1].
def choose(-A: Data, l: Tip<A>, r: Tip<A>) -> Tip<A>:
  match l r:
    case Dead{} _:
      r
    case Tip{+lx, la, lb, lp} Dead{}:
      Tip{lx, la, lb, lp}
    case Tip{+lx, la, lb, lp} Tip{+rx, ra, rb, rp}:
      choose.pick(A, U32.is_le(lx, rx), Tip{lx, la, lb, lp}, Tip{rx, ra, rb, rp})

def step.mid(~A: Data, ~eq: A -> A -> Bool, ts: List<&2, Tip<A>>, +prev: Tip<A>) -> List<&2, Tip<A>>:
  match ts:
    case Nil{}:
      [slide(~A, ~eq, tip.del(A, prev))]
    case Con{+t, rest}:
      slide(~A, ~eq, choose(A, tip.del(A, prev), tip.ins(A, t))) <> step.mid(~A, ~eq, rest, t)

# Diagonals -d..d, low k first, become -(d+1)..d+1.
def step(~A: Data, ~eq: A -> A -> Bool, ts: List<&2, Tip<A>>) -> List<&2, Tip<A>>:
  match ts:
    case Nil{}:
      Nil{}
    case Con{+t, rest}:
      slide(~A, ~eq, tip.ins(A, t)) <> step.mid(~A, ~eq, rest, t)

def find(-A: Data, ts: List<&2, Tip<A>>) -> Maybe<&2, List<&2, Move>>:
  match ts:
    case Nil{}:
      None{}
    case Con{Tip{_, Nil{}, Nil{}, p}, _}:
      Some{p}
    case Con{_, rest}:
      find(A, rest)

def run(~A: Data, ~eq: A -> A -> Bool, fuel: Nat, found: Maybe<&2, List<&2, Move>>, ts: List<&2, Tip<A>>) -> List<&2, Move>:
  match fuel found:
    case _ Some{p}:
      List.reverse(&2, Move, p)
    case 0n None{}:
      Nil{}
    case 1n+f None{}:
      +next = step(~A, ~eq, ts)
      run(~A, ~eq, f, find(A, next), next)

def moves(~A: Data, ~eq: A -> A -> Bool, +a: List<&2, A>, +b: List<&2, A>) -> List<&2, Move>:
  +t0 = {[slide(~A, ~eq, Tip{0, a, b, Nil{}})] : List<&2, Tip<A>>}
  run(~A, ~eq, 1n+Nat.add(List.length(&2, A, a), List.length(&2, A, b)), find(A, t0), t0)

# A shortest edit script from a to b. eq decides which items match.
def diff(~A: Data, ~eq: A -> A -> Bool, +a: List<&2, A>, +b: List<&2, A>) -> List<&2, Edit<A>>:
  walk(A, moves(~A, ~eq, a, b), a, b)

def lines.fin(empty: Bool, +h: String) -> List<&2, String>:
  match empty:
    case True{}:
      Nil{}
    case False{}:
      [h]

def lines.go(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, Nil{}}:
      lines.fin(String.is_empty(h), h)
    case Con{h, t}:
      h <> lines.go(t)

# Lines split on "\n". A final "\n" ends the last line; it does not start an empty one.
def lines(s: String) -> List<&2, String>:
  lines.go(String.lines(s))

def diff_lines(a: String, b: String) -> List<&2, Edit<String>>:
  diff(~String, ~String.eq, lines(a), lines(b))

def diff_chars(a: String, b: String) -> List<&2, Edit<Char>>:
  diff(~Char, ~Char.is_eq, String.to_list(a), String.to_list(b))

# ---- unified output

def far() -> U32:
  1000000000

def ahead.next(+r: List<&2, U32>) -> U32:
  match r:
    case Nil{}:
      far()
    case Con{d, _}:
      U32.min((d + 1 : U32), far())

def ahead.cons(+change: Bool, +r: List<&2, U32>) -> List<&2, U32>:
  Bool.pick(U32, change, 0, ahead.next(r)) <> r

def is_change(-A: Data, e: Edit<A>) -> Bool:
  match e:
    case Same{_, _}:
      False{}
    case _:
      True{}

# For each edit, how many edits ahead the next change is: 0 for a change.
def ahead(-A: Data, es: List<&2, Edit<A>>) -> List<&2, U32>:
  match es:
    case Nil{}:
      Nil{}
    case Con{+e, t}:
      ahead.cons(is_change(A, e), ahead(A, t))

# A Gap is a Same line outside every hunk. dold and dnew count the old and new lines a row consumes.
type Row is Data:
  Gap{}
  Line{text: String, dold: U32, dnew: U32}

def rows(es: List<&2, Edit<String>>, ds: List<&2, U32>, +ctx: U32, +back: U32) -> List<&2, Row>:
  match es ds:
    case Con{Same{_, n}, t} Con{+d, dt}:
      +b = U32.min((back + 1 : U32), far())
      Bool.pick(Row, U32.is_le(b, ctx) || U32.is_le(d, ctx), Line{" " ++ n, 1, 1}, Gap{}) <> rows(t, dt, ctx, b)
    case Con{Del{o}, t} Con{_, dt}:
      Line{"-" ++ o, 1, 0} <> rows(t, dt, ctx, 0)
    case Con{Ins{n}, t} Con{_, dt}:
      Line{"+" ++ n, 0, 1} <> rows(t, dt, ctx, 0)
    case _ _:
      Nil{}

type Hunk is Data:
  Hunk{o: U32, n: U32, ol: U32, nl: U32, body: List<&2, String>}

# GNU form: an empty range names the line before it, and a one-line range drops ",1".
def range.pick(empty: Bool, +start: U32, +len: U32) -> String:
  match empty:
    case True{}:
      U32.show(start) ++ ",0"
    case False{}:
      Bool.pick(String, U32.is_eq(len, 1), U32.show((start + 1 : U32)),
        U32.show((start + 1 : U32)) ++ "," ++ U32.show(len))

def range(+start: U32, +len: U32) -> String:
  range.pick(U32.is_eq(len, 0), start, len)

def hunk.show(h: Hunk) -> String:
  match h:
    case Hunk{o, n, ol, nl, body}:
      "@@ -" ++ range(o, ol) ++ " +" ++ range(n, nl) ++ " @@\n" ++
        String.concat(List.reverse(&2, String, body))

def close(cur: Maybe<&2, Hunk>, out: List<&2, String>) -> List<&2, String>:
  match cur:
    case None{}:
      out
    case Some{h}:
      hunk.show(h) <> out

def open(cur: Maybe<&2, Hunk>, +o: U32, +n: U32) -> Hunk:
  match cur:
    case None{}:
      Hunk{o, n, 0, 0, Nil{}}
    case Some{h}:
      h

def hunk.add(h: Hunk, text: String, +dold: U32, +dnew: U32) -> Hunk:
  match h:
    case Hunk{o, n, ol, nl, body}:
      Hunk{o, n, (ol + dold : U32), (nl + dnew : U32), (text ++ "\n") <> body}

# o and n count the old and new lines before the row.
def emit(rs: List<&2, Row>, +o: U32, +n: U32, cur: Maybe<&2, Hunk>, out: List<&2, String>) -> List<&2, String>:
  match rs:
    case Nil{}:
      close(cur, out)
    case Con{Gap{}, t}:
      emit(t, (o + 1 : U32), (n + 1 : U32), None{}, close(cur, out))
    case Con{Line{text, +dold, +dnew}, t}:
      emit(t, (o + dold : U32), (n + dnew : U32), Some{hunk.add(open(cur, o, n), text, dold, dnew)}, out)

def unified.fin(hs: List<&2, String>, old_name: String, new_name: String) -> String:
  match hs:
    case Nil{}:
      ""
    case Con{_, _}:
      "--- " ++ old_name ++ "\n+++ " ++ new_name ++ "\n" ++ String.concat(List.reverse(&2, String, hs))

# Unified diff text with ctx lines of context around each change; "" when nothing changed.
# Lines carry no newline, so a missing final newline is not marked.
def unified(old_name: String, new_name: String, +es: List<&2, Edit<String>>, +ctx: U32) -> String:
  unified.fin(emit(rows(es, ahead(String, es), ctx, far()), 0, 0, None{}, Nil{}), old_name, new_name)

# ---- Levenshtein distance

def lev.row(~A: Data, ~eq: A -> A -> Bool, b: List<&2, A>, up: List<&2, U32>, +x: A, +diag: U32, +left: U32) -> List<&2, U32>:
  match b up:
    case Con{+y, bt} Con{+u, ut}:
      +v = U32.min(U32.min((u + 1 : U32), (left + 1 : U32)), (diag + Bool.pick(U32, eq(x, y), 0, 1) : U32))
      v <> lev.row(~A, ~eq, bt, ut, x, u, v)
    case _ _:
      Nil{}

def lev.last(xs: List<&2, U32>, +d: U32) -> U32:
  match xs:
    case Nil{}:
      d
    case Con{+h, t}:
      lev.last(t, h)

def lev.init(n: Nat, +i: U32) -> List<&2, U32>:
  match n:
    case 0n:
      [i]
    case 1n+p:
      i <> lev.init(p, (i + 1 : U32))

def lev.go(~A: Data, ~eq: A -> A -> Bool, a: List<&2, A>, +b: List<&2, A>, prev: List<&2, U32>, +i: U32) -> U32:
  match a prev:
    case Con{+x, at} Con{+p0, pt}:
      +j = (i + 1 : U32)
      lev.go(~A, ~eq, at, b, j <> lev.row(~A, ~eq, b, pt, x, p0, j), j)
    case _ _:
      lev.last(prev, 0)

# Fewest inserts, deletes, and substitutions that turn a into b.
def edit_distance(~A: Data, ~eq: A -> A -> Bool, a: List<&2, A>, +b: List<&2, A>) -> U32:
  lev.go(~A, ~eq, a, b, lev.init(List.length(&2, A, b), 0), 0)

# Levenshtein distance by code point.
def distance(a: String, b: String) -> U32:
  edit_distance(~Char, ~Char.is_eq, String.to_list(a), String.to_list(b))

# ---- word wrap

def words.flush(cur: String, out: List<&2, String>) -> List<&2, String>:
  match cur:
    case SNil{}:
      out
    case SCon{h, t}:
      String.reverse(SCon{h, t}) <> out

# cur holds the word being read, reversed.
def words.step(sp: Bool, +c: Char, st: String & List<&2, String>) -> String & List<&2, String>:
  match sp:
    case True{}:
      (cur, out) = st
      (SNil{}, words.flush(cur, out))
    case False{}:
      (cur, out) = st
      (SCon{c, cur}, out)

def words.go(s: String, st: String & List<&2, String>) -> List<&2, String>:
  match s:
    case SNil{}:
      (cur, out) = st
      List.reverse(&2, String, words.flush(cur, out))
    case SCon{+c, t}:
      words.go(t, words.step(Char.is_space(c), c, st))

# Runs of non-space chars.
def words(s: String) -> List<&2, String>:
  words.go(s, (SNil{}, Nil{}))

# The line being built, its display width, and the finished lines, newest first.
type Wrap is Data:
  Wrap{cur: String, w: U32, out: List<&2, String>}

def wrap.flush(cur: String, out: List<&2, String>) -> List<&2, String>:
  match cur:
    case SNil{}:
      out
    case SCon{h, t}:
      SCon{h, t} <> out

def chop.pick(push: Bool, st: Wrap, g: String, +gw: U32) -> Wrap:
  match push:
    case True{}:
      match st:
        case Wrap{cur, w, out}:
          Wrap{g, gw, cur <> out}
    case False{}:
      match st:
        case Wrap{cur, w, out}:
          Wrap{cur ++ g, (w + gw : U32), out}

def chop.one(st: Wrap, +g: String, +width: U32) -> Wrap:
  match st:
    case Wrap{+cur, +w, out}:
      +gw = Tty.cluster(g)
      chop.pick(Bool.not(String.is_empty(cur)) && U32.is_lt(width, (w + gw : U32)), Wrap{cur, w, out}, g, gw)

# Breaks a word wider than the line at grapheme boundaries.
def chop(gs: List<&2, String>, +width: U32, st: Wrap) -> Wrap:
  match gs:
    case Nil{}:
      st
    case Con{g, t}:
      chop(t, width, chop.one(st, g, width))

def place(fits: Bool, out: List<&2, String>, +word: String, +ww: U32, +width: U32) -> Wrap:
  match fits:
    case True{}:
      Wrap{word, ww, out}
    case False{}:
      chop(Unicode.graphemes(word), width, Wrap{"", 0, out})

def wrap.word.pick(join: Bool, st: Wrap, word: String, +ww: U32, +width: U32) -> Wrap:
  match join:
    case True{}:
      match st:
        case Wrap{cur, w, out}:
          Wrap{cur ++ " " ++ word, (w + 1 + ww : U32), out}
    case False{}:
      match st:
        case Wrap{cur, w, out}:
          place(U32.is_le(ww, width), wrap.flush(cur, out), word, ww, width)

def wrap.word(st: Wrap, +word: String, +width: U32) -> Wrap:
  match st:
    case Wrap{+cur, +w, out}:
      +ww = Tty.width(word)
      wrap.word.pick(Bool.not(String.is_empty(cur)) && U32.is_le((w + 1 + ww : U32), width), Wrap{cur, w, out}, word, ww, width)

def wrap.go(ws: List<&2, String>, +width: U32, st: Wrap) -> List<&2, String>:
  match ws:
    case Nil{}:
      match st:
        case Wrap{cur, w, out}:
          List.reverse(&2, String, wrap.flush(cur, out))
    case Con{word, t}:
      wrap.go(t, width, wrap.word(st, word, width))

# Greedy word wrap to width display columns. Whitespace runs separate words; lines join words with one space.
# A word wider than width is broken between grapheme clusters. Only a single cluster wider than width
# makes a line wider than width.
def wrap(text: String, +width: U32) -> List<&2, String>:
  wrap.go(words(text), width, Wrap{"", 0, Nil{}})
