import Base
import ./http.bend as Http
import 0x1f2d80f53f971b16c6de6a65cb1918ae/url.bend as Url
import 0x584fc27920487ceab242392391418d7f/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import bend-kit-time@0.1.2.1/time.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int

# LAW: the text after a blank line is the body.
law body_after_blank:
  for b: String
  {Http.body("\r\n\r\n" ++ b) == b : String}

# LAW: the body is a suffix of the text.
law body_suffix:
  for +s: String
  exs p: String
  {p ++ Http.body(s) == s : String}

# LAW: a response is some head, then a blank line, then the page.
law page_after_blank:
  for +status: U32
  for headers: Map<&2, List<&2, String>>
  for +page: String
  exs head: String
  {head ++ ("\r\n\r\n" ++ page) == Http.response(status, headers, page) : String}

# LAW: equal 200 empty-header responses come from equal pages.
law response_inj:
  for +a: String
  for +b: String
  for e: {Http.response(200, Http.empty(), a) == Http.response(200, Http.empty(), b) : String}
  {a == b : String}

# LAW: sanitize drops CR.
law sanitize_drop_cr:
  for s: String
  {Http.sanitize(SCon{Chr{13}, s}) == Http.sanitize(s) : String}

# LAW: sanitize drops LF.
law sanitize_drop_lf:
  for s: String
  {Http.sanitize(SCon{Chr{10}, s}) == Http.sanitize(s) : String}

# RFC 9112 §3.2: HTTP/1.1 request without Host is not a message.
law http11_needs_host:
  for b: String
  {Http.parse("GET / HTTP/1.1\r\n\r\n" ++ b) == None{} : Maybe<&1, Http.Req>}

# RFC 9112 §6.3 (7): no CL and no TE ⇒ request body length 0.
law parse_zero_body:
  for b: String
  {Http.got_body(Http.parse("GET / HTTP/1.1\r\nHost: x\r\n\r\n" ++ b)) == Bytes.from_string("") : Bytes.Bytes}

# RFC 9112 §6.1/6.3: Transfer-Encoding without a chunked decoder is rejected.
law cl_te_rejects:
  for b: String
  {Http.parse("GET / HTTP/1.1\r\nHost: x\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n\r\n" ++ b) == None{} : Maybe<&1, Http.Req>}

# RFC 9112 §6.3 (6): response Content-Length is the body.
law parse_res_body:
  {Http.res_body(Http.parse_res("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")) == Bytes.from_string("ok") : Bytes.Bytes}

# RFC 9112 §8: a body shorter than Content-Length is incomplete, not a message.
law cl_short_rejects:
  {Http.parse("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\nhi") == None{} : Maybe<&1, Http.Req>}

# RFC 9112 §7.1: last-chunk then an empty trailer ends the body; later bytes are not body.
law chunk_last_ends:
  for b: String
  {Http.chunk.decode("0\r\n\r\n" ++ b) == Some{""} : Maybe<&2, String>}

# RFC 9112 §7.1: chunk-data is opaque; any octet, CR and LF included, passes through.
law chunk_data_opaque:
  for c: U32
  {Http.chunk.decode("1\r\n" ++ SCon{Chr{c}, "\r\n0\r\n\r\n"}) == Some{SCon{Chr{c}, SNil{}}} : Maybe<&2, String>}

# RFC 9112 §7.1: chunk-size is 1*HEXDIG; an empty size is not a chunk.
law chunk_needs_size:
  for b: String
  {Http.chunk.decode("\r\n" ++ b) == None{} : Maybe<&2, String>}

law chunk_hello:
  {Http.chunk.decode("5\r\nhello\r\n0\r\n\r\n") == Some{"hello"} : Maybe<&2, String>}

law chunk_many:
  {Http.chunk.decode("5\r\nhello\r\n1\r\n \r\n5\r\nworld\r\n0\r\n\r\n") == Some{"hello world"} : Maybe<&2, String>}

# chunk-size is case-insensitive hex.
law chunk_hex_case:
  {Http.chunk.decode("a\r\n0123456789\r\nA\r\n0123456789\r\n0\r\n\r\n") == Some{"01234567890123456789"} : Maybe<&2, String>}

# RFC 9112 §7.1.1: unknown chunk extensions are ignored.
law chunk_ext_ignored:
  {Http.chunk.decode("5;name=\"v\"\r\nhello\r\n0;x\r\n\r\n") == Some{"hello"} : Maybe<&2, String>}

# RFC 9112 §7.1.2: trailer fields end with an empty line.
law chunk_trailer:
  {Http.chunk.decode("2\r\nok\r\n0\r\nExpires: never\r\n\r\n") == Some{"ok"} : Maybe<&2, String>}

law chunk_short_rejects:
  {Http.chunk.decode("5\r\nhi\r\n0\r\n\r\n") == None{} : Maybe<&2, String>}

law chunk_no_crlf_after_data_rejects:
  {Http.chunk.decode("2\r\nokXX0\r\n\r\n") == None{} : Maybe<&2, String>}

law chunk_unterminated_rejects:
  {Http.chunk.decode("2\r\nok\r\n0\r\n") == None{} : Maybe<&2, String>}

law chunk_bare_lf_rejects:
  {Http.chunk.decode("2\nok\r\n0\r\n\r\n") == None{} : Maybe<&2, String>}

# A size that overflows 32 bits must not wrap to a small length (smuggling).
law chunk_overflow_rejects:
  {Http.chunk.decode("100000002\r\nok\r\n0\r\n\r\n") == None{} : Maybe<&2, String>}

# RFC 9112 §6.1: chunked request without Content-Length is framed by chunks.
law parse_chunked_req:
  {Http.got_body(Http.parse("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nhi\r\n3\r\n yo\r\n0\r\n\r\n")) == Bytes.from_string("hi yo") : Bytes.Bytes}

def body_of(f: Http.Frame) -> Maybe<&1, Bytes.Bytes>:
  match f:
    case Http.FrameDone{r}:
      Some{Http.res_body(Some{r})}
    case Http.FrameBad{}:
      None{}
    case Http.FrameMore{}:
      None{}

# Header block not finished: read on while open; a cut after close is not a message.
law frame_head_more:
  {Http.frame("HTTP/1.1 200 OK\r\nContent-", False{}, False{}) == Http.FrameMore{} : Http.Frame}

law frame_head_cut_bad:
  {Http.frame("HTTP/1.1 200 OK\r\nContent-", True{}, False{}) == Http.FrameBad{} : Http.Frame}

