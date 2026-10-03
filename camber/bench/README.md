# Cross-framework HTTP comparison

This compares native Bend's existing raw/scoped controls with axum, Fastify, and FastAPI. It does not benchmark a complete Camber framework. The JavaScript server runs on Node, not Bend-on-Bun or `Bun.serve`.

## Run

Install the native [oha](https://github.com/hatoo/oha) load generator at the measured version, then run:

```sh
cargo install oha --version 1.16.0 --locked
python3 -B camber/bench/frameworks/run.py \
  --oha "$HOME/.cargo/bin/oha" \
  --output camber/bench/frameworks/results.json
```

The runner needs Bend, Cargo, Node, Bun (dependency installation only), and uv. It creates a temporary native Bend executable, release Rust executable, Python virtual environment, and binary payload file. It uses locked framework dependencies. It removes temporary binaries and payloads on normal completion without `--prepared`. It starts only one server at a time and guards deadlines and sampled RSS. Native Bend uses `--threads 1 --gpu off`; Rust uses a current-thread Tokio runtime; Node and Uvicorn each use one execution worker. This is not CPU affinity or a hard one-core quota.

`--prepared <owned-scratch>` reuses explicitly prepared binaries and a virtual environment. The result records that reuse instead of claiming a fresh build. The recorded run uses this option after its full socket smoke checks. `--duration`, `--trials`, and `--connections` default to two seconds, three trials, and 16 keep-alive connections. The load generator has two worker threads. HTTP/1.1 is explicit; there is no TLS, compression, or pipelining.

## Implementations

| Control | Transport and application layer |
| --- | --- |
| bend-raw | Existing `Raw.dispatch` on actual `Http.serve.on.with` |
| bend-scoped | Existing one-scope lifecycle on the same HTTP transport and business work |
| rust-hyper / rust-axum | Hyper HTTP/1 versus registered axum routes, shared Rust business work |
| js-http / js-fastify | Node HTTP versus registered Fastify routes, shared JavaScript business work |
| python-asgi / python-fastapi | Plain ASGI versus registered FastAPI routes, both on Uvicorn/uvloop/httptools, shared Python business work |

Versions are locked: axum 0.8.9, Hyper 1.11.1, Tokio 1.53.1, serde_json 1.0.151, Fastify 5.12.5, FastAPI 0.142.2, Starlette 1.7.0, Uvicorn 0.54.0, uvloop 0.23.0, and httptools 0.8.0. Runtime, compiler, generator, platform, and measurement settings are recorded in the result JSON. Dependencies are benchmark-only; no published package acquires them.

C is not included in this selected framework comparison. Its standard library has no HTTP server, and the approved comparison targets are Rust, JavaScript, and Python frameworks. The existing HTTP codec benchmark separately compares C, Rust, JavaScript, Python, and Bend.

## Work and correctness

The 19 workloads are the existing 18 raw controls plus authentication rejection:

- Fixed text and fixed JSON responses.
- A numeric user parameter with a JSON result.
- Parse and validate a 1 KiB JSON body containing one nonempty `name`, then encode that name.
- Zero, one, and five authorization checks with an observable hook count; reject an invalid credential.
- Last hit, miss, and wrong method in 10-, 100-, and 1,000-route profiles.
- Packed 64 KiB and 4 MiB binary echoes containing octets `7f 80 00 ff`.

Status, complete body bytes, Content-Length, media type, and required policy/method headers are checked through actual sockets before and after measured cells. Boundary probes check canonical route IDs, missing routes, method rejection, bad credentials, and a missing JSON field. All implementations use an 8 MiB body limit and compact JSON output. Fixed JSON is a literal in every implementation; only the decode/parameter workloads perform JSON serialization.

The native generator consumes complete bodies. Every measured sample must have only the expected status, no transport errors, and the exact aggregate response-byte count. This is not a per-response byte hash under load: exact bodies and headers are checked outside the timed generator. Invalid statuses and byte-count expectations were deliberately rejected during harness smoke validation. Expected 401/404/405 responses are successful benchmark outcomes, not transport failures.

## Measurement design

1. Calibrate each implementation/workload with a one-second closed-loop run.
2. Freeze each workload's common offered rate at half the slowest calibrated rate, with a minimum of one request per second.
3. Probe generator thread counts one, two, and four against the same Hyper fixed-text server.
4. Run three two-second closed-loop and fixed-rate trials per cell. Reverse implementation order on alternate rounds. Warm each cell for half a second before its measured trials.
5. Retain every raw sample and write results after each cell; do not discard slow trials or unexpected errors.

The fixed-rate trials use oha's `--latency-correction`; the reported latency includes scheduled-arrival delay. All started requests drain (`-w`) rather than being counted as deadline aborts. The fixed rate is identical across implementations, not a separate fraction of each server's capacity.

Server CPU is the delta of sampled cumulative `ps time`; it includes client startup and sampler boundaries. Server peak RSS is cumulative within that profile process, not a fresh per-cell or kernel peak. Client CPU and peak RSS come from `wait4` for the exact oha process; they exclude Python's sampler and are not process-tree measurements. On macOS the client kernel RSS is converted from bytes to KiB. The Python harness does not generate measured requests.

## Interpretation limits

- These are loopback generator/server measurements on one host, not production capacity or other-machine guarantees. No core affinity, frequency control, or exclusive-host claim is made.
- Generator scaling and client/server CPU reveal possible client limits; replacing Python does not automatically prove unlimited client headroom.
- Two-second trials are exploratory. Large-body tails and low fixed-rate sample counts need longer runs before precise p99 claims.
- Native Bend's route predicates specialize contiguous numeric paths. Frameworks register real literal routes; Python's plain control uses a dictionary, while its framework takes its own routing path. This is not a uniform routing algorithm or a general prepared-router scaling guarantee.
- The within-language difference includes routing, request/body adapters, and response construction. It is not a pure function-call overhead measurement. A framework can outperform the handwritten lower-level adapter.
- Framework controls use explicit byte responses and shared business validation. They do not exercise every framework's default schema/dependency/error machinery. FastAPI does not add Pydantic input/output model validation here; Fastify does not add JSON schema compilation. Bend's scoped control likewise is not the full typed application, transforms, File state, or final header guard.
- Authorization is the same synthetic credential comparison, not JWT verification. The callback models differ across frameworks; the observable number of checks and rejection result agree.
- JSON strictness, target normalization, malformed framing, cancellation, overload, shutdown, and production security are not declared equivalent outside the tested workload corpus.
- Header ordering, Date, and server-specific connection headers differ. Required semantics and response bodies agree; total wire overhead is not forced to be identical.

No performance target or old Camber overhead budget is altered by this comparison. SPEC, laws, public signatures, and published entry points are unchanged.

## Results

Median of three trials. All requests/s columns are closed-loop. Fixed-rate latency is corrected p99 in ms at the common rate shown. Full trials, p50/p95, client CPU/RSS, and status distributions are in [results.json](frameworks/results.json).

| workload | bend-raw | bend-scoped | rust-hyper | rust-axum | js-http | js-fastify | python-asgi | python-fastapi |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| text | 25,696 | 24,263 | 136,985 | 107,205 | 57,712 | 80,097 | 48,830 | 22,225 |
| json | 24,813 | 25,096 | 131,490 | 120,267 | 56,698 | 78,709 | 47,889 | 22,136 |
| parameter | 24,806 | 23,943 | 134,013 | 103,073 | 55,614 | 76,903 | 44,306 | 18,885 |
| json-1k | 21,960 | 22,003 | 117,107 | 107,467 | 49,969 | 66,681 | 39,674 | 18,758 |
| hooks-0 | 24,487 | 23,657 | 129,103 | 122,406 | 57,063 | 76,578 | 44,786 | 20,213 |
| hooks-1 | 23,614 | 23,668 | 132,093 | 124,439 | 57,213 | 79,274 | 48,163 | 20,552 |
| hooks-5 | 21,297 | 21,225 | 130,813 | 114,099 | 56,062 | 77,114 | 48,628 | 19,166 |
| hit-10 | 23,573 | 24,577 | 129,685 | 126,839 | 57,088 | 71,536 | 46,475 | 18,851 |
| miss-10 | 25,243 | 24,322 | 141,261 | 131,428 | 56,486 | 79,321 | 50,900 | 20,338 |
| method-10 | 24,034 | 24,494 | 138,896 | 126,492 | 53,631 | 70,005 | 58,719 | 20,934 |
| hit-100 | 24,788 | 23,795 | 128,810 | 111,826 | 54,712 | 62,354 | 43,979 | 11,193 |
| miss-100 | 24,106 | 23,784 | 131,257 | 112,349 | 58,782 | 61,999 | 49,152 | 11,623 |
| method-100 | 25,217 | 23,639 | 128,617 | 128,995 | 52,561 | 61,241 | 54,112 | 11,456 |
| hit-1000 | 22,439 | 23,371 | 42,460 | 120,777 | 46,013 | 70,626 | 29,386 | 1,870 |
| miss-1000 | 24,586 | 22,790 | 114,509 | 90,898 | 46,360 | 69,770 | 42,511 | 1,995 |
| method-1000 | 24,549 | 23,710 | 132,254 | 102,128 | 48,819 | 64,497 | 57,144 | 2,070 |
| echo-64k | 3,075 | 3,655 | 59,998 | 61,141 | 26,638 | 30,379 | 27,179 | 15,587 |
| echo-4m | 72 | 75 | 1,065 | 1,041 | 740 | 692 | 607 | 806 |
| auth-reject | 25,335 | 24,964 | 136,130 | 126,761 | 45,179 | 78,300 | 56,245 | 21,579 |

### Fixed-rate corrected p99

| workload | offered/s | bend-raw | bend-scoped | rust-hyper | rust-axum | js-http | js-fastify | python-asgi | python-fastapi |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| text | 10403 | 33.844 | 16.651 | 17.236 | 4.307 | 19.731 | 5.616 | 10.464 | 6.350 |
| json | 10792 | 14.387 | 10.570 | 12.324 | 9.134 | 5.048 | 12.941 | 13.410 | 16.473 |
| parameter | 7278 | 3.575 | 9.225 | 1.788 | 2.434 | 7.409 | 2.050 | 9.618 | 19.635 |
| json-1k | 1709 | 2.231 | 6.477 | 2.774 | 2.092 | 2.022 | 5.022 | 2.036 | 2.229 |
| hooks-0 | 4698 | 2.759 | 2.339 | 4.764 | 2.284 | 2.788 | 4.133 | 7.452 | 2.258 |
| hooks-1 | 5021 | 5.720 | 2.483 | 2.089 | 3.192 | 2.243 | 2.162 | 2.272 | 2.558 |
| hooks-5 | 8209 | 15.806 | 20.346 | 43.833 | 8.059 | 8.252 | 3.761 | 9.177 | 7.810 |
| hit-10 | 5198 | 2.686 | 13.225 | 2.354 | 2.015 | 3.439 | 2.055 | 2.069 | 22.230 |
| miss-10 | 6552 | 5.442 | 4.678 | 3.482 | 2.261 | 22.578 | 5.170 | 2.268 | 3.194 |
| method-10 | 10634 | 11.980 | 17.033 | 8.027 | 38.547 | 2.757 | 4.199 | 9.842 | 133.449 |
| hit-100 | 5315 | 5.289 | 4.389 | 1.851 | 6.050 | 2.288 | 1.951 | 2.069 | 7.106 |
| miss-100 | 5553 | 27.033 | 3.450 | 2.407 | 2.539 | 3.497 | 2.662 | 23.063 | 6.474 |
| method-100 | 5517 | 2.997 | 8.032 | 2.963 | 1.851 | 2.242 | 1.575 | 4.967 | 23.951 |
| hit-1000 | 1100 | 2.664 | 2.131 | 20.632 | 3.640 | 2.906 | 12.341 | 20.385 | 54.904 |
| miss-1000 | 1134 | 2.143 | 3.162 | 2.466 | 3.695 | 2.102 | 11.243 | 3.313 | 170.418 |
| method-1000 | 1135 | 3.104 | 33.831 | 3.050 | 3.023 | 3.136 | 8.241 | 3.182 | 5.656 |
| echo-64k | 1667 | 5.721 | 3.169 | 1.795 | 3.054 | 2.136 | 4.973 | 35.273 | 2.482 |
| echo-4m | 37 | 165.720 | 109.632 | 12.393 | 11.928 | 13.128 | 11.968 | 10.976 | 10.802 |
| auth-reject | 2962 | 2.784 | 1.102 | 1.847 | 2.804 | 3.575 | 2.258 | 2.063 | 2.193 |

### Framework/control throughput ratios

Median framework requests/s divided by median lower-level requests/s. Values below 1 mean lower throughput. This is an adapter comparison, not a pure middleware overhead ratio.

| workload | Bend scoped/raw | axum/Hyper | Fastify/Node | FastAPI/ASGI |
| --- | ---: | ---: | ---: | ---: |
| text | 0.94 | 0.78 | 1.39 | 0.46 |
| json | 1.01 | 0.91 | 1.39 | 0.46 |
| parameter | 0.97 | 0.77 | 1.38 | 0.43 |
| json-1k | 1.00 | 0.92 | 1.33 | 0.47 |
| hooks-0 | 0.97 | 0.95 | 1.34 | 0.45 |
| hooks-1 | 1.00 | 0.94 | 1.39 | 0.43 |
| hooks-5 | 1.00 | 0.87 | 1.38 | 0.39 |
| hit-10 | 1.04 | 0.98 | 1.25 | 0.41 |
| miss-10 | 0.96 | 0.93 | 1.40 | 0.40 |
| method-10 | 1.02 | 0.91 | 1.31 | 0.36 |
| hit-100 | 0.96 | 0.87 | 1.14 | 0.25 |
| miss-100 | 0.99 | 0.86 | 1.05 | 0.24 |
| method-100 | 0.94 | 1.00 | 1.17 | 0.21 |
| hit-1000 | 1.04 | 2.84 | 1.53 | 0.06 |
| miss-1000 | 0.93 | 0.79 | 1.50 | 0.05 |
| method-1000 | 0.97 | 0.77 | 1.32 | 0.04 |
| echo-64k | 1.19 | 1.02 | 1.14 | 0.57 |
| echo-4m | 1.05 | 0.98 | 0.93 | 1.33 |
| auth-reject | 0.99 | 0.93 | 1.73 | 0.38 |

### Generator scaling: Hyper text

| client threads | req/s | server CPU s | client CPU s | client peak MiB |
| --- | ---: | ---: | ---: | ---: |
| 1 | 104,423 | 1.490 | 1.763 | 104.1 |
| 2 | 128,435 | 1.770 | 2.881 | 113.4 |
| 4 | 123,403 | 1.740 | 4.133 | 87.8 |


### CPU and memory examples

Median closed-loop samples. CPU/response is server CPU delta divided by completed responses. Profile peak RSS is cumulative, so later cells include earlier activity. It is not steady-state memory.

| implementation/workload | server CPU s | server µs/response | client CPU s | server peak MiB | client peak MiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| bend-raw/text | 1.910 | 37.1 | 0.801 | 3.1 | 41.8 |
| bend-raw/hit-1000 | 1.820 | 40.5 | 0.761 | 3.1 | 35.5 |
| bend-raw/echo-4m | 2.010 | 12721.5 | 0.259 | 118.5 | 39.0 |
| bend-scoped/text | 1.840 | 37.9 | 0.722 | 3.1 | 35.3 |
| bend-scoped/hit-1000 | 1.890 | 40.4 | 0.774 | 3.2 | 36.4 |
| bend-scoped/echo-4m | 2.080 | 12606.1 | 0.263 | 119.0 | 39.1 |
| rust-hyper/text | 1.840 | 6.8 | 2.825 | 3.0 | 97.3 |
| rust-hyper/hit-1000 | 0.950 | 10.7 | 1.486 | 3.2 | 48.9 |
| rust-hyper/echo-4m | 1.880 | 871.8 | 1.861 | 203.3 | 40.5 |
| rust-axum/text | 1.670 | 7.8 | 2.422 | 3.6 | 81.6 |
| rust-axum/hit-1000 | 1.830 | 7.6 | 2.622 | 20.1 | 87.8 |
| rust-axum/echo-4m | 1.880 | 896.1 | 1.804 | 197.9 | 41.2 |
| js-http/text | 2.340 | 20.2 | 1.585 | 234.3 | 70.6 |
| js-http/hit-1000 | 2.080 | 22.6 | 1.507 | 231.9 | 54.0 |
| js-http/echo-4m | 2.550 | 1711.4 | 1.260 | 631.1 | 40.4 |
| js-fastify/text | 1.910 | 11.9 | 2.025 | 102.5 | 70.4 |
| js-fastify/hit-1000 | 1.840 | 12.9 | 2.008 | 129.6 | 64.3 |
| js-fastify/echo-4m | 2.430 | 1743.2 | 1.272 | 506.0 | 40.3 |
| python-asgi/text | 1.860 | 19.0 | 1.497 | 64.3 | 54.1 |
| python-asgi/hit-1000 | 1.490 | 25.3 | 1.201 | 71.2 | 40.0 |
| python-asgi/echo-4m | 1.700 | 1387.8 | 1.261 | 217.5 | 40.2 |
| python-fastapi/text | 1.920 | 43.1 | 0.778 | 64.6 | 35.1 |
| python-fastapi/hit-1000 | 1.770 | 470.4 | 0.190 | 71.6 | 20.8 |
| python-fastapi/echo-4m | 1.950 | 1213.2 | 1.251 | 211.8 | 40.7 |

### Longer focused generator check

Three five-second trials per configuration. Each list preserves trial order.

| Hyper workload/client threads | requests/s by trial |
| --- | --- |
| text-2 | 92,671, 90,954, 56,617 |
| text-4 | 62,068, 56,907, 44,322 |
| hit-1000-2 | 44,068, 50,929, 85,524 |
| hit-1000-4 | 109,511, 59,336, 51,563 |

## Findings

Recorded 2026-10-02 on macOS 26.6.2 arm64: Bend 2.0.34, Rust 1.91.0, Node 24.0.1, Python 3.14.6, oha 1.16.0. Prepared native Bend compilation took 26.654 s and sampled 8,202,560 KiB RSS. That build is outside the timed trials.

All 912 main trials passed status/error/aggregate-byte validation. The 152 calibration, nine original scaling, and 12 longer focused samples are retained too. No slow or unfavorable trial was removed.

- The scoped Bend control's median throughput is 0.93–1.19 times raw across this corpus; fixed text is 0.94 times raw. This prices the narrow existing scope, not a complete application framework.
- Bend scoped fixed text reaches about 24k requests/s versus axum 107k, Fastify 80k, and FastAPI 22k in these two-second measurements. Decode is about 22k versus 107k, 67k, and 19k. These observations do not establish precise capacity ratios.
- Large-body Bend throughput is the clear unfavorable result: about 75 four-MiB echoes/s versus roughly 1,041 axum, 692 Fastify, and 806 FastAPI. At the common 37/s offered rate, Bend raw/scoped corrected p99 is 166/110 ms versus roughly 11–13 ms for the other controls. Each fixed-rate trial contains only 74 responses. Packed bodies alone do not close the native HTTP gap.
- Fastify outperforms the deliberately simple Node async-iterator/Buffer aggregation adapter in most cells. This is not negative framework overhead: different adapters do different work. FastAPI's 1,000 literal-route profile falls to about 1.9–2.1k requests/s while its plain dictionary control is faster. Bend's specialized predicates do not justify a general router claim.
- The native generator remains material: increasing original Hyper text workers from one to two raises median throughput 23%; four workers reduces it 4%. At two workers, client CPU is 2.88 s versus server CPU 1.77 s over a two-second load. Longer focused trials still swing widely and extra threads do not give consistent gains. These are generator-sensitive, host-scheduling-sensitive loopback results, not a proven non-limiting client.
- Raw Hyper hit-1000 has original trial rates 13.5k, 42.5k, and 124.5k/s; scoped Bend text has a 9.2k/s trial versus two near 24k/s. Low CPU in several slow trials is consistent with scheduling gaps [INFERENCE], but no profiler proves their cause. Do not interpret the 2.84 axum/Hyper ratio for that cell as an isolated routing win.
- Calibration contains similarly low plain-ASGI trials; the common rates remain frozen from those observations, not retuned to flattering later medians. Corrected latency includes client scheduling and initial connections. Tail rankings across ordinary cells are unstable; the tables preserve them rather than claiming a winner.

The actionable direction is to profile native HTTP transport/body work before adding framework machinery. This comparison fixes none of the original routing, strict JSON, or cancellation findings. Later prepared routing addresses the routing gaps; the user-approved dedicated-process contract removes runtime cancellation as a release dependency, not the strict JSON or production transport requirements.

A separate [progress-under-load probe](../FINDINGS.md#progress-under-cpu-load) now shows ordinary-request and client-visible socket-close delays during serial pure CPU work in native single/default-thread and JS configurations. Those 21 observations are not part of this throughput dataset, and do not change its budgets or samples. They motivate measuring worst-case permitted parsing and handler work before claiming responsive production serving.

## Validation and review

Actual servers passed the matched pre/post socket checks and the load accounting gates. The runner's cleaned CLI was exercised after removal of two unused imports. Reuse, quality, and efficiency checks ran inline under the user's no-subagent constraint: existing Bend workloads/server guards are reused and each language shares its business work between controls. No new permanent tests or production package changes were needed for these experiment fixtures.

Code review: skipped (ce-code-review unavailable) — its independent-agent workflow cannot run under the user's no-subagent constraint. No independent review is claimed.
