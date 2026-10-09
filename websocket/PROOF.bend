import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import bend-mathlib@0.7.2.0/nat.bend as MNat
import bend-mathlib@0.7.2.0/list.bend as MList
import ../lemmas/lemmas.bend as Lemmas
import ./LAWS.bend as Laws
import ./websocket.bend as WS

def Laws.accept_input():
  {==}

def Laws.accept_rfc_sample():
  {==}

def Laws.key_rfc_sample():
  {==}

def Laws.request_rfc():
  {==}

def Laws.request_host_crlf():
  {==}

def Laws.request_path_crlf():
  {==}

def Laws.request_path_absolute():
  {==}

def Laws.request_key_space():
  {==}

def Laws.check_accepts():
  {==}

def Laws.check_status():
  {==}

def Laws.check_no_upgrade():
  {==}

def Laws.check_no_connection():
  {==}

def Laws.check_accept_mismatch():
  {==}

def Laws.check_duplicate_accept():
  {==}

def Laws.check_duplicate_upgrade():
  {==}

def Laws.check_connection_lines():
  {==}

def Laws.check_leading_line():
  {==}

def Laws.check_http10():
  {==}

def Laws.check_folded_line():
  {==}

def Laws.check_bare_line():
  {==}

def Laws.check_extension():
  {==}

def Laws.check_protocol():
  {==}

def Laws.split_leftover():
  {==}

def Laws.split_short():
  {==}

def Laws.encode_masked_hello():
  {==}

def Laws.encode_hello():
  {==}

def Laws.encode_256():
  {==}

def Laws.encode_control_long():
  {==}

def Laws.encode_control_fragment():
  {==}

def Laws.parse_hello():
  {==}

def Laws.parse_masked_hello():
  {==}

def Laws.parse_masked_on_client():
  {==}

def Laws.parse_unmasked_on_server():
  {==}

def Laws.parse_need_header():
  {==}

def Laws.parse_need_payload():
  {==}

def Laws.parse_rest():
  {==}

def Laws.parse_256():
  {==}

def Laws.parse_reserved():
  {==}

def Laws.parse_opcode():
  {==}

def Laws.parse_fragmented_ping():
  {==}

def Laws.parse_long_ping():
  {==}

def Laws.parse_too_big():
  {==}

def Laws.parse_64bit_high():
  {==}

def Laws.parse_64bit_high_max():
  {==}

def Laws.mask_involution():
  {==}

def Laws.mask_tail_zero():
  {==}

def Laws.feed_fragment_start():
  {==}

def Laws.feed_fragment_end():
  {==}

def Laws.feed_control_between():
  {==}

def Laws.feed_orphan_continuation():
  {==}

def Laws.feed_data_inside_fragments():
  {==}

def Laws.feed_utf8():
  {==}

def Laws.feed_utf8_four_byte():
  {==}

def Laws.feed_overlong():
  {==}

def Laws.feed_truncated():
  {==}

def Laws.feed_surrogate():
  {==}

def Laws.feed_binary_any_octets():
  {==}

def Laws.feed_message_too_big():
  {==}

def Laws.close_payload():
  {==}

def Laws.close_parse():
  {==}

def Laws.close_empty():
  {==}

def Laws.close_one_byte():
  {==}

def Laws.close_reserved_code():
  {==}

def Laws.close_bad_reason():
  {==}

# Incremental decoding.

