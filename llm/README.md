# llm

A client for the Anthropic Messages API and the OpenAI Chat Completions API. Streaming uses an incremental SSE parser in `sse.bend`.

```bend
import bend-kit-llm@0.13.0.1/llm.bend as Llm
import bend-kit-llm@0.13.0.1/sse.bend as Sse
import bend-kit-hairpin@0.13.0.1/hairpin.bend as Hairpin
import bend-kit-http@0.38.1.1/http.bend as Http
```

`llm.bend` imports that `http` and `hairpin`. `sse.bend` is part of this package. Import it when you drive the parser yourself.

`anthropic(key)` and `openai(key)` build a `Client`. The client is affine. `send` and `stream` return it beside the result. `close` closes the idle sockets.

`Req` is `Req{model, system, msgs, max}`. `send` returns `Reply{id, model, text, stop, input, output}`. `stream` returns a `Stream` opened on the client's pool. `next` returns the next text piece, or `None` at the end. `stream.close(c, s)` closes the stream and returns the client. A stream read to its end gives its connection back to the pool, so the next `send` or `stream` to the same origin skips the TCP and TLS handshakes. A stream closed before its end closes its connection. Retries cover a refused connect, a timeout, 408, 409, 429, and 5xx, which holds Anthropic's 529. `send` and the open of `stream` retry through Hairpin (`request.as` and `open.as`), on a budget of `retry` + 1 attempts, with Hairpin's bounded backoff and circuit breaker. When the budget runs out on a refused stream, `ErrApi` holds the last status and its error body. `ErrNet` holds a `Hairpin.Err`.

Tools and images go through the raw JSON path on the same client, not through `Req`. `smoke.bend` sends one reply and one stream to each API whose key is set: `ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN`, and `OPENAI_API_KEY`. `*_BASE_URL` and `*_MODEL` override the defaults.
