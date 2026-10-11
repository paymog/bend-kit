# cache

Cache validity for keyed values: expiry, negative results, invalidation, eviction, and fetch completions that cannot bring back stale data. It decides what a cache may serve. It does not fetch, store to disk, or talk to the network: your code does the fetch, and the cache decides whether the result lands.

```bend
import bend-kit-cache@0.1.0.0/cache.bend as C
```

It imports `bend-kit-collections@0.1.2.0` (`omap.bend`). Keys are `String`; values are any `Data` type `V`.

## Example

A configuration value changes upstream while a fetch of the old value is in flight. The late answer does not land.

```bend
import Base
import bend-kit-cache@0.1.0.0/cache.bend as C

def show(r: Maybe<&2, C.Entry<String>>) -> String:
  match r:
    case Some{C.Hit{v, x, t}}:
      "v" ++ Nat.show(v) ++ " " ++ x
    case Some{C.Miss{t}}:
      "missing"
    case None{}:
      "fetch"

def landed(old: C.Ticket, +c: C.Cache<String>, +now: Nat) -> IO(Unit):
  do IO<Unit>:
    IO.print(show(C.Cache.read(~String, c, "flags", now)))
    # The first fetch answers late. It started before the invalidation, so v2 stays.
    IO.print(show(C.Cache.read(~String, C.Cache.complete(~String, c, old, C.Found{1n, "dark=off"}), "flags", now)))

def refetched(old: C.Ticket, p: C.Ticket & C.Cache<String>, +now: Nat) -> IO(Unit):
  match p:
    case (t, c):
      landed(old, C.Cache.complete(~String, c, t, C.Found{2n, "dark=on"}), now)

def started(p: C.Ticket & C.Cache<String>, +now: Nat) -> IO(Unit):
  match p:
    case (old, c):
      # Upstream changed: void the fetch in flight, then fetch again.
      refetched(old, C.Cache.start(~String, C.Cache.invalidate(~String, c, "flags"), "flags", now), now)

def main() -> IO(Unit):
  do IO<Unit>:
    +now : Nat <- IO.now()
    started(C.Cache.start(~String, C.Cache.new(String, C.Policy{60000n, 5000n}), "flags", now), now)
```

It prints `v2 dark=on` twice. [check.bend](check.bend) runs the same story with a real delayed fetch on another task, then expiry, negative results, and eviction against the monotonic clock.

## Model

Each key has a `Slot{next, floor, entry}`.

- **Key identity.** Two keys are the same key when their strings are equal, code point by code point.
- **Generations.** `start` gives each fetch of a key the generation `next`, then raises `next`. The `Ticket` holds the key, the generation, and the clock at the start. It is affine, so a fetch completes at most once.
- **Completion.** `complete` stores a result only when `floor <= gen < next`. It then sets `floor` to `gen + 1`, so a fetch that started earlier can never land after it. Otherwise the cache does not change.
- **Expiry.** A `Found{version, value}` becomes `Hit{version, value, at + ttl}`, and `Missing` becomes `Miss{at + negative_ttl}`, where `at` is the clock when the fetch started. Age counts from the start, so time spent fetching counts against freshness.
- **Fresh reads.** `read(c, key, now)` serves an entry only while `now < expires`. Otherwise it answers `None`, and the caller must fetch.
- **Invalidation.** `invalidate` drops the entry and sets `floor` to `next`. Every fetch already started for that key becomes stale.
- **Eviction.** `evict` drops the entry and keeps `next` and `floor`. Eviction keeps one slot (two `Nat`s) for every key the cache has seen. That is what keeps a stale fetch stale after its key is evicted.

## API

| def | does |
|---|---|
| `Cache.new(V, policy)` | An empty cache. `Policy{ttl, negative_ttl}` is in the units of your clock. |
| `Cache.read(~V, c, key, now)` | The fresh `Entry` for `key` at `now`, or `None`. |
| `Cache.start(~V, c, key, at)` | Starts a fetch at clock `at`. Answers `(ticket, cache)`. |
| `Cache.complete(~V, c, ticket, found)` | Stores what the fetch found, unless its ticket is stale. |
| `Cache.invalidate(~V, c, key)` | Drops the entry and voids the fetches in flight. |
| `Cache.evict(~V, c, key)` | Drops the entry. Fetches in flight still land; stale ones stay stale. |

