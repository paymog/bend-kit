# llm

A client for the Anthropic Messages API and the OpenAI Chat Completions API. Streaming uses an incremental SSE parser in `sse.bend`.

```bend
import bend-kit-llm@0.3.0.0/llm.bend as Llm
import bend-kit-llm@0.3.0.0/sse.bend as Sse
import bend-kit-hairpin@0.3.0.0/hairpin.bend as Hairpin
import bend-kit-http@0.32.0.0/http.bend as Http
```

`llm.bend` imports that `http` and `hairpin`. `sse.bend` is part of this package. Import it when you drive the parser yourself.

`anthropic(key)` and `openai(key)` build a `Client`. The client is affine. `send` and `stream` return it beside the result. `close` closes the idle sockets.

`Req` is `Req{model, system, msgs, max}`. `send` returns `Reply{id, model, text, stop, input, output}`. `stream` returns a `Stream`. `next` returns the next text piece, or `None` at the end. Retries cover a refused connect, a timeout, 408, 409, 429, and 5xx, which holds Anthropic's 529. `send` retries through Hairpin, on a budget of `retry` + 1 attempts, with Hairpin's bounded backoff. `stream` still retries the open with its own loop on `Http.open.with`. `ErrNet` holds a `Hairpin.Err`.

Tools and images go through the raw JSON path on the same client, not through `Req`. `smoke.bend` sends one reply and one stream to each API whose key is set: `ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN`, and `OPENAI_API_KEY`. `*_BASE_URL` and `*_MODEL` override the defaults.