def cat(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  Laws.cat(xs, ys)

# The header once it is decided, else h2.
def known(h: WS.Header, h2: WS.Header) -> WS.Header:
  match h:
    case WS.HNeed{}:
      h2
    case WS.HBad{code, why}:
      WS.HBad{code, why}
    case WS.HOk{fin, op, m, key, hs, len}:
      WS.HOk{fin, op, m, key, hs, len}

def known_self(h: WS.Header) -> {known(h, h) == h : WS.Header}:
  match h:
    case WS.HNeed{}:
      {==}
    case WS.HBad{code, why}:
      {==}
    case WS.HOk{fin, op, m, key, hs, len}:
      {==}

def decided(h: WS.Header) -> {h == known(h, h) : WS.Header}:
  Equal.sym(WS.Header, known(h, h), h, known_self(h))

def key_more(m: Bool, t: List<&2, U32>, q: List<&2, U32>, +masked: Bool, +b0: U32, +hs: U32, +hi: U32, +len: U32) ->
  {WS.header.key(m, cat(t, q), masked, b0, hs, hi, len) == known(WS.header.key(m, t, masked, b0, hs, hi, len), WS.header.key(m, cat(t, q), masked, b0, hs, hi, len)) : WS.Header}:
  match m:
    case True{}:
      match t:
        case Nil{}:
          {==}
        case Con{k0, Nil{}}:
          {==}
        case Con{k0, Con{k1, Nil{}}}:
          {==}
        case Con{k0, Con{k1, Con{k2, Nil{}}}}:
          {==}
        case Con{+k0, Con{+k1, Con{+k2, Con{+k3, r}}}}:
          decided(WS.header.check(masked, b0, True{}, (k0 .|. (k1 << 8n) .|. (k2 << 16n) .|. (k3 << 24n) : U32), (hs + 4 : U32), hi, len))
    case False{}:
      decided(WS.header.check(masked, b0, False{}, 0, hs, hi, len))

def ext16_more(t: List<&2, U32>, q: List<&2, U32>, +masked: Bool, +b0: U32, +m: Bool) ->
  {WS.header.ext16(cat(t, q), masked, b0, m) == known(WS.header.ext16(t, masked, b0, m), WS.header.ext16(cat(t, q), masked, b0, m)) : WS.Header}:
  match t:
    case Nil{}:
      {==}
    case Con{x, Nil{}}:
      {==}
    case Con{+x, Con{+y, r}}:
      key_more(m, r, q, masked, b0, 4, 0, ((x << 8n) .|. y : U32))

def ext64_more(t: List<&2, U32>, q: List<&2, U32>, +masked: Bool, +b0: U32, +m: Bool) ->
  {WS.header.ext64(cat(t, q), masked, b0, m) == known(WS.header.ext64(t, masked, b0, m), WS.header.ext64(cat(t, q), masked, b0, m)) : WS.Header}:
  match t:
    case Nil{}:
      {==}
    case Con{a, Nil{}}:
      {==}
    case Con{a, Con{b, Nil{}}}:
      {==}
    case Con{a, Con{b, Con{c, Nil{}}}}:
      {==}
    case Con{a, Con{b, Con{c, Con{d, Nil{}}}}}:
      {==}
    case Con{a, Con{b, Con{c, Con{d, Con{e, Nil{}}}}}}:
      {==}
    case Con{a, Con{b, Con{c, Con{d, Con{e, Con{f, Nil{}}}}}}}:
      {==}
    case Con{a, Con{b, Con{c, Con{d, Con{e, Con{f, Con{g, Nil{}}}}}}}}:
      {==}
    case Con{+a, Con{+b, Con{+c, Con{+d, Con{+e, Con{+f, Con{+g, Con{+h, r}}}}}}}}:
      key_more(m, r, q, masked, b0, 10, WS.be32(a, b, c, d), WS.be32(e, f, g, h))

def ext_more(short: Bool, mid: Bool, t: List<&2, U32>, q: List<&2, U32>, +masked: Bool, +b0: U32, +m: Bool, +l7: U32) ->
  {WS.header.ext(short, mid, cat(t, q), masked, b0, m, l7) == known(WS.header.ext(short, mid, t, masked, b0, m, l7), WS.header.ext(short, mid, cat(t, q), masked, b0, m, l7)) : WS.Header}:
  match short:
    case True{}:
      key_more(m, t, q, masked, b0, 2, 0, l7)
    case False{}:
      match mid:
        case True{}:
          ext16_more(t, q, masked, b0, m)
        case False{}:
          ext64_more(t, q, masked, b0, m)

def b1_more(m: Bool, t: List<&2, U32>, q: List<&2, U32>, +masked: Bool, +b0: U32, +b1: U32) ->
  {WS.header.b1(m, cat(t, q), masked, b0, b1) == known(WS.header.b1(m, t, masked, b0, b1), WS.header.b1(m, cat(t, q), masked, b0, b1)) : WS.Header}:
  match m:
    case True{}:
      ext_more(U32.is_lt((b1 - 128 : U32), 126), U32.is_eq((b1 - 128 : U32), 126), t, q, masked, b0, True{}, (b1 - 128 : U32))
    case False{}:
      ext_more(U32.is_lt(b1, 126), U32.is_eq(b1, 126), t, q, masked, b0, False{}, b1)

# A header decided from p stays the same when more octets come after p.
def header_more(p: List<&2, U32>, q: List<&2, U32>, +masked: Bool) ->
  {WS.header(cat(p, q), masked) == known(WS.header(p, masked), WS.header(cat(p, q), masked)) : WS.Header}:
  match p:
    case Nil{}:
      {==}
    case Con{b0, Nil{}}:
      {==}
    case Con{+b0, Con{+b1, t}}:
      b1_more(U32.is_le(128, b1), t, q, masked, b0, b1)

def le_sub_of_add_le(a: Nat, b: Nat, c: Nat, h: MNat.le(Nat.add(a, b), c)) -> MNat.le(b, Nat.sub(c, a)):
  match a c:
    case 0n 0n:
      h
    case 0n 1n+q:
      h
    case 1n+p 0n:
      Empty.absurd(MNat.le(b, Nat.sub(0n, 1n+p)), MNat.internal_false_ne_true(h))
    case 1n+p 1n+q:
      le_sub_of_add_le(p, b, q, h)

def le_cat(+a: Nat, +xs: List<&2, U32>, +ys: List<&2, U32>, h: MNat.le(a, List.length(&2, U32, xs))) -> MNat.le(a, List.length(&2, U32, cat(xs, ys))):
  %MList.length_append_sym(&2, U32, xs, ys) : MNat.le(a, _)
  MNat.le_trans(a, List.length(&2, U32, xs), Nat.add(List.length(&2, U32, xs), List.length(&2, U32, ys)), h,
    MNat.le_add_right(List.length(&2, U32, xs), List.length(&2, U32, ys)))

def le_drop(+h: Nat, +n: Nat, +xs: List<&2, U32>, e: MNat.le(Nat.add(h, n), List.length(&2, U32, xs))) -> MNat.le(n, List.length(&2, U32, List.drop(&2, U32, xs, h))):
  %MList.length_drop_sym(&2, U32, xs, h) : MNat.le(n, _)
  le_sub_of_add_le(h, n, List.length(&2, U32, xs), e)

# d once it is decided, with ys after its rest; else d2.
def extend(d: WS.Decode<List<&2, U32>, List<&2, U32>>, +ys: List<&2, U32>, d2: WS.Decode<List<&2, U32>, List<&2, U32>>) -> WS.Decode<List<&2, U32>, List<&2, U32>>:
  match d:
    case WS.Need{b}:
      d2
    case WS.Got{f, r}:
      WS.Got{f, cat(r, ys)}
    case WS.Bad{code, why}:
      WS.Bad{code, why}

def fits_more(+xs: List<&2, U32>, +ys: List<&2, U32>, +fin: Bool, +op: U32, +m: Bool, +key: U32, +hs: U32, +len: U32, c: Bool,
  +ec: {Nat.is_le(Nat.add(U32.to_nat(hs), U32.to_nat(len)), List.length(&2, U32, xs)) == c : Bool}) ->
  {WS.next.fits(~List<&2, U32>, ~List<&2, U32>, ~WS.list.cut, ~WS.list.unmask, fin, op, m, key, hs, len, WS.list.fits(cat(xs, ys), hs, len))
    == extend(WS.next.fits(~List<&2, U32>, ~List<&2, U32>, ~WS.list.cut, ~WS.list.unmask, fin, op, m, key, hs, len, (xs, c)), ys,
      WS.next.fits(~List<&2, U32>, ~List<&2, U32>, ~WS.list.cut, ~WS.list.unmask, fin, op, m, key, hs, len, WS.list.fits(cat(xs, ys), hs, len))) : WS.Decode<List<&2, U32>, List<&2, U32>>}:
  match c:
    case False{}:
      {==}
    case True{}:
      +a = Nat.add(U32.to_nat(hs), U32.to_nat(len))
      +lh = MNat.le_trans(U32.to_nat(hs), a, List.length(&2, U32, xs), MNat.le_add_right(U32.to_nat(hs), U32.to_nat(len)), ec)
      +ln = le_drop(U32.to_nat(hs), U32.to_nat(len), xs, ec)
      %Equal.sym(Bool, Nat.is_le(a, List.length(&2, U32, cat(xs, ys))), True{}, le_cat(a, xs, ys, ec)) :
        {WS.next.fits(~List<&2, U32>, ~List<&2, U32>, ~WS.list.cut, ~WS.list.unmask, fin, op, m, key, hs, len, (cat(xs, ys), _))
          == WS.Got{WS.Frame{fin, op, WS.unmask.when(~List<&2, U32>, ~WS.list.unmask, m, key, List.take(&2, U32, List.drop(&2, U32, xs, U32.to_nat(hs)), U32.to_nat(len)))}, cat(List.drop(&2, U32, xs, a), ys)} : WS.Decode<List<&2, U32>, List<&2, U32>>}
      %MList.drop_append_of_le_length_sym(&2, U32, xs, ys, U32.to_nat(hs), lh) :
        {WS.Got{WS.Frame{fin, op, WS.unmask.when(~List<&2, U32>, ~WS.list.unmask, m, key, List.take(&2, U32, _, U32.to_nat(len)))}, List.drop(&2, U32, cat(xs, ys), a)}
          == WS.Got{WS.Frame{fin, op, WS.unmask.when(~List<&2, U32>, ~WS.list.unmask, m, key, List.take(&2, U32, List.drop(&2, U32, xs, U32.to_nat(hs)), U32.to_nat(len)))}, cat(List.drop(&2, U32, xs, a), ys)} : WS.Decode<List<&2, U32>, List<&2, U32>>}
      %MList.take_append_of_le_length_sym(&2, U32, List.drop(&2, U32, xs, U32.to_nat(hs)), ys, U32.to_nat(len), ln) :
        {WS.Got{WS.Frame{fin, op, WS.unmask.when(~List<&2, U32>, ~WS.list.unmask, m, key, _)}, List.drop(&2, U32, cat(xs, ys), a)}
          == WS.Got{WS.Frame{fin, op, WS.unmask.when(~List<&2, U32>, ~WS.list.unmask, m, key, List.take(&2, U32, List.drop(&2, U32, xs, U32.to_nat(hs)), U32.to_nat(len)))}, cat(List.drop(&2, U32, xs, a), ys)} : WS.Decode<List<&2, U32>, List<&2, U32>>}
      %MList.drop_append_of_le_length_sym(&2, U32, xs, ys, a, ec) :
        {WS.Got{WS.Frame{fin, op, WS.unmask.when(~List<&2, U32>, ~WS.list.unmask, m, key, List.take(&2, U32, List.drop(&2, U32, xs, U32.to_nat(hs)), U32.to_nat(len)))}, _}
          == WS.Got{WS.Frame{fin, op, WS.unmask.when(~List<&2, U32>, ~WS.list.unmask, m, key, List.take(&2, U32, List.drop(&2, U32, xs, U32.to_nat(hs)), U32.to_nat(len)))}, cat(List.drop(&2, U32, xs, a), ys)} : WS.Decode<List<&2, U32>, List<&2, U32>>}
      {==}

def size_more(c: Bool, +xs: List<&2, U32>, +ys: List<&2, U32>, +fin: Bool, +op: U32, +m: Bool, +key: U32, +hs: U32, +len: U32) ->
  {WS.next.size(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, c, fin, op, m, key, hs, len, cat(xs, ys))
    == extend(WS.next.size(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, c, fin, op, m, key, hs, len, xs), ys,
      WS.next.size(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, c, fin, op, m, key, hs, len, cat(xs, ys))) : WS.Decode<List<&2, U32>, List<&2, U32>>}:
  match c:
    case True{}:
      {==}
    case False{}:
      fits_more(xs, ys, fin, op, m, key, hs, len, Nat.is_le(Nat.add(U32.to_nat(hs), U32.to_nat(len)), List.length(&2, U32, xs)), {==})

def next_more.h(+masked: Bool, +max: U32, +xs: List<&2, U32>, +ys: List<&2, U32>, h: WS.Header,
  hm: {WS.header(cat(xs, ys), masked) == known(h, WS.header(cat(xs, ys), masked)) : WS.Header}) ->
  {WS.next.head(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, max, WS.header(cat(xs, ys), masked), cat(xs, ys))
    == extend(WS.next.head(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, max, h, xs), ys,
      WS.next.head(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, max, WS.header(cat(xs, ys), masked), cat(xs, ys))) : WS.Decode<List<&2, U32>, List<&2, U32>>}:
  match h:
    case WS.HNeed{}:
      {==}
    case WS.HBad{+code, +why}:
      %Equal.sym(WS.Header, WS.header(cat(xs, ys), masked), WS.HBad{code, why}, hm) :
        {WS.next.head(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, max, _, cat(xs, ys)) == WS.Bad{code, why} : WS.Decode<List<&2, U32>, List<&2, U32>>}
      {==}
    case WS.HOk{+fin, +op, +m, +key, +hs, +len}:
      %Equal.sym(WS.Header, WS.header(cat(xs, ys), masked), WS.HOk{fin, op, m, key, hs, len}, hm) :
        {WS.next.head(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, max, _, cat(xs, ys))
          == extend(WS.next.head(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, max, WS.HOk{fin, op, m, key, hs, len}, xs), ys,
            WS.next.head(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, max, _, cat(xs, ys))) : WS.Decode<List<&2, U32>, List<&2, U32>>}
      size_more(U32.is_lt(max, len), xs, ys, fin, op, m, key, hs, len)

# A frame or a fault decoded from xs stays the same when more octets come after xs.
def next_more(+masked: Bool, +max: U32, +xs: List<&2, U32>, +ys: List<&2, U32>) ->
  {WS.list.next(masked, max, cat(xs, ys)) == extend(WS.list.next(masked, max, xs), ys, WS.list.next(masked, max, cat(xs, ys))) : WS.Decode<List<&2, U32>, List<&2, U32>>}:
  next_more.h(masked, max, xs, ys, WS.header(xs, masked), header_more(xs, ys, masked))

def chunk.d(n: Nat, +masked: Bool, +max: U32, +xs: List<&2, U32>, +ys: List<&2, U32>, d: WS.Decode<List<&2, U32>, List<&2, U32>>) ->
  {Laws.drain(n, masked, max, cat(xs, ys), extend(d, ys, WS.list.next(masked, max, cat(xs, ys)))) == Laws.resume(Laws.drain(n, masked, max, xs, d), masked, max, ys) : Laws.Run}:
  match n:
    case 0n:
      match d:
        case WS.Need{b}:
          {==}
        case WS.Got{f, r}:
          {==}
        case WS.Bad{code, why}:
          {==}
    case 1n+p:
      match d:
        case WS.Need{b}:
          {==}
        case WS.Got{f, +r}:
          %Equal.sym(WS.Decode<List<&2, U32>, List<&2, U32>>, WS.list.next(masked, max, cat(r, ys)), extend(WS.list.next(masked, max, r), ys, WS.list.next(masked, max, cat(r, ys))), next_more(masked, max, r, ys)) :
            {Laws.RFrame{f, Laws.drain(p, masked, max, cat(r, ys), _)} == Laws.RFrame{f, Laws.resume(Laws.drain(p, masked, max, r, WS.list.next(masked, max, r)), masked, max, ys)} : Laws.Run}
          %Equal.sym(Laws.Run, Laws.drain(p, masked, max, cat(r, ys), extend(WS.list.next(masked, max, r), ys, WS.list.next(masked, max, cat(r, ys)))), Laws.resume(Laws.drain(p, masked, max, r, WS.list.next(masked, max, r)), masked, max, ys), chunk.d(p, masked, max, r, ys, WS.list.next(masked, max, r))) :
            {Laws.RFrame{f, _} == Laws.RFrame{f, Laws.resume(Laws.drain(p, masked, max, r, WS.list.next(masked, max, r)), masked, max, ys)} : Laws.Run}
          {==}
        case WS.Bad{code, why}:
          {==}

def chunk(n: Nat, +masked: Bool, +max: U32, +xs: List<&2, U32>, +ys: List<&2, U32>) ->
  {Laws.frames(n, masked, max, cat(xs, ys)) == Laws.resume(Laws.frames(n, masked, max, xs), masked, max, ys) : Laws.Run}:
  %Equal.sym(WS.Decode<List<&2, U32>, List<&2, U32>>, WS.list.next(masked, max, cat(xs, ys)), extend(WS.list.next(masked, max, xs), ys, WS.list.next(masked, max, cat(xs, ys))), next_more(masked, max, xs, ys)) :
    {Laws.drain(n, masked, max, cat(xs, ys), _) == Laws.resume(Laws.frames(n, masked, max, xs), masked, max, ys) : Laws.Run}
  chunk.d(n, masked, max, xs, ys, WS.list.next(masked, max, xs))

def Laws.feed_split(n, masked, max, xs, ys):
  Equal.sym(Laws.Run, Laws.frames(n, masked, max, cat(xs, ys)), Laws.resume(Laws.frames(n, masked, max, xs), masked, max, ys), chunk(n, masked, max, xs, ys))

def Laws.feed_empty(n, masked, max, xs):
  %MList.append_nil(&2, U32, xs) : {Laws.resume(Laws.frames(n, masked, max, xs), masked, max, Nil{}) == Laws.frames(n, masked, max, _) : Laws.Run}
  Laws.feed_split(n, masked, max, xs, Nil{})

def Laws.got_more(masked, max, xs, ys, f, r, e):
  %e : {WS.list.next(masked, max, cat(xs, ys)) == extend(_, ys, WS.list.next(masked, max, cat(xs, ys))) : WS.Decode<List<&2, U32>, List<&2, U32>>}
  next_more(masked, max, xs, ys)

def Laws.bad_more(masked, max, xs, ys, code, why, e):
  %e : {WS.list.next(masked, max, cat(xs, ys)) == extend(_, ys, WS.list.next(masked, max, cat(xs, ys))) : WS.Decode<List<&2, U32>, List<&2, U32>>}
  next_more(masked, max, xs, ys)

def hwire(h: WS.Header) -> Nat:
  match h:
    case WS.HOk{fin, op, m, key, +hs, +len}:
      Nat.add(U32.to_nat(hs), U32.to_nat(len))
    case _:
      0n

def hlen(h: WS.Header) -> Nat:
  match h:
    case WS.HOk{fin, op, m, key, hs, +len}:
      U32.to_nat(len)
    case _:
      0n

# A decided header takes between 2 and 14 octets.
def hsize(h: WS.Header) -> Type:
  match h:
    case WS.HOk{fin, op, m, key, +hs, len}:
      MNat.le(2n, U32.to_nat(hs)) & MNat.le(U32.to_nat(hs), 14n)
    case _:
      Unit

def plen(f: WS.Frame<List<&2, U32>>) -> Nat:
  match f:
    case WS.Frame{fin, op, p}:
      List.length(&2, U32, p)

def rest_of(d: WS.Decode<List<&2, U32>, List<&2, U32>>) -> List<&2, U32>:
  match d:
    case WS.Got{f, r}:
      r
    case _:
      Nil{}

def plen_of(d: WS.Decode<List<&2, U32>, List<&2, U32>>) -> Nat:
  match d:
    case WS.Got{f, r}:
      plen(f)
    case _:
      0n

def got_disc(d: WS.Decode<List<&2, U32>, List<&2, U32>>) -> Type:
  match d:
    case WS.Got{f, r}:
      Unit
    case _:
      Empty

def need_disc(d: WS.Decode<List<&2, U32>, List<&2, U32>>) -> Type:
  match d:
    case WS.Need{b}:
      Unit
    case _:
      Empty

def need_not_got(+b: List<&2, U32>, -f: WS.Frame<List<&2, U32>>, -r: List<&2, U32>, e: {WS.Need{b} == WS.Got{f, r} : WS.Decode<List<&2, U32>, List<&2, U32>>}) -> Empty:
  %Equal.sym(WS.Decode<List<&2, U32>, List<&2, U32>>, WS.Need{b}, WS.Got{f, r}, e) : got_disc(_)
  Unit{}

def bad_not_got(+code: U32, +why: String, -f: WS.Frame<List<&2, U32>>, -r: List<&2, U32>, e: {WS.Bad{code, why} == WS.Got{f, r} : WS.Decode<List<&2, U32>, List<&2, U32>>}) -> Empty:
  %Equal.sym(WS.Decode<List<&2, U32>, List<&2, U32>>, WS.Bad{code, why}, WS.Got{f, r}, e) : got_disc(_)
  Unit{}

def got_not_need(-f: WS.Frame<List<&2, U32>>, -r: List<&2, U32>, +b: List<&2, U32>, e: {WS.Got{f, r} == WS.Need{b} : WS.Decode<List<&2, U32>, List<&2, U32>>}) -> Empty:
  %Equal.sym(WS.Decode<List<&2, U32>, List<&2, U32>>, WS.Got{f, r}, WS.Need{b}, e) : need_disc(_)
  Unit{}

def bad_not_need(+code: U32, +why: String, +b: List<&2, U32>, e: {WS.Bad{code, why} == WS.Need{b} : WS.Decode<List<&2, U32>, List<&2, U32>>}) -> Empty:
  %Equal.sym(WS.Decode<List<&2, U32>, List<&2, U32>>, WS.Bad{code, why}, WS.Need{b}, e) : need_disc(_)
  Unit{}

def verdict_hs(err: Maybe<&1, U32 & String>, +fin: Bool, +op: U32, +m: Bool, +key: U32, +hs: U32, +len: U32,
  hh: MNat.le(2n, U32.to_nat(hs)) & MNat.le(U32.to_nat(hs), 14n)) -> hsize(WS.header.verdict(err, fin, op, m, key, hs, len)):
  match err:
    case Some{(code, why)}:
      Unit{}
    case None{}:
      hh

def check_hs(+masked: Bool, +b0: U32, +m: Bool, +key: U32, +hs: U32, +hi: U32, +len: U32,
  hh: MNat.le(2n, U32.to_nat(hs)) & MNat.le(U32.to_nat(hs), 14n)) -> hsize(WS.header.check(masked, b0, m, key, hs, hi, len)):
  verdict_hs(WS.header.err(masked, b0, m, hi, len), U32.is_ne((b0 .&. 128 : U32), 0), (b0 .&. 15 : U32), m, key, hs, len, hh)

def key_hs(m: Bool, t: List<&2, U32>, +masked: Bool, +b0: U32, +hs: U32, +hi: U32, +len: U32,
  h0: MNat.le(2n, U32.to_nat(hs)) & MNat.le(U32.to_nat(hs), 14n),
  h4: MNat.le(2n, U32.to_nat((hs + 4 : U32))) & MNat.le(U32.to_nat((hs + 4 : U32)), 14n)) -> hsize(WS.header.key(m, t, masked, b0, hs, hi, len)):
  match m:
    case True{}:
      match t:
        case Nil{}:
          Unit{}
        case Con{k0, Nil{}}:
          Unit{}
        case Con{k0, Con{k1, Nil{}}}:
          Unit{}
        case Con{k0, Con{k1, Con{k2, Nil{}}}}:
          Unit{}
        case Con{+k0, Con{+k1, Con{+k2, Con{+k3, r}}}}:
          check_hs(masked, b0, True{}, (k0 .|. (k1 << 8n) .|. (k2 << 16n) .|. (k3 << 24n) : U32), (hs + 4 : U32), hi, len, h4)
    case False{}:
      check_hs(masked, b0, False{}, 0, hs, hi, len, h0)

def ext16_hs(t: List<&2, U32>, +masked: Bool, +b0: U32, +m: Bool) -> hsize(WS.header.ext16(t, masked, b0, m)):
  match t:
    case Nil{}:
      Unit{}
    case Con{x, Nil{}}:
      Unit{}
    case Con{+x, Con{+y, r}}:
      key_hs(m, r, masked, b0, 4, 0, ((x << 8n) .|. y : U32), ({==}, {==}), ({==}, {==}))

def ext64_hs(t: List<&2, U32>, +masked: Bool, +b0: U32, +m: Bool) -> hsize(WS.header.ext64(t, masked, b0, m)):
  match t:
    case Nil{}:
      Unit{}
    case Con{x0, Nil{}}:
      Unit{}
    case Con{x0, Con{x1, Nil{}}}:
      Unit{}
    case Con{x0, Con{x1, Con{x2, Nil{}}}}:
      Unit{}
    case Con{x0, Con{x1, Con{x2, Con{x3, Nil{}}}}}:
      Unit{}
    case Con{x0, Con{x1, Con{x2, Con{x3, Con{x4, Nil{}}}}}}:
      Unit{}
    case Con{x0, Con{x1, Con{x2, Con{x3, Con{x4, Con{x5, Nil{}}}}}}}:
      Unit{}
    case Con{x0, Con{x1, Con{x2, Con{x3, Con{x4, Con{x5, Con{x6, Nil{}}}}}}}}:
      Unit{}
    case Con{+a, Con{+b, Con{+c, Con{+d, Con{+e, Con{+f, Con{+g, Con{+h, r}}}}}}}}:
      key_hs(m, r, masked, b0, 10, WS.be32(a, b, c, d), WS.be32(e, f, g, h), ({==}, {==}), ({==}, {==}))

def ext_hs(short: Bool, mid: Bool, t: List<&2, U32>, +masked: Bool, +b0: U32, +m: Bool, +l7: U32) -> hsize(WS.header.ext(short, mid, t, masked, b0, m, l7)):
  match short:
    case True{}:
      key_hs(m, t, masked, b0, 2, 0, l7, ({==}, {==}), ({==}, {==}))
    case False{}:
      match mid:
        case True{}:
          ext16_hs(t, masked, b0, m)
        case False{}:
          ext64_hs(t, masked, b0, m)

def b1_hs(m: Bool, t: List<&2, U32>, +masked: Bool, +b0: U32, +b1: U32) -> hsize(WS.header.b1(m, t, masked, b0, b1)):
  match m:
    case True{}:
      ext_hs(U32.is_lt((b1 - 128 : U32), 126), U32.is_eq((b1 - 128 : U32), 126), t, masked, b0, True{}, (b1 - 128 : U32))
    case False{}:
      ext_hs(U32.is_lt(b1, 126), U32.is_eq(b1, 126), t, masked, b0, False{}, b1)

def header_hs(p: List<&2, U32>, +masked: Bool) -> hsize(WS.header(p, masked)):
  match p:
    case Nil{}:
      Unit{}
    case Con{b0, Nil{}}:
      Unit{}
    case Con{+b0, Con{+b1, t}}:
      b1_hs(U32.is_le(128, b1), t, masked, b0, b1)


def got_facts(+max: U32, +xs: List<&2, U32>, -f: WS.Frame<List<&2, U32>>, +r: List<&2, U32>, h: WS.Header) -> Type:
  MNat.le(hwire(h), List.length(&2, U32, xs)) & {r == List.drop(&2, U32, xs, hwire(h)) : List<&2, U32>} & MNat.le(hlen(h), U32.to_nat(max)) & {plen(f) == hlen(h) : Nat} & MNat.le(2n, hwire(h))

def take_len(+xs: List<&2, U32>, +n: Nat, h: MNat.le(n, List.length(&2, U32, xs))) -> {List.length(&2, U32, List.take(&2, U32, xs, n)) == n : Nat}:
  match xs n:
    case Nil{} 0n:
      {==}
    case Nil{} 1n+p:
      Empty.absurd({List.length(&2, U32, List.take(&2, U32, Nil{}, 1n+p)) == 1n+p : Nat}, MNat.internal_false_ne_true(h))
    case Con{x, t} 0n:
      {==}
    case Con{x, +t} 1n+p:
      %take_len(t, p, h) : {1n+List.length(&2, U32, List.take(&2, U32, t, p)) == 1n+_ : Nat}
      {==}

def unmask_len(xs: List<&2, U32>, +key: U32) -> {List.length(&2, U32, WS.list.unmask.go(xs, key)) == List.length(&2, U32, xs) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      %unmask_len(t, ((key >> 8n) .|. (key << 24n) : U32)) :
        {1n+List.length(&2, U32, WS.list.unmask.go(t, ((key >> 8n) .|. (key << 24n) : U32))) == 1n+_ : Nat}
      {==}

def unmask_when_len(m: Bool, +key: U32, +ys: List<&2, U32>) -> {List.length(&2, U32, WS.unmask.when(~List<&2, U32>, ~WS.list.unmask, m, key, ys)) == List.length(&2, U32, ys) : Nat}:
  match m:
    case True{}:
      unmask_len(ys, key)
    case False{}:
      {==}

def got_inv.f(+max: U32, +xs: List<&2, U32>, -f: WS.Frame<List<&2, U32>>, +r: List<&2, U32>, +fin: Bool, +op: U32, +m: Bool, +key: U32, +hs: U32, +len: U32, c: Bool,
  +ec: {Nat.is_le(Nat.add(U32.to_nat(hs), U32.to_nat(len)), List.length(&2, U32, xs)) == c : Bool}, lim: MNat.le(U32.to_nat(len), U32.to_nat(max)), lo: MNat.le(2n, U32.to_nat(hs)),
  e: {WS.next.fits(~List<&2, U32>, ~List<&2, U32>, ~WS.list.cut, ~WS.list.unmask, fin, op, m, key, hs, len, (xs, c)) == WS.Got{f, r} : WS.Decode<List<&2, U32>, List<&2, U32>>}) ->
  got_facts(max, xs, f, r, WS.HOk{fin, op, m, key, hs, len}):
  match c:
    case False{}:
      Empty.absurd(got_facts(max, xs, f, r, WS.HOk{fin, op, m, key, hs, len}), need_not_got(xs, f, r, e))
    case True{}:
      +e2 = e
      +rr = Equal.sym(List<&2, U32>, List.drop(&2, U32, xs, Nat.add(U32.to_nat(hs), U32.to_nat(len))), r, Equal.cong(WS.Decode<List<&2, U32>, List<&2, U32>>, List<&2, U32>, d => rest_of(d), WS.Got{WS.Frame{fin, op, WS.unmask.when(~List<&2, U32>, ~WS.list.unmask, m, key, List.take(&2, U32, List.drop(&2, U32, xs, U32.to_nat(hs)), U32.to_nat(len)))}, List.drop(&2, U32, xs, Nat.add(U32.to_nat(hs), U32.to_nat(len)))}, WS.Got{f, r}, e2))
      +pf = Equal.sym(Nat, plen(WS.Frame{fin, op, WS.unmask.when(~List<&2, U32>, ~WS.list.unmask, m, key, List.take(&2, U32, List.drop(&2, U32, xs, U32.to_nat(hs)), U32.to_nat(len)))}), plen(f), Equal.cong(WS.Decode<List<&2, U32>, List<&2, U32>>, Nat, d => plen_of(d), WS.Got{WS.Frame{fin, op, WS.unmask.when(~List<&2, U32>, ~WS.list.unmask, m, key, List.take(&2, U32, List.drop(&2, U32, xs, U32.to_nat(hs)), U32.to_nat(len)))}, List.drop(&2, U32, xs, Nat.add(U32.to_nat(hs), U32.to_nat(len)))}, WS.Got{f, r}, e2))
      +pn = Equal.trans(Nat, List.length(&2, U32, WS.unmask.when(~List<&2, U32>, ~WS.list.unmask, m, key, List.take(&2, U32, List.drop(&2, U32, xs, U32.to_nat(hs)), U32.to_nat(len)))),
        List.length(&2, U32, List.take(&2, U32, List.drop(&2, U32, xs, U32.to_nat(hs)), U32.to_nat(len))), U32.to_nat(len),
        unmask_when_len(m, key, List.take(&2, U32, List.drop(&2, U32, xs, U32.to_nat(hs)), U32.to_nat(len))),
        take_len(List.drop(&2, U32, xs, U32.to_nat(hs)), U32.to_nat(len), le_drop(U32.to_nat(hs), U32.to_nat(len), xs, ec)))
      (ec, rr, lim, Equal.trans(Nat, plen(f), plen(WS.Frame{fin, op, WS.unmask.when(~List<&2, U32>, ~WS.list.unmask, m, key, List.take(&2, U32, List.drop(&2, U32, xs, U32.to_nat(hs)), U32.to_nat(len)))}), U32.to_nat(len), pf, pn), MNat.le_trans(2n, U32.to_nat(hs), Nat.add(U32.to_nat(hs), U32.to_nat(len)), lo, MNat.le_add_right(U32.to_nat(hs), U32.to_nat(len))))

def u32_not_lt(+a: U32, +b: U32, e: {U32.is_lt(a, b) == False{} : Bool}) -> MNat.le(U32.to_nat(b), U32.to_nat(a)):
  MNat.le_of_not_lt(U32.to_nat(a), U32.to_nat(b), Equal.trans(Bool, Nat.is_lt(U32.to_nat(a), U32.to_nat(b)), U32.is_lt(a, b), False{},
    Equal.sym(Bool, U32.is_lt(a, b), Nat.is_lt(U32.to_nat(a), U32.to_nat(b)), Lemmas.u32_is_lt_nat(a, b)), e))

def got_inv.s(+max: U32, +xs: List<&2, U32>, -f: WS.Frame<List<&2, U32>>, +r: List<&2, U32>, +fin: Bool, +op: U32, +m: Bool, +key: U32, +hs: U32, +len: U32,
  c: Bool, +ec: {U32.is_lt(max, len) == c : Bool}, lo: MNat.le(2n, U32.to_nat(hs)), e: {WS.next.size(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, c, fin, op, m, key, hs, len, xs) == WS.Got{f, r} : WS.Decode<List<&2, U32>, List<&2, U32>>}) ->
  got_facts(max, xs, f, r, WS.HOk{fin, op, m, key, hs, len}):
  match c:
    case True{}:
      Empty.absurd(got_facts(max, xs, f, r, WS.HOk{fin, op, m, key, hs, len}), bad_not_got(1009, "frame over the size limit", f, r, e))
    case False{}:
      got_inv.f(max, xs, f, r, fin, op, m, key, hs, len, Nat.is_le(Nat.add(U32.to_nat(hs), U32.to_nat(len)), List.length(&2, U32, xs)), {==}, u32_not_lt(max, len, ec), lo, e)

def got_inv.h(+max: U32, +xs: List<&2, U32>, -f: WS.Frame<List<&2, U32>>, +r: List<&2, U32>, h: WS.Header, hh: hsize(h),
  e: {WS.next.head(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, max, h, xs) == WS.Got{f, r} : WS.Decode<List<&2, U32>, List<&2, U32>>}) -> got_facts(max, xs, f, r, h):
  match h:
    case WS.HNeed{}:
      Empty.absurd(got_facts(max, xs, f, r, WS.HNeed{}), need_not_got(xs, f, r, e))
    case WS.HBad{+code, +why}:
      Empty.absurd(got_facts(max, xs, f, r, WS.HBad{code, why}), bad_not_got(code, why, f, r, e))
    case WS.HOk{+fin, +op, +m, +key, +hs, +len}:
      (lo, hi) = hh
      got_inv.s(max, xs, f, r, fin, op, m, key, hs, len, U32.is_lt(max, len), {==}, lo, e)

# What a decoded frame tells about the header at the front of xs.
def got_inv(+masked: Bool, +max: U32, +xs: List<&2, U32>, -f: WS.Frame<List<&2, U32>>, +r: List<&2, U32>, e: {WS.list.next(masked, max, xs) == WS.Got{f, r} : WS.Decode<List<&2, U32>, List<&2, U32>>}) ->
  got_facts(max, xs, f, r, WS.header(xs, masked)):
  got_inv.h(max, xs, f, r, WS.header(xs, masked), header_hs(xs, masked), e)

def suffix(+xs: List<&2, U32>, +r: List<&2, U32>, +k: Nat, rr: {r == List.drop(&2, U32, xs, k) : List<&2, U32>}) -> {cat(List.take(&2, U32, xs, k), r) == xs : List<&2, U32>}:
  %Equal.sym(List<&2, U32>, r, List.drop(&2, U32, xs, k), rr) : {cat(List.take(&2, U32, xs, k), _) == xs : List<&2, U32>}
  MList.take_append_drop(&2, U32, xs, k)

def got_suffix.of(+masked: Bool, +max: U32, +xs: List<&2, U32>, -f: WS.Frame<List<&2, U32>>, +r: List<&2, U32>, t: got_facts(max, xs, f, r, WS.header(xs, masked))) ->
  &k:Nat -> {cat(List.take(&2, U32, xs, k), r) == xs : List<&2, U32>}:
  (lw, rr, lim, pl, l2) = t
  (hwire(WS.header(xs, masked)), suffix(xs, r, hwire(WS.header(xs, masked)), rr))

def Laws.got_suffix(masked, max, xs, f, r, e):
  got_suffix.of(masked, max, xs, f, r, got_inv(masked, max, xs, f, r, e))

def progress_nat(+k: Nat, +l: Nat, h1: MNat.le(1n, k), h2: MNat.le(k, l)) -> MNat.lt(Nat.sub(l, k), l):
  match k l:
    case 0n _:
      Empty.absurd(MNat.lt(Nat.sub(l, 0n), l), MNat.internal_false_ne_true(h1))
    case 1n+a 0n:
      Empty.absurd(MNat.lt(Nat.sub(0n, 1n+a), 0n), MNat.internal_false_ne_true(h2))
    case 1n+a 1n+b:
      MNat.sub_lt(b, a)

def progress(+xs: List<&2, U32>, +r: List<&2, U32>, +k: Nat, rr: {r == List.drop(&2, U32, xs, k) : List<&2, U32>}, h1: MNat.le(1n, k), h2: MNat.le(k, List.length(&2, U32, xs))) ->
  MNat.lt(List.length(&2, U32, r), List.length(&2, U32, xs)):
  %Equal.sym(List<&2, U32>, r, List.drop(&2, U32, xs, k), rr) : MNat.lt(List.length(&2, U32, _), List.length(&2, U32, xs))
  %MList.length_drop_sym(&2, U32, xs, k) : MNat.lt(_, List.length(&2, U32, xs))
  progress_nat(k, List.length(&2, U32, xs), h1, h2)

def got_progress.of(+masked: Bool, +max: U32, +xs: List<&2, U32>, -f: WS.Frame<List<&2, U32>>, +r: List<&2, U32>, t: got_facts(max, xs, f, r, WS.header(xs, masked))) ->
  MNat.lt(List.length(&2, U32, r), List.length(&2, U32, xs)):
  (lw, rr, lim, pl, l2) = t
  progress(xs, r, hwire(WS.header(xs, masked)), rr, MNat.le_trans(1n, 2n, hwire(WS.header(xs, masked)), {==}, l2), lw)

def Laws.got_progress(masked, max, xs, f, r, e):
  got_progress.of(masked, max, xs, f, r, got_inv(masked, max, xs, f, r, e))

def limit(+p: List<&2, U32>, +n: Nat, +mx: Nat, pl: {List.length(&2, U32, p) == n : Nat}, lim: MNat.le(n, mx)) -> MNat.le(List.length(&2, U32, p), mx):
  %Equal.sym(Nat, List.length(&2, U32, p), n, pl) : MNat.le(_, mx)
  lim

def got_limit.of(+masked: Bool, +max: U32, +xs: List<&2, U32>, +fin: Bool, +op: U32, +p: List<&2, U32>, +r: List<&2, U32>, t: got_facts(max, xs, WS.Frame{fin, op, p}, r, WS.header(xs, masked))) ->
  MNat.le(List.length(&2, U32, p), U32.to_nat(max)):
  (lw, rr, lim, pl, l2) = t
  limit(p, hlen(WS.header(xs, masked)), U32.to_nat(max), pl, lim)

def Laws.got_limit(masked, max, xs, fin, op, p, r, e):
  got_limit.of(masked, max, xs, fin, op, p, r, got_inv(masked, max, xs, WS.Frame{fin, op, p}, r, e))

def bound.d(n: Nat, +masked: Bool, +max: U32, +xs: List<&2, U32>, d: WS.Decode<List<&2, U32>, List<&2, U32>>, e: {WS.list.next(masked, max, xs) == d : WS.Decode<List<&2, U32>, List<&2, U32>>}) ->
  MNat.le(Laws.emitted(Laws.drain(n, masked, max, xs, d)), List.length(&2, U32, xs)):
  match n d:
    case 0n WS.Need{b}:
      MNat.zero_le(List.length(&2, U32, xs))
    case 0n WS.Got{f, r}:
      MNat.zero_le(List.length(&2, U32, xs))
    case 0n WS.Bad{code, why}:
      MNat.zero_le(List.length(&2, U32, xs))
    case 1n+p WS.Need{b}:
      MNat.zero_le(List.length(&2, U32, xs))
    case 1n+p WS.Got{f, +r}:
      +q = p
      MNat.le_trans(1n+Laws.emitted(Laws.drain(q, masked, max, r, WS.list.next(masked, max, r))), 1n+List.length(&2, U32, r), List.length(&2, U32, xs),
        bound.d(q, masked, max, r, WS.list.next(masked, max, r), {==}),
        MNat.succ_le_of_lt(List.length(&2, U32, r), List.length(&2, U32, xs), Laws.got_progress(masked, max, xs, f, r, e)))
    case 1n+p WS.Bad{code, why}:
      MNat.zero_le(List.length(&2, U32, xs))

def Laws.frames_bound(n, masked, max, xs):
  bound.d(n, masked, max, xs, WS.list.next(masked, max, xs), {==})


def is_need(h: WS.Header) -> Bool:
  match h:
    case WS.HNeed{}:
      True{}
    case _:
      False{}

def verdict_decided(err: Maybe<&1, U32 & String>, +fin: Bool, +op: U32, +m: Bool, +key: U32, +hs: U32, +len: U32) ->
  {is_need(WS.header.verdict(err, fin, op, m, key, hs, len)) == False{} : Bool}:
  match err:
    case Some{(code, why)}:
      {==}
    case None{}:
      {==}

def check_decided(+masked: Bool, +b0: U32, +m: Bool, +key: U32, +hs: U32, +hi: U32, +len: U32) ->
  {is_need(WS.header.check(masked, b0, m, key, hs, hi, len)) == False{} : Bool}:
  verdict_decided(WS.header.err(masked, b0, m, hi, len), U32.is_ne((b0 .&. 128 : U32), 0), (b0 .&. 15 : U32), m, key, hs, len)

def key_long(m: Bool, +k0: U32, +k1: U32, +k2: U32, +k3: U32, +r: List<&2, U32>, +masked: Bool, +b0: U32, +hs: U32, +hi: U32, +len: U32) ->
  {is_need(WS.header.key(m, Con{k0, Con{k1, Con{k2, Con{k3, r}}}}, masked, b0, hs, hi, len)) == False{} : Bool}:
  match m:
    case True{}:
      check_decided(masked, b0, True{}, (k0 .|. (k1 << 8n) .|. (k2 << 16n) .|. (k3 << 24n) : U32), (hs + 4 : U32), hi, len)
    case False{}:
      check_decided(masked, b0, False{}, 0, hs, hi, len)

def ext_long(short: Bool, mid: Bool, +masked: Bool, +b0: U32, +m: Bool, +l7: U32, +c3: U32, +c4: U32, +c5: U32, +c6: U32, +c7: U32, +c8: U32, +c9: U32, +c10: U32, +c11: U32, +c12: U32, +c13: U32, +c14: U32, +rest: List<&2, U32>) ->
  {is_need(WS.header.ext(short, mid, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Con{c8, Con{c9, Con{c10, Con{c11, Con{c12, Con{c13, Con{c14, rest}}}}}}}}}}}}, masked, b0, m, l7)) == False{} : Bool}:
  match short:
    case True{}:
      key_long(m, c3, c4, c5, c6, Con{c7, Con{c8, Con{c9, Con{c10, Con{c11, Con{c12, Con{c13, Con{c14, rest}}}}}}}}, masked, b0, 2, 0, l7)
    case False{}:
      match mid:
        case True{}:
          key_long(m, c5, c6, c7, c8, Con{c9, Con{c10, Con{c11, Con{c12, Con{c13, Con{c14, rest}}}}}}, masked, b0, 4, 0, ((c3 << 8n) .|. c4 : U32))
        case False{}:
          key_long(m, c11, c12, c13, c14, rest, masked, b0, 10, WS.be32(c3, c4, c5, c6), WS.be32(c7, c8, c9, c10))

