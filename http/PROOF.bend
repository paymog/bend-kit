import Base
import ./http.bend as Http
import ./LAWS.bend as Laws

def Laws.body_after_blank(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def suffix_step(
  a: U32, -t: String, -e: Bool, -w: U32, -acc: String,
  ih: (&p: String -> {p ++ Http.body.of(Http.split_at_blank.go(t, e, w, acc)) == t : String})
) -> (&p: String -> {p ++ Http.body.of(Http.split_at_blank.go(t, e, w, acc)) == SCon{Chr{a}, t} : String}):
  (p, pf) = ih
  (SCon{Chr{a}, p}, Equal.cong(String, String, x => SCon{Chr{a}, x}, p ++ Http.body.of(Http.split_at_blank.go(t, e, w, acc)), t, pf))

def suffix_go(s: String, e: Bool, w: U32, acc: String) ->
  (&p: String -> {p ++ Http.body.of(Http.split_at_blank.go(s, e, w, acc)) == s : String}):
  match s:
    case SNil{}:
      ("", {==})
    case SCon{Chr{+a}, +t}:
      match e:
        case True{}:
          ("", {==})
        case False{}:
          +w2 = (w * 256 + a : U32)
          suffix_step(a, t, U32.is_eq(w2, 218762506), w2, SCon{Chr{a}, acc}, suffix_go(t, U32.is_eq(w2, 218762506), w2, SCon{Chr{a}, acc}))

def Laws.body_suffix(s):
  suffix_go(s, False{}, 0, SNil{})

def Laws.page_after_blank(status, headers, page):
  ("HTTP/1.1 " ++ U32.show(status) ++ " " ++ Http.reason(status) ++ Http.headers_block(headers), {==})

def drop(n: Nat, s: String) -> String:
  match n:
    case 0n:
      s
    case 1n+p:
      match s:
        case SNil{}:
          SNil{}
        case SCon{h, t}:
          drop(p, t)

def Laws.response_inj(a, b, e):
  Equal.cong(String, String, s => drop(19n, s), Http.response(200, Http.empty(), a), Http.response(200, Http.empty(), b), e)

def Laws.sanitize_drop_cr(s):
  {==}

def Laws.sanitize_drop_lf(s):
  {==}

def Laws.http11_needs_host(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.parse_zero_body(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.cl_te_rejects(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.parse_res_body():
  {==}

def Laws.cl_short_rejects():
  {==}

def Laws.chunk_last_ends(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.chunk_data_opaque(c):
  {==}

def Laws.chunk_needs_size(b):
  match b:
    case SNil{}:
      {==}
    case SCon{h, t}:
      {==}

def Laws.chunk_hello():
  {==}

def Laws.chunk_many():
  {==}

def Laws.chunk_hex_case():
  {==}

def Laws.chunk_ext_ignored():
  {==}

def Laws.chunk_trailer():
  {==}

def Laws.chunk_short_rejects():
  {==}

def Laws.chunk_no_crlf_after_data_rejects():
  {==}

def Laws.chunk_unterminated_rejects():
  {==}

def Laws.chunk_bare_lf_rejects():
  {==}

def Laws.chunk_overflow_rejects():
  {==}

def Laws.parse_chunked_req():
  {==}

def Laws.frame_head_more():
  {==}

def Laws.frame_head_cut_bad():
  {==}

def Laws.frame_cl_more():
  {==}

def Laws.frame_cl_cut_bad():
  {==}

def Laws.frame_cl_done(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.frame_open_more(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.frame_open_close(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.frame_chunked_more():
  {==}

def Laws.frame_chunked_done():
  {==}

def Laws.frame_head_request(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.frame_204():
  {==}

def Laws.frame_304():
  {==}

def Laws.frame_bad_status():
  {==}

def Laws.frame_chunk_bad_size():
  {==}

def Laws.frame_chunk_bad_data():
  {==}

def Laws.frame_chunk_bare_lf():
  {==}

def Laws.frame_chunk_size_more():
  {==}

def Laws.frame_cl_and_te():
  {==}

def Laws.frame_bad_length():
  {==}

def Laws.frame_te_gzip_more():
  {==}

def Laws.frame_te_gzip_close():
  {==}

def Laws.text_utf8():
  {==}

def Laws.json_flag():
  {==}

def Laws.json_utf8():
  {==}

def Laws.json_bad_utf8_none():
  {==}

def Laws.frame_100_waits():
  {==}

def Laws.frame_100_cut():
  {==}

def Laws.frame_100_then_ok():
  {==}

def Laws.frame_103_then_ok():
  {==}

def Laws.frame_101_final():
  {==}

def Laws.frame_interim_cap():
  {==}

def Laws.frame_interim_eight():
  {==}


def Laws.after_cl():
  {==}

def Laws.after_chunk():
  {==}

def Laws.after_close_none():
  {==}

def Laws.after_204():
  {==}
def Laws.req_get():
  {==}

def Laws.req_keep():
  {==}
def Laws.again_keep():
  {==}

def Laws.again_asked_close():
  {==}

def Laws.again_peer_close():
  {==}

def Laws.again_until_close():
  {==}

def Laws.req_post_guarded():
  {==}

def Laws.policy_manual():
  {==}

def Laws.policy_error():
  {==}

def Laws.policy_error_ok():
  {==}

def Laws.req_roundtrip():
  {==}

def Laws.redirect_301_post_to_get():
  {==}

def Laws.redirect_302_get_kept():
  {==}

def Laws.redirect_303_put_to_get():
  {==}

def Laws.redirect_303_head_kept():
  {==}

def Laws.redirect_307_keeps_post():
  {==}

def Laws.redirect_308_keeps_put():
  {==}

def Laws.redirect_cross_origin_drops_creds():
  {==}

def Laws.redirect_same_origin_keeps_creds():
  {==}

def Laws.redirect_downgrade_is_cross_origin():
  {==}

def Laws.redirect_200_none():
  {==}

def Laws.redirect_no_location_none():
  {==}

def Laws.redirect_other_scheme_none():
  {==}

def Laws.err_timeout_mac():
  {==}

def Laws.err_timeout_linux():
  {==}

def Laws.err_tls_keeps_why():
  {==}

def Laws.err_connect_keeps_code():
  {==}

def Laws.set_cookie_kept():
  {==}

def Laws.set_cookie_not_joined():
  {==}

def Laws.vary_kept():
  {==}

def Laws.set_cookie_lines():
  {==}

def Laws.req_head_more():
  {==}

def Laws.req_cl_more():
  {==}

def Laws.req_chunk_more():
  {==}

def Laws.req_chunk_bad():
  {==}

def Laws.req_te_other_bad():
  {==}

def Laws.req_http2_bad():
  {==}

def Laws.req_http10_no_host():
  {==}

def Laws.reason_404():
  {==}

def Laws.reason_unknown():
  {==}

def Laws.encode_204_nobody():
  {==}

def Laws.encode_head():
  {==}


def Laws.serve_keep_v11():
  {==}

def Laws.serve_keep_close():
  {==}

def Laws.serve_keep_http10():
  {==}

def Laws.req_after_content_length():
  {==}

def Laws.req_after_chunked():
  {==}

def Laws.req_hint_complete():
  {==}

def Laws.chunk_feed_split():
  {==}

def Laws.chunk_feed_split_size():
  {==}

def Laws.chunk_suffix_pipelined():
  {==}

def Laws.pool_key_origin():
  {==}

def Laws.pool_retry_get_stale():
  {==}

def Laws.pool_no_retry_post():
  {==}

def Laws.pool_no_retry_partial():
  {==}

def Laws.decoded_gzip():
  {==}

def Laws.decoded_order():
  {==}

def Laws.decoded_unknown():
  {==}

def Laws.decoded_corrupt():
  {==}

def Laws.decoded_empty():
  {==}

def Laws.accept_enc_default():
  {==}

def Laws.accept_enc_caller():
  {==}

def Laws.hex_chunk_size():
  {==}

def Laws.hex_zero():
  {==}

def Laws.serve_head_split():
  {==}

def Laws.serve_cl_pieces():
  {==}

def Laws.serve_chunk_run():
  {==}

def Laws.serve_cl_short():
  {==}

def Laws.loop_head_more_whole():
  {==}

def Laws.loop_head_cut_bad_whole():
  {==}

def Laws.loop_head_cut_bad_bytes():
  {==}

def Laws.loop_cl_more_whole():
  {==}

def Laws.loop_cl_more_bytes():
  {==}

def Laws.loop_cl_cut_bad_whole():
  {==}

def Laws.loop_cl_done_whole():
  {==}

def Laws.loop_cl_done_bytes():
  {==}

def Laws.loop_open_more_whole():
  {==}

def Laws.loop_open_close_whole():
  {==}

def Laws.loop_open_close_bytes():
  {==}

def Laws.loop_chunked_more_whole():
  {==}

def Laws.loop_chunked_more_bytes():
  {==}

def Laws.loop_chunked_done_whole():
  {==}

def Laws.loop_chunked_done_bytes():
  {==}

def Laws.loop_head_request_whole():
  {==}

def Laws.loop_head_request_bytes():
  {==}

def Laws.loop_304_whole():
  {==}

def Laws.loop_bad_status_whole():
  {==}

def Laws.loop_chunk_bad_size_whole():
  {==}

def Laws.loop_chunk_bad_data_whole():
  {==}

def Laws.loop_chunk_bad_data_bytes():
  {==}

def Laws.loop_chunk_cut_whole():
  {==}

def Laws.loop_chunk_cut_bytes():
  {==}

def Laws.loop_cl_and_te_whole():
  {==}

def Laws.loop_bad_length_whole():
  {==}

def Laws.loop_te_gzip_close_whole():
  {==}

def Laws.loop_te_gzip_close_bytes():
  {==}

def Laws.loop_100_then_ok_whole():
  {==}

def Laws.loop_100_then_ok_bytes():
  {==}

def Laws.loop_100_cut_whole():
  {==}

def Laws.loop_101_final_whole():
  {==}

def Laws.loop_interim_cap_whole():
  {==}

def Laws.loop_interim_eight_whole():
  {==}

def Laws.loop_cookies_whole():
  {==}

def Laws.loop_cookies_bytes():
  {==}

def Laws.loop_close_rest():
  {==}

def Laws.loop_cl_rest():
  {==}

def Laws.stream_cl():
  {==}

def Laws.stream_chunked():
  {==}

def Laws.stream_cl_te():
  {==}

def Laws.stream_close():
  {==}

def Laws.stream_nobody():
  {==}

def Laws.stream_len_split():
  {==}

def Laws.stream_len_more():
  {==}

def Laws.stream_chunk_piece():
  {==}

def Laws.stream_chunk_end():
  {==}

def Laws.stream_len_cut():
  {==}

def Laws.decoded_plain():
  {==}

def Laws.retry_statuses():
  {==}

def Laws.retry_idempotent():
  {==}

def Laws.retry_connect():
  {==}

def Laws.retry_timeout():
  {==}

def Laws.retry_dns_stops():
  {==}

def Laws.retry_503():
  {==}

def Laws.retry_429_backoff():
  {==}

def Laws.retry_200_stops():
  {==}

def Laws.retry_post_stops():
  {==}

def Laws.retry_post_connect_stops():
  {==}

def Laws.retry_base():
  {==}

def Laws.retry_backoff():
  {==}

def Laws.retry_after_secs():
  {==}

def Laws.retry_after_date():
  {==}

def Laws.retry_after_bad():
  {==}

def Laws.retry_delay():
  {==}
