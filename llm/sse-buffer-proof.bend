import Base
import ./sse.bend as Sse
import ./sse-scan-proof.bend as Scan
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes

def index(r: Array<U32> & U32) -> U32:
  (a, i) = r
  i

def related_reads(~R: U32 -> U32 -> Type, f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32) -> Type:
  match f:
    case 0n:
      R(i, j)
    case 1n+p:
      (a, +c) = r
      (b, d) = s
      R(i, j) & ({c == d : U32} & related_reads(~R, p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32)))

def related_step(~R: U32 -> U32 -> Type, +f: Nat, -a: Array<U32>, -b: Array<U32>, +c: U32, +i: U32, +j: U32,
  here: R(i, j),
  next: R(index(Sse.eol(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))), index(Sse.eol(f, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))))) ->
  R(index(Sse.eol(1n+f, (a, c), i)), index(Sse.eol(1n+f, (b, c), j))):
  -left : Array<U32> & U32 = Sse.eol(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))
  -right : Array<U32> & U32 = Sse.eol(f, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))
  Scan.eol_elim(x => R(i, j) -> R(index(left), index(right)) -> R(index(x), index(Sse.eol(1n+f, (b, c), j))), f, a, c, i,
    eq => h => n =>
      (%Equal.sym(U32, c, 10, eq) : R(i, index(Sse.eol(1n+f, (b, _), j))); h),
    eq => h => n =>
      (%Equal.sym(U32, c, 13, eq) : R(i, index(Sse.eol(1n+f, (b, _), j))); h),
    good => h => n =>
      (%Equal.sym(Array<U32> & U32, Sse.eol(1n+f, (b, c), j), right, Scan.eol_step(f, b, c, j, good)) :
        R(index(left), index(_)); n))(here)(next)

def eol_related(~R: U32 -> U32 -> Type, f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32,
  ok: related_reads(~R, f, r, s, i, j)) ->
  R(index(Sse.eol(f, r, i)), index(Sse.eol(f, s, j))):
  match f:
    case 0n:
      (a, c) = r
      (b, d) = s
      ok
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      (here, (head, tail)) = ok
      %head : R(index(Sse.eol(1n+p, (a, c), i)), index(Sse.eol(1n+p, (b, _), j)))
      related_step(~R, p, a, b, c, i, j, here,
        eol_related(~R, p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32), tail))

def matching_reads(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32) -> Type:
  match f:
    case 0n:
      Unit
    case 1n+p:
      (a, +c) = r
      (b, d) = s
      {c == d : U32} & matching_reads(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32))

def same_index(i: U32, j: U32) -> Type:
  {i == j : U32}

def eol_same(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, ok: matching_reads(f, r, s, i, i)) ->
  {index(Sse.eol(f, r, i)) == index(Sse.eol(f, s, i)) : U32}:
  match f:
    case 0n:
      (a, c) = r
      (b, d) = s
      {==}
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      (head, tail) = ok
      %head : {index(Sse.eol(1n+p, (a, c), i)) == index(Sse.eol(1n+p, (b, _), i)) : U32}
      related_step(~same_index, p, a, b, c, i, i, {==},
        eol_same(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (i + 1 : U32)), (i + 1 : U32), tail))

def transport_clean(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32,
  same: matching_reads(f, r, s, i, j), clean: Scan.clean_prefix(f, r, i)) ->
  Scan.clean_prefix(f, s, j):
  match f:
    case 0n:
      Unit{}
    case 1n+p:
      (a, +c) = r
      (b, +d) = s
      (head, tail) = same
      (hc, tc) = clean
      ((%head : Scan.clean(_); hc),
        transport_clean(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32), tail, tc))

def observed(f: Nat, r: Array<U32> & U32, +i: U32) -> String:
  match f:
    case 0n:
      ""
    case 1n+p:
      (a, c) = r
      SCon{Chr{c}, observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))}

def observed.head(s: String) -> U32:
  match s:
    case SNil{}:
      0
    case SCon{Chr{c}, t}:
      c

def observed.tail(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{c, t}:
      t

def observations_match(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32,
  +eq: {observed(f, r, i) == observed(f, s, j) : String}) ->
  matching_reads(f, r, s, i, j):
  match f:
    case 0n:
      Unit{}
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      (Equal.cong(String, U32, observed.head,
        SCon{Chr{c}, observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))},
        SCon{Chr{d}, observed(p, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))}, eq),
        observations_match(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32),
          Equal.cong(String, String, observed.tail,
            SCon{Chr{c}, observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))},
            SCon{Chr{d}, observed(p, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))}, eq)))

def eol_observed(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32,
  +eq: {observed(f, r, i) == observed(f, s, i) : String}) ->
  {index(Sse.eol(f, r, i)) == index(Sse.eol(f, s, i)) : U32}:
  match f:
    case 0n:
      (a, c) = r
      (b, d) = s
      {==}
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      -left : String = SCon{Chr{c}, observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))}
      -right : String = SCon{Chr{d}, observed(p, Bytes.peek(b, (i + 1 : U32)), (i + 1 : U32))}
      %Equal.cong(String, U32, observed.head, left, right, eq) :
        {index(Sse.eol(1n+p, (a, c), i)) == index(Sse.eol(1n+p, (b, _), i)) : U32}
      related_step(~same_index, p, a, b, c, i, i, {==},
        eol_observed(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (i + 1 : U32)), (i + 1 : U32),
          Equal.cong(String, String, observed.tail, left, right, eq)))

def clean_observed(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32,
  +eq: {observed(f, r, i) == observed(f, s, j) : String}, clean: Scan.clean_prefix(f, r, i)) ->
  Scan.clean_prefix(f, s, j):
  match f:
    case 0n:
      Unit{}
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      (head, tail) = clean
      -left : String = SCon{Chr{c}, observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))}
      -right : String = SCon{Chr{d}, observed(p, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))}
      ((%Equal.cong(String, U32, observed.head, left, right, eq) : Scan.clean(_); head),
        clean_observed(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32),
          Equal.cong(String, String, observed.tail, left, right, eq), tail))