def b1_long(m: Bool, +masked: Bool, +b0: U32, +b1: U32, +c3: U32, +c4: U32, +c5: U32, +c6: U32, +c7: U32, +c8: U32, +c9: U32, +c10: U32, +c11: U32, +c12: U32, +c13: U32, +c14: U32, +rest: List<&2, U32>) ->
  {is_need(WS.header.b1(m, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Con{c8, Con{c9, Con{c10, Con{c11, Con{c12, Con{c13, Con{c14, rest}}}}}}}}}}}}, masked, b0, b1)) == False{} : Bool}:
  match m:
    case True{}:
      ext_long(U32.is_lt((b1 - 128 : U32), 126), U32.is_eq((b1 - 128 : U32), 126), masked, b0, True{}, (b1 - 128 : U32), c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, rest)
    case False{}:
      ext_long(U32.is_lt(b1, 126), U32.is_eq(b1, 126), masked, b0, False{}, b1, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, rest)

# A header always decides by its 14th octet.
def header_long(p: List<&2, U32>, +masked: Bool, h: MNat.le(14n, List.length(&2, U32, p))) ->
  {is_need(WS.header(p, masked)) == False{} : Bool}:
  match p:
    case Nil{}:
      Empty.absurd({is_need(WS.header(Nil{}, masked)) == False{} : Bool}, MNat.internal_false_ne_true(h))
    case Con{c1, Nil{}}:
      Empty.absurd({is_need(WS.header(Con{c1, Nil{}}, masked)) == False{} : Bool}, MNat.internal_false_ne_true(h))
    case Con{c1, Con{c2, Nil{}}}:
      Empty.absurd({is_need(WS.header(Con{c1, Con{c2, Nil{}}}, masked)) == False{} : Bool}, MNat.internal_false_ne_true(h))
    case Con{c1, Con{c2, Con{c3, Nil{}}}}:
      Empty.absurd({is_need(WS.header(Con{c1, Con{c2, Con{c3, Nil{}}}}, masked)) == False{} : Bool}, MNat.internal_false_ne_true(h))
    case Con{c1, Con{c2, Con{c3, Con{c4, Nil{}}}}}:
      Empty.absurd({is_need(WS.header(Con{c1, Con{c2, Con{c3, Con{c4, Nil{}}}}}, masked)) == False{} : Bool}, MNat.internal_false_ne_true(h))
    case Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Nil{}}}}}}:
      Empty.absurd({is_need(WS.header(Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Nil{}}}}}}, masked)) == False{} : Bool}, MNat.internal_false_ne_true(h))
    case Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Nil{}}}}}}}:
      Empty.absurd({is_need(WS.header(Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Nil{}}}}}}}, masked)) == False{} : Bool}, MNat.internal_false_ne_true(h))
    case Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Nil{}}}}}}}}:
      Empty.absurd({is_need(WS.header(Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Nil{}}}}}}}}, masked)) == False{} : Bool}, MNat.internal_false_ne_true(h))
    case Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Con{c8, Nil{}}}}}}}}}:
      Empty.absurd({is_need(WS.header(Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Con{c8, Nil{}}}}}}}}}, masked)) == False{} : Bool}, MNat.internal_false_ne_true(h))
    case Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Con{c8, Con{c9, Nil{}}}}}}}}}}:
      Empty.absurd({is_need(WS.header(Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Con{c8, Con{c9, Nil{}}}}}}}}}}, masked)) == False{} : Bool}, MNat.internal_false_ne_true(h))
    case Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Con{c8, Con{c9, Con{c10, Nil{}}}}}}}}}}}:
      Empty.absurd({is_need(WS.header(Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Con{c8, Con{c9, Con{c10, Nil{}}}}}}}}}}}, masked)) == False{} : Bool}, MNat.internal_false_ne_true(h))
    case Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Con{c8, Con{c9, Con{c10, Con{c11, Nil{}}}}}}}}}}}}:
      Empty.absurd({is_need(WS.header(Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Con{c8, Con{c9, Con{c10, Con{c11, Nil{}}}}}}}}}}}}, masked)) == False{} : Bool}, MNat.internal_false_ne_true(h))
    case Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Con{c8, Con{c9, Con{c10, Con{c11, Con{c12, Nil{}}}}}}}}}}}}}:
      Empty.absurd({is_need(WS.header(Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Con{c8, Con{c9, Con{c10, Con{c11, Con{c12, Nil{}}}}}}}}}}}}}, masked)) == False{} : Bool}, MNat.internal_false_ne_true(h))
    case Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Con{c8, Con{c9, Con{c10, Con{c11, Con{c12, Con{c13, Nil{}}}}}}}}}}}}}}:
      Empty.absurd({is_need(WS.header(Con{c1, Con{c2, Con{c3, Con{c4, Con{c5, Con{c6, Con{c7, Con{c8, Con{c9, Con{c10, Con{c11, Con{c12, Con{c13, Nil{}}}}}}}}}}}}}}, masked)) == False{} : Bool}, MNat.internal_false_ne_true(h))
    case Con{+c1, Con{+c2, Con{+c3, Con{+c4, Con{+c5, Con{+c6, Con{+c7, Con{+c8, Con{+c9, Con{+c10, Con{+c11, Con{+c12, Con{+c13, Con{+c14, rest}}}}}}}}}}}}}}:
      b1_long(U32.is_le(128, c2), masked, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, rest)