The `Slot.*` defs are the same operations on one key, and they are what the laws cover.

## Laws

`LAWS.bend` states these for every slot, generation, clock value, and policy, and over any list of operations (`start`, `complete`, `invalidate`, `evict`) on one key. `PROOF.bend` proves them.

| law | claim |
|---|---|
| `read_fresh` | A read never serves an entry with `expires <= now`. |
| `read_serves`, `read_expired` | An entry is served exactly while `now < expires`. |
| `new_valid`, `run_valid` | Every reachable slot has `floor <= next`. |
| `run_floor` | The floor never goes down. |
| `start_lands`, `complete_lands` | A fetch at or above the floor lands, and the floor passes it. |
| `complete_stale` | A completion below the floor changes nothing. |
| `stale_forever` | Once a generation is below the floor, after any operations, its completion changes nothing. |
| `invalidate_clears` | An invalidated key serves nothing. |
| `invalidate_forever` | A fetch started before an invalidation never lands, whatever follows. |
| `older_loses` | After fetch `g` lands, a fetch at or below `g` cannot overwrite it. |
| `negative_served`, `negative_expires` | A `Missing` result is served as `Miss` exactly until `at + negative_ttl`. |
| `evict_clears` | An evicted key serves nothing. |
| `evict_only_availability` | After any operations, a slot that was evicted equals the slot that was not, up to its current entry. Eviction changes what is cached now, never which fetches land or what they store. |

Equality in the laws is equality of `Slot` values: same `next`, same `floor`, same entry.

The laws cover one key. The keyed `Cache` reads a key's slot with `OMap.get`, applies the slot operation, and writes it back with `OMap.put`, using `key.cmp` as the order. That other keys do not change rests on `omap_get_put_same` and `omap_get_put_other_key`, proven in `collections`, and on `key.cmp` being a total order, which is not proven here. `check.bend` tests it: evicting one key leaves another key's value as it was.

## Trust boundary

- **Clock.** The core takes the clock as a `Nat` argument. Pass a monotonic clock, such as `Time.mono` in milliseconds, as `check.bend` does. A wall clock that goes back can keep an entry fresh for too long.
- **Upstream versions.** The cache orders fetches by when they started, not by the upstream `version`. It assumes upstream is linearizable: a fetch that starts later sees a version at least as new. A replica that lags can answer an older version to a newer fetch, and the cache stores it. `version` is reported, not compared.
- **Invalidation.** The cache learns of an upstream change only when you call `invalidate`. Until then it serves the old value up to its TTL.
- **One owner.** A `Cache` is a value. Keep it in one task and run fetches elsewhere, as `check.bend` does: the forked task only fetches, and the main task completes. Two copies of a cache that both take completions diverge.
- **Tickets.** A ticket names a key and a generation, not a cache. Complete it on the cache that issued it.
- **Not distributed.** This is the validity of one process's cache. Coherence across processes needs a protocol on top, such as versioned invalidation messages.
- **Memory.** Eviction keeps each key's slot. A cache that sees unboundedly many keys grows without bound.

## Checks

`bend PROOF.bend --check-only` proves the laws. `bend check.bend` runs the configuration-cache scenario and prints the version each read returns:

- a delayed fetch, started before an invalidation, answers after a newer fetch lands, and is dropped;
- two fetches race without an invalidation, and the older answer does not overwrite the newer one;
- a `Missing` result is served until its negative TTL, and a value until its TTL, on the real clock;
- an eviction drops one key, leaves another, lets a fetch in flight land, and keeps an older fetch dropped.

`bench/` times stores and fresh reads against Rust, Python, and JavaScript TTL caches. See [bench/README.md](bench/README.md).
