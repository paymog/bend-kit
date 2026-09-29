"""OAuth2 benchmark in Python: hashlib + base64 for PKCE, json for the token response (see README.md)."""
import base64, hashlib, json, time

N = 10_000
v = b"dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
t0 = time.perf_counter()
for _ in range(N):
    v = base64.urlsafe_b64encode(hashlib.sha256(v).digest()).rstrip(b"=")
t1 = time.perf_counter()
print(f"pkce\t{(t1 - t0) * 1000:.3f}\t{v.decode()}")

body = ('{"access_token":"' + "A" * 1024 + '","token_type":"Bearer","expires_in":3600,'
        '"refresh_token":"tGzv3JOkF0XG5Qx2TlKWIA","scope":"openid profile email"}').encode()
good, last = 0, None
t0 = time.perf_counter()
for _ in range(N):
    t = json.loads(body)
    if t.get("access_token"):
        good, last = good + 1, t
t1 = time.perf_counter()
print(f"parse\t{(t1 - t0) * 1000:.3f}\t{good} {len(last['access_token'])} {last['refresh_token']} {last['scope']} {last['expires_in']}")