def need_clash(+xs: List<&2, U32>, +masked: Bool, eh: {WS.header(xs, masked) == WS.HNeed{} : WS.Header},
  hl: {is_need(WS.header(xs, masked)) == False{} : Bool}) -> {False{} == True{} : Bool}:
  %eh : {False{} == is_need(_) : Bool}
  Equal.sym(Bool, is_need(WS.header(xs, masked)), False{}, hl)

def need_short.c(+masked: Bool, +max: U32, +xs: List<&2, U32>, c: Bool, +ec: {Nat.is_le(14n, List.length(&2, U32, xs)) == c : Bool},
  eh: {WS.header(xs, masked) == WS.HNeed{} : WS.Header}) -> MNat.lt(List.length(&2, U32, xs), Nat.add(14n, U32.to_nat(max))):
  match c:
    case True{}:
      +hl = header_long(xs, masked, ec)
      Empty.absurd(MNat.lt(List.length(&2, U32, xs), Nat.add(14n, U32.to_nat(max))), MNat.internal_false_ne_true(need_clash(xs, masked, eh, hl)))
    case False{}:
      MNat.lt_of_lt_of_le(List.length(&2, U32, xs), 14n, Nat.add(14n, U32.to_nat(max)), MNat.lt_of_not_le(14n, List.length(&2, U32, xs), ec), MNat.le_add_right(14n, U32.to_nat(max)))

