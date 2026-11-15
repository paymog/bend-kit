# gateway

A guarded read-through gateway. One `Gate` authorizes a request with `authz`, takes one unit from a `resources` pool, and reads a `cache`. A hit gives the unit back at once. A miss keeps the unit and starts a fetch; `finish` stores what the fetch found and gives the unit back.

```bend
import bend-kit-gateway@0.4.0.0/gateway.bend as G
```

It imports `bend-kit-authz@0.1.0.0`, `bend-kit-resources@0.1.0.0`, and `bend-kit-cache@0.3.1.0`. Import those versions to build an `Az.Policy`, an `Az.Request`, or a `C.Policy`. Cached values are `String`.

```
authz.granted --> resources.reserve --> Cache.read
  hit  --> respond, release
  miss --> Cache.start --> fetch (hairpin: budget + breaker) --> Cache.complete --> respond, release
```

## Example

```bend
import Base
import bend-kit-authz@0.1.0.0/authz.bend as Az
import bend-kit-cache@0.3.1.0/cache.bend as C
import bend-kit-gateway@0.4.0.0/gateway.bend as G

def readers() -> Az.Policy:
  Az.Permit{Az.Role{"reader"}}

def alice() -> Az.Request:
  Az.Request{Some{"alice"}, Some{["reader"]}, None{}, "GET", "/items/1"}

def gate.of(f: G.Finish) -> G.Gate:
  match f:
    case G.Settled{g}:
      g
    case G.Unheld{g}:
      g

def served(b: G.Begin) -> String:
  match b:
    case G.Fresh{g, C.Hit{v, x, t}}:
      x
    case _:
      "no hit"

# The first read misses. The fetch answers "one"; finish stores it and gives the unit back.
def fetched(b: G.Begin) -> String:
  match b:
    case G.Fetch{g, p}:
      served(G.begin(readers(), alice(), gate.of(G.finish(g, p, G.Fetched{C.Found{1n, "one"}})), "/items/1", 20n))
    case _:
      "no fetch"

def main() -> String:
  fetched(G.begin(readers(), alice(), G.new(7n, 2n, C.Policy{1000n, 100n}), "/items/1", 10n))
```

`main` answers `"one"`: the second read is a hit.

## API

| def | does |
|---|---|
| `new(owner, capacity, ttl)` | An empty gate: a pool of `capacity` units named `owner`, and an empty cache with the `C.Policy` TTLs. |
| `begin(policy, req, gate, key, now)` | Authorizes `req`, takes one unit, and reads `key` at clock `now`. |
| `finish(gate, pending, upstream)` | Stores what the fetch did and gives its unit back. |
| `start(cache, key, at)`, `settle(cache, pending, upstream)` | The cache steps that `begin` and `finish` take, as data. |

`begin` answers a `Begin`:

| answer | meaning | unit |
|---|---|---|
| `Denied{gate}` | `Az.granted` said no. | none taken |
| `Busy{gate}` | The pool is full. | none taken |
| `Fresh{gate, entry}` | A fresh `Hit` or `Miss` entry. | taken and given back |
| `Fetch{gate, pending}` | Fetch upstream, then call `finish` with `pending`. | held until `finish` |

`Pending{key, gen, at}` is the cache ticket as data, so it can cross to the task that fetches. `Upstream` is `Fetched{C.Found}` (a value or `Missing`) or `Failed` (an upstream error, a spent budget, or an open breaker; the cache does not change). `finish` answers `Settled{gate}`, or `Unheld{gate}` when no unit was lent.

The gate keeps one grant that joins every unit it lent, as `http` admission does: a take reserves one unit and joins it; a give splits one unit off and releases it.

## Laws

`LAWS.bend` states these for every policy, request, pool, cache, key, clock value, and upstream result. `PROOF.bend` proves them.

| law | claim |
|---|---|
| `denied_untouched` | A denied request reserves nothing and starts no fetch: the gate comes back unchanged. |
| `busy_untouched` | A granted request that does not fit answers `Busy` and changes nothing. |
| `hit_releases` | A fresh hit takes one unit and gives it back: the gate comes back unchanged. |
| `miss_holds` | A miss holds one more unit in the pool and the grant, and starts one fetch at `now`. |
| `finish_releases` | A `finish` gives back exactly the one unit, whatever upstream did. |
| `finish_unheld` | A `finish` with no unit lent frees nothing. |
| `every_path_releases` | Every path ends with the pool and grant it started with: deny, busy, hit, and a miss that finishes with a value, `Missing`, a failure, or an open breaker. |
| `older_fetch_loses` | Two fetches of one key race. The newer one lands first. The older one's answer, whatever it is, does not change the cache. |

