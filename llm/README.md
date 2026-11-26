# llm

A client for the Anthropic Messages API and the OpenAI Chat Completions API. Streaming uses an incremental SSE parser in `sse.bend`.

```bend
import bend-kit-llm@0.17.0.1/llm.bend as Llm
import bend-kit-llm@0.17.0.1/sse.bend as Sse
import bend-kit-hairpin@0.17.0.1/hairpin.bend as Hairpin
import bend-kit-http@0.44.0.2/http.bend as Http
import bend-kit-http@0.44.0.2/pure.bend as HttpPure
```

`llm.bend` imports HTTP model types and header helpers from `pure.bend`, runtime streams and effects from `http.bend`, and the client from `hairpin.bend`. `sse.bend` is part of this package. Import it when you drive the parser yourself.

`pure.bend` holds the request and response codecs, stream event decoding, and retry status policy. The laws import this module and `sse.bend`, so the proof gate does not load network effects. `llm.bend` converts the pure values at the runtime boundary and keeps its public types.

`anthropic(key)` and `openai(key)` build a `Client`. The client is affine. `send` and `stream` return it beside the result. `close` closes the idle sockets.

`Req` is `Req{model, system, msgs, max}`. `send` returns `Reply{id, model, text, stop, input, output}`. `stream` returns a `Stream` opened on the client's pool. `next` returns the next text piece, or `None` at the end. `stream.close(c, s)` closes the stream and returns the client. A stream read to its end gives its connection back to the pool, so the next `send` or `stream` to the same origin skips the TCP and TLS handshakes. A stream closed before its end closes its connection. Retries cover a refused connect, a timeout, 408, 409, 429, and 5xx, which holds Anthropic's 529. `send` and the open of `stream` retry through Hairpin (`request.as` and `open.as`), on a budget of `retry` + 1 attempts, with Hairpin's bounded backoff and circuit breaker. When the budget runs out on a refused stream, `ErrApi` holds the last status and its error body. `ErrNet` holds a `Hairpin.Err`.

A refused stream returns its connection to the pool when its error body is read to its end. Each chunk is appended to the error body before the next stream read. A drain that reaches its piece limit or fails closes the connection. `check.bend` checks that a multi-piece refusal keeps its first bytes and still respects the piece limit.

Tools and images go through the raw JSON path on the same client, not through `Req`. `smoke.bend` sends one reply and one stream to each API whose key is set: `ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN`, and `OPENAI_API_KEY`. `*_BASE_URL` and `*_MODEL` override the defaults.