def need_inv.f(+max: U32, +xs: List<&2, U32>, +b: List<&2, U32>, +fin: Bool, +op: U32, +m: Bool, +key: U32, +hs: U32, +len: U32, c: Bool,
  +ec: {Nat.is_le(Nat.add(U32.to_nat(hs), U32.to_nat(len)), List.length(&2, U32, xs)) == c : Bool}, lim: MNat.le(U32.to_nat(len), U32.to_nat(max)), hi: MNat.le(U32.to_nat(hs), 14n),
  e: {WS.next.fits(~List<&2, U32>, ~List<&2, U32>, ~WS.list.cut, ~WS.list.unmask, fin, op, m, key, hs, len, (xs, c)) == WS.Need{b} : WS.Decode<List<&2, U32>, List<&2, U32>>}) -> MNat.lt(List.length(&2, U32, xs), Nat.add(14n, U32.to_nat(max))):
  match c:
    case True{}:
      Empty.absurd(MNat.lt(List.length(&2, U32, xs), Nat.add(14n, U32.to_nat(max))), got_not_need(
        WS.Frame{fin, op, WS.unmask.when(~List<&2, U32>, ~WS.list.unmask, m, key, List.take(&2, U32, List.drop(&2, U32, xs, U32.to_nat(hs)), U32.to_nat(len)))},
        List.drop(&2, U32, xs, Nat.add(U32.to_nat(hs), U32.to_nat(len))), b, e))
    case False{}:
      MNat.lt_of_lt_of_le(List.length(&2, U32, xs), Nat.add(U32.to_nat(hs), U32.to_nat(len)), Nat.add(14n, U32.to_nat(max)), MNat.lt_of_not_le(Nat.add(U32.to_nat(hs), U32.to_nat(len)), List.length(&2, U32, xs), ec), MNat.add_le_add(U32.to_nat(hs), U32.to_nat(len), 14n, U32.to_nat(max), hi, lim))

