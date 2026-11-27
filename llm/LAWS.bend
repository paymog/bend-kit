import Base
import ./pure.bend as Llm
import ./sse.bend as Sse
import ./sse-scan-proof.bend as Scan
import ./sse-buffer-proof.bend as Buffer
import bend-kit-json@0.7.3.2/json.bend as Json
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import ./sse-packed-proof.bend as Packed
import ../bytes/append-proof.bend as PackedModel
import ../lemmas/array.bend as Tree
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import ../bits/array-proof.bend as Bound

def b(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

# ---- SSE

def drain(f: Nat, r: Sse.Reader & Sse.Next, acc: List<&1, Sse.Message>) -> Sse.Reader & List<&1, Sse.Message>:
  match f:
    case 0n:
      (rd, n) = r
      (rd, acc)
    case 1n+g:
      (rd, n) = r
      match n:
        case Sse.Got{e}:
          drain(g, Sse.next(rd), Con{e, acc})
        case Sse.Want{}:
          (rd, acc)

def feed_drain(r: Sse.Reader, acc: List<&1, Sse.Message>) -> Sse.Reader & List<&1, Sse.Message>:
  Sse.Reader{Bytes.Bytes{+n, a}, pos, seen, cr, st} = r
  drain(Nat.add(U32.to_nat(n), 1n), Sse.next(Sse.Reader{Bytes.Bytes{n, a}, pos, seen, cr, st}), acc)

def feed(pieces: List<&2, String>, r: Sse.Reader & List<&1, Sse.Message>) -> Sse.Reader & List<&1, Sse.Message>:
  match pieces:
    case Nil{}:
      r
    case Con{h, t}:
      (rd, acc) = r
      feed(t, feed_drain(Sse.feed(rd, b(h)), acc))

def got(r: Sse.Reader & List<&1, Sse.Message>) -> List<&1, Sse.Message>:
  (rd, acc) = r
  List.reverse(&1, Sse.Message, acc)

# The events the pieces give, fed one at a time.
def events(pieces: List<&2, String>) -> List<&1, Sse.Message>:
  got(feed(pieces, (Sse.reader(), Nil{})))

def show(xs: List<&1, Sse.Message>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Sse.Message{name, data, id}, t}:
      Con{name ++ "|" ++ Bytes.to_string(data) ++ "|" ++ id, show(t)}

def sse(pieces: List<&2, String>) -> List<&2, String>:
  show(events(pieces))

def retried.of(r: Sse.Reader & Maybe<&2, U32>) -> Maybe<&2, U32>:
  (rd, m) = r
  m

def retried(r: Sse.Reader & List<&1, Sse.Message>) -> Maybe<&2, U32>:
  (rd, acc) = r
  retried.of(Sse.retry(rd))

def ones(s: String) -> List<&2, String>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{c, t}:
      Con{SCon{c, SNil{}}, ones(t)}

def twos(s: String) -> List<&2, String>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{c, t}:
      match t:
        case SNil{}:
          [SCon{c, SNil{}}]
        case SCon{d, u}:
          Con{SCon{c, SCon{d, SNil{}}}, twos(u)}

def threes(s: String) -> List<&2, String>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{c, t}:
      match t:
        case SNil{}:
          [SCon{c, SNil{}}]
        case SCon{d, u}:
          match u:
            case SNil{}:
              [SCon{c, SCon{d, SNil{}}}]
            case SCon{e, v}:
              Con{SCon{c, SCon{d, SCon{e, SNil{}}}}, threes(v)}

# CRLF, LF, and CR line ends; a comment; a value with two spaces; a field with no colon; an event
# with no data; an id with no value; and a last event that no blank line ends.
def stream() -> String:
  ": hello\r\nevent: add\r\ndata: first\r\ndata:  second\r\nid: 42\r\n\r\nretry: 1500\ndata\n\nevent: gone\n\ndata: x\rid\r\rdata: tail"

def want() -> List<&2, String>:
  ["add|first\n second|42", "message||42", "message|x|"]

law sse_whole:
  {sse([stream()]) == want() : List<&2, String>}

# However the bytes are cut into pieces, the events are the same.
law sse_ones:
  {sse(ones(stream())) == want() : List<&2, String>}

law sse_twos:
  {sse(twos(stream())) == want() : List<&2, String>}

law sse_threes:
  {sse(threes(stream())) == want() : List<&2, String>}

# A CR that ends one piece and an LF that starts the next make one line end.
law sse_crlf_cut:
  {sse(["data: a\r", "\n", "\r", "\ndata: b\r\n\r\n"]) == ["message|a|", "message|b|"] : List<&2, String>}

law sse_cr_blank:
  {sse(["data: a\r\r"]) == ["message|a|"] : List<&2, String>}

law sse_retry:
  {retried(feed([stream()], (Sse.reader(), Nil{}))) == Some{1500} : Maybe<&2, U32>}

law sse_retry_bad:
  {retried(feed(["retry: 15x\nretry: 7\nretry:\nretry: 1234567890\n"], (Sse.reader(), Nil{}))) == Some{7} : Maybe<&2, U32>}

# Field names are exact; unknown fields are ignored.
law sse_names:
  {sse(["datum: no\nDATA: no\ndata2: no\nfoo: bar\ndata: yes\n\n"]) == ["message|yes|"] : List<&2, String>}

# An id that holds NUL is ignored; an id persists to later events.
law sse_id:
  {sse(["id: 1\ndata: a\n\nid: 2" ++ SCon{Chr{0}, "\ndata: b\n\n"}]) == ["message|a|1", "message|b|1"] : List<&2, String>}

# Batch composition keeps the complete reader, including a pending CR and the last event ID.
law sse_feed_compose:
  for xs: List<&2, String>
  for ys: List<&2, String>
  for r: Sse.Reader & List<&1, Sse.Message>
  {feed(List.append(&2, String, xs, ys), r) == feed(ys, feed(xs, r)) : Sse.Reader & List<&1, Sse.Message>}

# Feed the real parser one octet at a time, with the same drain policy as feed.
def feed_octets(chunk: String, r: Sse.Reader & List<&1, Sse.Message>) -> Sse.Reader & List<&1, Sse.Message>:
  match chunk:
    case SNil{}:
      r
    case SCon{c, t}:
      (rd, acc) = r
      feed_octets(t, feed_drain(Sse.feed(rd, b(SCon{c, SNil{}})), acc))

law sse_octet_compose:
  for a: String
  for b: String
  for r: Sse.Reader & List<&1, Sse.Message>
  {feed_octets(a ++ b, r) == feed_octets(b, feed_octets(a, r)) : Sse.Reader & List<&1, Sse.Message>}

def after_lf(r: Sse.Reader & Sse.Next) -> Sse.Reader:
  (rd, n) = r
  Sse.feed(rd, b(""))

# The LF after a chunk-ending CR consumes no field and preserves arbitrary event state.
law sse_crlf_state:
  for st: Sse.St
  {after_lf(Sse.next(Sse.Reader{b("\n"), 0, 0, True{}, st})) == Sse.Reader{b(""), 0, 0, False{}, st} : Sse.Reader}

def dispatch_id(r: Sse.St & Maybe<&1, Sse.Message>) -> String:
  (Sse.St{name, data, id, retry}, message) = r
  id

law sse_id_persists:
  for empty: Bool
  for name: String
  for data: Bytes.Bytes
  for id: String
  for retry: Maybe<&2, U32>
  {dispatch_id(Sse.dispatch.of(empty, name, data, id, retry)) == id : String}

def message_id(r: Sse.St & Maybe<&1, Sse.Message>) -> Maybe<&2, String>:
  (st, message) = r
  match message:
    case None{}:
      None{}
    case Some{Sse.Message{name, data, id}}:
      Some{id}

law sse_message_id:
  for name: String
  for data: Bytes.Bytes
  for id: String
  for retry: Maybe<&2, U32>
  {message_id(Sse.dispatch.of(False{}, name, data, id, retry)) == Some{id} : Maybe<&2, String>}

# Keep line progress separate from conversion to Reader so fuel can be split.
def line_advance(f: Nat, l: Sse.Line, +len: U32) -> Sse.Line:
  match f:
    case 0n:
      l
    case 1n+p:
      match l:
        case Sse.LMore{a, +pos, cr, st}:
          line_advance(p, Sse.line(a, len, pos, pos, cr, st), len)
        case Sse.LWant{a, pos, cr, st}:
          Sse.LWant{a, pos, cr, st}
        case Sse.LGot{a, pos, cr, st, e}:
          Sse.LGot{a, pos, cr, st, e}

law sse_loop_compose:
  for f: Nat
  for g: Nat
  for l: Sse.Line
  for +len: U32
  {Sse.loop(Nat.add(f, g), l, len) == Sse.loop(g, line_advance(f, l, len), len) : Sse.Reader & Sse.Next}

law sse_crlf_skip:
  for +len: U32
  for +pos: U32
  for a: Array<U32>
  for b: Array<U32>
  for more: {U32.is_lt(pos, len) == True{} : Bool}
  for first: {Bytes.peek(a, pos) == (b, 10) : Array<U32> & U32}
  {Sse.skip(True{}, a, len, pos) == (b, (pos + 1 : U32), False{}) : Array<U32> & U32 & Bool}

# Scanning a delimiter-free prefix can be split from scanning its suffix.
law sse_scan_extend:
  for f: Nat
  for +g: Nat
  for r: Array<U32> & U32
  for +i: U32
  for clean: Scan.clean_prefix(f, r, i)
  {Sse.eol(Nat.add(f, g), r, i) == Scan.resume(g, Scan.advance(f, r, i)) : Array<U32> & U32}

# Equal packed-read observations give the same delimiter position.
law sse_scan_observe:
  for f: Nat
  for r: Array<U32> & U32
  for s: Array<U32> & U32
  for +i: U32
  for same: {Buffer.observed(f, r, i) == Buffer.observed(f, s, i) : String}
  {Buffer.index(Sse.eol(f, r, i)) == Buffer.index(Sse.eol(f, s, i)) : U32}

# A position relation that holds along equal read traces holds at their scan results.
law sse_scan_relocate:
  for ~R: U32 -> U32 -> Type
  for f: Nat
  for r: Array<U32> & U32
  for s: Array<U32> & U32
  for +i: U32
  for +j: U32
  for same: Buffer.related_reads(~R, f, r, s, i, j)
  R(Buffer.index(Sse.eol(f, r, i)), Buffer.index(Sse.eol(f, s, j)))

law sse_scan_clean_transport:
  for f: Nat
  for r: Array<U32> & U32
  for s: Array<U32> & U32
  for +i: U32
  for +j: U32
  for same: {Buffer.observed(f, r, i) == Buffer.observed(f, s, j) : String}
  for clean: Scan.clean_prefix(f, r, i)
  Scan.clean_prefix(f, s, j)

# Field delimiters and exact field-name matches depend only on observed octets.
law sse_colon_observe:
  for f: Nat
  for r: Array<U32> & U32
  for s: Array<U32> & U32
  for +i: U32
  for same: {Buffer.observed(f, r, i) == Buffer.observed(f, s, i) : String}
  {Buffer.index(Sse.colon(f, r, i)) == Buffer.index(Sse.colon(f, s, i)) : U32}

law sse_colon_relocate:
  for ~R: U32 -> U32 -> Type
  for f: Nat
  for r: Array<U32> & U32
  for s: Array<U32> & U32
  for +i: U32
  for +j: U32
  for same: Buffer.related_reads(~R, f, r, s, i, j)
  R(Buffer.index(Sse.colon(f, r, i)), Buffer.index(Sse.colon(f, s, j)))

law sse_name_observe:
  for +needle: String
  for +ok: Bool
  for r: Array<U32> & U32
  for s: Array<U32> & U32
  for +i: U32
  for +j: U32
  for same: {Buffer.observed(String.length(needle), r, i) == Buffer.observed(String.length(needle), s, j) : String}
  {Buffer.matched(Bytes.at.go(needle, ok, r, i)) == Buffer.matched(Bytes.at.go(needle, ok, s, j)) : Bool}

# Scanning leaves the complete packed buffer unchanged, not just the observed prefix.
law sse_scan_preserves_buffer:
  for +f: Nat
  for a: Array<U32>
  for +c: U32
  for +i: U32
  {Buffer.array(Sse.eol(f, (a, c), i)) == a : Array<U32>}

law sse_colon_preserves_buffer:
  for +f: Nat
  for a: Array<U32>
  for +c: U32
  for +i: U32
  {Buffer.array(Sse.colon(f, (a, c), i)) == a : Array<U32>}

law sse_name_preserves_buffer:
  for +needle: String
  for +ok: Bool
  for a: Array<U32>
  for +c: U32
  for +i: U32
  {Buffer.at_array(Bytes.at.go(needle, ok, (a, c), i)) == a : Array<U32>}

# The hub byte operations used by SSE implement the unrestricted packed-copy model.
law sse_packed_copy:
  for +m: U32
  for +src: Tree.Tree<U32>
  for +dst: Tree.Tree<U32>
  for +s: U32
  for +d: U32
  {Bytes.copy(m, Tree.reify(U32, src), Tree.reify(U32, dst), s, d) ==
    (Tree.reify(U32, src), Tree.reify(U32, PackedModel.copy(m, src, dst, s, d))) : Array<U32> & Array<U32>}

# Appending arbitrary bounded chunks preserves their forward packed-read observations.
law sse_packed_append:
  for +a: String
  for +b: String
  for +limit: Nat
  for +hn: MNat.lt(Nat.add(Nat.add(String.length(a), String.length(b)), 3n), limit)
  for +hu: MNat.le(limit, Lemmas.pow2(32n))
  {Packed.observe(String.length(PackedModel.mask(a) ++ PackedModel.mask(b)),
    Bytes.append(Bytes.from_string(a), Bytes.from_string(b)), 0) == PackedModel.mask(a) ++ PackedModel.mask(b) : String}

law sse_packed_append_scan:
  for +a: String
  for +b: String
  for +limit: Nat
  for +hn: MNat.lt(Nat.add(Nat.add(String.length(a), String.length(b)), 3n), limit)
  for +hu: MNat.le(limit, Lemmas.pow2(32n))
  {Packed.scan(String.length(PackedModel.mask(a) ++ PackedModel.mask(b)), Bytes.append(Bytes.from_string(a), Bytes.from_string(b)), 0) ==
    Packed.scan(String.length(PackedModel.mask(a) ++ PackedModel.mask(b)), Bytes.from_string(a ++ b), 0) : U32}

# This feed-buffer bridge does not yet cover compaction or draining.
law sse_feed_buffer_observe:
  for +a: String
  for +b: String
  for +seen: U32
  for +cr: Bool
  for -st: Sse.St
  for +limit: Nat
  for +hn: MNat.lt(Nat.add(Nat.add(String.length(a), String.length(b)), 3n), limit)
  for +hu: MNat.le(limit, Lemmas.pow2(32n))
  {Packed.reader_observed(String.length(PackedModel.mask(a) ++ PackedModel.mask(b)),
    Sse.feed(Sse.Reader{Bytes.from_string(a), 0, seen, cr, st}, Bytes.from_string(b))) == PackedModel.mask(a) ++ PackedModel.mask(b) : String}

law sse_kind_observe:
  for +n: U32
  for +a: Tree.Tree<U32>
  for +b: Tree.Tree<U32>
  for +i: U32
  for +j: U32
  for two: {Buffer.observed(2n, Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(2n, Bytes.peek(Tree.reify(U32, b), j), j) : String}
  for four: {Buffer.observed(4n, Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(4n, Bytes.peek(Tree.reify(U32, b), j), j) : String}
  for +five: {Buffer.observed(5n, Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(5n, Bytes.peek(Tree.reify(U32, b), j), j) : String}
  {Packed.kind_index(n, a, i) == Packed.kind_index(n, b, j) : U32}

law sse_shifted_copy_word:
  for +i: Nat
  for +n: Nat
  for +depth: Nat
  for +src: Tree.Tree<U32>
  for +dst: Tree.Tree<U32>
  for +lo: Nat
  for +hi: Nat
  for +s: U32
  for +d: U32
  for +limit: Nat
  for shape: Bound.shape(depth, PackedModel.as_bits(dst))
  for hd: MNat.lt(depth, 32n)
  for hl: MNat.le(limit, 1n+Lemmas.pow2(depth))
  for hu: MNat.le(limit, Lemmas.pow2(32n))
  for end: MNat.lt(Nat.add(n, 1n+Nat.add(i, U32.to_nat(d))), limit)
  {Tree.read(U32, PackedModel.copy.shift(Nat.add(i, 1n+n), src, dst, lo, hi,
    Tree.read(U32, src, s), (s + 1 : U32), d, Tree.read(U32, src, (s + 1 : U32))), PackedModel.advance(i, d)) ==
    (U32.shrn(Tree.read(U32, src, PackedModel.advance(i, s)), lo) .|.
      U32.shln(Tree.read(U32, src, PackedModel.advance(1n+i, s)), hi) : U32) : U32}

# Positive shifted copies preserve the first octet, including exact-capacity buffers.
law sse_shifted_copy_head:
  for +m: U32
  for +n: Nat
  for +depth: Nat
  for +src: Tree.Tree<U32>
  for +dst: Tree.Tree<U32>
  for +s: U32
  for +limit: Nat
  for shape: Bound.shape(depth, PackedModel.as_bits(dst))
  for +hd: MNat.lt(depth, 32n)
  for +hl: MNat.le(limit, 1n+Nat.mul(Lemmas.pow2(depth), 4n))
  for hu: MNat.le(limit, Lemmas.pow2(32n))
  for +hn: MNat.lt(Nat.add(n, 1n), limit)
  for +em: {U32.to_nat(m) == 1n+n : Nat}
  {Packed.shifted_copy_head(m, src, dst, s) == Buffer.index(Bytes.peek(Tree.reify(U32, src), s)) : U32}

law sse_copy_octet:
  for +depth: Nat
  for +m: U32
  for +src: Tree.Tree<U32>
  for +dst: Tree.Tree<U32>
  for +s: U32
  for +i: U32
  for +limit: Nat
  for +source_limit: Nat
  for shape: Bound.shape(depth, PackedModel.as_bits(dst))
  for hd: MNat.lt(depth, 32n)
  for hl: MNat.le(limit, 1n+Nat.mul(Lemmas.pow2(depth), 4n))
  for hu: MNat.le(limit, Lemmas.pow2(32n))
  for hi: MNat.lt(U32.to_nat(i), U32.to_nat(m))
  for end: MNat.lt(Nat.add(U32.to_nat(m), 0n), limit)
  for source: MNat.lt(Nat.add(U32.to_nat(s), U32.to_nat(i)), source_limit)
  for hsu: MNat.le(source_limit, Lemmas.pow2(32n))
  {Packed.copied_octet(m, src, dst, s, i) == Buffer.index(Bytes.peek(Tree.reify(U32, src), (s + i : U32))) : U32}

law sse_slice_observe:
  for +text: String
  for +len: U32
  for +src: Tree.Tree<U32>
  for +start: U32
  for +n: U32
  for +limit: Nat
  for hn: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit)
  for hu: MNat.le(limit, Lemmas.pow2(32n))
  for elen: {U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))) == String.length(text) : Nat}
  for reads: PackedModel.Reads(text, src, U32.min(start, len))
  {Packed.observe(String.length(text), Packed.slice_second(Bytes.slice(Bytes.Bytes{len, Tree.reify(U32, src)}, start, n)), 0) == text : String}

