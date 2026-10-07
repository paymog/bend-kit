# url

RFC 3986 paths, queries, absolute `http` and `https` URLs, and percent-encoding.

```bend
import bend-kit-url@0.4.1.0/url.bend as Url
```

`parse` reads an origin-form target, such as `/x?a=1&b=2`, into `Url{path, query}`. It does not read an absolute URL. `encode` writes that value back. `form` writes `application/x-www-form-urlencoded` text. Space is `%20`.

`absolute` reads an absolute `http` or `https` URL into `Abs{scheme, host, port, target}`. A bracketed IPv6 host stays bracketed. `resolve(base, ref)` applies RFC 3986 §5.2 and returns `None` when `ref` has another scheme.

`pct.encode_path`, `pct.encode_q`, and `pct.decode` are the percent-encoding helpers. `pct.decode` returns `None` on a bad escape.

`http` imports this package as `0x1f2d80f53f971b16c6de6a65cb1918ae/url.bend`, which is this version. Pass that import's `Abs` into code that expects `http`'s URL type.
