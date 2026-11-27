import Base
import ./LAWS.bend as Laws
import ./sse.bend as Sse
import ./sse-scan-proof.bend as Scan
import ./sse-buffer-proof.bend as Buffer
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import ./sse-packed-proof.bend as Packed
import ./sse-feed-proof.bend as Feed
import ./sse-offset-proof.bend as Offset
import ./sse-capacity-proof.bend as Capacity
import ./sse-reader-proof.bend as Reader
import ./sse-field-proof.bend as Field
import ./sse-refinement-proof.bend as Refinement
import ./sse-line-proof.bend as Line
import ./sse-boundary-proof.bend as Boundary
import ./sse-drain-proof.bend as Drain

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

def Laws.sse_drain_schedule(fs, r):
  Drain.schedule_refines(fs, r)

def Laws.sse_drain_finish(f, r, acc):
  Drain.finish_refines(f, r, acc)

def Laws.sse_interleaved_event_drains(pieces, r):
  Drain.interleaved_refines(pieces, r)

def Laws.sse_drain_repartition(left, right, same, r):
  Drain.repartition_refines(left, right, same, r)

def Laws.sse_event_drain_fixture():
  {==}

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

def Laws.sse_scan_observe(f, r, s, i, same):
  Buffer.eol_observed(f, r, s, i, same)

def Laws.sse_scan_relocate(R, f, r, s, i, j, same):
  Buffer.eol_related(~R, f, r, s, i, j, same)

def Laws.sse_scan_clean_transport(f, r, s, i, j, same, clean):
  Buffer.clean_observed(f, r, s, i, j, same, clean)

def Laws.sse_colon_observe(f, r, s, i, same):
  Buffer.colon_observed(f, r, s, i, same)

def Laws.sse_colon_relocate(R, f, r, s, i, j, same):
  Buffer.colon_related(~R, f, r, s, i, j, same)

def Laws.sse_name_observe(needle, ok, r, s, i, j, same):
  Buffer.at_observed(needle, ok, r, s, i, j, same)

def Laws.sse_scan_preserves_buffer(f, a, c, i):
  Buffer.eol_preserves(f, a, c, i)

def Laws.sse_colon_preserves_buffer(f, a, c, i):
  Buffer.colon_preserves(f, a, c, i)

def Laws.sse_name_preserves_buffer(needle, ok, a, c, i):
  Buffer.at_preserves(needle, ok, a, c, i)

def Laws.sse_packed_copy(m, src, dst, s, d):
  Packed.copy_bridge(m, src, dst, s, d)

def Laws.sse_packed_append(a, b, limit, hn, hu):
  Packed.canonical_append_observed(a, b, limit, hn, hu)

def Laws.sse_packed_append_scan(a, b, limit, hn, hu):
  Packed.canonical_append_scan(a, b, limit, hn, hu)

def Laws.sse_feed_buffer_observe(a, b, seen, cr, st, limit, hn, hu):
  Packed.feed_zero_observed(a, b, seen, cr, st, limit, hn, hu)

def Laws.sse_kind_observe(n, a, b, i, j, two, four, five):
  Packed.kind_observed(n, a, b, i, j, two, four, five)

def Laws.sse_shifted_copy_word(i, n, depth, src, dst, lo, hi, s, d, limit, shape, hd, hl, hu, end):
  Packed.shift_bounded(i, n, depth, src, dst, lo, hi, s, d, limit, shape, hd, hl, hu, end)

def Laws.sse_shifted_copy_head(m, n, depth, src, dst, s, limit, shape, hd, hl, hu, hn, em):
  Packed.shifted_head_capacity(m, n, depth, src, dst, s, limit, shape, hd, hl, hu, hn, em)

def Laws.sse_copy_octet(depth, m, src, dst, s, i, limit, source_limit, shape, hd, hl, hu, hi, end, source, hsu):
  Packed.copied_octet_value(depth, m, src, dst, s, i, limit, source_limit, shape, hd, hl, hu, hi, end, source, hsu)