def need_inv.s(+max: U32, +xs: List<&2, U32>, +b: List<&2, U32>, +fin: Bool, +op: U32, +m: Bool, +key: U32, +hs: U32, +len: U32,
  c: Bool, +ec: {U32.is_lt(max, len) == c : Bool}, hi: MNat.le(U32.to_nat(hs), 14n),
  e: {WS.next.size(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, c, fin, op, m, key, hs, len, xs) == WS.Need{b} : WS.Decode<List<&2, U32>, List<&2, U32>>}) -> MNat.lt(List.length(&2, U32, xs), Nat.add(14n, U32.to_nat(max))):
  match c:
    case True{}:
      Empty.absurd(MNat.lt(List.length(&2, U32, xs), Nat.add(14n, U32.to_nat(max))), bad_not_need(1009, "frame over the size limit", b, e))
    case False{}:
      need_inv.f(max, xs, b, fin, op, m, key, hs, len, Nat.is_le(Nat.add(U32.to_nat(hs), U32.to_nat(len)), List.length(&2, U32, xs)), {==}, u32_not_lt(max, len, ec), hi, e)

def need_inv.h(+masked: Bool, +max: U32, +xs: List<&2, U32>, +b: List<&2, U32>, h: WS.Header, eh: {WS.header(xs, masked) == h : WS.Header}, hh: hsize(h),
  e: {WS.next.head(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, max, h, xs) == WS.Need{b} : WS.Decode<List<&2, U32>, List<&2, U32>>}) -> MNat.lt(List.length(&2, U32, xs), Nat.add(14n, U32.to_nat(max))):
  match h:
    case WS.HNeed{}:
      need_short.c(masked, max, xs, Nat.is_le(14n, List.length(&2, U32, xs)), {==}, eh)
    case WS.HBad{+code, +why}:
      Empty.absurd(MNat.lt(List.length(&2, U32, xs), Nat.add(14n, U32.to_nat(max))), bad_not_need(code, why, b, e))
    case WS.HOk{+fin, +op, +m, +key, +hs, +len}:
      (lo, hi) = hh
      need_inv.s(max, xs, b, fin, op, m, key, hs, len, U32.is_lt(max, len), {==}, hi, e)

def Laws.need_bound(masked, max, xs, b, e):
  need_inv.h(masked, max, xs, b, WS.header(xs, masked), {==}, header_hs(xs, masked), e)


def fits_le(+n: U32, +hs: U32, +len: U32, h: {Bytes.fits(n, hs, len) == True{} : Bool}) -> MNat.le(Nat.add(U32.to_nat(hs), U32.to_nat(len)), U32.to_nat(n)):
  Equal.trans(Bool, Nat.is_le(Nat.add(U32.to_nat(hs), U32.to_nat(len)), U32.to_nat(n)), Bytes.fits(n, hs, len), True{},
    Equal.sym(Bool, Bytes.fits(n, hs, len), Nat.is_le(Nat.add(U32.to_nat(hs), U32.to_nat(len)), U32.to_nat(n)), Lemmas.u32_fits_nat(n, hs, len)), h)

def add_le_of_le_sub(+a: Nat, +b: Nat, +c: Nat, h1: MNat.le(b, c), h2: MNat.le(a, Nat.sub(c, b))) -> MNat.le(Nat.add(b, a), c):
  match b c:
    case 0n 0n:
      h2
    case 0n 1n+q:
      h2
    case 1n+p 0n:
      Empty.absurd(MNat.le(Nat.add(1n+p, a), 0n), MNat.internal_false_ne_true(h1))
    case 1n+p 1n+q:
      add_le_of_le_sub(a, p, q, h1, h2)

def cut.left(+pos: U32, +end: U32, +hs: U32, +len: U32, +le: MNat.le(U32.to_nat(pos), U32.to_nat(end)), +h: {Bytes.fits((end - pos : U32), hs, len) == True{} : Bool}) ->
  MNat.le(Nat.add(U32.to_nat(hs), U32.to_nat(len)), Nat.sub(U32.to_nat(end), U32.to_nat(pos))):
  %Lemmas.u32_sub_nat(end, pos, le) : MNat.le(Nat.add(U32.to_nat(hs), U32.to_nat(len)), _)
  fits_le((end - pos : U32), hs, len, h)

def cut.within(+pos: U32, +end: U32, +hs: U32, +len: U32, +le: MNat.le(U32.to_nat(pos), U32.to_nat(end)), +h: {Bytes.fits((end - pos : U32), hs, len) == True{} : Bool}) ->
  MNat.le(Nat.add(U32.to_nat(pos), Nat.add(U32.to_nat(hs), U32.to_nat(len))), U32.to_nat(end)):
  add_le_of_le_sub(Nat.add(U32.to_nat(hs), U32.to_nat(len)), U32.to_nat(pos), U32.to_nat(end), le, cut.left(pos, end, hs, len, le, h))

def cut.lt(+end: U32, +x: Nat, hx: MNat.le(x, U32.to_nat(end))) -> MNat.lt(x, Lemmas.pow2(32n)):
  MNat.lt_of_le_of_lt(x, U32.to_nat(end), Lemmas.pow2(32n), hx, Lemmas.u32_to_nat_lt(end))

