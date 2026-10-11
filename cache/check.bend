# A versioned configuration cache, run against the real clock with a delayed fetch.
import Base
import ./cache.bend as C
import bend-kit-time@0.1.2.1/time.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int

# Values stay fresh for 1000 ms; a missing key is remembered for 400 ms.
def POLICY() -> C.Policy:
  C.Policy{1000n, 400n}

def ok(good: Bool, +name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad " ++ name)

# Monotonic milliseconds.
def clock() -> IO(Nat):
  do IO<Nat>:
    d : Time.Duration <- Time.mono()
    return Maybe.default(&2, Nat, Int.I64.to_nat(Time.Duration.to_ms(d)), 0n)

def shown(r: Maybe<&2, C.Entry<String>>) -> String:
  match r:
    case None{}:
      "none"
    case Some{C.Hit{v, x, t}}:
      "v" ++ Nat.show(v) ++ " " ++ x
    case Some{C.Miss{t}}:
      "missing"

# Reads key at the current clock and checks the answer, version included.
def expect(+c: C.Cache<String>, +key: String, +want: String, +name: String) -> IO(Unit):
  do IO<Unit>:
    now : Nat <- clock()
    +got : String = shown(C.Cache.read(~String, c, key, now))
    ok(String.eq(got, want), name ++ ": " ++ key ++ " is " ++ got)

# Starts a fetch and completes it at once.
def fetch.now(p: C.Ticket & C.Cache<String>, r: C.Found<String>) -> C.Cache<String>:
  (t, c) = p
  C.Cache.complete(~String, c, t, r)

def fetch(c: C.Cache<String>, +key: String, +now: Nat, r: C.Found<String>) -> C.Cache<String>:
  fetch.now(C.Cache.start(~String, c, key, now), r)

# A fetch that answers what upstream held when it started, ms later.
def fetch.slow(ms: U32, r: C.Found<String>) -> IO(C.Found<String>):
  do IO<C.Found<String>>:
    IO.sleep(ms)
    return r

# Eviction: fetch F starts, then E. Evicting flags drops only its entry: limits
# stays, E still lands, and F, older than E, is still dropped after it.
def evicted.landed(tf: C.Ticket, +c: C.Cache<String>) -> IO(Unit):
  do IO<Unit>:
    expect(c, "flags", "v5 dark=never", "a fetch in flight lands after an eviction")
    +d : C.Cache<String> = C.Cache.complete(~String, c, tf, C.Found{4n, "dark=auto"})
    expect(d, "flags", "v5 dark=never", "an older fetch stays dropped after an eviction")

def evicted.go(tf: C.Ticket, p: C.Ticket & C.Cache<String>) -> IO(Unit):
  match p:
    case (te, c):
      +e : C.Cache<String> = C.Cache.evict(~String, c, "flags")
      do IO<Unit>:
        expect(e, "flags", "none", "an evicted key serves nothing")
        expect(e, "limits", "v1 rps=100", "an eviction leaves other keys as they were")
        evicted.landed(tf, C.Cache.complete(~String, e, te, C.Found{5n, "dark=never"}))

def evicted(p: C.Ticket & C.Cache<String>, +now: Nat) -> IO(Unit):
  match p:
    case (tf, c):
      evicted.go(tf, C.Cache.start(~String, c, "flags", now))

# Expiry and negative results, against the real clock.
def expiry(+c: C.Cache<String>) -> IO(Unit):
  do IO<Unit>:
    expect(c, "flags", "v4 dark=auto", "a fresh entry is served")
    expect(c, "beta", "missing", "a missing key is remembered")
    IO.sleep(600)
    expect(c, "beta", "none", "a missing key expires after its negative ttl")
    expect(c, "flags", "v4 dark=auto", "an entry stays until its ttl")
    IO.sleep(600)
    expect(c, "flags", "none", "an entry expires after its ttl")
    +now : Nat <- clock()
    +d : C.Cache<String> = fetch(fetch(c, "flags", now, C.Found{4n, "dark=auto"}), "limits", now, C.Found{1n, "rps=100"})
    evicted(C.Cache.start(~String, d, "flags", now), now)

# Two fetches race without an invalidation: the newer lands first, then the older arrives.
def race.go(tc: C.Ticket, p: C.Ticket & C.Cache<String>) -> C.Cache<String>:
  (td, c) = p
  C.Cache.complete(~String, C.Cache.complete(~String, c, td, C.Found{3n, "dark=auto"}), tc, C.Found{2n, "dark=on"})

def race(p: C.Ticket & C.Cache<String>, +now: Nat) -> C.Cache<String>:
  (tc, c) = p
  race.go(tc, C.Cache.start(~String, c, "flags", now))

def raced(+c: C.Cache<String>) -> IO(Unit):
  do IO<Unit>:
    expect(c, "flags", "v3 dark=auto", "an older completion does not overwrite a newer one")
    +now : Nat <- clock()
    +d : C.Cache<String> = fetch(C.Cache.invalidate(~String, c, "flags"), "flags", now, C.Found{4n, "dark=auto"})
    expiry(fetch(d, "beta", now, C.Missing{}))

def delayed(ta: C.Ticket, chan: Chan(C.Found<String>), p: C.Ticket & C.Cache<String>) -> IO(Unit):
  match p:
    case (tb, c):
      +d : C.Cache<String> = C.Cache.complete(~String, c, tb, C.Found{2n, "dark=on"})
      do IO<Unit>:
        expect(d, "flags", "v2 dark=on", "a fetch after the invalidation lands")
        r : C.Found<String> <- IO.join(C.Found<String>, chan)
        +e : C.Cache<String> = C.Cache.complete(~String, d, ta, r)
        expect(e, "flags", "v2 dark=on", "a delayed fetch from before the invalidation is dropped")
        +now : Nat <- clock()
        raced(race(C.Cache.start(~String, e, "flags", now), now))

# Fetch A starts while upstream holds v1. Upstream moves to v2 and the key is
# invalidated. Fetch B starts and lands. A answers v1 150 ms later.
def started(p: C.Ticket & C.Cache<String>) -> IO(Unit):
  match p:
    case (ta, c):
      do IO<Unit>:
        chan : Chan(C.Found<String>) <- IO.fork(C.Found<String>, fetch.slow(150, C.Found{1n, "dark=off"}))
        +d : C.Cache<String> = C.Cache.invalidate(~String, c, "flags")
        expect(d, "flags", "none", "an invalidated key serves nothing")
        now : Nat <- clock()
        delayed(ta, chan, C.Cache.start(~String, d, "flags", now))

def main() -> IO(Unit):
  do IO<Unit>:
    +c : C.Cache<String> = C.Cache.new(String, POLICY())
    expect(c, "flags", "none", "a new cache serves nothing")
    now : Nat <- clock()
    started(C.Cache.start(~String, c, "flags", now))
