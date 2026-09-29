#!/usr/bin/env python3
"""Build and run the webhook verify benchmark; print versions and a markdown table. See README.md."""
import base64, hashlib, hmac, os, statistics, subprocess, sys, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
N = 10_000
PY = "standardwebhooks==1.1.0"
JS = "standardwebhooks@1.1.1"
RS = "standardwebhooks 1.0.1"  # pinned with = in rs/Cargo.toml
SSL = os.environ.get("OPENSSL_PREFIX", "/opt/homebrew/opt/openssl@3")
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1", "NODE_NO_WARNINGS": "1"}
ID = "msg_p5jXN8AQM9LWM0D4loKWxJek"
SECRET = "whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw"
BODY = '{"test": 2432232314}'
WANT = f"{N} {ID}"

# name -> (build argv or None, run argv). Every program prints `verify<TAB>ms<TAB><verified count> <webhook-id>`.
VARIANTS = {
    "C": (["clang", "-O2", f"-I{SSL}/include", f"-L{SSL}/lib", "-o", OUT / "c", "bench.c", "-lcrypto"], [OUT / "c"]),
    "Rust": (["cargo", "build", "-q", "--release", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"],
             [OUT / "rs" / "release" / "bench"]),
    "Bun": (["sh", "-c", f"npm i -s --prefix out/js {JS} && cp bench.mjs out/js/"], ["bun", OUT / "js" / "bench.mjs"]),
    "Node": (None, ["node", OUT / "js" / "bench.mjs"]),
    "Python": (None, ["uv", "run", "-q", "--no-project", "--with", PY, "python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}

VERSIONS = [
    ["bend", "version"],
    ["clang", "--version"],
    ["pkg-config", "--modversion", f"{SSL}/lib/pkgconfig/libcrypto.pc"],
    ["rustc", "--version"],
    ["bun", "--version"],
    ["node", "--version"],
    ["uv", "run", "-q", "--no-project", "--with", PY, "python3", "--version"],
]


# The libraries check webhook-timestamp against the real clock (5 minutes' tolerance), so each run gets the
# fixed id, secret, and body signed now, per the Standard Webhooks spec, with hmac and base64.
def signed():
    ts = str(int(time.time()))
    key = base64.b64decode(SECRET.removeprefix("whsec_"))
    mac = hmac.new(key, f"{ID}.{ts}.{BODY}".encode(), hashlib.sha256).digest()
    return {"WEBHOOK_TS": ts, "WEBHOOK_SIG": "v1," + base64.b64encode(mac).decode()}


def main():
    OUT.mkdir(exist_ok=True)
    table = {}
    for name, (build, run) in VARIANTS.items():
        if build:
            b = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            if b.returncode != 0:
                sys.exit(f"build failed: {name}\n{b.stderr or b.stdout}")
        times = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env={**ENV, **signed()}, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed ({r.returncode}):\n{r.stdout}{r.stderr}")
            op, ms, got = r.stdout.strip().split("\t")
            if got != WANT:
                sys.exit(f"{name} checksum mismatch: want {WANT!r}, got {got!r}")
            times.append(float(ms))
        table[name] = statistics.median(times)
        print(f"ran {name}", file=sys.stderr)
    print(f"checksum {WANT}", file=sys.stderr)

    for v in VERSIONS:
        r = subprocess.run(v, cwd=HERE, env=ENV, capture_output=True, text=True)
        line = (r.stdout or r.stderr).strip().splitlines()
        print(f"- `{' '.join(map(str, v))}`: {line[0] if line else '?'}")
    print(f"- libraries: Python {PY}, JavaScript {JS}, Rust {RS}")
    print()

    best = min(table.values()) or 0.001
    print("| variant | ms | us/verify | vs fastest |")
    print("|---|---:|---:|---:|")
    for name, ms in table.items():
        print(f"| {name} | {ms:,.1f} | {ms * 1000 / N:,.2f} | {ms / best:.1f}x |")


main()