law sse_slice_preserves_buffer:
  for +len: U32
  for +src: Tree.Tree<U32>
  for +start: U32
  for +n: U32
  {Packed.slice_first(Bytes.slice(Bytes.Bytes{len, Tree.reify(U32, src)}, start, n)) == Bytes.Bytes{len, Tree.reify(U32, src)} : Bytes.Bytes}

law sse_slice_string:
  for +text: String
  for +len: U32
  for +m: U32
  for +src: Tree.Tree<U32>
  for +s: U32
  for +limit: Nat
  for +hn: MNat.lt(Nat.add(U32.to_nat(m), 3n), limit)
  for +hu: MNat.le(limit, Lemmas.pow2(32n))
  for +elen: {U32.to_nat(m) == String.length(text) : Nat}
  for total: MNat.lt(Nat.add(U32.to_nat(m), U32.to_nat(s)), limit)
  for reads: PackedModel.Reads(text, src, s)
  {Bytes.to_string(Packed.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m))) == text : String}

law sse_compact_feed_state:
  for +len: U32
  for +src: Tree.Tree<U32>
  for +pos: U32
  for +seen: U32
  for +cr: Bool
  for st: Sse.St
  for +lb: U32
  for +right: Tree.Tree<U32>
  {Sse.feed.at(False{}, Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st, Bytes.Bytes{lb, Tree.reify(U32, right)}) ==
    Sse.Reader{Bytes.Bytes{(Packed.compact_length(len, pos) + lb : U32),
      Tree.reify(U32, PackedModel.append(Packed.compact_length(len, pos), Packed.compact_tree(len, src, pos), lb, right))},
      0, (U32.max(seen, pos) - pos : U32), cr, st} : Sse.Reader}

