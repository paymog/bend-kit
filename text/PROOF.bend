import Base
import ./text.bend as T
import ./LAWS.bend as Laws
import bend-kit-unicode@0.1.0.0/unicode.bend as Unicode

def ins_before(-A: Data, b: List<&2, A>) -> {T.before(A, T.walk.ins(A, b)) == [] : List<&2, A>}:
  match b:
    case Nil{}:
      {==}
    case Con{y, t}:
      ins_before(A, t)

def ins_after(-A: Data, b: List<&2, A>) -> {T.after(A, T.walk.ins(A, b)) == b : List<&2, A>}:
  match b:
    case Nil{}:
      {==}
    case Con{+y, t}:
      Equal.cong(List<&2, A>, List<&2, A>, l => y <> l, T.after(A, T.walk.ins(A, t)), t, ins_after(A, t))

def rest_before(-A: Data, a: List<&2, A>, b: List<&2, A>) -> {T.before(A, T.walk.rest(A, a, b)) == a : List<&2, A>}:
  match a:
    case Nil{}:
      ins_before(A, b)
    case Con{+x, t}:
      Equal.cong(List<&2, A>, List<&2, A>, l => x <> l, T.before(A, T.walk.rest(A, t, b)), t, rest_before(A, t, b))

def rest_after(-A: Data, a: List<&2, A>, b: List<&2, A>) -> {T.after(A, T.walk.rest(A, a, b)) == b : List<&2, A>}:
  match a:
    case Nil{}:
      ins_after(A, b)
    case Con{x, t}:
      rest_after(A, t, b)

def Laws.walk_before(A, ms, a, b):
  match ms a b:
    case Nil{} _ _:
      rest_before(A, a, b)
    case Con{T.MSame{}, t} Con{+x, xs} Con{y, ys}:
      Equal.cong(List<&2, A>, List<&2, A>, l => x <> l, T.before(A, T.walk(A, t, xs, ys)), xs, Laws.walk_before(~A, t, xs, ys))
    case Con{T.MDel{}, t} Con{+x, xs} _:
      Equal.cong(List<&2, A>, List<&2, A>, l => x <> l, T.before(A, T.walk(A, t, xs, b)), xs, Laws.walk_before(~A, t, xs, b))
    case Con{T.MIns{}, t} _ Con{y, ys}:
      Laws.walk_before(~A, t, a, ys)
    case Con{T.MSame{}, t} Nil{} _:
      Laws.walk_before(~A, t, Nil{}, b)
    case Con{T.MSame{}, t} Con{x, xs} Nil{}:
      Laws.walk_before(~A, t, Con{x, xs}, Nil{})
    case Con{T.MDel{}, t} Nil{} _:
      Laws.walk_before(~A, t, Nil{}, b)
    case Con{T.MIns{}, t} _ Nil{}:
      Laws.walk_before(~A, t, a, Nil{})

def Laws.walk_after(A, ms, a, b):
  match ms a b:
    case Nil{} _ _:
      rest_after(A, a, b)
    case Con{T.MSame{}, t} Con{x, xs} Con{+y, ys}:
      Equal.cong(List<&2, A>, List<&2, A>, l => y <> l, T.after(A, T.walk(A, t, xs, ys)), ys, Laws.walk_after(~A, t, xs, ys))
    case Con{T.MDel{}, t} Con{x, xs} _:
      Laws.walk_after(~A, t, xs, b)
    case Con{T.MIns{}, t} _ Con{+y, ys}:
      Equal.cong(List<&2, A>, List<&2, A>, l => y <> l, T.after(A, T.walk(A, t, a, ys)), ys, Laws.walk_after(~A, t, a, ys))
    case Con{T.MSame{}, t} Nil{} _:
      Laws.walk_after(~A, t, Nil{}, b)
    case Con{T.MSame{}, t} Con{x, xs} Nil{}:
      Laws.walk_after(~A, t, Con{x, xs}, Nil{})
    case Con{T.MDel{}, t} Nil{} _:
      Laws.walk_after(~A, t, Nil{}, b)
    case Con{T.MIns{}, t} _ Nil{}:
      Laws.walk_after(~A, t, a, Nil{})

def Laws.diff_before(A, eq, a, b):
  Laws.walk_before(~A, T.moves(~A, ~eq, a, b), a, b)

def Laws.diff_after(A, eq, a, b):
  Laws.walk_after(~A, T.moves(~A, ~eq, a, b), a, b)