def Laws.sse_slice_observe(text, len, src, start, n, limit, hn, hu, elen, reads):
  Packed.slice_observed_bounded(text, len, src, start, n, limit, hn, hu, elen, reads)

def Laws.sse_slice_preserves_buffer(len, src, start, n):
  Packed.slice_preserves(len, src, start, n)

def Laws.sse_slice_string(text, len, m, src, s, limit, hn, hu, elen, total, reads):
  Packed.slice_at_string(text, len, m, src, s, limit, hn, hu, elen, total, reads)

def Laws.sse_compact_feed_state(len, src, pos, seen, cr, st, lb, right):
  Packed.feed_compact_bridge(len, src, pos, seen, cr, st, lb, right)

def Laws.sse_slice_append_observe(text, chunk, len, src, start, n, lb, right, limit, hl, hu, ea, eb, hn, ra, rb):
  Feed.slice_append_bounded(text, chunk, len, src, start, n, lb, right, limit, hl, hu, ea, eb, hn, ra, rb)

def Laws.sse_feed_state_observe(text, chunk, len, src, pos, seen, cr, st, lb, right, limit, shape, hl, hu, ea, eb, hn, ra, rb):
  Feed.feed_observed(text, chunk, len, src, pos, seen, cr, st, lb, right, limit, shape, hl, hu, ea, eb, hn, ra, rb)

def Laws.sse_scan_logical_offset(f, a, b, delta, i, j, limit, hi, hj, hu, here, same):
  Offset.scan_observed(f, a, b, delta, i, j, limit, hi, hj, hu, here, same)

def Laws.sse_slice_scan_offset(text, len, m, src, s, limit, hn, hu, elen, total, reads):
  Offset.slice_scan(text, len, m, src, s, limit, hn, hu, elen, total, reads)

def Laws.sse_colon_logical_offset(f, a, b, delta, i, j, limit, hi, hj, hu, here, same):
  Offset.colon_observed(f, a, b, delta, i, j, limit, hi, hj, hu, here, same)

def Laws.sse_append_capacity(a, b, left, right, limit, shape, h, hn, hu):
  Capacity.append_shape(a, b, left, right, limit, shape, h, hn, hu)

def Laws.sse_set_data_observe(a, b, la, lb, left, right, limit, name, id, retry, shape, ea, eb, hn, hu, ra, rb):
  Feed.set_data_observed(a, b, la, lb, left, right, limit, name, id, retry, shape, ea, eb, hn, hu, ra, rb)

def Laws.sse_set_event_values(a, b, st, same):
  Feed.event_values(a, b, st, same)

def Laws.sse_set_id_values(a, b, st, same):
  Feed.id_values(a, b, st, same)

def Laws.sse_set_retry_values(a, b, st, same):
  Feed.retry_values(a, b, st, same)

def Laws.sse_feed_valid(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit, hu, eb, hn, rb, valid):
  Reader.feed_valid(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit, hu, eb, hn, rb, valid)

def Laws.sse_feed_pair_valid(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right, limit, hu, ea, eb, ha, hb, ra, rb, valid):
  Reader.feed_pair_valid(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right, limit, hu, ea, eb, ha, hb, ra, rb, valid)

def Laws.sse_line_restart(prefix, len, src, pos, seen, cr, st, limit, hl, hu, hp, hs, ep, clean):
  Reader.line_restart(prefix, len, src, pos, seen, cr, st, limit, hl, hu, hp, hs, ep, clean)

def Laws.sse_kind_span_reads(name, n, a, b, i, j, length, ra, rb):
  Field.kind_span_reads(name, n, a, b, i, j, length, ra, rb)

def Laws.sse_field_set_data(old, value, la, left, len, src, v, e, limit, name, id, retry, shape, hl, hu, ea, eb, hn, ra, rb):
  Field.field_set_data(old, value, la, left, len, src, v, e, limit, name, id, retry, shape, hl, hu, ea, eb, hn, ra, rb)

