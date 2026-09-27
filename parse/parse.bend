# Parser combinators over text, with positioned errors. Source: https://github.com/paymog/bend-kit/tree/main/parse
import Base

# A parser is a template `~p: Parse.Cur -> Parse.Res<A>`. Choice backtracks
# (PEG). A Bend def cannot recurse through a template, so a nested grammar
# uses `rec`, which keeps its own stack.
#   import ./parse/parse.bend as Parse

# left is the length of s: loops use it as fuel. Build a Cur with `start`.
type Cur is Data:
  Cur{s: String, off: U32, left: Nat}

# off is the char offset of the failure; want names what was expected there.
type Res<-A: Data> is Data:
  Ok{v: A, cur: Cur}
  Err{off: U32, want: String}

# One step of `rec`: a finished value, or a frame that wants a child value.
type Step<-A: Data, -F: Data> is Data:
  Leaf{v: A}
  Open{f: F}

# A reusable pair (a, b); `A & B` is not Data.
def Both(-A: Data, -B: Data) -> Data:
  Sigma<&2, &2, A, _ => B>

def start(+s: String) -> Cur:
  Cur{s, 0, String.length(s)}

def off(c: Cur) -> U32:
  match c:
    case Cur{s, o, n}:
      o

def fuel(c: Cur) -> Nat:
  match c:
    case Cur{s, o, n}:
      n