def repeated_events(n: Nat) -> String:
  match n:
    case 0n:
      ""
    case 1n+p:
      "data:x\n\n" ++ repeated_events(p)

# A single chunk must not discard the event after the old 64-event budget.
law sse_large_chunk:
  {List.length(&1, Sse.Message, events([repeated_events(65n)])) == 65n : Nat}

# ---- replies

def anthropic.body() -> String:
  "{\"id\":\"msg_1\",\"type\":\"message\",\"role\":\"assistant\",\"model\":\"claude-x\",\"content\":[{\"type\":\"text\",\"text\":\"Hello \"},{\"type\":\"tool_use\",\"id\":\"t\",\"name\":\"f\",\"input\":{\"text\":\"no\"}},{\"type\":\"text\",\"text\":\"there\"}],\"stop_reason\":\"end_turn\",\"stop_sequence\":null,\"usage\":{\"input_tokens\":12,\"output_tokens\":7}}"

# The text blocks join; a tool's input is not text.
law reply_anthropic:
  {Llm.reply(Llm.Anthropic{}, b(anthropic.body())) == Done{Llm.Reply{"msg_1", "claude-x", "Hello there", "end_turn", 12, 7}} : Result<&1, &1, Llm.Err, Llm.Reply>}

def openai.body() -> String:
  "{\"id\":\"chatcmpl-1\",\"object\":\"chat.completion\",\"model\":\"gpt-x\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"Hi there\",\"refusal\":null},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":11,\"completion_tokens\":3,\"total_tokens\":14}}"

