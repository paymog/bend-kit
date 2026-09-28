#!/usr/bin/env python3
"""Write the recording, build and run the SSE parse benchmark; print a markdown table. See README.md."""
import json, os, statistics, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 3
EVENTS = int(sys.argv[2]) if len(sys.argv) > 2 else 100000
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}
PARSER, SSECLIENT = "4.1.1", "1.9.0"

# name -> (build argv or None, run argv). Every program reads out/stream.sse and prints `parse<TAB>ms<TAB>checksum`.
VARIANTS = {
    "Rust": (["cargo", "build", "--release", "-q", "--manifest-path", "rs/Cargo.toml", "--target-dir", OUT / "rs"], [OUT / "rs" / "release" / "rs"]),
    "Bun": (["sh", "-c", f"npm i -s --prefix out/js eventsource-parser@{PARSER} && cp bench.mjs out/js/"], ["bun", OUT / "js" / "bench.mjs"]),
    "Node": (None, ["node", OUT / "js" / "bench.mjs"]),
    "Python": (None, ["uv", "run", "-q", "--no-project", "--with", f"sseclient-py=={SSECLIENT}", "python3", "bench.py"]),
    "Bend": (["bend", "bench.bend", "-o", OUT / "bend"], [OUT / "bend"]),
}


# One Anthropic Messages stream: start, a text block of 20 deltas, then the end. Some text is not ASCII.
def message(i):
    words = ["Bend", " is", " pure", ",", " café", " naïve", " \u2014", " 🙂", " fast", "\n"]
    evs = [
        ("message_start", {"type": "message_start", "message": {"id": f"msg_{i}", "type": "message", "role": "assistant",
            "model": "claude-x", "content": [], "stop_reason": None, "usage": {"input_tokens": 25 + i % 100, "output_tokens": 1}}}),
        ("content_block_start", {"type": "content_block_start", "index": 0, "content_block": {"type": "text", "text": ""}}),
        ("ping", {"type": "ping"}),
    ]
    for j in range(20):
        text = "".join(words[(i + j + k) % len(words)] for k in range(1 + (i * 7 + j) % 6))
        evs.append(("content_block_delta", {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": text}}))
    evs += [
        ("content_block_stop", {"type": "content_block_stop", "index": 0}),
        ("message_delta", {"type": "message_delta", "delta": {"stop_reason": "end_turn", "stop_sequence": None}, "usage": {"output_tokens": 20 + i % 50}}),
        ("message_stop", {"type": "message_stop"}),
    ]
    return evs


# h = h*31 + x (u32): 1, the event type's bytes, 2, the data's bytes, for each event. Then add the event count.
def checksum(evs):
    h = 0
    for name, data in evs:
        h = (h * 31 + 1) & 0xFFFFFFFF
        for b in name:
            h = (h * 31 + b) & 0xFFFFFFFF
        h = (h * 31 + 2) & 0xFFFFFFFF
        for b in data:
            h = (h * 31 + b) & 0xFFFFFFFF
    return (h + len(evs)) & 0xFFFFFFFF


def main():
    OUT.mkdir(exist_ok=True)
    evs = []
    i = 0
    while len(evs) < EVENTS:
        evs += [(n.encode(), json.dumps(d, ensure_ascii=False, separators=(",", ":")).encode()) for n, d in message(i)]
        i += 1
    evs = evs[:EVENTS]
    data = b"".join(b"event: " + n + b"\ndata: " + d + b"\n\n" for n, d in evs)
    (OUT / "stream.sse").write_bytes(data)
    want = str(checksum(evs))
    print(f"input {len(data):,} bytes, {len(evs)} events, checksum {want}", file=sys.stderr)

    table, checks = {}, {}
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
        table[name] = statistics.median(t for t, _ in runs)
        checks[name] = runs[0][1]
        print(f"ran {name}", file=sys.stderr)

    bad = [(n, c) for n, c in checks.items() if c != want]
    if bad:
        sys.exit(f"checksum mismatch: want {want}, got {bad}")
    print(f"checksum {want}", file=sys.stderr)

    names = list(table)
    best = min(table.values())
    print("| op | " + " | ".join(names) + " |")
    print("|---|" + "---:|" * len(names))
    cells = [f"{table[n]:,.1f}" + (f" ({table[n] / best:.1f}x)" if best > 0 else "") for n in names]
    print("| parse | " + " | ".join(cells) + " |")


main()
