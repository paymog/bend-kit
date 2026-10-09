import Base
import ./webhooks.bend as W
import ../hairpin/hairpin.bend as Hairpin
import ../hairpin/retry.bend as Retry
import ../http/http.bend as Http
import ../http/admission.bend as Admission
import ../http/completion.bend as Completion
import bend-kit-time@0.1.0.0/time.bend as Time
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# HMAC and the constant-time compare need libcrypto, so actual sign and verify run here; LAWS.bend covers framing.
# Fixtures:
# - Standard Webhooks: the reference vector of the official libraries' tests, e.g.
#   https://github.com/standard-webhooks/standard-webhooks/blob/main/libraries/python/tests/test_webhooks.py
# - GitHub: the example in https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries#testing-the-webhook-payload-validation
# - Stripe publishes no fixed signature. The payload and secret are stripe-node's README test fixture
#   (https://github.com/stripe/stripe-node#testing-webhook-signing): JSON.stringify({id: 'evt_test_webhook', object: 'event'}, null, 2)
#   under 'whsec_test_secret'. The signature at t=1614265330 was computed independently, per
#   https://docs.stripe.com/webhooks#verify-manually, with Python:
#   hmac.new(b"whsec_test_secret", b"1614265330." + payload, hashlib.sha256).hexdigest()
# - The second Standard Webhooks key, whsec_ + base64("this is a second key for tests"), is a throwaway;
#   its signature of the reference message was computed the same way, base64 of the HMAC.

def name(e: W.Err) -> String:
  match e:
    case W.Missing{n}:
      "Missing " ++ n
    case W.BadSecret{}:
      "BadSecret"
    case W.BadId{}:
      "BadId"
    case W.BadTimestamp{}:
      "BadTimestamp"
    case W.TooOld{}:
      "TooOld"
    case W.TooNew{}:
      "TooNew"
    case W.NoMatch{}:
      "NoMatch"
    case W.CryptoErr{c, m}:
      "CryptoErr " ++ U32.show(c) ++ " " ++ m

def ok(b: Bool, +label: String, +got: String) -> IO(Unit):
  match b:
    case True{}:
      IO.print("ok " ++ label)
    case False{}:
      IO.die(Unit, 1, label ++ " gave " ++ got)

def same(+label: String, +want: String, +got: String) -> IO(Unit):
  ok(String.eq(got, want), label, got)

# want is "Done <id>" or the Err's name.
def expect(+label: String, +want: String, r: Bytes.Bytes & Result<&1, &1, W.Err, String>) -> IO(Unit):
  (body, v) = r
  match v:
    case Fail{e}:
      same(label, want, name(e))
    case Done{id}:
      same(label, want, "Done " ++ id)

# want is "Done" or the Err's name.
def expect.u(+label: String, +want: String, r: Bytes.Bytes & Result<&1, &1, W.Err, Unit>) -> IO(Unit):
  (body, v) = r
  match v:
    case Fail{e}:
      same(label, want, name(e))
    case Done{u}:
      same(label, want, "Done")

def at(+s: U32) -> Time.Instant:
  Time.Instant.of_unix(Time.i64(s))

def hs() -> Map<&2, List<&2, String>>:
  Map.new(&2, List<&2, String>)

def one(+k: String, +v: String) -> Map<&2, List<&2, String>>:
  W.put(hs(), k, v)

# ---- Standard Webhooks

def std.id() -> String:
  "msg_p5jXN8AQM9LWM0D4loKWxJek"

def std.key() -> String:
  "whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw"

def std.key2() -> String:
  "whsec_dGhpcyBpcyBhIHNlY29uZCBrZXkgZm9yIHRlc3Rz"

def std.sig() -> String:
  "v1,g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE="

# std.key2's signature of the reference message.
def std.sig2() -> String:
  "v1,jPeqLlAW3Hgte/zLdqe39p230cTa4SGLJ0xIvqorlsw="

def std.body() -> Bytes.Bytes:
  Bytes.from_string("{\"test\": 2432232314}")

