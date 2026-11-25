import Base
import ./LAWS.bend as Laws
import ./sse.bend as Sse

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
      Laws.sse_feed_compose(t, ys, Laws.drain(64n, Sse.next(Sse.feed(rd, Laws.b(h))), acc))

def Laws.sse_octet_compose(a, b, r):
  match a:
    case SNil{}:
      {==}
    case SCon{c, t}:
      (rd, acc) = r
      Laws.sse_octet_compose(t, b, Laws.drain(64n, Sse.next(Sse.feed(rd, Laws.b(SCon{c, SNil{}}))), acc))

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
