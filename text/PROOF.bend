import Base
import ./text.bend as T
import ./LAWS.bend as Laws

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

def Laws.diff_lines_after(a, b):
  Laws.diff_after(~String, ~String.eq, T.lines(a), T.lines(b))

def Laws.myers_paper():
  {==}

def Laws.diff_same():
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
