#!/usr/bin/env python3
"""Build and run the SigV4 signing benchmark; print a markdown table. See README.md."""
import hashlib, hmac, os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}
BOTOCORE = "1.42.55"
JS = "@aws-sdk/signature-v4-multi-region@3.996.47 @smithy/hash-node@4.5.2 @smithy/protocol-http@5.6.2"
CRT = os.environ.get("AWS_CRT_PREFIX", "/opt/homebrew")
CRT_LIBS = ["-laws-c-auth", "-laws-c-http", "-laws-c-io", "-laws-c-cal", "-laws-c-sdkutils", "-laws-c-compression", "-laws-c-common"]

# name -> (build argv or None, run argv). Every program signs the same request 10,000 times and prints
# `sign<TAB>ms<TAB>signature`, the hex signature of the last one.
VARIANTS = {
    "C": (["clang", "-O2", f"-I{CRT}/include", f"-L{CRT}/lib", "-o", OUT / "c", "bench.c", *CRT_LIBS], [OUT / "c"]),
    "Rust": (["cargo", "build", "--release", "-q", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"], [OUT / "rs" / "release" / "rs"]),
    "Bun": (["sh", "-c", f"npm i -s --prefix out/js {JS} && cp bench.mjs out/js/"], ["bun", OUT / "js" / "bench.mjs"]),
    "Node": (None, ["node", OUT / "js" / "bench.mjs"]),
    "Python": (None, ["uv", "run", "-q", "--no-project", "--with", f"botocore=={BOTOCORE}", "python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


# The benchmark request signed from the SigV4 spec with hashlib and hmac, independent of every library.
def reference():
    sha = lambda b: hashlib.sha256(b).hexdigest()
    mac = lambda k, m: hmac.new(k, m.encode(), hashlib.sha256).digest()
    date, day, scope = "20130524T000000Z", "20130524", "20130524/us-east-1/s3/aws4_request"
    body = sha(b"Welcome to Amazon S3.")
    headers = f"host:examplebucket.s3.amazonaws.com\nx-amz-content-sha256:{body}\nx-amz-date:{date}\n"
    canonical = f"PUT\n/test.txt\nx-id=PutObject\n{headers}\nhost;x-amz-content-sha256;x-amz-date\n{body}"
    to_sign = f"AWS4-HMAC-SHA256\n{date}\n{scope}\n{sha(canonical.encode())}"
    key = b"AWS4wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    for part in (day, "us-east-1", "s3", "aws4_request"):
        key = mac(key, part)
    return hmac.new(key, to_sign.encode(), hashlib.sha256).hexdigest()


def main():
    OUT.mkdir(exist_ok=True)
    want = reference()
    print(f"reference signature {want}", file=sys.stderr)
    table = {}
    for name, (build, run) in VARIANTS.items():
        if build:
            b = subprocess.run(build, cwd=HERE, env=ENV, capture_output=True, text=True)
            if b.returncode != 0:
                sys.exit(f"build failed: {name}\n{b.stderr}")
        runs = []
        for _ in range(RUNS):
            r = subprocess.run(run, cwd=HERE, env=ENV, capture_output=True, text=True)
            if r.returncode != 0:
                sys.exit(f"{name} failed ({r.returncode}):\n{r.stdout}{r.stderr}")
            op, ms, c = r.stdout.strip().split("\t")
            runs.append((float(ms), c))
        bad = {c for _, c in runs if c != want}
        if bad:
            sys.exit(f"{name} signature mismatch: want {want}, got {sorted(bad)}")
        table[name] = statistics.median(t for t, _ in runs)
        print(f"ran {name}", file=sys.stderr)

    names = list(table)
    best = min(table.values()) or 0.001
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    print("| sign | " + " | ".join(f"{table[n]:,.1f} ({table[n] / best:.1f}x)" for n in names) + " |")


main()