## Camber app

`app.bend` is a Camber application with one route, `GET /items/:id`. `check.bend`, `demo.bend`, and `upstream.bend` use it. They are repository examples, not published modules; compile them from this checkout.

- One `Gate` lives in a Camber dependency owner (`C.start`, one bundle). Each request calls it twice: `OpBegin`, then `OpFinish` after a miss. The owner runs one operation at a time and answers `Exhausted` to the others, so `call` tries again every millisecond. A finish has to land, or its unit would stay lent.
- The handler reads `Time.mono.ms()` once. That value is the cache clock and the start of the retry budget (`Retry.Budget.new(attempts, now, Some{deadline})`).
- Each Camber request slot owns one `Hairpin.Client` with a step timeout, one retry, and a circuit breaker (`Retry.Circuit{2n, 10000n, 2000n, 1n}`).
- `x-subject` and `x-roles` stand for a verified identity. The policy lets `reader` read and denies `suspended`.

| path | status | `x-cache` |
|---|---|---|
| denied | 403 | none |
| pool full | 503 | `busy` |
| fresh hit | 200, or 404 for a remembered missing item | `hit` |
| miss | the upstream 200 or 404 | `miss` |
| upstream failure | 502 | `miss` |
| open breaker | 503 | `open` |

### Run it

```sh
bend gateway/upstream.bend -o /tmp/gw-upstream
bend gateway/demo.bend -o /tmp/gw-demo
/tmp/gw-upstream 18470 &
/tmp/gw-demo 18471 http://127.0.0.1:18470/
```

The demo admits 2 requests at once, keeps values for 30 s and missing items for 10 s, and has 4 request slots. The upstream answers 404 for `/items/gone`, 500 for `/items/broken`, after 1.5 s for `/items/slow-a`, `-b`, and `-c`, and `item <path>` for anything else. It prints each request it serves.

```sh
curl -i -H 'x-subject: alice' -H 'x-roles: reader' http://127.0.0.1:18471/items/1
```

A native run on 2026-10-13 (macOS arm64, Bend 2.0.36) printed this, in order:

| request | status | `x-cache` | body |
|---|---|---|---|
| `/items/1`, no role | 403 | | |
| `/items/1`, `reader,suspended` | 403 | | |
| `/items/1` | 200 | `miss` | `item /items/1` |
| `/items/1` | 200 | `hit` | `item /items/1` |
| `/items/gone` | 404 | `miss` | |
| `/items/gone` | 404 | `hit` | |
| `/items/slow-a` and `/items/slow-b` at once, then `/items/2` beside them | 200, 200, 503 | `miss`, `miss`, `busy` | |
| `/items/broken` | 502 | `miss` | |
| `/items/3` | 503 | `open` | |
| `/items/1` | 200 | `hit` | `item /items/1` |
| `/items/3`, 2.2 s later | 200 | `miss` | `item /items/3` |

The upstream saw `/items/1`, `/items/gone`, `/items/slow-a`, `/items/slow-b`, `/items/broken` twice (one retry), and `/items/3` once. Hits, denials, the busy request, and the request against the open breaker never reached it.

## Trust boundary

- The laws cover the pure gate. They do not cover the Camber owner, the sockets, the clock, or the retry loop in `hairpin`. `check.bend` and the demo test those.
- `Pending` is data, so code can call `finish` twice for one fetch. The app calls it once per `Fetch`. A stray `finish` with nothing lent is `Unheld` (`finish_unheld`); a stray `finish` while other units are lent gives one of theirs back.
- `older_fetch_loses` is proved on a cache that holds the one key. That other keys stay unchanged rests on the `collections` OMap laws and on the order facts of the cache's key comparator, as in `cache`.
- The cache orders fetches by when they started, not by upstream version. The app stores version 0 for every value.
- Each request slot has its own breaker. With requests at once on several slots, each slot opens after its own failures.
- `call` gives up after 60,000 tries (about a minute). A finish that gives up leaves its unit lent.
- Cached values are `String`s, one list cell per character. Large bodies are slow to cache.

## Checks

`bend PROOF.bend --check-only` proves the laws. `bend check.bend` starts the local upstream and runs the Camber app through `C.dispatch` with a gate of capacity 1. It checks each status and `x-cache` header and the units lent: a denied request reserves nothing, a slow fetch holds one unit while a request beside it gets 503, and after a failure (502), an open breaker (503), and a hit served while the breaker is open, no unit is lent. `bench/` times a guarded hit against Rust, Python, and JavaScript. See [bench/README.md](bench/README.md).
