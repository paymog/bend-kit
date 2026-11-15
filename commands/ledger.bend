# A payment ledger fed by webhook events: each event id is a command id, so a redelivered event applies once.
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-json@0.7.0.0/json.bend as Json
import ./commands.bend as C

# ---- state: one row per account, the key the account name and the value its balance in decimal

# ---- payload: {"account":"acct_1","credit":500} or {"account":"acct_1","debit":200}

type Op is Data:
  Credit{account: String, amount: U32}
  Debit{account: String, amount: U32}

type Fields is Data:
  Fields{account: Maybe<&2, String>, credit: Maybe<&2, U32>, debit: Maybe<&2, U32>}

def field.str(+k: String, +s: String, f: Fields) -> Fields:
  Fields{+a, +c, +d} = f
  Bool.pick(Fields, String.eq(k, "account"), Fields{Some{s}, c, d}, Fields{a, c, d})

def field.num(+k: String, +n: Maybe<&2, U32>, f: Fields) -> Fields:
  Fields{+a, +c, +d} = f
  Bool.pick(Fields, String.eq(k, "credit"), Fields{a, n, d}, Bool.pick(Fields, String.eq(k, "debit"), Fields{a, c, n}, Fields{a, c, d}))

def field(v: Json.Val, +k: String, f: Fields) -> Fields:
  match v:
    case Json.Str{b}:
      field.str(k, Bytes.to_string(b), f)
    case Json.Num{b}:
      field.num(k, Bytes.u32.read(b), f)
    case _:
      f

def fields(kvs: List<&1, Bytes.Bytes & Json.Val>, f: Fields) -> Fields:
  match kvs:
    case Nil{}:
      f
    case Con{kv, rest}:
      (k, v) = kv
      fields(rest, field(v, Bytes.to_string(k), f))

def op.of(f: Fields) -> Maybe<&2, Op>:
  match f:
    case Fields{Some{a}, Some{n}, None{}}:
      Some{Credit{a, n}}
    case Fields{Some{a}, None{}, Some{n}}:
      Some{Debit{a, n}}
    case _:
      None{}

def payload.of(mv: Maybe<&1, Json.Val>) -> Maybe<&2, Op>:
  match mv:
    case Some{Json.Obj{kvs}}:
      op.of(fields(kvs, Fields{None{}, None{}, None{}}))
    case _:
      None{}

# Strict UTF-8 JSON with unique keys. Callers send one canonical encoding per event: the bytes are the identity.
def payload(p: Bytes.Bytes) -> Maybe<&2, Op>:
  payload.of(Json.parse.strict.unique.bytes(p, 1))

# ---- decide

# The rows that a command reads: its account's row.
def keys.of(o: Maybe<&2, Op>) -> List<Bytes.Bytes>:
  match o:
    case Some{Credit{a, n}}:
      [Bytes.from_string(a)]
    case Some{Debit{a, n}}:
      [Bytes.from_string(a)]
    case None{}:
      []

def keys(p: Bytes.Bytes) -> List<Bytes.Bytes>:
  keys.of(payload(p))

# The balance in the account's row: 0 when no row holds it, None when the row does not decode.
def balance(rs: List<C.Row>) -> Maybe<&2, U32>:
  match rs:
    case Con{C.Row{k, Some{v}}, rest}:
      Bytes.u32.read(v)
    case Con{C.Row{k, None{}}, rest}:
      Some{0}
    case Nil{}:
      None{}

def accepted(+a: String, +n: U32) -> C.Decision<List<C.Row>, Bytes.Bytes, Bytes.Bytes>:
  C.Accept{[C.Row{Bytes.from_string(a), Some{Bytes.u32.show(n)}}], Bytes.u32.show(n), [Bytes.from_string(a ++ "=" ++ U32.show(n))]}

def settle(ok: Bool, +a: String, +n: U32, why: String) -> C.Decision<List<C.Row>, Bytes.Bytes, Bytes.Bytes>:
  match ok:
    case True{}:
      accepted(a, n)
    case False{}:
      C.Refuse{Bytes.from_string(why)}

def apply(o: Op, +b: U32) -> C.Decision<List<C.Row>, Bytes.Bytes, Bytes.Bytes>:
  match o:
    case Credit{+a, +n}:
      +t = (b + n : U32)
      settle(U32.is_le(b, t), a, t, "balance overflow")
    case Debit{+a, +n}:
      settle(U32.is_le(n, b), a, (b - n : U32), "insufficient funds")

def decide.go(o: Maybe<&2, Op>, b: Maybe<&2, U32>) -> C.Decision<List<C.Row>, Bytes.Bytes, Bytes.Bytes>:
  match o b:
    case Some{x} Some{n}:
      apply(x, n)
    case None{} _:
      C.Refuse{Bytes.from_string("invalid payload")}
    case Some{x} None{}:
      C.Refuse{Bytes.from_string("balance does not decode")}

# A credit or debit of one account. rs holds the account's row. The result is the new balance; the effect notifies the account holder.
def decide(rs: List<C.Row>, p: Bytes.Bytes) -> C.Decision<List<C.Row>, Bytes.Bytes, Bytes.Bytes>:
  decide.go(payload(p), balance(rs))

def outcome.show(o: C.Outcome<Bytes.Bytes>) -> String:
  match o:
    case C.Accepted{r}:
      "accepted " ++ Bytes.to_string(r)
    case C.Refused{r}:
      "refused " ++ Bytes.to_string(r)

def reply.show(r: C.Reply<Bytes.Bytes>) -> String:
  match r:
    case C.Fresh{o}:
      "fresh " ++ outcome.show(o)
    case C.Replayed{o}:
      "replayed " ++ outcome.show(o)
    case C.Conflict{}:
      "conflict"
