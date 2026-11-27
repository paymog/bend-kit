import Base
import ./LAWS.bend as Laws
import ./sse.bend as Sse
import ./sse-scan-proof.bend as Scan
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes

def Laws.sse_whole():
  {==}

def Laws.sse_ones():
  {==}

def Laws.sse_twos():
  {==}

def Laws.sse_threes():
  {==}

def Laws.sse_crlf_cut():
  {==}

def Laws.sse_cr_blank():
  {==}

def Laws.sse_retry():
  {==}

def Laws.sse_retry_bad():
  {==}

def Laws.sse_names():
  {==}

def Laws.sse_id():
  {==}

def Laws.sse_feed_compose(xs, ys, r):
  match xs:
    case Nil{}:
      {==}
    case Con{h, t}:
      (rd, acc) = r
      Laws.sse_feed_compose(t, ys, Laws.feed_drain(Sse.feed(rd, Laws.b(h)), acc))

def Laws.sse_octet_compose(a, b, r):
  match a:
    case SNil{}:
      {==}
    case SCon{c, t}:
      (rd, acc) = r
      Laws.sse_octet_compose(t, b, Laws.feed_drain(Sse.feed(rd, Laws.b(SCon{c, SNil{}})), acc))

def Laws.sse_crlf_state(st):
  {==}

def Laws.sse_id_persists(empty, name, data, id, retry):
  match empty:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.sse_message_id(name, data, id, retry):
  {==}

def loop_want(g: Nat, a: Array<U32>, pos: U32, cr: Bool, st: Sse.St, len: U32) ->
  {Sse.loop(g, Sse.LWant{a, pos, cr, st}, len) == Sse.stop(Sse.LWant{a, pos, cr, st}, len) : Sse.Reader & Sse.Next}:
  match g:
    case 0n:
      {==}
    case 1n+p:
      {==}

def loop_got(g: Nat, a: Array<U32>, pos: U32, cr: Bool, st: Sse.St, e: Sse.Message, len: U32) ->
  {Sse.loop(g, Sse.LGot{a, pos, cr, st, e}, len) == Sse.stop(Sse.LGot{a, pos, cr, st, e}, len) : Sse.Reader & Sse.Next}:
  match g:
    case 0n:
      {==}
    case 1n+p:
      {==}

def Laws.sse_loop_compose(f, g, l, len):
  match f:
    case 0n:
      {==}
    case 1n+p:
      match l:
        case Sse.LMore{a, +pos, cr, st}:
          Laws.sse_loop_compose(p, g, Sse.line(a, len, pos, pos, cr, st), len)
        case Sse.LWant{a, pos, cr, st}:
          Equal.sym(Sse.Reader & Sse.Next, Sse.loop(g, Sse.LWant{a, pos, cr, st}, len), Sse.stop(Sse.LWant{a, pos, cr, st}, len), loop_want(g, a, pos, cr, st, len))
        case Sse.LGot{a, pos, cr, st, e}:
          Equal.sym(Sse.Reader & Sse.Next, Sse.loop(g, Sse.LGot{a, pos, cr, st, e}, len), Sse.stop(Sse.LGot{a, pos, cr, st, e}, len), loop_got(g, a, pos, cr, st, e, len))

def Laws.sse_crlf_skip(len, pos, a, b, more, first):
  %Equal.sym(Bool, U32.is_lt(pos, len), True{}, more) : {Sse.skip.at(_, a, pos) == (b, (pos + 1 : U32), False{}) : Array<U32> & U32 & Bool}
  %Equal.sym(Array<U32> & U32, Bytes.peek(a, pos), (b, 10), first) : {Sse.skip.byte(pos, _) == (b, (pos + 1 : U32), False{}) : Array<U32> & U32 & Bool}
  {==}

def Laws.sse_large_chunk():
  {==}

def Laws.sse_scan_extend(f, g, r, i, clean):
  Scan.extend(f, g, r, i, clean)

def Laws.reply_anthropic():
  {==}

def Laws.reply_openai():
  {==}

def Laws.reply_utf8():
  {==}

def Laws.reply_bad():
  {==}

def Laws.ev_anthropic_text():
  {==}

def Laws.ev_anthropic_tool():
  {==}

def Laws.ev_anthropic_ping():
  {==}

def Laws.ev_anthropic_stop():
  {==}

def Laws.ev_anthropic_error():
  {==}

def Laws.ev_openai_text():
  {==}

def Laws.ev_openai_role():
  {==}

def Laws.ev_openai_done():
  {==}

def Laws.ev_openai_error():
  {==}

def Laws.body_anthropic():
  {==}

def Laws.body_anthropic_plain():
  {==}

def Laws.body_openai():
  {==}

def Laws.body_openai_plain():
  {==}

def Laws.again_overloaded():
  {==}

def Laws.again_rate():
  {==}

def Laws.again_bad_request():
  {==}

def Laws.again_ok():
  {==}