# RFC 9112 §6.3 (6) and §8: short Content-Length body.
law frame_cl_more:
  {Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhi", False{}, False{}) == Http.FrameMore{} : Http.Frame}

law frame_cl_cut_bad:
  {Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhi", True{}, False{}) == Http.FrameBad{} : Http.Frame}

# Content-Length ends the message; no need to wait for close, extra bytes are not body.
law frame_cl_done:
  for b: String
  {body_of(Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok" ++ b, False{}, False{})) == Some{Bytes.from_string("ok")} : Maybe<&1, Bytes.Bytes>}

# RFC 9112 §6.3 (8): no framing ⇒ wait for close, then everything is body.
law frame_open_more:
  for b: String
  {Http.frame("HTTP/1.1 200 OK\r\n\r\n" ++ b, False{}, False{}) == Http.FrameMore{} : Http.Frame}

law frame_open_close:
  for b: String
  {body_of(Http.frame("HTTP/1.1 200 OK\r\n\r\n" ++ b, True{}, False{})) == Some{Bytes.from_string(b)} : Maybe<&1, Bytes.Bytes>}

# Chunked: a partial chunk reads on; the last-chunk ends it without close.
law frame_chunked_more:
  {Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhel", False{}, False{}) == Http.FrameMore{} : Http.Frame}

law frame_chunked_done:
  {body_of(Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n", False{}, False{})) == Some{Bytes.from_string("hello")} : Maybe<&1, Bytes.Bytes>}

# RFC 9112 §6.3 (1): a HEAD response has no body, whatever Content-Length says.
law frame_head_request:
  for b: String
  {body_of(Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n" ++ b, False{}, True{})) == Some{Bytes.from_string("")} : Maybe<&1, Bytes.Bytes>}

# RFC 9112 §6.3 (1): 204 and 304 have no body.
law frame_204:
  {body_of(Http.frame("HTTP/1.1 204 No Content\r\n\r\n", False{}, False{})) == Some{Bytes.from_string("")} : Maybe<&1, Bytes.Bytes>}

law frame_304:
  {body_of(Http.frame("HTTP/1.1 304 Not Modified\r\nContent-Length: 9\r\n\r\n", False{}, False{})) == Some{Bytes.from_string("")} : Maybe<&1, Bytes.Bytes>}

law frame_bad_status:
  {Http.frame("HTTP/1.1 abc OK\r\n\r\n", False{}, False{}) == Http.FrameBad{} : Http.Frame}

# A bad chunk is never a message, even while the connection is open.
law frame_chunk_bad_size:
  {Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nG\r\n", False{}, False{}) == Http.FrameBad{} : Http.Frame}

law frame_chunk_bad_data:
  {Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nokXX", False{}, False{}) == Http.FrameBad{} : Http.Frame}

law frame_chunk_bare_lf:
  {Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\n", False{}, False{}) == Http.FrameBad{} : Http.Frame}

# A size line that has not ended can still become a chunk.
law frame_chunk_size_more:
  {Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5", False{}, False{}) == Http.FrameMore{} : Http.Frame}

# RFC 9112 §6.3: both Content-Length and Transfer-Encoding is an error.
law frame_cl_and_te:
  {Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\nZ", False{}, False{}) == Http.FrameBad{} : Http.Frame}

law frame_bad_length:
  {Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 5abc\r\n\r\n", False{}, False{}) == Http.FrameBad{} : Http.Frame}

# RFC 9112 §6.3: a transfer coding other than chunked is read until close.
law frame_te_gzip_more:
  {Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: gzip\r\n\r\nabc", False{}, False{}) == Http.FrameMore{} : Http.Frame}

law frame_te_gzip_close:
  {body_of(Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: gzip\r\n\r\nabc", True{}, False{})) == Some{Bytes.from_string("abc")} : Maybe<&1, Bytes.Bytes>}

law text_utf8:
  {Http.text(Http.Res{200, Http.empty(), Bytes.from_string(SCon{Chr{195}, SCon{Chr{169}, SNil{}}})}) == "é" : String}

law json_flag:
  {Http.json(Http.Res{200, Http.empty(), Bytes.from_string("true")}) == Some{Json.Flag{True{}}} : Maybe<&1, Json.Val>}

law json_utf8:
  {Http.json(Http.Res{200, Http.empty(), Bytes.from_string("\"\u{c3}\u{a9}\"")}) == Some{Json.Str{Json.utf8("é")}} : Maybe<&1, Json.Val>}

law json_bad_utf8_none:
  {Http.json(Http.Res{200, Http.empty(), Bytes.from_string("\"\u{c3}\"")}) == None{} : Maybe<&1, Json.Val>}


law req_keep:
  {Http.encode_req.on("GET", "/x", "h", Http.empty(), Bytes.new(0), False{}) == Bytes.from_string("GET /x HTTP/1.1\r\nconnection: keep-alive\r\nhost: h\r\n\r\n") : Bytes.Bytes}

law again_keep:
  {Http.again(False{}, Http.empty(), Some{Bytes.from_string("x")}) == Some{Bytes.from_string("x")} : Maybe<&1, Bytes.Bytes>}

law again_asked_close:
  {Http.again(True{}, Http.empty(), Some{Bytes.from_string("x")}) == None{} : Maybe<&1, Bytes.Bytes>}

law again_peer_close:
  {Http.again(False{}, Http.set(Http.empty(), "connection", "Close"), Some{Bytes.from_string("x")}) == None{} : Maybe<&1, Bytes.Bytes>}

law again_until_close:
  {Http.again(False{}, Http.empty(), None{}) == None{} : Maybe<&1, Bytes.Bytes>}

def sample_hop() -> Http.Hop:
  Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/"}, Http.empty(), Bytes.new(0)}

law policy_manual:
  {Http.fetch.policy(Http.ModeManual{}, 19n, sample_hop(), Done{Http.Res{301, Http.set(Http.empty(), "location", "/z"), Bytes.new(0)}}) == Http.NDone{Done{Http.Res{301, Http.set(Http.empty(), "location", "/z"), Bytes.new(0)}}} : Http.Next}

law policy_error:
  {Http.fetch.policy(Http.ModeError{}, 19n, sample_hop(), Done{Http.Res{301, Http.set(Http.empty(), "location", "/z"), Bytes.new(0)}}) == Http.NDone{Fail{Http.ErrRedirect{}}} : Http.Next}

law policy_error_ok:
  {Http.fetch.policy(Http.ModeError{}, 19n, sample_hop(), Done{Http.Res{200, Http.empty(), Bytes.new(0)}}) == Http.NDone{Done{Http.Res{200, Http.empty(), Bytes.new(0)}}} : Http.Next}
def hints(n: Nat) -> String:
  match n:
    case 0n:
      ""
    case 1n+p:
      "HTTP/1.1 100 Continue\r\n\r\n" ++ hints(p)

# RFC 9110 §15.2: 100 and 103 are not the final response.
law frame_100_waits:
  {Http.frame("HTTP/1.1 100 Continue\r\n\r\n", False{}, False{}) == Http.FrameMore{} : Http.Frame}

law frame_100_cut:
  {Http.frame("HTTP/1.1 100 Continue\r\n\r\n", True{}, False{}) == Http.FrameBad{} : Http.Frame}

law frame_100_then_ok:
  {body_of(Http.frame("HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok", False{}, False{})) == Some{Bytes.from_string("ok")} : Maybe<&1, Bytes.Bytes>}

law frame_103_then_ok:
  {body_of(Http.frame("HTTP/1.1 103 Early Hints\r\nLink: </a>; rel=preload\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok", False{}, False{})) == Some{Bytes.from_string("ok")} : Maybe<&1, Bytes.Bytes>}

# 101 switches the protocol; nothing follows.
law frame_101_final:
  {body_of(Http.frame("HTTP/1.1 101 Switching Protocols\r\n\r\n", False{}, False{})) == Some{Bytes.from_string("")} : Maybe<&1, Bytes.Bytes>}

law frame_interim_cap:
  {Http.frame(hints(9n), False{}, False{}) == Http.FrameBad{} : Http.Frame}

law frame_interim_eight:
  {body_of(Http.frame(hints(8n) ++ "HTTP/1.1 200 OK\r\nContent-Length: 1\r\n\r\nZ", False{}, False{})) == Some{Bytes.from_string("Z")} : Maybe<&1, Bytes.Bytes>}

# RFC 9110 §8.6: a bodiless GET carries no Content-Length.
law req_get:
  {Http.encode_req("GET", "/x", "h", Http.empty(), Bytes.new(0)) == Bytes.from_string("GET /x HTTP/1.1\r\nconnection: close\r\nhost: h\r\n\r\n") : Bytes.Bytes}

# Content-Length counts octets; caller CL/TE never reach the wire; field values cannot inject lines.
law req_post_guarded:
  {Http.encode_req("POST", "/", "h:8080", Http.set(Http.set(Http.set(Http.empty(), "Content-Length", "99"), "Transfer-Encoding", "chunked"), "X-A", "1\r\nEvil: 1"), Bytes.from_string(SCon{Chr{195}, SCon{Chr{169}, SNil{}}})) == Bytes.from_string("POST / HTTP/1.1\r\nconnection: close\r\ncontent-length: 2\r\nhost: h:8080\r\nx-a: 1Evil: 1\r\n\r\n" ++ SCon{Chr{195}, SCon{Chr{169}, SNil{}}}) : Bytes.Bytes}

# What the client sends, the server parses back to the same body.
law req_roundtrip:
  {Http.got_body(Http.parse(Bytes.to_string(Http.encode_req("PUT", "/k", "h", Http.empty(), Bytes.from_string("v=1"))))) == Bytes.from_string("v=1") : Bytes.Bytes}

# RFC 9110 §15.4.2 note: user agents change POST to GET on 301 and 302; body headers go with the body.
law redirect_301_post_to_get:
  {Http.redirect(301, Http.set(Http.empty(), "location", "z"), Http.Hop{"POST", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.set(Http.empty(), "content-type", "text/plain"), "x-a", "1"), Bytes.from_string("b")}) == Some{Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/z"}, Http.set(Http.empty(), "x-a", "1"), Bytes.new(0)}} : Maybe<&1, Http.Hop>}

law redirect_302_get_kept:
  {Http.redirect(302, Http.set(Http.empty(), "location", "/q?1"), Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.empty(), "x-a", "1"), Bytes.new(0)}) == Some{Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/q?1"}, Http.set(Http.empty(), "x-a", "1"), Bytes.new(0)}} : Maybe<&1, Http.Hop>}

# §15.4.4: 303 means GET the new URI.
law redirect_303_put_to_get:
  {Http.redirect(303, Http.set(Http.empty(), "location", "/done"), Http.Hop{"PUT", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.set(Http.empty(), "content-type", "text/plain"), "x-a", "1"), Bytes.from_string("b")}) == Some{Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/done"}, Http.set(Http.empty(), "x-a", "1"), Bytes.new(0)}} : Maybe<&1, Http.Hop>}

law redirect_303_head_kept:
  {Http.redirect(303, Http.set(Http.empty(), "location", "/done"), Http.Hop{"HEAD", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.empty(), Bytes.new(0)}) == Some{Http.Hop{"HEAD", Url.Abs{"https", "a.com", 443, "/done"}, Http.empty(), Bytes.new(0)}} : Maybe<&1, Http.Hop>}

# §15.4.8, §15.4.9: 307 and 308 keep the method and the body.
law redirect_307_keeps_post:
  {Http.redirect(307, Http.set(Http.empty(), "location", "/v2"), Http.Hop{"POST", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.set(Http.empty(), "content-type", "text/plain"), "x-a", "1"), Bytes.from_string("b")}) == Some{Http.Hop{"POST", Url.Abs{"https", "a.com", 443, "/v2"}, Http.set(Http.set(Http.empty(), "content-type", "text/plain"), "x-a", "1"), Bytes.from_string("b")}} : Maybe<&1, Http.Hop>}

law redirect_308_keeps_put:
  {Http.redirect(308, Http.set(Http.empty(), "location", "/v2"), Http.Hop{"PUT", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.set(Http.empty(), "content-type", "text/plain"), "x-a", "1"), Bytes.from_string("b")}) == Some{Http.Hop{"PUT", Url.Abs{"https", "a.com", 443, "/v2"}, Http.set(Http.set(Http.empty(), "content-type", "text/plain"), "x-a", "1"), Bytes.from_string("b")}} : Maybe<&1, Http.Hop>}

# Credentials never follow a hop to another origin.
law redirect_cross_origin_drops_creds:
  {Http.redirect(302, Http.set(Http.empty(), "location", "https://evil.com/"), Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.set(Http.set(Http.empty(), "authorization", "t"), "cookie", "c"), "x-a", "1"), Bytes.new(0)}) == Some{Http.Hop{"GET", Url.Abs{"https", "evil.com", 443, "/"}, Http.set(Http.empty(), "x-a", "1"), Bytes.new(0)}} : Maybe<&1, Http.Hop>}

law redirect_same_origin_keeps_creds:
  {Http.redirect(302, Http.set(Http.empty(), "location", "/b"), Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.empty(), "authorization", "t"), Bytes.new(0)}) == Some{Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/b"}, Http.set(Http.empty(), "authorization", "t"), Bytes.new(0)}} : Maybe<&1, Http.Hop>}

# https to http is another origin too.
law redirect_downgrade_is_cross_origin:
  {Http.redirect(302, Http.set(Http.empty(), "location", "http://a.com/x/y"), Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.empty(), "authorization", "t"), Bytes.new(0)}) == Some{Http.Hop{"GET", Url.Abs{"http", "a.com", 80, "/x/y"}, Http.empty(), Bytes.new(0)}} : Maybe<&1, Http.Hop>}

law redirect_200_none:
  {Http.redirect(200, Http.set(Http.empty(), "location", "/z"), Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.empty(), Bytes.new(0)}) == None{} : Maybe<&1, Http.Hop>}

law redirect_no_location_none:
  {Http.redirect(301, Http.empty(), Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.empty(), Bytes.new(0)}) == None{} : Maybe<&1, Http.Hop>}

law redirect_other_scheme_none:
  {Http.redirect(301, Http.set(Http.empty(), "location", "ftp://a.com/"), Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.empty(), Bytes.new(0)}) == None{} : Maybe<&1, Http.Hop>}

law after_cl:
  {Http.after("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nokNEXT", False{}) == Some{"NEXT"} : Maybe<&2, String>}

law after_chunk:
  {Http.after("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nok\r\n0\r\n\r\nNEXT", False{}) == Some{"NEXT"} : Maybe<&2, String>}

law after_close_none:
  {Http.after("HTTP/1.1 200 OK\r\n\r\nhello", False{}) == None{} : Maybe<&2, String>}

law after_204:
  {Http.after("HTTP/1.1 204 No Content\r\n\r\nNEXT", False{}) == Some{"NEXT"} : Maybe<&2, String>}

# A macOS ETIMEDOUT is a timeout, not a connect error.
law err_timeout_mac:
  {Http.err.or_late(60, Http.ErrConnect{60, "x"}) == Http.ErrTimeout{} : Http.Err}

# A Linux ETIMEDOUT is a timeout, not a read error.
law err_timeout_linux:
  {Http.err.or_late(110, Http.ErrRead{110, ""}) == Http.ErrTimeout{} : Http.Err}

# A TLS failure keeps the verify text the effect already returned.
law err_tls_keeps_why:
  {Http.err.or_late(1, Http.ErrTls{1, "expired"}) == Http.ErrTls{1, "expired"} : Http.Err}

# A refused connect keeps the errno.
law err_connect_keeps_code:
  {Http.err.or_late(61, Http.ErrConnect{61, ""}) == Http.ErrConnect{61, ""} : Http.Err}

# Repeated Set-Cookie lines stay separate, in order. header() is the first, never a join.
law set_cookie_kept:
  {Http.res_fields(Http.parse_res("HTTP/1.1 200 OK\r\nSet-Cookie: a=1\r\nSet-Cookie: b=2\r\n\r\n"), "set-cookie") == ["a=1", "b=2"] : List<&2, String>}

law set_cookie_not_joined:
  {Http.header(Http.add(Http.add(Http.empty(), "set-cookie", "a=1"), "set-cookie", "b=2"), "set-cookie") == "a=1" : String}

# RFC 9110 §5.3: a repeated list field keeps every value.
law vary_kept:
  {Http.res_fields(Http.parse_res("HTTP/1.1 200 OK\r\nVary: accept\r\nVary: accept-encoding\r\n\r\n"), "vary") == ["accept", "accept-encoding"] : List<&2, String>}

law set_cookie_lines:
  {Http.headers_block(Http.add(Http.add(Http.empty(), "set-cookie", "a=1"), "set-cookie", "b=2")) == "\r\nset-cookie: a=1\r\nset-cookie: b=2" : String}

# serve reads on while the header block is open.
law req_head_more:
  {Http.parse.got("GET / HTTP/1.1\r\nHost: x\r\n") == Http.GotMore{} : Http.Got}

# RFC 9112 §6.3 (6): a body shorter than Content-Length is read on, not refused.
law req_cl_more:
  {Http.parse.got("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\nhi") == Http.GotHead{Http.Req{"POST", "/", Http.add(Http.add(Http.empty(), "host", "x"), "content-length", "5"), Bytes.new(0)}} : Http.Got}

# RFC 9112 §7.1: an open chunked body is read on.
law req_chunk_more:
  {Http.parse.got("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nhi") == Http.GotHead{Http.Req{"POST", "/", Http.add(Http.add(Http.empty(), "host", "x"), "transfer-encoding", "chunked"), Bytes.new(0)}} : Http.Got}

# A bad chunk size is refused at once, not waited on.
law req_chunk_bad:
  {Http.parse.got("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\nzz\r\n") == Http.GotBad{} : Http.Got}

# RFC 9112 §6.3 (4): a request coding other than chunked is refused.
law req_te_other_bad:
  {Http.parse.got("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: gzip\r\n\r\n") == Http.GotBad{} : Http.Got}

# Only HTTP/1.1 and HTTP/1.0 request lines are messages.
law req_http2_bad:
  {Http.parse.got("GET / HTTP/2.0\r\nHost: x\r\n\r\n") == Http.GotBad{} : Http.Got}

# RFC 9112 §3.2: HTTP/1.0 does not need Host.
law req_http10_no_host:
  {Http.got_body(Http.parse("POST / HTTP/1.0\r\nContent-Length: 2\r\n\r\nhi")) == Bytes.from_string("hi") : Bytes.Bytes}

# RFC 9110 §15: the reason phrase follows the status.
law reason_404:
  {Http.response(404, Http.empty(), "") == "HTTP/1.1 404 Not Found\r\n\r\n" : String}

# RFC 9112 §4: an unknown status has an empty reason.
law reason_unknown:
  {Http.response(599, Http.empty(), "") == "HTTP/1.1 599 \r\n\r\n" : String}

# RFC 9110 §8.6: 204 has no body and no Content-Length.
law encode_204_nobody:
  {Http.encode(Http.Res{204, Http.empty(), Bytes.from_string("x")}) == Bytes.from_string("HTTP/1.1 204 No Content\r\n\r\n") : Bytes.Bytes}

# RFC 9110 §9.3.2: HEAD gets the length but not the body.
law encode_head:
  {Http.encode.on(Http.Res{200, Http.empty(), Bytes.from_string("hi")}, True{}) == Bytes.from_string("HTTP/1.1 200 OK\r\ncontent-length: 2\r\n\r\n") : Bytes.Bytes}


# RFC 9112 §9.3: an HTTP/1.1 request without close keeps the connection.
law serve_keep_v11:
  {Http.serve.keep(Http.empty(), True{}, 200, Http.empty()) == True{} : Bool}

# RFC 9112 §9.3: a request that says close ends the connection.
law serve_keep_close:
  {Http.serve.keep(Http.set(Http.empty(), "connection", "close"), True{}, 200, Http.empty()) == False{} : Bool}

# HTTP/1.0 may close after each response.
law serve_keep_http10:
  {Http.serve.keep(Http.empty(), False{}, 200, Http.empty()) == False{} : Bool}

# A complete Content-Length request leaves the next request untouched.
law req_after_content_length:
  {Http.serve.frame(["POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 2\r\n\r\nhiGET / HTTP/1.1\r\nHost: x\r\n\r\n"]) == Some{("hi", "GET / HTTP/1.1\r\nHost: x\r\n\r\n")} : Maybe<&1, String & String>}

# A complete chunked request leaves the next request untouched.
law req_after_chunked:
  {Http.serve.frame(["POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nhi\r\n0\r\n\r\nGET / HTTP/1.1\r\nHost: x\r\n\r\n"]) == Some{("hi", "GET / HTTP/1.1\r\nHost: x\r\n\r\n")} : Maybe<&1, String & String>}

# A request with no body is whole at the blank line.
law req_hint_complete:
  {Http.serve.frame(["GET / HTTP/1.1\r\nHost: x\r\n\r\n"]) == Some{("", "")} : Maybe<&1, String & String>}

# A chunked body fed in two pieces decodes as if it came at once.
law chunk_feed_split:
  {Http.serve.frame(["POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhel", "lo\r\n0\r\n\r\n"]) == Some{("hello", "")} : Maybe<&1, String & String>}

# A split inside the size line or the final CRLF CRLF still decodes.
law chunk_feed_split_size:
  {Http.serve.frame(["POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n3", "\r\nabc\r\n0\r\n\r", "\n"]) == Some{("abc", "")} : Maybe<&1, String & String>}

# Bytes after the last chunk and trailer belong to the next request.
law chunk_suffix_pipelined:
  {Http.chunk.suffix("1\r\na\r\n0\r\nT: 1\r\n\r\nGET") == Some{"GET"} : Maybe<&2, String>}

# Idle sockets are keyed by origin: scheme, host, and port.
law pool_key_origin:
  {Http.pool.key("https", "example.com", 443) == "https://example.com:443" : String}

# RFC 9112 §9.3.1: an idempotent request on a reused socket that got no response byte is retried.
law pool_retry_get_stale:
  {Http.pool.retry(True{}, Http.pool.idempotent("GET")) == True{} : Bool}

# RFC 9110 §9.2.2: POST is not idempotent, so it is never retried.
law pool_no_retry_post:
  {Http.pool.retry(True{}, Http.pool.idempotent("POST")) == False{} : Bool}

# A response that had started is never retried.
law pool_no_retry_partial:
  {Http.pool.retry(False{}, Http.pool.idempotent("GET")) == False{} : Bool}

def gzbytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{c, t}:
      SCon{Chr{c}, gzbytes(t)}

# RFC 9110 §8.4.1.3: a gzip body is decoded; the headers stay as sent.
law decoded_gzip:
  {Http.res_body(Http.decoded.some(Http.Res{200, Http.set(Http.empty(), "content-encoding", "gzip"), Bytes.from_string(gzbytes([31, 139, 8, 0, 0, 0, 0, 0, 2, 255, 203, 72, 205, 201, 201, 87, 72, 175, 202, 44, 80, 40, 207, 47, 202, 73, 1, 0, 107, 125, 232, 183, 16, 0, 0, 0]))})) == Bytes.from_string("hello gzip world") : Bytes.Bytes}

# RFC 9110 §8.4: codings are listed in the order applied, so they are undone in reverse.
law decoded_order:
  {Http.res_body(Http.decoded.some(Http.Res{200, Http.set(Http.empty(), "content-encoding", "deflate, gzip"), Bytes.from_string(gzbytes([31, 139, 8, 0, 0, 0, 0, 0, 2, 255, 171, 152, 163, 173, 121, 62, 252, 132, 231, 26, 31, 93, 45, 54, 6, 209, 15, 44, 220, 0, 65, 130, 38, 92, 18, 0, 0, 0]))})) == Bytes.from_string("two layers") : Bytes.Bytes}

# A coding we cannot decode leaves the body as sent.
law decoded_unknown:
  {Http.res_body(Http.decoded.some(Http.Res{200, Http.set(Http.empty(), "content-encoding", "br"), Bytes.from_string("xyz")})) == Bytes.from_string("xyz") : Bytes.Bytes}

# A corrupt gzip body is a malformed response.
law decoded_corrupt:
  {Http.decoded(Http.Res{200, Http.set(Http.empty(), "content-encoding", "gzip"), Bytes.from_string("not gzip")}) == Fail{Http.ErrBad{}} : Result<&1, &1, Http.Err, Http.Res>}

# An empty body (HEAD, 204, 304) is never decoded.
law decoded_empty:
  {Http.res_body(Http.decoded.some(Http.Res{200, Http.set(Http.empty(), "content-encoding", "gzip"), Bytes.from_string("")})) == Bytes.from_string("") : Bytes.Bytes}

# fetch asks for the codings it can undo unless the caller says otherwise.
law accept_enc_default:
  {Http.header(Http.accept.enc(Http.empty(), "gzip, deflate, br"), "accept-encoding") == "gzip, deflate, br" : String}

# A caller's own Accept-Encoding wins.
law accept_enc_caller:
  {Http.header(Http.accept.enc(Http.set(Http.empty(), "accept-encoding", "identity"), "gzip, deflate"), "accept-encoding") == "identity" : String}

# Chunk sizes are hex without leading zeros.
law hex_chunk_size:
  {Http.hex(4096) == "1000" : String}

# Zero is one digit.
law hex_zero:
  {Http.hex(0) == "0" : String}

# RFC 9112 §2.2: the blank line that ends the head may arrive split across reads.
law serve_head_split:
  {Http.serve.frame(["GET / HTTP/1.1\r\nHost: x\r\n\r", "\nGET"]) == Some{("", "GET")} : Maybe<&1, String & String>}

# RFC 9112 §6.2: a Content-Length body spans reads, and the bytes past it are the next request.
law serve_cl_pieces:
  {Http.serve.frame(["POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\nh", "el", "loGET"]) == Some{("hello", "GET")} : Maybe<&1, String & String>}

# RFC 9112 §7.1: one chunk's data may span reads.
law serve_chunk_run:
  {Http.serve.frame(["POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\na\r\n01234", "56789\r\n1\r\n!\r\n0\r\n\r\n"]) == Some{("0123456789!", "")} : Maybe<&1, String & String>}

# RFC 9112 §8: a request cut short is not a request.
law serve_cl_short:
  {Http.serve.frame(["POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\nhell"]) == None{} : Maybe<&1, String & String>}

def bytewise(s: String) -> List<&2, String>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{c, t}:
      Con{SCon{c, SNil{}}, bytewise(t)}

# The read loop frames a response as frame does, whole or one byte per read.
law loop_head_more_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nContent-"], False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nContent-", False{}, False{}) : Http.Frame}

law loop_head_cut_bad_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nContent-"], True{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nContent-", True{}, False{}) : Http.Frame}

law loop_head_cut_bad_bytes:
  {Http.res.frame(bytewise("HTTP/1.1 200 OK\r\nContent-"), True{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nContent-", True{}, False{}) : Http.Frame}

law loop_cl_more_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhi"], False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhi", False{}, False{}) : Http.Frame}

law loop_cl_more_bytes:
  {Http.res.frame(bytewise("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhi"), False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhi", False{}, False{}) : Http.Frame}

law loop_cl_cut_bad_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhi"], True{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhi", True{}, False{}) : Http.Frame}

law loop_cl_done_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nokNEXT"], False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nokNEXT", False{}, False{}) : Http.Frame}

law loop_cl_done_bytes:
  {Http.res.frame(bytewise("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nokNEXT"), False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nokNEXT", False{}, False{}) : Http.Frame}

law loop_open_more_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\n\r\nabc"], False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\n\r\nabc", False{}, False{}) : Http.Frame}

law loop_open_close_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\n\r\nabc"], True{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\n\r\nabc", True{}, False{}) : Http.Frame}

law loop_open_close_bytes:
  {Http.res.frame(bytewise("HTTP/1.1 200 OK\r\n\r\nabc"), True{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\n\r\nabc", True{}, False{}) : Http.Frame}

law loop_chunked_more_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhel"], False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhel", False{}, False{}) : Http.Frame}

law loop_chunked_more_bytes:
  {Http.res.frame(bytewise("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhel"), False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhel", False{}, False{}) : Http.Frame}

law loop_chunked_done_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\nT: 1\r\n\r\n"], False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\nT: 1\r\n\r\n", False{}, False{}) : Http.Frame}

law loop_chunked_done_bytes:
  {Http.res.frame(bytewise("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\nT: 1\r\n\r\n"), False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\nT: 1\r\n\r\n", False{}, False{}) : Http.Frame}

law loop_head_request_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n"], False{}, True{}) == Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n", False{}, True{}) : Http.Frame}

law loop_head_request_bytes:
  {Http.res.frame(bytewise("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n"), False{}, True{}) == Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n", False{}, True{}) : Http.Frame}

law loop_304_whole:
  {Http.res.frame(["HTTP/1.1 304 Not Modified\r\nContent-Length: 9\r\n\r\n"], False{}, False{}) == Http.frame("HTTP/1.1 304 Not Modified\r\nContent-Length: 9\r\n\r\n", False{}, False{}) : Http.Frame}

law loop_bad_status_whole:
  {Http.res.frame(["HTTP/1.1 abc OK\r\n\r\n"], False{}, False{}) == Http.frame("HTTP/1.1 abc OK\r\n\r\n", False{}, False{}) : Http.Frame}

law loop_chunk_bad_size_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nG\r\n"], False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nG\r\n", False{}, False{}) : Http.Frame}

law loop_chunk_bad_data_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nokXX"], False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nokXX", False{}, False{}) : Http.Frame}

law loop_chunk_bad_data_bytes:
  {Http.res.frame(bytewise("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nokXX"), False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nokXX", False{}, False{}) : Http.Frame}

law loop_chunk_cut_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nok\r\n"], True{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nok\r\n", True{}, False{}) : Http.Frame}

law loop_chunk_cut_bytes:
  {Http.res.frame(bytewise("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nok\r\n"), True{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nok\r\n", True{}, False{}) : Http.Frame}

law loop_cl_and_te_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\nZ"], False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\nZ", False{}, False{}) : Http.Frame}

law loop_bad_length_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nContent-Length: 5abc\r\n\r\n"], False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 5abc\r\n\r\n", False{}, False{}) : Http.Frame}

law loop_te_gzip_close_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nTransfer-Encoding: gzip\r\n\r\nabc"], True{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: gzip\r\n\r\nabc", True{}, False{}) : Http.Frame}