def std.h(+sig: String) -> Map<&2, List<&2, String>>:
  W.put(W.put(one("webhook-id", std.id()), "webhook-timestamp", "1614265330"), "webhook-signature", sig)

def std.at(+label: String, +want: String, +now: U32) -> IO(Unit):
  do IO<Unit>:
    r : Bytes.Bytes & Result<&1, &1, W.Err, String> <- W.verify([std.key()], at(now), std.h(std.sig()), std.body())
    expect(label, want, r)

def signed.header(+label: String, +want: String, r: Bytes.Bytes & Result<&1, &1, W.Err, Map<&2, List<&2, String>>>) -> IO(Unit):
  (body, v) = r
  match v:
    case Fail{e}:
      IO.die(Unit, 1, label ++ " sign failed: " ++ name(e))
    case Done{+h}:
      same(label, want, Maybe.default(&2, String, W.field(h, "webhook-signature"), "none"))

# sign, then verify the headers sign wrote, over the body it handed back.
def trip.go(+label: String, +want: String, secrets: List<&2, String>, now: Time.Instant,
    r: Bytes.Bytes & Result<&1, &1, W.Err, Map<&2, List<&2, String>>>) -> IO(Unit):
  (body, v) = r
  match v:
    case Fail{e}:
      IO.die(Unit, 1, label ++ " sign failed: " ++ name(e))
    case Done{+h}:
      do IO<Unit>:
        s : Bytes.Bytes & Result<&1, &1, W.Err, String> <- W.verify(secrets, now, h, body)
        expect(label, want, s)

def trip(+label: String, +want: String, +key: String, secrets: List<&2, String>, +now: U32) -> IO(Unit):
  do IO<Unit>:
    r : Bytes.Bytes & Result<&1, &1, W.Err, Map<&2, List<&2, String>>> <-
      W.sign("evt_2", Time.i64(1700000000), Bytes.from_string("{\"type\":\"invoice.paid\",\"n\":[1,2,3]}"), key)
    trip.go(label, want, secrets, at(now), r)

# ---- Stripe

def stripe.body() -> Bytes.Bytes:
  Bytes.from_string("{\n  \"id\": \"evt_test_webhook\",\n  \"object\": \"event\"\n}")

def stripe.h() -> Map<&2, List<&2, String>>:
  one("stripe-signature", "t=1614265330,v1=af4ead0627a34a8cca29808e8de9ada8e41a92e6237c63cef6eacf51d36cca34")

# ---- GitHub

def github.h() -> Map<&2, List<&2, String>>:
  one("x-hub-signature-256", "sha256=757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17")

# ---- delivery through Hairpin, against a local receiver that verifies every attempt

def secret() -> String:
  std.key()

def respond(status: U32) -> IO(Http.Res):
  IO.pure(Http.Res, Http.Res{status, Http.set(Http.set(Http.empty(), "connection", "close"), "retry-after", "0"), Bytes.new(0)})

def verified.id(status: U32, ok: Bool) -> IO(Http.Res):
  match ok:
    case False{}:
      IO.die(Http.Res, 1, "FAIL the event ID changed between attempts")
    case True{}:
      respond(status)

def verified(status: U32, r: Bytes.Bytes & Result<&1, &1, W.Err, String>) -> IO(Http.Res):
  (body, result) = r
  match result:
    case Fail{e}:
      IO.die(Http.Res, 1, "FAIL the receiver rejected the signature: " ++ name(e))
    case Done{id}:
      verified.id(status, String.eq(id, "msg_local_1"))

def handle(status: U32, req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, +headers, body} = req
  do IO<Http.Res>:
    now : Time.Instant <- Time.now()
    r : Bytes.Bytes & Result<&1, &1, W.Err, String> <- W.verify([secret()], now, headers, body)
    verified(status, r)

def s.busy(req: Http.Req) -> IO(Http.Res):
  handle(501, req)

def s.accepted(req: Http.Req) -> IO(Http.Res):
  handle(200, req)