def dec(n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+k:
      k

def quote(s: String) -> String:
  "\"" ++ s ++ "\""

# Primitives
# ----------

def satisfy.if(ok: Bool, +h: U32, t: String, +o: U32, n: Nat, want: String) -> Res<U32>:
  match ok:
    case True{}:
      Ok{h, Cur{t, (o + 1 : U32), dec(n)}}
    case False{}:
      Err{o, want}

# One char c with f(c); the value is its code.
def satisfy(~f: @+c: U32 -> Bool, want: String, c: Cur) -> Res<U32>:
  match c:
    case Cur{s, +o, n}:
      match s:
        case SNil{}:
          Err{o, want}
        case SCon{Chr{+h}, t}:
          satisfy.if(f(h), h, t, o, n, want)

# The char w.
def char(+w: U32, c: Cur) -> Res<U32>:
  match c:
    case Cur{s, +o, n}:
      match s:
        case SNil{}:
          Err{o, quote(SCon{Chr{w}, SNil{}})}
        case SCon{Chr{+h}, t}:
          satisfy.if(U32.is_eq(h, w), h, t, o, n, quote(SCon{Chr{w}, SNil{}}))

def lit.if(ok: Bool, +w: String, +s: String, +o: U32, n: Nat) -> Res<String>:
  match ok:
    case True{}:
      +k = String.length(w)
      Ok{w, Cur{String.drop(s, k), (o + U32.from_nat(k) : U32), Nat.sub(n, k)}}
    case False{}:
      Err{o, quote(w)}

# The string w.
def lit(+w: String, c: Cur) -> Res<String>:
  match c:
    case Cur{+s, o, n}:
      lit.if(String.starts_with(s, w), w, s, o, n)

# h is the next char and t the text after it; ok is f(h).
def take_while.go(~f: @+c: U32 -> Bool, t: String, +h: U32, +o: U32, n: Nat, acc: String, ok: Bool) -> Res<String>:
  match t:
    case SNil{}:
      match ok:
        case True{}:
          Ok{String.reverse(SCon{Chr{h}, acc}), Cur{SNil{}, (o + 1 : U32), dec(n)}}
        case False{}:
          Ok{String.reverse(acc), Cur{SCon{Chr{h}, SNil{}}, o, n}}
    case SCon{Chr{+d}, u}:
      match ok:
        case True{}:
          take_while.go(~f, u, d, (o + 1 : U32), dec(n), SCon{Chr{h}, acc}, f(d))
        case False{}:
          Ok{String.reverse(acc), Cur{SCon{Chr{h}, SCon{Chr{d}, u}}, o, n}}

# The longest run of chars with f; it can be empty.
def take_while(~f: @+c: U32 -> Bool, c: Cur) -> Res<String>:
  match c:
    case Cur{s, o, n}:
      match s:
        case SNil{}:
          Ok{"", Cur{SNil{}, o, n}}
        case SCon{Chr{+h}, t}:
          take_while.go(~f, t, h, o, n, "", f(h))

def eof(c: Cur) -> Res<Unit>:
  match c:
    case Cur{s, +o, n}:
      match s:
        case SNil{}:
          Ok{Unit{}, Cur{SNil{}, o, n}}
        case SCon{h, t}:
          Err{o, "end of input"}

# Combinators
# -----------

def pure(-A: Data, v: A, c: Cur) -> Res<A>:
  Ok{v, c}

def fail(-A: Data, want: String, c: Cur) -> Res<A>:
  Err{off(c), want}

def map.r(~A: Data, ~B: Data, ~f: A -> B, r: Res<A>) -> Res<B>:
  match r:
    case Ok{v, c}:
      Ok{f(v), c}
    case Err{o, w}:
      Err{o, w}

def map(~A: Data, ~B: Data, ~f: A -> B, ~p: Cur -> Res<A>, c: Cur) -> Res<B>:
  map.r(~A, ~B, ~f, p(c))

def bind.r(~A: Data, ~B: Data, ~k: A -> Cur -> Res<B>, r: Res<A>) -> Res<B>:
  match r:
    case Ok{v, c}:
      k(v, c)
    case Err{o, w}:
      Err{o, w}

# p, then the parser k picks from p's value.
def bind(~A: Data, ~B: Data, ~p: Cur -> Res<A>, ~k: A -> Cur -> Res<B>, c: Cur) -> Res<B>:
  bind.r(~A, ~B, ~k, p(c))

def seq.b(-A: Data, -B: Data, v: A, r: Res<B>) -> Res<Both(A, B)>:
  match r:
    case Ok{w, c}:
      Ok{(v, w), c}
    case Err{o, w}:
      Err{o, w}

def seq.a(~A: Data, ~B: Data, ~q: Cur -> Res<B>, r: Res<A>) -> Res<Both(A, B)>:
  match r:
    case Ok{v, c}:
      seq.b(A, B, v, q(c))
    case Err{o, w}:
      Err{o, w}

# p, then q; both values.
def seq(~A: Data, ~B: Data, ~p: Cur -> Res<A>, ~q: Cur -> Res<B>, c: Cur) -> Res<Both(A, B)>:
  seq.a(~A, ~B, ~q, p(c))

def keep.b(-A: Data, -B: Data, v: A, r: Res<B>) -> Res<A>:
  match r:
    case Ok{w, c}:
      Ok{v, c}
    case Err{o, w}:
      Err{o, w}

def keep.a(~A: Data, ~B: Data, ~q: Cur -> Res<B>, r: Res<A>) -> Res<A>:
  match r:
    case Ok{v, c}:
      keep.b(A, B, v, q(c))
    case Err{o, w}:
      Err{o, w}

# p, then q; p's value.
def left(~A: Data, ~B: Data, ~p: Cur -> Res<A>, ~q: Cur -> Res<B>, c: Cur) -> Res<A>:
  keep.a(~A, ~B, ~q, p(c))

def skip.a(~A: Data, ~B: Data, ~q: Cur -> Res<B>, r: Res<A>) -> Res<B>:
  match r:
    case Ok{v, c}:
      q(c)
    case Err{o, w}:
      Err{o, w}

# p, then q; q's value.
def right(~A: Data, ~B: Data, ~p: Cur -> Res<A>, ~q: Cur -> Res<B>, c: Cur) -> Res<B>:
  skip.a(~A, ~B, ~q, p(c))

def alt.join(same: Bool, w1: String, w2: String) -> String:
  match same:
    case True{}:
      w1
    case False{}:
      w1 ++ " or " ++ w2

# The error that got further wins; at the same offset, both wants join.
def alt.pick(-A: Data, k: Cmp, +o1: U32, +w1: String, +o2: U32, +w2: String) -> Res<A>:
  match k:
    case LT{}:
      Err{o2, w2}
    case GT{}:
      Err{o1, w1}
    case EQ{}:
      Err{o1, alt.join(String.eq(w1, w2), w1, w2)}

def alt.e(-A: Data, +o1: U32, +w1: String, r: Res<A>) -> Res<A>:
  match r:
    case Ok{v, c}:
      Ok{v, c}
    case Err{+o2, +w2}:
      alt.pick(A, U32.cmp(o1, o2), o1, w1, o2, w2)

def alt.r(~A: Data, ~q: Cur -> Res<A>, c: Cur, r: Res<A>) -> Res<A>:
  match r:
    case Ok{v, d}:
      Ok{v, d}
    case Err{+o, w}:
      alt.e(A, o, w, q(c))

# p; if it fails, q from the same place.
def alt(~A: Data, ~p: Cur -> Res<A>, ~q: Cur -> Res<A>, +c: Cur) -> Res<A>:
  alt.r(~A, ~q, c, p(c))

def opt.r(-A: Data, c: Cur, r: Res<A>) -> Res<Maybe<&2, A>>:
  match r:
    case Ok{v, d}:
      Ok{Some{v}, d}
    case Err{o, w}:
      Ok{None{}, c}

# p, or None with no input taken.
def opt(~A: Data, ~p: Cur -> Res<A>, +c: Cur) -> Res<Maybe<&2, A>>:
  opt.r(A, c, p(c))

def progress.if(-A: Data, ok: Bool, v: A, c: Cur, +o: U32) -> Res<A>:
  match ok:
    case True{}:
      Ok{v, c}
    case False{}:
      Err{o, "progress"}

# A success that took no input fails, so loops end.
def progress(-A: Data, +o: U32, r: Res<A>) -> Res<A>:
  match r:
    case Ok{v, Cur{s, +o2, n}}:
      progress.if(A, U32.is_lt(o, o2), v, Cur{s, o2, n}, o2)
    case Err{e, w}:
      Err{e, w}

def many.go(~A: Data, ~p: Cur -> Res<A>, fuel: Nat, c: Cur, acc: List<&2, A>, r: Res<A>) -> Res<List<&2, A>>:
  match fuel:
    case 0n:
      Ok{List.reverse(&2, A, acc), c}
    case 1n+k:
      match r:
        case Err{o, w}:
          Ok{List.reverse(&2, A, acc), c}
        case Ok{v, +d}:
          many.go(~A, ~p, k, d, v <> acc, progress(A, off(d), p(d)))

# p zero or more times, until it fails or takes no input.
def many(~A: Data, ~p: Cur -> Res<A>, +c: Cur) -> Res<List<&2, A>>:
  many.go(~A, ~p, fuel(c), c, Nil{}, progress(A, off(c), p(c)))

def cons.r(-A: Data, v: A, r: Res<List<&2, A>>) -> Res<List<&2, A>>:
  match r:
    case Ok{xs, c}:
      Ok{v <> xs, c}
    case Err{o, w}:
      Err{o, w}

def many1.r(~A: Data, ~p: Cur -> Res<A>, r: Res<A>) -> Res<List<&2, A>>:
  match r:
    case Ok{v, c}:
      cons.r(A, v, many(~A, ~p, c))
    case Err{o, w}:
      Err{o, w}

# p one or more times.
def many1(~A: Data, ~p: Cur -> Res<A>, c: Cur) -> Res<List<&2, A>>:
  many1.r(~A, ~p, p(c))

def text.r(-A: Data, +s: String, +o: U32, r: Res<A>) -> Res<String>:
  match r:
    case Ok{v, +d}:
      Ok{String.take(s, U32.to_nat((off(d) - o : U32))), d}
    case Err{e, w}:
      Err{e, w}

# p; the value is the text p took.
def text(~A: Data, ~p: Cur -> Res<A>, c: Cur) -> Res<String>:
  match c:
    case Cur{+s, +o, n}:
      text.r(A, s, o, p(Cur{s, o, n}))

def sep_by1.r(~A: Data, ~S: Data, ~p: Cur -> Res<A>, ~sep: Cur -> Res<S>, r: Res<A>) -> Res<List<&2, A>>:
  match r:
    case Ok{v, c}:
      cons.r(A, v, many(~A, ~(d => right(~S, ~A, ~sep, ~p, d)), c))
    case Err{o, w}:
      Err{o, w}

# p one or more times, with sep between.
def sep_by1(~A: Data, ~S: Data, ~p: Cur -> Res<A>, ~sep: Cur -> Res<S>, c: Cur) -> Res<List<&2, A>>:
  sep_by1.r(~A, ~S, ~p, ~sep, p(c))

def nil.r(-A: Data, c: Cur, r: Res<List<&2, A>>) -> Res<List<&2, A>>:
  match r:
    case Ok{xs, d}:
      Ok{xs, d}
    case Err{o, w}:
      Ok{Nil{}, c}

# p zero or more times, with sep between.
def sep_by(~A: Data, ~S: Data, ~p: Cur -> Res<A>, ~sep: Cur -> Res<S>, +c: Cur) -> Res<List<&2, A>>:
  nil.r(A, c, sep_by1(~A, ~S, ~p, ~sep, c))

def res.off(-A: Data, r: Res<A>) -> U32:
  match r:
    case Ok{v, c}:
      off(c)
    case Err{o, w}:
      o

def rec.go(
  ~A: Data, ~F: Data, ~open: Cur -> Res<Step<A, F>>, ~next: F -> A -> Cur -> Res<Step<A, F>>,
  fuel: Nat, r: Res<Step<A, F>>, stack: List<&2, F>
) -> Res<A>:
  match fuel:
    case 0n:
      Err{res.off(Step<A, F>, r), "progress"}
    case 1n+k:
      match r:
        case Err{o, w}:
          Err{o, w}
        case Ok{Open{f}, +c}:
          rec.go(~A, ~F, ~open, ~next, k, progress(Step<A, F>, off(c), open(c)), f <> stack)
        case Ok{Leaf{v}, +c}:
          match stack:
            case Nil{}:
              Ok{v, c}
            case Con{f, up}:
              rec.go(~A, ~F, ~open, ~next, k, progress(Step<A, F>, off(c), next(f, v, c)), up)

# A nested value. At a value, open gives a Leaf, or an Open frame that wants
# a child. When a child v ends inside frame f, next(f, v) gives the finished
# container as a Leaf, or the frame for the next child as an Open. Each step
# must take input.
def rec(
  ~A: Data, ~F: Data, ~open: Cur -> Res<Step<A, F>>, ~next: F -> A -> Cur -> Res<Step<A, F>>, +c: Cur
) -> Res<A>:
  rec.go(~A, ~F, ~open, ~next, 1n+fuel(c), progress(Step<A, F>, off(c), open(c)), Nil{})

# p over all of s.
def run(~A: Data, ~p: Cur -> Res<A>, +s: String) -> Res<A>:
  left(~A, ~Unit, ~p, ~eof, start(s))