def push_join(c: Char, ls: List<&2, String>) -> {String.concat(T.lines.push(c, ls)) == SCon{c, String.concat(ls)} : String}:
  match ls:
    case Nil{}:
      {==}
    case Con{h, t}:
      {==}

def pick_join(b: Bool, c: Char, ls: List<&2, String>) -> {String.concat(T.lines.pick(b, c, ls)) == SCon{c, String.concat(ls)} : String}:
  match b:
    case True{}:
      {==}
    case False{}:
      push_join(c, ls)

def Laws.lines_join(s):
  match s:
    case SNil{}:
      {==}
    case SCon{+c, +t}:
      Equal.trans(String, String.concat(T.lines.pick(Char.is_eq(c, '\n'), c, T.lines(t))), SCon{c, String.concat(T.lines(t))}, SCon{c, t},
        pick_join(Char.is_eq(c, '\n'), c, T.lines(t)),
        Equal.cong(String, String, u => SCon{c, u}, String.concat(T.lines(t)), t, Laws.lines_join(t)))

def Laws.diff_lines_after(a, b):
  +la = T.lines(a)
  +lb = T.lines(b)
  Equal.trans(String, String.concat(T.after(String, T.diff(~String, ~String.eq, la, lb))), String.concat(lb), b,
    Equal.cong(List<&2, String>, String, ls => String.concat(ls), T.after(String, T.diff(~String, ~String.eq, la, lb)), lb, Laws.diff_after(~String, ~String.eq, la, lb)),
    Laws.lines_join(b))

def Laws.myers_paper():
  {==}

def Laws.diff_same():
  {==}

def Laws.diff_final_newline():
  {==}

def Laws.lines_final_newline():
  {==}

def Laws.lines_no_final_newline():
  {==}

def Laws.lines_empty():
  {==}

def Laws.unified_two_hunks():
  {==}

def Laws.unified_zero_context():
  {==}

def Laws.unified_merge():
  {==}

def Laws.unified_split():
  {==}

def Laws.unified_from_empty():
  {==}

def Laws.unified_to_empty():
  {==}

def Laws.unified_no_change():
  {==}

def Laws.distance_kitten():
  {==}

def Laws.distance_flaw():
  {==}

def Laws.distance_gumbo():
  {==}

def Laws.distance_from_empty():
  {==}

def Laws.distance_to_empty():
  {==}

def Laws.distance_same():
  {==}

def Laws.distance_code_points():
  {==}

def Laws.wrap_words():
  {==}

def Laws.wrap_long_word():
  {==}

def Laws.wrap_wide():
  {==}

def Laws.wrap_empty():
  {==}

def Laws.wrap_fits_words():
  {==}

def Laws.wrap_fits_long_word():
  {==}

def Laws.wrap_fits_wide():
  {==}

def Laws.wrap_fits_combining():
  {==}

def Laws.unified_old_no_newline():
  {==}

def Laws.unified_new_no_newline():
  {==}

def Laws.unified_both_no_newline():
  {==}

def Laws.unified_same_no_newline():
  {==}

def Laws.wrap_fits_vs16():
  {==}

# ---- wrap: every line is ok

def isF(b: Bool) -> Type:
  match b:
    case True{}:
      Empty
    case False{}:
      Unit

def ft(e: {False{} == True{} : Bool}) -> Empty:
  %e : isF(_)
  Unit{}

def and_l(x: Bool, -y: Bool, e: {Bool.and(x, y) == True{} : Bool}) -> {x == True{} : Bool}:
  match x:
    case True{}:
      {==}
    case False{}:
      Empty.absurd({False{} == True{} : Bool}, ft(e))

def and_r(x: Bool, -y: Bool, e: {Bool.and(x, y) == True{} : Bool}) -> {y == True{} : Bool}:
  match x:
    case True{}:
      e
    case False{}:
      Empty.absurd({y == True{} : Bool}, ft(e))

def and_i(x: Bool, -y: Bool, ex: {x == True{} : Bool}, ey: {y == True{} : Bool}) -> {Bool.and(x, y) == True{} : Bool}:
  match x:
    case True{}:
      ey
    case False{}:
      Empty.absurd({Bool.and(False{}, y) == True{} : Bool}, ft(ex))

def okp(b: Bool, -s: String, e: {b == True{} : Bool}) -> {T.ok.pick(b, s) == True{} : Bool}:
  match b:
    case True{}:
      {==}
    case False{}:
      Empty.absurd({T.ok.pick(False{}, s) == True{} : Bool}, ft(e))