def wrap(op: IO(Http.Res)) -> IO(Http.Reply):
  do IO<Http.Reply>:
    res : Http.Res <- op
    return Http.Reply{res, Completion.Unobserved{}}

def serve.one(k: Bool, +inbox: Chan(Admission.Command), a: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  match k:
    case True{}:
      Http.conn(~(req => wrap(s.accepted(req))), ~Completion.ignore, Http.limits(1048576n), inbox, a)
    case False{}:
      Http.conn(~(req => wrap(s.busy(req))), ~Completion.ignore, Http.limits(1048576n), inbox, a)

def serve.go(ks: List<&2, Bool>, +inbox: Chan(Admission.Command), l: Listener) -> IO(Unit):
  match ks:
    case Nil{}:
      do IO<Unit>:
        Listener.close(l)
        Admission.close(inbox)
    case Con{k, rest}:
      do IO<Unit>:
        a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
        l2 : Listener <- serve.one(k, inbox, a)
        serve.go(rest, inbox, l2)

# Accept exactly one connection per script entry, then stop listening. True: 200, False: 501.
def serve(ks: List<&2, Bool>, l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    serve.go(ks, inbox, l)

def served.of(+label: String, m: Maybe<&1, Unit>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "FAIL " ++ label ++ ": the receiver still waits for an attempt")
    case Some{u}:
      IO.print("ok " ++ label ++ ": every scripted attempt arrived, and no more")

# A missing attempt times out here, and an extra one finds no listener.
def served(+label: String, ch: Chan(Unit)) -> IO(Unit):
  do IO<Unit>:
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    served.of(label, m)

def status(r: Result<&1, &1, W.SendErr, Http.Res>) -> String:
  match r:
    case Fail{W.SendSign{e}}:
      "SendSign " ++ name(e)
    case Fail{W.SendNet{Hairpin.ErrHttp{e}}}:
      "SendNet ErrHttp"
    case Fail{W.SendNet{Hairpin.ErrDenied{why}}}:
      "SendNet ErrDenied"
    case Done{res}:
      Http.Res{+s, h, b} = res
      U32.show(s)

def sent(+label: String, +want: String, x: Hairpin.Client & Result<&1, &1, W.SendErr, Http.Res>) -> IO(Hairpin.Client):
  (c, r) = x
  do IO<Hairpin.Client>:
    same(label, want, status(r))
    return c

def sent.in(+label: String, +want: String, x: Hairpin.Client & Retry.Budget & Result<&1, &1, W.SendErr, Http.Res>) ->
    IO(Hairpin.Client & Retry.Budget):
  (c, b, r) = x
  do IO<Hairpin.Client & Retry.Budget>:
    same(label, want, status(r))
    return (c, b)

def url() -> String:
  "http://127.0.0.1:47852/webhook"

def body() -> Bytes.Bytes:
  Bytes.from_string("{\"test\": 2432232314}")

def again(x: Hairpin.Client & Retry.Budget) -> IO(Hairpin.Client & Retry.Budget & Result<&1, &1, W.SendErr, Http.Res>):
  (c, b) = x
  W.send.in(c, b, url(), "msg_local_1", secret(), body())

def drop(x: Hairpin.Client & Retry.Budget) -> Hairpin.Client:
  (c, b) = x
  c

# A 501 retried to a 200. Then a caller's own retry layer delivers twice on one budget of 3, with retry 2:
# the first delivery takes all 3 attempts, and the second is denied. Without the shared budget it would be 6.
def deliveries() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", 47852))
    ch : Chan(Unit) <- IO.fork(Unit, serve([False{}, True{}, False{}, False{}, False{}], l))
    r1 : Hairpin.Client & Result<&1, &1, W.SendErr, Http.Res> <- W.send(Hairpin.new(), url(), "msg_local_1", secret(), body())
    c1 : Hairpin.Client <- sent("send: a 501 retried to a verified 200", "200", r1)
    r2 : Hairpin.Client & Retry.Budget & Result<&1, &1, W.SendErr, Http.Res> <-
      W.send.in(Hairpin.retry(c1, 2), Retry.Budget.new(3n, 0n, None{}), url(), "msg_local_1", secret(), body())
    x2 : Hairpin.Client & Retry.Budget <- sent.in("send.in: the first delivery takes the 3 attempts", "501", r2)
    r3 : Hairpin.Client & Retry.Budget & Result<&1, &1, W.SendErr, Http.Res> <- again(x2)
    x3 : Hairpin.Client & Retry.Budget <- sent.in("send.in: the second delivery is denied, the budget is spent", "SendNet ErrDenied", r3)
    Hairpin.close(drop(x3))
    served("deliveries: 2 + 3 attempts", ch)

def main() -> IO(Unit):
  +done = "Done " ++ std.id()
  do IO<Unit>:
    # Standard Webhooks reference vector: sign writes the published signature, and verify accepts it.
    g : Bytes.Bytes & Result<&1, &1, W.Err, Map<&2, List<&2, String>>> <- W.sign(std.id(), Time.i64(1614265330), std.body(), std.key())
    signed.header("std sign reference vector", std.sig(), g)
    std.at("std verify reference vector", done, 1614265330)
    # Round trip, with the whsec_ prefix and without it.
    trip("std sign-verify round trip", "Done evt_2", std.key2(), [std.key2()], 1700000000)
    trip("std round trip, key without whsec_", "Done evt_2", "dGhpcyBpcyBhIHNlY29uZCBrZXkgZm9yIHRlc3Rz", [std.key2()], 1700000000)
    trip("std round trip under another secret", "NoMatch", std.key2(), [std.key()], 1700000000)
    # One byte changed: the body's last digit, then the signature's last base64 digit.
    r1 : Bytes.Bytes & Result<&1, &1, W.Err, String> <-
      W.verify([std.key()], at(1614265330), std.h(std.sig()), Bytes.from_string("{\"test\": 2432232315}"))
    expect("std 1-byte body tamper", "NoMatch", r1)
    r2 : Bytes.Bytes & Result<&1, &1, W.Err, String> <-
      W.verify([std.key()], at(1614265330), std.h("v1,g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OI="), std.body())
    expect("std 1-byte signature tamper", "NoMatch", r2)
    r3 : Bytes.Bytes & Result<&1, &1, W.Err, String> <- W.verify([std.key2()], at(1614265330), std.h(std.sig()), std.body())
    expect("std wrong secret", "NoMatch", r3)
    r4 : Bytes.Bytes & Result<&1, &1, W.Err, String> <- W.verify(["whsec_"], at(1614265330), std.h(std.sig()), std.body())
    expect("std empty secret", "BadSecret", r4)
    # 300 s either way is accepted; 301 s is not.
    std.at("std 300 s old", done, 1614265630)
    std.at("std 301 s old", "TooOld", 1614265631)
    std.at("std 300 s ahead", done, 1614265030)
    std.at("std 301 s ahead", "TooNew", 1614265029)
    r5 : Bytes.Bytes & Result<&1, &1, W.Err, String> <- W.verify.with(10, [std.key()], at(1614265341), std.h(std.sig()), std.body())
    expect("std 11 s old, 10 s tolerance", "TooOld", r5)
    # Rotation: several secrets, several signatures.
    r6 : Bytes.Bytes & Result<&1, &1, W.Err, String> <- W.verify([std.key2(), std.key()], at(1614265330), std.h(std.sig()), std.body())
    expect("std rotated secrets, second matches", done, r6)
    r7 : Bytes.Bytes & Result<&1, &1, W.Err, String> <-
      W.verify([std.key()], at(1614265330), std.h(std.sig2() ++ " v2,xyz " ++ std.sig()), std.body())
    expect("std multi signature, last matches", done, r7)
    r8 : Bytes.Bytes & Result<&1, &1, W.Err, String> <-
      W.verify([std.key2()], at(1614265330), std.h(std.sig2() ++ " " ++ std.sig()), std.body())
    expect("std multi signature, first matches", done, r8)
    r9 : Bytes.Bytes & Result<&1, &1, W.Err, String> <-
      W.verify([std.key2()], at(1614265330), std.h("v2," ++ String.drop(std.sig2(), 3n)), std.body())
    expect("std v2 signature ignored", "NoMatch", r9)
    r10 : Bytes.Bytes & Result<&1, &1, W.Err, String> <- W.verify(["whsec_", std.key()], at(1614265330), std.h(std.sig()), std.body())
    expect("std bad secret among rotated", "BadSecret", r10)
    # Stripe.
    s1 : Bytes.Bytes & Result<&1, &1, W.Err, Unit> <- W.stripe.verify(["whsec_test_secret"], at(1614265330), stripe.h(), stripe.body())
    expect.u("stripe stripe-node fixture", "Done", s1)
    s2 : Bytes.Bytes & Result<&1, &1, W.Err, Unit> <- W.stripe.verify(["whsec_other", "whsec_test_secret"], at(1614265330), stripe.h(), stripe.body())
    expect.u("stripe rotated secrets", "Done", s2)
    s3 : Bytes.Bytes & Result<&1, &1, W.Err, Unit> <-
      W.stripe.verify(["whsec_test_secret"], at(1614265330), stripe.h(), Bytes.from_string("{\n  \"id\": \"evt_test_webhooK\",\n  \"object\": \"event\"\n}"))
    expect.u("stripe 1-byte body tamper", "NoMatch", s3)
    s4 : Bytes.Bytes & Result<&1, &1, W.Err, Unit> <- W.stripe.verify(["whsec_other"], at(1614265330), stripe.h(), stripe.body())
    expect.u("stripe wrong secret", "NoMatch", s4)
    s5 : Bytes.Bytes & Result<&1, &1, W.Err, Unit> <- W.stripe.verify(["whsec_test_secret"], at(1614265631), stripe.h(), stripe.body())
    expect.u("stripe 301 s old", "TooOld", s5)
    s6 : Bytes.Bytes & Result<&1, &1, W.Err, Unit> <- W.stripe.verify(["whsec_test_secret"], at(1614265029), stripe.h(), stripe.body())
    expect.u("stripe 301 s ahead", "TooNew", s6)
    s7 : Bytes.Bytes & Result<&1, &1, W.Err, Unit> <-
      W.stripe.verify(["whsec_test_secret"], at(1614265330), one("stripe-signature", "t=1614265330,v0=af4ead0627a34a8cca29808e8de9ada8e41a92e6237c63cef6eacf51d36cca34"), stripe.body())
    expect.u("stripe v0 signature ignored", "NoMatch", s7)
    # GitHub.
    h1 : Bytes.Bytes & Result<&1, &1, W.Err, Unit> <- W.github.verify(["It's a Secret to Everybody"], github.h(), Bytes.from_string("Hello, World!"))
    expect.u("github docs vector", "Done", h1)
    h2 : Bytes.Bytes & Result<&1, &1, W.Err, Unit> <- W.github.verify(["It's a Secret to Everybody"], github.h(), Bytes.from_string("Hello, World?"))
    expect.u("github 1-byte body tamper", "NoMatch", h2)
    h3 : Bytes.Bytes & Result<&1, &1, W.Err, Unit> <- W.github.verify(["It's a secret to everybody"], github.h(), Bytes.from_string("Hello, World!"))
    expect.u("github wrong secret", "NoMatch", h3)
    h4 : Bytes.Bytes & Result<&1, &1, W.Err, Unit> <-
      W.github.verify(["It's a Secret to Everybody"], one("x-hub-signature-256", "757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17"), Bytes.from_string("Hello, World!"))
    expect.u("github without sha256=", "NoMatch", h4)
    h5 : Bytes.Bytes & Result<&1, &1, W.Err, Unit> <- W.github.verify(["It's a Secret to Everybody"], hs(), Bytes.from_string("Hello, World!"))
    expect.u("github missing header", "Missing x-hub-signature-256", h5)
    deliveries()