law reply_openai:
  {Llm.reply(Llm.OpenAI{}, b(openai.body())) == Done{Llm.Reply{"chatcmpl-1", "gpt-x", "Hi there", "stop", 11, 3}} : Result<&1, &1, Llm.Err, Llm.Reply>}

# Strings are decoded from UTF-8.
law reply_utf8:
  {Llm.reply(Llm.OpenAI{}, b("{\"choices\":[{\"message\":{\"content\":\"" ++ SCon{Chr{195}, SCon{Chr{169}, "\"}}]}"}})) == Done{Llm.Reply{"", "", "é", "", 0, 0}} : Result<&1, &1, Llm.Err, Llm.Reply>}

law reply_bad:
  {Llm.reply(Llm.Anthropic{}, b("<html>")) == Fail{Llm.ErrReply{"<html>"}} : Result<&1, &1, Llm.Err, Llm.Reply>}

# ---- stream events

def ev(api: Llm.Api, +name: String, +data: String) -> Llm.Ev:
  Llm.ev(api, Sse.Message{name, b(data), ""})

law ev_anthropic_text:
  {ev(Llm.Anthropic{}, "content_block_delta", "{\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Hi\"}}") == Llm.EText{"Hi"} : Llm.Ev}

law ev_anthropic_tool:
  {ev(Llm.Anthropic{}, "content_block_delta", "{\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"{\"}}") == Llm.ESkip{} : Llm.Ev}

law ev_anthropic_ping:
  {ev(Llm.Anthropic{}, "ping", "{\"type\":\"ping\"}") == Llm.ESkip{} : Llm.Ev}

law ev_anthropic_stop:
  {ev(Llm.Anthropic{}, "message_stop", "{\"type\":\"message_stop\"}") == Llm.EEnd{} : Llm.Ev}

law ev_anthropic_error:
  {ev(Llm.Anthropic{}, "error", "{\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\",\"message\":\"Overloaded\"}}") == Llm.EFail{Llm.ErrApi{200, "Overloaded"}} : Llm.Ev}

law ev_openai_text:
  {ev(Llm.OpenAI{}, "message", "{\"choices\":[{\"index\":0,\"delta\":{\"content\":\"Hi\"}}]}") == Llm.EText{"Hi"} : Llm.Ev}

law ev_openai_role:
  {ev(Llm.OpenAI{}, "message", "{\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\",\"content\":\"\"}}]}") == Llm.ESkip{} : Llm.Ev}

law ev_openai_done:
  {ev(Llm.OpenAI{}, "message", "[DONE]") == Llm.EEnd{} : Llm.Ev}

law ev_openai_error:
  {ev(Llm.OpenAI{}, "message", "{\"error\":{\"message\":\"Rate limit\",\"type\":\"rate_limit_error\"}}") == Llm.EFail{Llm.ErrApi{200, "Rate limit"}} : Llm.Ev}

# ---- request bodies

def s(x: String) -> Json.Val:
  Json.Str{Json.utf8(x)}

def k(x: String, v: Json.Val) -> Bytes.Bytes & Json.Val:
  (Json.utf8(x), v)

def n(+x: String) -> Json.Val:
  Json.Num{b(x)}

def m(+role: String, +text: String) -> Json.Val:
  Json.Obj{[k("role", s(role)), k("content", s(text))]}

def req(+system: String) -> Llm.Req:
  Llm.Req{"m", system, [Llm.Msg{Llm.User{}, "hi"}, Llm.Msg{Llm.Assistant{}, "yo"}], 9}

law body_anthropic:
  {Llm.body(Llm.Anthropic{}, req("be brief"), True{}) == Json.Obj{[k("model", s("m")), k("max_tokens", n("9")), k("system", s("be brief")),
    k("messages", Json.Arr{[m("user", "hi"), m("assistant", "yo")]}), k("stream", Json.Flag{True{}})]} : Json.Val}

law body_anthropic_plain:
  {Llm.body(Llm.Anthropic{}, req(""), False{}) == Json.Obj{[k("model", s("m")), k("max_tokens", n("9")),
    k("messages", Json.Arr{[m("user", "hi"), m("assistant", "yo")]})]} : Json.Val}

# OpenAI takes the system prompt as the first message.
law body_openai:
  {Llm.body(Llm.OpenAI{}, req("be brief"), True{}) == Json.Obj{[k("model", s("m")), k("max_completion_tokens", n("9")),
    k("messages", Json.Arr{[m("system", "be brief"), m("user", "hi"), m("assistant", "yo")]}), k("stream", Json.Flag{True{}})]} : Json.Val}

law body_openai_plain:
  {Llm.body(Llm.OpenAI{}, req(""), False{}) == Json.Obj{[k("model", s("m")), k("max_completion_tokens", n("9")),
    k("messages", Json.Arr{[m("user", "hi"), m("assistant", "yo")]})]} : Json.Val}

# ---- retries

law again_overloaded:
  {Llm.again.status(529) == True{} : Bool}

law again_rate:
  {Llm.again.status(429) == True{} : Bool}

law again_bad_request:
  {Llm.again.status(400) == False{} : Bool}

law again_ok:
  {Llm.again.status(200) == False{} : Bool}