law loop_te_gzip_close_bytes:
  {Http.res.frame(bytewise("HTTP/1.1 200 OK\r\nTransfer-Encoding: gzip\r\n\r\nabc"), True{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: gzip\r\n\r\nabc", True{}, False{}) : Http.Frame}

law loop_100_then_ok_whole:
  {Http.res.frame(["HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok"], False{}, False{}) == Http.frame("HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok", False{}, False{}) : Http.Frame}

law loop_100_then_ok_bytes:
  {Http.res.frame(bytewise("HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok"), False{}, False{}) == Http.frame("HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok", False{}, False{}) : Http.Frame}

law loop_100_cut_whole:
  {Http.res.frame(["HTTP/1.1 100 Continue\r\n\r\n"], True{}, False{}) == Http.frame("HTTP/1.1 100 Continue\r\n\r\n", True{}, False{}) : Http.Frame}

law loop_101_final_whole:
  {Http.res.frame(["HTTP/1.1 101 Switching Protocols\r\n\r\n"], False{}, False{}) == Http.frame("HTTP/1.1 101 Switching Protocols\r\n\r\n", False{}, False{}) : Http.Frame}

law loop_interim_cap_whole:
  {Http.res.frame([hints(9n)], False{}, False{}) == Http.frame(hints(9n), False{}, False{}) : Http.Frame}

law loop_interim_eight_whole:
  {Http.res.frame([{hints(8n) ++ "HTTP/1.1 200 OK\r\nContent-Length: 1\r\n\r\nZ" : String}], False{}, False{}) == Http.frame({hints(8n) ++ "HTTP/1.1 200 OK\r\nContent-Length: 1\r\n\r\nZ" : String}, False{}, False{}) : Http.Frame}

law loop_cookies_whole:
  {Http.res.frame(["HTTP/1.1 200 OK\r\nSet-Cookie: a=1\r\nSet-Cookie: b=2\r\nContent-Length: 0\r\n\r\n"], False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nSet-Cookie: a=1\r\nSet-Cookie: b=2\r\nContent-Length: 0\r\n\r\n", False{}, False{}) : Http.Frame}

law loop_cookies_bytes:
  {Http.res.frame(bytewise("HTTP/1.1 200 OK\r\nSet-Cookie: a=1\r\nSet-Cookie: b=2\r\nContent-Length: 0\r\n\r\n"), False{}, False{}) == Http.frame("HTTP/1.1 200 OK\r\nSet-Cookie: a=1\r\nSet-Cookie: b=2\r\nContent-Length: 0\r\n\r\n", False{}, False{}) : Http.Frame}

# RFC 9112 §6.3 (8): a body that ends at close leaves nothing to reuse the connection for.
law loop_close_rest:
  {Http.rt.rest(Http.rv.go(["HTTP/1.1 200 OK\r\n\r\nabc"], True{}, False{}, Http.RtMore{Http.rv.start()})) == None{} : Maybe<&1, Bytes.Bytes>}

# A self-delimited body leaves the bytes that came with its end, and no later read is taken.
law loop_cl_rest:
  {Http.rt.rest(Http.rv.go(["HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\no", "kNE", "XT"], False{}, False{}, Http.RtMore{Http.rv.start()})) == Some{Bytes.from_string("NE")} : Maybe<&1, Bytes.Bytes>}

# RFC 9112 §6.3: how a streamed body ends.
law stream_cl:
  {Http.rb.of(Http.set(Http.empty(), "content-length", "5"), False{}) == Some{Http.RbLen{5}} : Maybe<&2, Http.Rb>}

law stream_chunked:
  {Http.rb.of(Http.set(Http.empty(), "transfer-encoding", "chunked"), False{}) == Some{Http.RbChunk{Http.dc.start()}} : Maybe<&2, Http.Rb>}

law stream_cl_te:
  {Http.rb.of(Http.set(Http.set(Http.empty(), "content-length", "5"), "transfer-encoding", "chunked"), False{}) == None{} : Maybe<&2, Http.Rb>}

law stream_close:
  {Http.rb.of(Http.empty(), False{}) == Some{Http.RbClose{}} : Maybe<&2, Http.Rb>}

law stream_nobody:
  {Http.rb.of(Http.set(Http.empty(), "content-length", "5"), True{}) == Some{Http.RbDone{}} : Maybe<&2, Http.Rb>}

# A Content-Length body stops at its length; bytes past it are not body.
law stream_len_split:
  {Http.pc.of(Http.RbLen{3}, Bytes.from_string("abcdef")) == Http.Pc{Http.RbDone{}, Http.PoPiece{Bytes.from_string("abc")}} : Http.Pc}

# A short read is a piece, and the rest is still owed.
law stream_len_more:
  {Http.pc.of(Http.RbLen{5}, Bytes.from_string("ab")) == Http.Pc{Http.RbLen{3}, Http.PoPiece{Bytes.from_string("ab")}} : Http.Pc}

# A chunk split across reads gives the bytes that have arrived.
law stream_chunk_piece:
  {Http.pc.of(Http.RbChunk{Http.dc.start()}, Bytes.from_string("5\r\nhel")) == Http.Pc{Http.RbChunk{Http.DcData{2}}, Http.PoPiece{Bytes.from_string("hel")}} : Http.Pc}

# The last chunk ends the stream even when no data came with it.
law stream_chunk_end:
  {Http.pc.of(Http.RbChunk{Http.dc.start()}, Bytes.from_string("0\r\n\r\n")) == Http.Pc{Http.RbDone{}, Http.PoEnd{}} : Http.Pc}

# RFC 9112 §8: a close before Content-Length is met is an error.
law stream_len_cut:
  {Http.pc.eof(Http.RbLen{3}) == Http.Pc{Http.RbDone{}, Http.PoBad{Http.ErrBad{}}} : Http.Pc}

# A body with no Content-Encoding passes through as sent.

law decoded_plain:
  {Http.decoded(Http.Res{200, Http.empty(), Bytes.from_string("hi")}) == Done{Http.Res{200, Http.empty(), Bytes.from_string("hi")}} : Result<&1, &1, Http.Err, Http.Res>}

# Retry (RFC 9110 §9.2.2, §10.2.3, §15)
# --------------------------------------

def retry_now() -> Time.Instant:
  Time.Instant.of_unix(Int.I64.from_u32(784111775))

# LAW: 408, 429, 500, 502, 503 and 504 are retried; other statuses are not.
law retry_statuses:
  {[Http.retry.status(408), Http.retry.status(429), Http.retry.status(500), Http.retry.status(502), Http.retry.status(503), Http.retry.status(504), Http.retry.status(200), Http.retry.status(404), Http.retry.status(501)] == [True{}, True{}, True{}, True{}, True{}, True{}, False{}, False{}, False{}] : List<&2, Bool>}

# LAW: only idempotent methods may be tried again.
law retry_idempotent:
  {[Http.pool.idempotent("GET"), Http.pool.idempotent("HEAD"), Http.pool.idempotent("OPTIONS"), Http.pool.idempotent("TRACE"), Http.pool.idempotent("PUT"), Http.pool.idempotent("DELETE"), Http.pool.idempotent("POST"), Http.pool.idempotent("PATCH")] == [True{}, True{}, True{}, True{}, True{}, True{}, False{}, False{}] : List<&2, Bool>}

# LAW: a refused connect is retried, and the error is kept for when retries run out.
law retry_connect:
  {Http.retry.judge(True{}, Fail{Http.ErrConnect{61, "refused"}}) == (Fail{Http.ErrConnect{61, "refused"}}, Some{""}) : Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>}

# LAW: a timeout is retried.
law retry_timeout:
  {Http.retry.judge(True{}, Fail{Http.ErrTimeout{}}) == (Fail{Http.ErrTimeout{}}, Some{""}) : Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>}

# LAW: other errors would repeat, so they end the retries.
law retry_dns_stops:
  {Http.retry.judge(True{}, Fail{Http.ErrDns{}}) == (Fail{Http.ErrDns{}}, None{}) : Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>}

# LAW: a 503 is retried with its Retry-After, and the response is kept whole.
law retry_503:
  {Http.retry.judge(True{}, Done{Http.Res{503, Http.set(Http.empty(), "retry-after", "2"), Bytes.from_string("busy")}}) == (Done{Http.Res{503, Http.set(Http.empty(), "retry-after", "2"), Bytes.from_string("busy")}}, Some{"2"}) : Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>}

# LAW: a retryable status without Retry-After asks for the backoff ("").
law retry_429_backoff:
  {Http.retry.judge(True{}, Done{Http.Res{429, Http.empty(), Bytes.from_string("")}}) == (Done{Http.Res{429, Http.empty(), Bytes.from_string("")}}, Some{""}) : Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>}

# LAW: a success ends the retries.
law retry_200_stops:
  {Http.retry.judge(True{}, Done{Http.Res{200, Http.empty(), Bytes.from_string("ok")}}) == (Done{Http.Res{200, Http.empty(), Bytes.from_string("ok")}}, None{}) : Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>}

# LAW: POST is not retried, not even on a 503 or a refused connect.
law retry_post_stops:
  {Http.retry.judge(Http.pool.idempotent("POST"), Done{Http.Res{503, Http.empty(), Bytes.from_string("busy")}}) == (Done{Http.Res{503, Http.empty(), Bytes.from_string("busy")}}, None{}) : Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>}

law retry_post_connect_stops:
  {Http.retry.judge(Http.pool.idempotent("POST"), Fail{Http.ErrConnect{61, "refused"}}) == (Fail{Http.ErrConnect{61, "refused"}}, None{}) : Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>}

# LAW: the base wait doubles from 500 ms and stops at 30 s.
law retry_base:
  {[Http.retry.base(0n), Http.retry.base(1n), Http.retry.base(2n), Http.retry.base(3n), Http.retry.base(4n), Http.retry.base(5n), Http.retry.base(6n), Http.retry.base(20n)] == [500, 1000, 2000, 4000, 8000, 16000, 30000, 30000] : List<&2, U32>}

# LAW: for fixed jitter r, the wait is half the base plus r mod (half + 1).
law retry_backoff:
  {[Http.retry.backoff(0n, 0), Http.retry.backoff(0n, 4294967295), Http.retry.backoff(1n, 0), Http.retry.backoff(1n, 1000), Http.retry.backoff(3n, 7), Http.retry.backoff(6n, 0), Http.retry.backoff(10n, 4294967295)] == [250, 372, 500, 999, 2007, 15000, 15983] : List<&2, U32>}

# LAW: Retry-After in seconds is a wait in ms, at most 30 s.
law retry_after_secs:
  {[Http.retry.after("0", retry_now()), Http.retry.after("2", retry_now()), Http.retry.after("120", retry_now()), Http.retry.after("99999999999", retry_now())] == [Some{0}, Some{2000}, Some{30000}, Some{30000}] : List<&2, Maybe<&2, U32>>}

# LAW: Retry-After as an HTTP-date waits until then; a past date waits 0.
law retry_after_date:
  {[Http.retry.after("Sun, 06 Nov 1994 08:49:37 GMT", retry_now()), Http.retry.after("Sun, 06 Nov 1994 08:49:37 GMT", Time.Instant.of_unix(Int.I64.from_u32(784111800)))] == [Some{2000}, Some{0}] : List<&2, Maybe<&2, U32>>}

# LAW: an absent or unreadable Retry-After is no delay.
law retry_after_bad:
  {[Http.retry.after("", retry_now()), Http.retry.after("soon", retry_now()), Http.retry.after("-1", retry_now())] == [None{}, None{}, None{}] : List<&2, Maybe<&2, U32>>}

# LAW: Retry-After wins over the backoff; without it, the backoff.
law retry_delay:
  {[Http.retry.delay("3", retry_now(), 1n, 0), Http.retry.delay("", retry_now(), 1n, 0), Http.retry.delay("soon", retry_now(), 2n, 5)] == [3000, 500, 1005] : List<&2, U32>}

law proxy_no_exact:
  {Http.proxy.no_match("example.com", 80, "example.com") == True{} : Bool}

law proxy_no_subdomain:
  {Http.proxy.no_match("api.example.com", 443, ".example.com") == True{} : Bool}

law proxy_no_boundary:
  {Http.proxy.no_match("notexample.com", 80, "example.com") == False{} : Bool}

law proxy_no_port:
  {Http.proxy.no_match("example.com", 80, "example.com:443") == False{} : Bool}

law proxy_no_list:
  {Http.proxy.no_match("api.example.com", 443, " localhost , .example.com:443 ") == True{} : Bool}

law proxy_no_wildcard:
  {Http.proxy.no_match("example.com", 443, "*") == True{} : Bool}

law proxy_no_ipv6:
  {Http.proxy.no_match("::1", 443, "[::1]:443") == True{} : Bool}

law proxy_absolute_request:
  {Http.encode_req("GET", Http.proxy.absolute("http", "example.com:8080", "/x?q=1"),
    "example.com:8080", Http.empty(), Bytes.new(0)) ==
    Bytes.from_string("GET http://example.com:8080/x?q=1 HTTP/1.1\r\nconnection: close\r\nhost: example.com:8080\r\n\r\n") : Bytes.Bytes}

# Cookies (RFC 6265bis §5)
# ------------------------

def cookie_now() -> Time.Instant:
  Time.Instant.of_unix(Int.I64.from_u32(784111777))

def cookie_later(secs: U32) -> Time.Instant:
  Time.Instant.of_unix(Int.I64.from_u32((784111777 + secs : U32)))

def cookie_res(lines: List<&2, String>) -> Http.Res:
  Http.Res{200, Map.set(&2, List<&2, String>, Http.empty(), "set-cookie", lines), Bytes.new(0)}

def cookie_jar.of(r: Http.Jar & Http.Res) -> Http.Jar:
  (j, res) = r
  j

# The Cookie value sent to `to`, secs after `from` answered at cookie_now() with these Set-Cookie lines.
def cookie_sent(from: String, lines: List<&2, String>, secs: U32, to: String) -> String:
  Http.header(Http.jar.apply(Http.jar.at(cookie_jar.of(Http.jar.store(Http.jar.new(cookie_now()), from, cookie_res(lines))), cookie_later(secs)), to, Http.empty()), "cookie")

def cookie_after(lines: List<&2, String>, secs: U32) -> String:
  cookie_sent("https://s.example/", lines, secs, "https://s.example/")

def cookie_unix(m: Maybe<&2, Time.Instant>) -> Maybe<&2, U32>:
  match m:
    case None{}:
      None{}
    case Some{Time.Instant{s, n}}:
      Some{Int.I64.to_u32(s)}

# LAW: §5.1.3: a host domain-matches itself and a parent domain on a label boundary; an IP address matches only itself.
law cookie_domain_match:
  {[Http.cookie.domain_match("www.site.example", "site.example"), Http.cookie.domain_match("site.example", "site.example"), Http.cookie.domain_match("badsite.example", "site.example"), Http.cookie.domain_match("site.example", "www.site.example"), Http.cookie.domain_match("10.0.0.1", "0.0.1"), Http.cookie.domain_match("10.0.0.1", "10.0.0.1")] == [True{}, True{}, False{}, False{}, False{}, True{}] : List<&2, Bool>}

# LAW: §5.7: no Domain is host-only; Domain widens to subdomains, never to another site or a public suffix; ports do not matter.
law cookie_domain_scope:
  {[cookie_sent("https://www.site.example/", ["a=1"], 0, "https://www.site.example/x"), cookie_sent("https://www.site.example/", ["a=1"], 0, "https://sub.www.site.example/"), cookie_sent("https://www.site.example/", ["b=2; Domain=.Site.Example"], 0, "https://other.site.example/"), cookie_sent("https://www.site.example/", ["f=6; Domain=www.site.example"], 0, "https://x.www.site.example/"), cookie_sent("https://www.site.example/", ["c=3; Domain=evil.example"], 0, "https://evil.example/"), cookie_sent("https://www.site.example/", ["d=4; Domain=example"], 0, "https://other.example/"), cookie_sent("https://a.example/", ["e=5"], 0, "https://b.example/"), cookie_sent("https://a.example/", ["g=7"], 0, "http://a.example:8080/")] == ["a=1", "", "b=2", "f=6", "", "", "", "g=7"] : List<&2, String>}

# LAW: §5.1.4: a cookie path matches itself and the paths under it at a "/".
law cookie_path_match:
  {[Http.cookie.path_match("/docs", "/docs"), Http.cookie.path_match("/docs/web", "/docs"), Http.cookie.path_match("/docsets", "/docs"), Http.cookie.path_match("/docs/x", "/docs/"), Http.cookie.path_match("/docs", "/docs/"), Http.cookie.path_match("/", "/docs")] == [True{}, True{}, False{}, True{}, False{}, False{}] : List<&2, Bool>}

# LAW: §5.1.4: the default path is the request path up to its last "/", or "/".
law cookie_default_path:
  {[Http.cookie.default_path("/docs/web/page"), Http.cookie.default_path("/page"), Http.cookie.default_path(""), Http.cookie.default_path("/docs/"), Http.cookie.default_path("docs")] == ["/docs/web", "/", "/", "/docs", "/"] : List<&2, String>}

# LAW: §5.7, §5.8.3: the default or given path scopes a cookie, the query is not path, an invalid Path is the default, and longer paths go first.
law cookie_path_scope:
  {[cookie_sent("https://s.example/docs/login", ["a=1"], 0, "https://s.example/docs/x"), cookie_sent("https://s.example/docs/login", ["a=1"], 0, "https://s.example/other"), cookie_sent("https://s.example/docs/login", ["a=1"], 0, "https://s.example/docs?q=1"), cookie_sent("https://s.example/docs/login", ["z=1; Path=nope"], 0, "https://s.example/other"), cookie_sent("https://s.example/", ["x=1; Path=/", "y=2; Path=/docs"], 0, "https://s.example/docs/page")] == ["a=1", "", "a=1", "", "y=2; x=1"] : List<&2, String>}

# LAW: §5.1.1: cookie-dates in the common forms, and ones that are not dates.
law cookie_date:
  {[cookie_unix(Http.cookie.date("Sun, 06 Nov 1994 08:49:37 GMT")), cookie_unix(Http.cookie.date("Sunday, 06-Nov-94 08:49:37 GMT")), cookie_unix(Http.cookie.date("Sun Nov  6 08:49:37 1994")), cookie_unix(Http.cookie.date("Thu, 01-Jan-1970 00:00:01 GMT")), cookie_unix(Http.cookie.date("06 Nov 1994")), cookie_unix(Http.cookie.date("Sun, 31 Feb 1994 08:49:37 GMT")), cookie_unix(Http.cookie.date("Sun, 06 Nov 1600 08:49:37 GMT")), cookie_unix(Http.cookie.date("Sun, 06 Nov 1994 24:00:00 GMT"))] == [Some{784111777}, Some{784111777}, Some{784111777}, Some{1}, None{}, None{}, None{}, None{}] : List<&2, Maybe<&2, U32>>}

# LAW: §5.6.1, §5.6.2, §5.7: Max-Age beats Expires either way round, a cookie dies at its expiry, a past expiry deletes the cookie of the same path, session cookies last, leading zeros do not lengthen Max-Age, and no cookie outlives 400 days.
law cookie_expiry:
  {[cookie_after(["a=1; Max-Age=60"], 59), cookie_after(["a=1; Max-Age=60"], 60), cookie_after(["b=1; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Max-Age=60"], 0), cookie_after(["b=1; Max-Age=0; Expires=Wed, 06 Nov 1996 08:49:37 GMT"], 0), cookie_after(["c=1; Expires=Sun, 06 Nov 1994 08:49:36 GMT"], 0), cookie_after(["d=1; Expires=Sun, 06 Nov 1994 08:50:37 GMT"], 59), cookie_after(["d=1; Expires=Sun, 06 Nov 1994 08:50:37 GMT"], 60), cookie_after(["e=1", "e=; Max-Age=0"], 0), cookie_after(["e=1; Path=/", "e=; Max-Age=0; Path=/x"], 0), cookie_after(["f=1", "f=2"], 0), cookie_after(["g=1"], 315360000), cookie_after(["h=1; Max-Age=soon"], 315360000), cookie_after(["i=1; Max-Age=99999999999"], 34559999), cookie_after(["i=1; Max-Age=99999999999"], 34560000), cookie_after(["j=1; Expires=Wed, 06 Nov 2030 08:49:37 GMT"], 34560000), cookie_after(["k=1", "k=; Max-Age=0000000000"], 0), cookie_after(["l=1; Max-Age=00000000060"], 59), cookie_after(["l=1; Max-Age=00000000060"], 60)] == ["a=1", "", "b=1", "", "", "d=1", "", "", "e=1", "f=2", "g=1", "h=1", "i=1", "", "", "", "l=1", ""] : List<&2, String>}