def cut.ph(+pos: U32, +end: U32, +hs: U32, +len: U32, +le: MNat.le(U32.to_nat(pos), U32.to_nat(end)), +h: {Bytes.fits((end - pos : U32), hs, len) == True{} : Bool}) ->
  {U32.to_nat((pos + hs : U32)) == Nat.add(U32.to_nat(pos), U32.to_nat(hs)) : Nat}:
  Lemmas.u32_add_nat(pos, hs, cut.lt(end, Nat.add(U32.to_nat(pos), U32.to_nat(hs)), MNat.le_trans(Nat.add(U32.to_nat(pos), U32.to_nat(hs)), Nat.add(U32.to_nat(pos), Nat.add(U32.to_nat(hs), U32.to_nat(len))), U32.to_nat(end),
    MNat.add_le_add_left(U32.to_nat(hs), Nat.add(U32.to_nat(hs), U32.to_nat(len)), U32.to_nat(pos), MNat.le_add_right(U32.to_nat(hs), U32.to_nat(len))), cut.within(pos, end, hs, len, le, h))))

def cut.sum(+pos: U32, +end: U32, +hs: U32, +len: U32, +le: MNat.le(U32.to_nat(pos), U32.to_nat(end)), +h: {Bytes.fits((end - pos : U32), hs, len) == True{} : Bool}) ->
  {Nat.add(U32.to_nat((pos + hs : U32)), U32.to_nat(len)) == Nat.add(U32.to_nat(pos), Nat.add(U32.to_nat(hs), U32.to_nat(len))) : Nat}:
  %Equal.sym(Nat, U32.to_nat((pos + hs : U32)), Nat.add(U32.to_nat(pos), U32.to_nat(hs)), cut.ph(pos, end, hs, len, le, h)) : {Nat.add(_, U32.to_nat(len)) == Nat.add(U32.to_nat(pos), Nat.add(U32.to_nat(hs), U32.to_nat(len))) : Nat}
  MNat.add_assoc(U32.to_nat(pos), U32.to_nat(hs), U32.to_nat(len))

def cut.lt2(+pos: U32, +end: U32, +hs: U32, +len: U32, +le: MNat.le(U32.to_nat(pos), U32.to_nat(end)), +h: {Bytes.fits((end - pos : U32), hs, len) == True{} : Bool}) ->
  MNat.lt(Nat.add(U32.to_nat((pos + hs : U32)), U32.to_nat(len)), Lemmas.pow2(32n)):
  %Equal.sym(Nat, Nat.add(U32.to_nat((pos + hs : U32)), U32.to_nat(len)), Nat.add(U32.to_nat(pos), Nat.add(U32.to_nat(hs), U32.to_nat(len))), cut.sum(pos, end, hs, len, le, h)) : MNat.lt(_, Lemmas.pow2(32n))
  cut.lt(end, Nat.add(U32.to_nat(pos), Nat.add(U32.to_nat(hs), U32.to_nat(len))), cut.within(pos, end, hs, len, le, h))

def Laws.cut_exact(pos, end, hs, len, le, h):
  Equal.trans(Nat, U32.to_nat(((pos + hs : U32) + len : U32)), Nat.add(U32.to_nat((pos + hs : U32)), U32.to_nat(len)), Nat.add(U32.to_nat(pos), Nat.add(U32.to_nat(hs), U32.to_nat(len))),
    Lemmas.u32_add_nat((pos + hs : U32), len, cut.lt2(pos, end, hs, len, le, h)), cut.sum(pos, end, hs, len, le, h))

def Laws.cut_within(pos, end, hs, len, le, h):
  %Equal.sym(Nat, U32.to_nat(((pos + hs : U32) + len : U32)), Nat.add(U32.to_nat(pos), Nat.add(U32.to_nat(hs), U32.to_nat(len))), Laws.cut_exact(pos, end, hs, len, le, h)) : MNat.le(_, U32.to_nat(end))
  cut.within(pos, end, hs, len, le, h)

def lt32(+n: Nat, h: MNat.le(n, 125n)) -> MNat.lt(n, Lemmas.pow2(32n)):
  MNat.lt_of_le_of_lt(n, U32.to_nat(125), Lemmas.pow2(32n), h, Lemmas.u32_to_nat_lt(125))

def b1_nat(+n: Nat, h: MNat.le(n, 125n)) -> {U32.to_nat(U32.from_nat(n)) == n : Nat}:
  Lemmas.u32_to_from_nat(n, lt32(n, h))

def b1_m(+n: Nat, +h: MNat.le(n, 125n)) -> {U32.is_le(128, U32.from_nat(n)) == False{} : Bool}:
  %Equal.sym(Bool, U32.is_le(128, U32.from_nat(n)), Nat.is_le(U32.to_nat(128), U32.to_nat(U32.from_nat(n))), Lemmas.u32_is_le_nat(128, U32.from_nat(n))) : {_ == False{} : Bool}
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(n)), n, b1_nat(n, h)) : {Nat.is_le(U32.to_nat(128), _) == False{} : Bool}
  MNat.not_le_of_lt(n, U32.to_nat(128), MNat.lt_of_le_of_lt(n, 125n, U32.to_nat(128), h, {==}))

def b1_s(+n: Nat, +h: MNat.le(n, 125n)) -> {U32.is_lt(U32.from_nat(n), 126) == True{} : Bool}:
  %Equal.sym(Bool, U32.is_lt(U32.from_nat(n), 126), Nat.is_lt(U32.to_nat(U32.from_nat(n)), U32.to_nat(126)), Lemmas.u32_is_lt_nat(U32.from_nat(n), 126)) : {_ == True{} : Bool}
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(n)), n, b1_nat(n, h)) : {Nat.is_lt(_, U32.to_nat(126)) == True{} : Bool}
  MNat.lt_of_le_of_lt(n, 125n, U32.to_nat(126), h, {==})

def le_not_gt(c: Cmp, h: {Cmp.is_le(c) == True{} : Bool}) -> {Cmp.is_gt(c) == False{} : Bool}:
  match c:
    case LT{}:
      {==}
    case EQ{}:
      {==}
    case GT{}:
      Empty.absurd({Cmp.is_gt(GT{}) == False{} : Bool}, MNat.internal_false_ne_true(h))

def b1_g(+n: Nat, +h: MNat.le(n, 125n)) -> {U32.is_gt(U32.from_nat(n), 125) == False{} : Bool}:
  %Equal.sym(Cmp, U32.cmp(U32.from_nat(n), 125), Nat.cmp(U32.to_nat(U32.from_nat(n)), U32.to_nat(125)), Lemmas.u32_cmp_nat(U32.from_nat(n), 125)) : {Cmp.is_gt(_) == False{} : Bool}
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(n)), n, b1_nat(n, h)) : {Cmp.is_gt(Nat.cmp(_, U32.to_nat(125))) == False{} : Bool}
  le_not_gt(Nat.cmp(n, U32.to_nat(125)), h)

def b1_z(+max: U32, +n: Nat, +h: MNat.le(n, 125n), fit: MNat.le(n, U32.to_nat(max))) -> {U32.is_lt(max, U32.from_nat(n)) == False{} : Bool}:
  %Equal.sym(Bool, U32.is_lt(max, U32.from_nat(n)), Nat.is_lt(U32.to_nat(max), U32.to_nat(U32.from_nat(n))), Lemmas.u32_is_lt_nat(max, U32.from_nat(n))) : {_ == False{} : Bool}
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(n)), n, b1_nat(n, h)) : {Nat.is_lt(U32.to_nat(max), _) == False{} : Bool}
  MNat.not_lt_of_le(n, U32.to_nat(max), fit)

# The header of an unmasked frame with a 7-bit length, decoded on a client.
def rt_check(+fin: Bool, +o: Laws.Op, +b1: U32, ok: {Laws.op.ok(fin, o) == True{} : Bool}, hg: {U32.is_gt(b1, 125) == False{} : Bool}) ->
  {WS.header.check(False{}, (Bool.pick(U32, fin, 128, 0) .|. Laws.op.code(o) : U32), False{}, 0, 2, 0, b1) == WS.HOk{fin, Laws.op.code(o), False{}, 0, 2, b1} : WS.Header}:
  match fin o:
    case True{} Laws.OCont{}:
      {==}
    case True{} Laws.OText{}:
      {==}
    case True{} Laws.OBin{}:
      {==}
    case True{} Laws.OClose{}:
      %Equal.sym(Bool, U32.is_gt(b1, 125), False{}, hg) :
        {WS.header.verdict(WS.first(WS.rules.big(True{}, 0, 8, _), WS.first(WS.reject(False{}, 1002, "mask bit does not match the peer's role"), WS.reject(False{}, 1009, "frame over the size limit"))), True{}, 8, False{}, 0, 2, b1) == WS.HOk{True{}, 8, False{}, 0, 2, b1} : WS.Header}
      {==}
    case True{} Laws.OPing{}:
      %Equal.sym(Bool, U32.is_gt(b1, 125), False{}, hg) :
        {WS.header.verdict(WS.first(WS.rules.big(True{}, 0, 9, _), WS.first(WS.reject(False{}, 1002, "mask bit does not match the peer's role"), WS.reject(False{}, 1009, "frame over the size limit"))), True{}, 9, False{}, 0, 2, b1) == WS.HOk{True{}, 9, False{}, 0, 2, b1} : WS.Header}
      {==}
    case True{} Laws.OPong{}:
      %Equal.sym(Bool, U32.is_gt(b1, 125), False{}, hg) :
        {WS.header.verdict(WS.first(WS.rules.big(True{}, 0, 10, _), WS.first(WS.reject(False{}, 1002, "mask bit does not match the peer's role"), WS.reject(False{}, 1009, "frame over the size limit"))), True{}, 10, False{}, 0, 2, b1) == WS.HOk{True{}, 10, False{}, 0, 2, b1} : WS.Header}
      {==}
    case False{} Laws.OCont{}:
      {==}
    case False{} Laws.OText{}:
      {==}
    case False{} Laws.OBin{}:
      {==}
    case False{} Laws.OClose{}:
      Empty.absurd({WS.header.check(False{}, (Bool.pick(U32, fin, 128, 0) .|. Laws.op.code(o) : U32), False{}, 0, 2, 0, b1) == WS.HOk{fin, Laws.op.code(o), False{}, 0, 2, b1} : WS.Header}, MNat.internal_false_ne_true(ok))
    case False{} Laws.OPing{}:
      Empty.absurd({WS.header.check(False{}, (Bool.pick(U32, fin, 128, 0) .|. Laws.op.code(o) : U32), False{}, 0, 2, 0, b1) == WS.HOk{fin, Laws.op.code(o), False{}, 0, 2, b1} : WS.Header}, MNat.internal_false_ne_true(ok))
    case False{} Laws.OPong{}:
      Empty.absurd({WS.header.check(False{}, (Bool.pick(U32, fin, 128, 0) .|. Laws.op.code(o) : U32), False{}, 0, 2, 0, b1) == WS.HOk{fin, Laws.op.code(o), False{}, 0, 2, b1} : WS.Header}, MNat.internal_false_ne_true(ok))