def ok_fits(+s: String, +n: U32, e: {T.fits(s, n) == True{} : Bool}) -> {T.ok(s, n) == True{} : Bool}:
  okp(T.fits(s, n), s, e)

def okc(b: Bool, c: Char) -> {T.ok.pick(b, SCon{c, SNil{}}) == True{} : Bool}:
  match b c:
    case True{} _:
      {==}
    case False{} Chr{u}:
      {==}

def ok_char(+c: Char, +n: U32) -> {T.ok(SCon{c, SNil{}}, n) == True{} : Bool}:
  okc(T.fits(SCon{c, SNil{}}, n), c)

def cur_ok(m: Maybe<&2, String>, +n: U32) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{s}:
      T.ok(s, n)

def inv(st: T.Wr, +n: U32) -> Bool:
  match st:
    case T.Wr{out, cur}:
      Bool.and(Laws.all_ok(out, n), cur_ok(cur, n))

def step0p(b: Bool, +out: List<&2, String>, +s: String, +c: Char, +n: U32,
  eb: {T.fits(s ++ SCon{c, SNil{}}, n) == b : Bool},
  io: {Laws.all_ok(out, n) == True{} : Bool}, es: {T.ok(s, n) == True{} : Bool}
) -> {inv(T.step0.pick(b, out, s, c), n) == True{} : Bool}:
  match b:
    case True{}:
      and_i(Laws.all_ok(out, n), T.ok(s ++ SCon{c, SNil{}}, n), io, ok_fits(s ++ SCon{c, SNil{}}, n, eb))
    case False{}:
      and_i(Laws.all_ok(s <> out, n), T.ok(SCon{c, SNil{}}, n),
        and_i(T.ok(s, n), Laws.all_ok(out, n), es, io), ok_char(c, n))

def step0_ok(st: T.Wr, +c: Char, +n: U32, +i: {inv(st, n) == True{} : Bool}) -> {inv(T.step0(st, c, n), n) == True{} : Bool}:
  match st:
    case T.Wr{+out, None{}}:
      and_i(Laws.all_ok(out, n), T.ok(SCon{c, SNil{}}, n), and_l(Laws.all_ok(out, n), True{}, i), ok_char(c, n))
    case T.Wr{+out, Some{+s}}:
      step0p(T.fits(s ++ SCon{c, SNil{}}, n), out, s, c, n, {==},
        and_l(Laws.all_ok(out, n), T.ok(s, n), i), and_r(Laws.all_ok(out, n), T.ok(s, n), i))

def run0_ok(s: String, +n: U32, +st: T.Wr, +i: {inv(st, n) == True{} : Bool}) -> {inv(T.run0(s, n, st), n) == True{} : Bool}:
  match s:
    case SNil{}:
      i
    case SCon{+c, t}:
      run0_ok(t, n, T.step0(st, c, n), step0_ok(st, c, n, i))

def start1_ok(b: Bool, +out: List<&2, String>, +g: String, +n: U32, eb: {T.ok(g, n) == b : Bool},
  io: {Laws.all_ok(out, n) == True{} : Bool}
) -> {inv(T.start1(b, out, g, n), n) == True{} : Bool}:
  match b:
    case True{}:
      and_i(Laws.all_ok(out, n), T.ok(g, n), io, eb)
    case False{}:
      run0_ok(g, n, T.Wr{out, None{}}, and_i(Laws.all_ok(out, n), True{}, io, {==}))

def step1p(b: Bool, +out: List<&2, String>, +s: String, +g: String, +n: U32,
  eb: {T.fits(s ++ g, n) == b : Bool},
  io: {Laws.all_ok(out, n) == True{} : Bool}, es: {T.ok(s, n) == True{} : Bool}
) -> {inv(T.step1.pick(b, out, s, g, n), n) == True{} : Bool}:
  match b:
    case True{}:
      and_i(Laws.all_ok(out, n), T.ok(s ++ g, n), io, ok_fits(s ++ g, n, eb))
    case False{}:
      start1_ok(T.ok(g, n), s <> out, g, n, {==}, and_i(T.ok(s, n), Laws.all_ok(out, n), es, io))

def step1_ok(st: T.Wr, +g: String, +n: U32, +i: {inv(st, n) == True{} : Bool}) -> {inv(T.step1(st, g, n), n) == True{} : Bool}:
  match st:
    case T.Wr{+out, None{}}:
      start1_ok(T.ok(g, n), out, g, n, {==}, and_l(Laws.all_ok(out, n), True{}, i))
    case T.Wr{+out, Some{+s}}:
      step1p(T.fits(s ++ g, n), out, s, g, n, {==},
        and_l(Laws.all_ok(out, n), T.ok(s, n), i), and_r(Laws.all_ok(out, n), T.ok(s, n), i))

