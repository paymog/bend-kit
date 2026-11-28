import Base
import ./LAWS.bend as Laws
import ../bytes/append-proof.bend as Model
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas


def bounded(+pieces: List<&2, String>, +limit: Nat) -> Data:
  MNat.lt(Nat.add(String.length(Laws.joined(pieces)), 4n), limit)

def joined_cons(+head: String, tail: List<&2, String>) ->
  {Laws.joined(Con{head, tail}) == head ++ Laws.joined(tail) : String}:
  match tail:
    case Nil{}: Equal.sym(String, head ++ "", head, Model.append_nil(head))
    case Con{next, rest}: {==}

def joined_merge(+prefix: String, +head: String, +tail: List<&2, String>) ->
  {Laws.joined(Con{prefix, Con{head, tail}}) == Laws.joined(Con{prefix ++ head, tail}) : String}:
  Equal.trans(String, Laws.joined(Con{prefix, Con{head, tail}}), prefix ++ (head ++ Laws.joined(tail)),
    Laws.joined(Con{prefix ++ head, tail}),
    Equal.cong(String, String, value => prefix ++ value,
      Laws.joined(Con{head, tail}), head ++ Laws.joined(tail), joined_cons(head, tail)),
    Equal.trans(String, prefix ++ (head ++ Laws.joined(tail)), (prefix ++ head) ++ Laws.joined(tail),
      Laws.joined(Con{prefix ++ head, tail}),
      Equal.sym(String, (prefix ++ head) ++ Laws.joined(tail), prefix ++ (head ++ Laws.joined(tail)),
        Model.append_assoc(prefix, head, Laws.joined(tail))),
      Equal.sym(String, Laws.joined(Con{prefix ++ head, tail}), (prefix ++ head) ++ Laws.joined(tail),
        joined_cons(prefix ++ head, tail))))

def merge_bounded(+prefix: String, +head: String, +tail: List<&2, String>, +limit: Nat,
  bound: bounded(Con{prefix, Con{head, tail}}, limit)) -> bounded(Con{prefix ++ head, tail}, limit):
  %joined_merge(prefix, head, tail) : MNat.lt(Nat.add(String.length(_), 4n), limit)
  bound

def prefix_induction(
  ~fusion: @limit: Nat -> @prefix: String -> @head: String -> @tail: List<&2, String> ->
    MNat.le(limit, Lemmas.pow2(32n)) ->
    bounded(Con{prefix, Con{head, tail}}, limit) ->
    {Laws.sse(Con{prefix, Con{head, tail}}) == Laws.sse(Con{prefix ++ head, tail}) : List<&2, String>},
  pieces: List<&2, String>, +prefix: String, +limit: Nat,
  +upper: MNat.le(limit, Lemmas.pow2(32n)), +bound: bounded(Con{prefix, pieces}, limit)) ->
  {Laws.sse(Con{prefix, pieces}) == Laws.sse([prefix ++ Laws.joined(pieces)]) : List<&2, String>}:
  match pieces:
    case Nil{}:
      Equal.cong(String, List<&2, String>, text => Laws.sse([text]), prefix, prefix ++ "",
        Equal.sym(String, prefix ++ "", prefix, Model.append_nil(prefix)))
    case Con{+head, +tail}:
      Equal.trans(List<&2, String>, Laws.sse(Con{prefix, Con{head, tail}}), Laws.sse(Con{prefix ++ head, tail}),
        Laws.sse([prefix ++ Laws.joined(Con{head, tail})]),
        fusion(limit, prefix, head, tail, upper, bound),
        Equal.trans(List<&2, String>, Laws.sse(Con{prefix ++ head, tail}), Laws.sse([(prefix ++ head) ++ Laws.joined(tail)]),
          Laws.sse([prefix ++ Laws.joined(Con{head, tail})]),
          prefix_induction(~fusion, tail, prefix ++ head, limit, upper, merge_bounded(prefix, head, tail, limit, bound)),
          Equal.cong(String, List<&2, String>, text => Laws.sse([text]),
            (prefix ++ head) ++ Laws.joined(tail), prefix ++ Laws.joined(Con{head, tail}),
            Equal.trans(String, (prefix ++ head) ++ Laws.joined(tail), prefix ++ (head ++ Laws.joined(tail)),
              prefix ++ Laws.joined(Con{head, tail}), Model.append_assoc(prefix, head, Laws.joined(tail)),
              Equal.cong(String, String, value => prefix ++ value,
                head ++ Laws.joined(tail), Laws.joined(Con{head, tail}),
                Equal.sym(String, Laws.joined(Con{head, tail}), head ++ Laws.joined(tail), joined_cons(head, tail)))))))

def partition(
  ~fusion: @limit: Nat -> @prefix: String -> @head: String -> @tail: List<&2, String> ->
    MNat.le(limit, Lemmas.pow2(32n)) ->
    bounded(Con{prefix, Con{head, tail}}, limit) ->
    {Laws.sse(Con{prefix, Con{head, tail}}) == Laws.sse(Con{prefix ++ head, tail}) : List<&2, String>},
  pieces: List<&2, String>, +limit: Nat, upper: MNat.le(limit, Lemmas.pow2(32n)), bound: bounded(pieces, limit)) ->
  {Laws.sse(pieces) == Laws.sse([Laws.joined(pieces)]) : List<&2, String>}:
  match pieces:
    case Nil{}: {==}
    case Con{+head, +tail}:
      Equal.trans(List<&2, String>, Laws.sse(Con{head, tail}), Laws.sse([head ++ Laws.joined(tail)]),
        Laws.sse([Laws.joined(Con{head, tail})]),
        prefix_induction(~fusion, tail, head, limit, upper, bound),
        Equal.cong(String, List<&2, String>, text => Laws.sse([text]), head ++ Laws.joined(tail), Laws.joined(Con{head, tail}),
          Equal.sym(String, Laws.joined(Con{head, tail}), head ++ Laws.joined(tail), joined_cons(head, tail))))