def rt_head(+fin: Bool, +o: Laws.Op, +b1: U32, +t: List<&2, U32>, ok: {Laws.op.ok(fin, o) == True{} : Bool},
  hm: {U32.is_le(128, b1) == False{} : Bool}, hs: {U32.is_lt(b1, 126) == True{} : Bool}, hg: {U32.is_gt(b1, 125) == False{} : Bool}) ->
  {WS.header(Con{(Bool.pick(U32, fin, 128, 0) .|. Laws.op.code(o) : U32), Con{b1, t}}, False{}) == WS.HOk{fin, Laws.op.code(o), False{}, 0, 2, b1} : WS.Header}:
  %Equal.sym(Bool, U32.is_le(128, b1), False{}, hm) : {WS.header.b1(_, t, False{}, (Bool.pick(U32, fin, 128, 0) .|. Laws.op.code(o) : U32), b1) == WS.HOk{fin, Laws.op.code(o), False{}, 0, 2, b1} : WS.Header}
  %Equal.sym(Bool, U32.is_lt(b1, 126), True{}, hs) : {WS.header.ext(_, U32.is_eq(b1, 126), t, False{}, (Bool.pick(U32, fin, 128, 0) .|. Laws.op.code(o) : U32), False{}, b1) == WS.HOk{fin, Laws.op.code(o), False{}, 0, 2, b1} : WS.Header}
  rt_check(fin, o, b1, ok, hg)

def rt_fits(+p: List<&2, U32>, +ys: List<&2, U32>, +fin: Bool, +o: Laws.Op, +short: MNat.le(List.length(&2, U32, p), 125n)) ->
  {Nat.is_le(Nat.add(U32.to_nat(2), U32.to_nat(U32.from_nat(List.length(&2, U32, p)))), List.length(&2, U32, cat(Laws.wire(fin, o, p), ys))) == True{} : Bool}:
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(List.length(&2, U32, p))), List.length(&2, U32, p), b1_nat(List.length(&2, U32, p), short)) : MNat.le(_, List.length(&2, U32, cat(p, ys)))
  le_cat(List.length(&2, U32, p), p, ys, MNat.le_refl(List.length(&2, U32, p)))

def Laws.roundtrip(fin, o, max, p, ys, ok, short, fit):
  %Equal.sym(WS.Header, WS.header(cat(Laws.wire(fin, o, p), ys), False{}), WS.HOk{fin, Laws.op.code(o), False{}, 0, 2, U32.from_nat(List.length(&2, U32, p))}, rt_head(fin, o, U32.from_nat(List.length(&2, U32, p)), cat(p, ys), ok, b1_m(List.length(&2, U32, p), short), b1_s(List.length(&2, U32, p), short), b1_g(List.length(&2, U32, p), short))) :
    {WS.next.head(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, max, _, cat(Laws.wire(fin, o, p), ys)) == WS.Got{WS.Frame{fin, Laws.op.code(o), p}, ys} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  %Equal.sym(Bool, U32.is_lt(max, U32.from_nat(List.length(&2, U32, p))), False{}, b1_z(max, List.length(&2, U32, p), short, fit)) :
    {WS.next.size(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, _, fin, Laws.op.code(o), False{}, 0, 2, U32.from_nat(List.length(&2, U32, p)), cat(Laws.wire(fin, o, p), ys)) == WS.Got{WS.Frame{fin, Laws.op.code(o), p}, ys} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  %Equal.sym(Bool, Nat.is_le(Nat.add(U32.to_nat(2), U32.to_nat(U32.from_nat(List.length(&2, U32, p)))), List.length(&2, U32, cat(Laws.wire(fin, o, p), ys))), True{}, rt_fits(p, ys, fin, o, short)) :
    {WS.next.fits(~List<&2, U32>, ~List<&2, U32>, ~WS.list.cut, ~WS.list.unmask, fin, Laws.op.code(o), False{}, 0, 2, U32.from_nat(List.length(&2, U32, p)), (cat(Laws.wire(fin, o, p), ys), _)) == WS.Got{WS.Frame{fin, Laws.op.code(o), p}, ys} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(List.length(&2, U32, p))), List.length(&2, U32, p), b1_nat(List.length(&2, U32, p), short)) :
    {WS.Got{WS.Frame{fin, Laws.op.code(o), List.take(&2, U32, List.drop(&2, U32, cat(p, ys), 0n), _)}, List.drop(&2, U32, cat(p, ys), _)} == WS.Got{WS.Frame{fin, Laws.op.code(o), p}, ys} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  %MList.drop_zero_sym(&2, U32, cat(p, ys)) :
    {WS.Got{WS.Frame{fin, Laws.op.code(o), List.take(&2, U32, _, List.length(&2, U32, p))}, List.drop(&2, U32, cat(p, ys), List.length(&2, U32, p))} == WS.Got{WS.Frame{fin, Laws.op.code(o), p}, ys} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  %MList.take_append_of_le_length_sym(&2, U32, p, ys, List.length(&2, U32, p), MNat.le_refl(List.length(&2, U32, p))) :
    {WS.Got{WS.Frame{fin, Laws.op.code(o), _}, List.drop(&2, U32, cat(p, ys), List.length(&2, U32, p))} == WS.Got{WS.Frame{fin, Laws.op.code(o), p}, ys} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  %MList.take_length_sym(U32, p) :
    {WS.Got{WS.Frame{fin, Laws.op.code(o), _}, List.drop(&2, U32, cat(p, ys), List.length(&2, U32, p))} == WS.Got{WS.Frame{fin, Laws.op.code(o), p}, ys} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  %MList.drop_append_of_le_length_sym(&2, U32, p, ys, List.length(&2, U32, p), MNat.le_refl(List.length(&2, U32, p))) :
    {WS.Got{WS.Frame{fin, Laws.op.code(o), p}, _} == WS.Got{WS.Frame{fin, Laws.op.code(o), p}, ys} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  %MList.drop_length_sym(U32, p) :
    {WS.Got{WS.Frame{fin, Laws.op.code(o), p}, cat(_, ys)} == WS.Got{WS.Frame{fin, Laws.op.code(o), p}, ys} : WS.Decode<List<&2, U32>, List<&2, U32>>}
  {==}

def pn_fits(+p: List<&2, U32>, +j: Nat, +short: MNat.le(List.length(&2, U32, p), 125n), less: MNat.lt(j, List.length(&2, U32, p))) ->
  {Nat.is_le(Nat.add(U32.to_nat(2), U32.to_nat(U32.from_nat(List.length(&2, U32, p)))), 1n+1n+List.length(&2, U32, List.take(&2, U32, p, j))) == False{} : Bool}:
  %Equal.sym(Nat, U32.to_nat(U32.from_nat(List.length(&2, U32, p))), List.length(&2, U32, p), b1_nat(List.length(&2, U32, p), short)) : {Nat.is_le(_, List.length(&2, U32, List.take(&2, U32, p, j))) == False{} : Bool}
  MNat.not_le_of_lt(List.length(&2, U32, List.take(&2, U32, p, j)), List.length(&2, U32, p),
    MNat.lt_of_le_of_lt(List.length(&2, U32, List.take(&2, U32, p, j)), j, List.length(&2, U32, p), MList.length_take_le(&2, U32, p, j), less))

def Laws.prefix_need(fin, o, max, p, k, ok, short, fit, less):
  match k:
    case 0n:
      {==}
    case 1n+k1:
      match k1:
        case 0n:
          {==}
        case 1n+j:
          %Equal.sym(WS.Header, WS.header(List.take(&2, U32, Laws.wire(fin, o, p), 1n+1n+j), False{}), WS.HOk{fin, Laws.op.code(o), False{}, 0, 2, U32.from_nat(List.length(&2, U32, p))}, rt_head(fin, o, U32.from_nat(List.length(&2, U32, p)), List.take(&2, U32, p, j), ok, b1_m(List.length(&2, U32, p), short), b1_s(List.length(&2, U32, p), short), b1_g(List.length(&2, U32, p), short))) :
            {WS.next.head(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, max, _, List.take(&2, U32, Laws.wire(fin, o, p), 1n+1n+j)) == WS.Need{List.take(&2, U32, Laws.wire(fin, o, p), 1n+1n+j)} : WS.Decode<List<&2, U32>, List<&2, U32>>}
          %Equal.sym(Bool, U32.is_lt(max, U32.from_nat(List.length(&2, U32, p))), False{}, b1_z(max, List.length(&2, U32, p), short, fit)) :
            {WS.next.size(~List<&2, U32>, ~List<&2, U32>, ~WS.list.fits, ~WS.list.cut, ~WS.list.unmask, _, fin, Laws.op.code(o), False{}, 0, 2, U32.from_nat(List.length(&2, U32, p)), List.take(&2, U32, Laws.wire(fin, o, p), 1n+1n+j)) == WS.Need{List.take(&2, U32, Laws.wire(fin, o, p), 1n+1n+j)} : WS.Decode<List<&2, U32>, List<&2, U32>>}
          %Equal.sym(Bool, Nat.is_le(Nat.add(U32.to_nat(2), U32.to_nat(U32.from_nat(List.length(&2, U32, p)))), 1n+1n+List.length(&2, U32, List.take(&2, U32, p, j))), False{}, pn_fits(p, j, short, less)) :
            {WS.next.fits(~List<&2, U32>, ~List<&2, U32>, ~WS.list.cut, ~WS.list.unmask, fin, Laws.op.code(o), False{}, 0, 2, U32.from_nat(List.length(&2, U32, p)), (List.take(&2, U32, Laws.wire(fin, o, p), 1n+1n+j), _)) == WS.Need{List.take(&2, U32, Laws.wire(fin, o, p), 1n+1n+j)} : WS.Decode<List<&2, U32>, List<&2, U32>>}
          {==}