def run1_ok(gs: List<&2, String>, +n: U32, +st: T.Wr, +i: {inv(st, n) == True{} : Bool}) -> {inv(T.run1(gs, n, st), n) == True{} : Bool}:
  match gs:
    case Nil{}:
      i
    case Con{+g, t}:
      run1_ok(t, n, T.step1(st, g, n), step1_ok(st, g, n, i))

def start2_ok(b: Bool, +out: List<&2, String>, +w: String, +n: U32, eb: {T.ok(w, n) == b : Bool},
  io: {Laws.all_ok(out, n) == True{} : Bool}
) -> {inv(T.start2(b, out, w, n), n) == True{} : Bool}:
  match b:
    case True{}:
      and_i(Laws.all_ok(out, n), T.ok(w, n), io, eb)
    case False{}:
      run1_ok(Unicode.graphemes(w), n, T.Wr{out, None{}}, and_i(Laws.all_ok(out, n), True{}, io, {==}))

def step2p(b: Bool, +out: List<&2, String>, +s: String, +w: String, +n: U32,
  eb: {T.fits(s ++ " " ++ w, n) == b : Bool},
  io: {Laws.all_ok(out, n) == True{} : Bool}, es: {T.ok(s, n) == True{} : Bool}
) -> {inv(T.step2.pick(b, out, s, w, n), n) == True{} : Bool}:
  match b:
    case True{}:
      and_i(Laws.all_ok(out, n), T.ok(s ++ " " ++ w, n), io, ok_fits(s ++ " " ++ w, n, eb))
    case False{}:
      start2_ok(T.ok(w, n), s <> out, w, n, {==}, and_i(T.ok(s, n), Laws.all_ok(out, n), es, io))

def step2_ok(st: T.Wr, +w: String, +n: U32, +i: {inv(st, n) == True{} : Bool}) -> {inv(T.step2(st, w, n), n) == True{} : Bool}:
  match st:
    case T.Wr{+out, None{}}:
      start2_ok(T.ok(w, n), out, w, n, {==}, and_l(Laws.all_ok(out, n), True{}, i))
    case T.Wr{+out, Some{+s}}:
      step2p(T.fits(s ++ " " ++ w, n), out, s, w, n, {==},
        and_l(Laws.all_ok(out, n), T.ok(s, n), i), and_r(Laws.all_ok(out, n), T.ok(s, n), i))

def run2_ok(ws: List<&2, String>, +n: U32, +st: T.Wr, +i: {inv(st, n) == True{} : Bool}) -> {inv(T.run2(ws, n, st), n) == True{} : Bool}:
  match ws:
    case Nil{}:
      i
    case Con{+w, t}:
      run2_ok(t, n, T.step2(st, w, n), step2_ok(st, w, n, i))

def rev_ok(xs: List<&2, String>, +acc: List<&2, String>, +n: U32,
  +ex: {Laws.all_ok(xs, n) == True{} : Bool}, ea: {Laws.all_ok(acc, n) == True{} : Bool}
) -> {Laws.all_ok(List.reverse.go(&2, String, xs, acc), n) == True{} : Bool}:
  match xs:
    case Nil{}:
      ea
    case Con{+h, +t}:
      rev_ok(t, h <> acc, n, and_r(T.ok(h, n), Laws.all_ok(t, n), ex),
        and_i(T.ok(h, n), Laws.all_ok(acc, n), and_l(T.ok(h, n), Laws.all_ok(t, n), ex), ea))

def lines_ok(st: T.Wr, +n: U32, +i: {inv(st, n) == True{} : Bool}) -> {Laws.all_ok(T.wrap.lines(st), n) == True{} : Bool}:
  match st:
    case T.Wr{+out, None{}}:
      rev_ok(out, Nil{}, n, and_l(Laws.all_ok(out, n), True{}, i), {==})
    case T.Wr{+out, Some{+s}}:
      rev_ok(s <> out, Nil{}, n,
        and_i(T.ok(s, n), Laws.all_ok(out, n), and_r(Laws.all_ok(out, n), T.ok(s, n), i), and_l(Laws.all_ok(out, n), T.ok(s, n), i)), {==})

def Laws.wrap_ok(text, width):
  lines_ok(T.run2(T.words(text), width, T.Wr{Nil{}, None{}}), width, run2_ok(T.words(text), width, T.Wr{Nil{}, None{}}, {==}))