def Laws.sse_kind_relocated(name, delta, a, b, s, t, c, d, hs, ht, starts, ends, length, ra, rb):
  Field.kind_relocated(name, delta, a, b, s, t, c, d, hs, ht, starts, ends, length, ra, rb)

def Laws.sse_value_relocated(delta, c, d, e, f, b, limit, hc1, hd1, hc2, hd2, hu, colons, ends):
  Field.value_relocated(delta, c, d, e, f, b, limit, hc1, hd1, hc2, hd2, hu, colons, ends)

def Laws.sse_observation_span(f, g, h, a, b, i, j, u, v, limit, hu, ha, hb, ea, eb, same):
  Reader.observed_span(f, g, h, a, b, i, j, u, v, limit, hu, ha, hb, ea, eb, same)

def Laws.sse_field_pair(len, src, s, e, st):
  Field.field_pair(len, src, s, e, st)

def Laws.sse_field_colon_bounds(src, s, e, limit, hs, he, hu):
  Field.field_colon_bounds(src, s, e, limit, hs, he, hu)

def Laws.sse_field_start_bounds(len, src, s, e, limit, hs, he, hl, hu):
  Field.field_start_bounds(len, src, s, e, limit, hs, he, hl, hu)

def Laws.sse_classify_relocated(name, delta, a, b, s, t, c, d, hs, ht, starts, ends, length, ra, rb):
  Field.classify_relocated(name, delta, a, b, s, t, c, d, hs, ht, starts, ends, length, ra, rb)

def Laws.sse_field_observed(old, value, la, left, len, src, s, e, limit, name, id, retry, shape, hl, hu, ea, eb, hn, ra, rb):
  Field.field_observed(old, value, la, left, len, src, s, e, limit, name, id, retry, shape, hl, hu, ea, eb, hn, ra, rb)

def Laws.sse_field_valid(old, value, la, left, len, src, s, e, limit, name, id, retry, shape, hl, hu, ea, eb, hn, ra, rb):
  Field.field_valid(old, value, la, left, len, src, s, e, limit, name, id, retry, shape, hl, hu, ea, eb, hn, ra, rb)

def Laws.sse_field_spans(a, b, s, t, e, f, delta, limit, se, tf, he, hf, hu, starts, ends, same):
  Refinement.field_spans(a, b, s, t, e, f, delta, limit, se, tf, he, hf, hu, starts, ends, same)

def Laws.sse_field_refines(old, name, id, retry, a, b, len, other, s, t, e, f, st, next, delta, limit, hl, hr, hu, se, tf, el, fo, starts, ends, hn, left_state, right_state, same):
  Refinement.field_refines(old, name, id, retry, a, b, len, other, s, t, e, f, st, next, delta, limit, hl, hr, hu, se, tf, el, fo, starts, ends, hn, left_state, right_state, same)

def Laws.sse_scanned_field_refines(old, name, id, retry, a, b, len, other, s, t, st, next, delta, limit, hl, hr, hu, sl, to, starts, ends, hn, left_state, right_state, same):
  Refinement.scanned_field_refines(old, name, id, retry, a, b, len, other, s, t, st, next, delta, limit, hl, hr, hu, sl, to, starts, ends, hn, left_state, right_state, same)

def Laws.sse_trim_string(text, len, src, depth, limit, hd, hl, hu, hc, length, shape, reads):
  Line.trim_string(text, len, src, depth, limit, hd, hl, hu, hc, length, shape, reads)

def Laws.sse_dispatch_content(text, name, id, retry, len, src, depth, limit, nonempty, hd, hl, hu, hc, length, shape, reads):
  Line.dispatch_nonempty(text, name, id, retry, len, src, depth, limit, nonempty, hd, hl, hu, hc, length, shape, reads)

def Laws.sse_runtime_feed_composition(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right, limit, hu, ea, eb, ha, hb, hab, hc, shape, ra, rb, valid):
  Boundary.feed_composition(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right, limit, hu, ea, eb, ha, hb, hab, hc, shape, ra, rb, valid)

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
