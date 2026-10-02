"""Measure raw dispatch and actual Http.serve; no Camber implementation is timed."""
import argparse
import concurrent.futures
from contextlib import closing
import http.client
import json
import math
import os
from pathlib import Path
import platform
import signal
import socket
import statistics
import subprocess
import tempfile
import threading
import time

from run_dispatch import ENV, ROOT, RSS_LIMIT_KIB, guarded


def workloads():
    rows = [
        ("text", 0, "GET", "/text", b"", 200, b"OK\n", {}),
        ("json", 0, "GET", "/json", b"", 200, b'{"ok":true}', {}),
        ("parameter", 0, "GET", "/users/7", b"", 200, b'{"id":7}', {}),
        ("json-1k", 0, "POST", "/decode", b'{"name":"Cara"}' + b" " * 1009, 200, b'{"name":"Cara"}', {}),
    ]
    for n in (0, 1, 5):
        rows.append((f"hooks-{n}", 0, "GET", f"/hooks/{n}", b"", 200, b'{"ok":true}', {"x-hook-count": str(n)}))
    for n in (10, 100, 1000):
        rows.extend([
            (f"hit-{n}", n, "GET", f"/route/{n-1}", b"", 200, f'{{"id":{n-1}}}'.encode(), {}),
            (f"miss-{n}", n, "GET", f"/route/{n}", b"", 404, b"not found", {}),
            (f"method-{n}", n, "POST", f"/route/{n-1}", b"", 405, b"", {"allow": "GET, HEAD"}),
        ])
    for name, length in (("echo-64k", 65536), ("echo-4m", 4194304)):
        body = b"\x7f\x80\x00\xff" * (length // 4)
        rows.append((name, 0, "POST", "/echo", body, 200, body, {}))
    return rows


def exchange(peer, row, overrides=None):
    name, profile, verb, path, body, status, expected, required = row
    headers = {"host": "localhost", "connection": "keep-alive", "authorization": "Bearer alice",
               "content-type": "application/octet-stream" if path == "/echo" else "application/json",
               "content-length": str(len(body))}
    headers.update(overrides or {})
    peer.putrequest(verb, path, skip_host=True, skip_accept_encoding=True)
    for key, value in headers.items():
        peer.putheader(key, value)
    peer.endheaders(body)
    response = peer.getresponse()
    actual = response.read()
    finished = time.perf_counter()
    fields = dict(response.getheaders())
    fields = {key.lower(): value for key, value in fields.items()}
    assert response.status == status, (name, response.status, status, actual[:200])
    assert actual == expected, (name, "body mismatch", len(actual), len(expected))
    assert fields.get("content-length") == str(len(expected)), (name, fields)
    for key, value in required.items():
        assert fields.get(key) == value, (name, key, fields)
    if status not in (401, 405):
        media = "application/octet-stream" if path == "/echo" else "text/plain; charset=utf-8" if status in (400, 404, 415) or name == "text" else "application/json"
        assert fields.get("content-type") == media, (name, fields)
    return finished


def cpu_seconds(value):
    parts = value.split(":")
    return sum(float(part) * 60 ** index for index, part in enumerate(reversed(parts)))


class Server:
    def __init__(self, command, profile, ready):
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            self.port = reservation.getsockname()[1]
        self.log = tempfile.TemporaryFile()
        self.process = subprocess.Popen(command + ["serve", str(profile), str(self.port)], env=ENV,
                                        stdout=self.log, stderr=self.log, start_new_session=True)
        self.started = time.perf_counter()
        self.peak_kib = 0
        self.cpu = 0.0
        self.failure = None
        self.stop_event = threading.Event()
        self.monitor = threading.Thread(target=self.watch, daemon=True)
        self.monitor.start()
        try:
            while True:
                if self.process.poll() is not None or time.perf_counter() - self.started > 20:
                    self.log.seek(0)
                    raise RuntimeError("server failed readiness: " + self.log.read().decode(errors="replace"))
                try:
                    with self.peer() as peer:
                        exchange(peer, ready)
                    break
                except (ConnectionRefusedError, ConnectionResetError, http.client.RemoteDisconnected):
                    time.sleep(0.02)
            self.startup_seconds = time.perf_counter() - self.started
        except BaseException:
            self.close()
            raise

    def peer(self):
        return closing(http.client.HTTPConnection("127.0.0.1", self.port, timeout=15))

    def sample(self):
        result = subprocess.run(["ps", "-o", "rss=,time=", "-p", str(self.process.pid)], capture_output=True, text=True, timeout=3)
        fields = result.stdout.split()
        if fields:
            self.peak_kib = max(self.peak_kib, int(fields[0]))
            self.cpu = cpu_seconds(fields[1])

    def watch(self):
        try:
            while not self.stop_event.wait(0.1):
                self.sample()
                if self.peak_kib > RSS_LIMIT_KIB or time.perf_counter() - self.started > 240:
                    self.failure = "server RSS/deadline guard fired"
                    os.killpg(self.process.pid, signal.SIGKILL)
                    return
        except BaseException as error:
            self.failure = repr(error)
            if self.process.poll() is None:
                os.killpg(self.process.pid, signal.SIGKILL)

    def close(self):
        self.stop_event.set()
        self.monitor.join()
        self.sample()
        if self.process.poll() is None:
            os.killpg(self.process.pid, signal.SIGTERM)
        self.process.wait(timeout=5)
        self.log.close()
        if self.failure:
            raise RuntimeError(self.failure)


def trial(server, row, duration, concurrency, rate=None):
    server.sample()
    cpu_before = server.cpu
    client_before = time.process_time()
    start = time.perf_counter() + 0.03
    end = start + duration

    def ready():
        nonlocal start, end
        start = time.perf_counter() + 0.02
        end = start + duration

    barrier = threading.Barrier(concurrency, action=ready, timeout=20)

    def worker(index):
        samples = []
        with server.peer() as peer:
            # A verified warmup on each connection precedes the measurement barrier.
            exchange(peer, row)
            barrier.wait()
            while time.perf_counter() < start:
                time.sleep(0.001)
            number = index
            while True:
                scheduled = start + number / rate if rate else time.perf_counter()
                if scheduled >= end:
                    break
                if rate:
                    remaining = scheduled - time.perf_counter()
                    if remaining > 0:
                        time.sleep(remaining)
                finished = exchange(peer, row)
                samples.append((finished - scheduled) * 1000)
                number += concurrency
        return samples

    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as pool:
        groups = list(pool.map(worker, range(concurrency)))
    finish = time.perf_counter()
    samples = sorted(value for group in groups for value in group)
    assert samples, row[0]
    server.sample()
    percentile = lambda p: samples[max(0, math.ceil(p * len(samples)) - 1)]
    return {"requests": len(samples), "expected_responses_per_second": len(samples) / (finish - start),
            "elapsed_seconds": finish - start, "p50_ms": percentile(.5), "p95_ms": percentile(.95),
            "p99_ms": percentile(.99), "errors": 0, "server_cpu_seconds": server.cpu - cpu_before,
            "client_cpu_seconds": time.process_time() - client_before, "sampled_server_peak_rss_kib": server.peak_kib,
            "offered_requests_per_second": rate}


def probes(server, profile):
    if profile:
        for path in (f"/route/{profile}", "/route/00", "/route/abc", "/route/-1", "/route/4294967296", "/elsewhere"):
            with server.peer() as peer:
                exchange(peer, ("probe", profile, "GET", path, b"", 404, b"not found", {}))
        with server.peer() as peer:
            exchange(peer, ("probe", profile, "GET", "/route/0", b"", 200, b'{"id":0}', {}))
    else:
        with server.peer() as peer:
            exchange(peer, ("probe", 0, "GET", "/hooks/5", b"", 401, b"", {"www-authenticate": "Bearer"}), {"authorization": "wrong"})
        with server.peer() as peer:
            exchange(peer, ("probe", 0, "POST", "/decode", b"{}", 400, b"invalid name", {}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--seconds", type=float, default=1.0)
    parser.add_argument("--trials", type=int, default=3)
    parser.add_argument("--concurrency", type=int, default=2)
    args = parser.parse_args()
    if args.seconds <= 0 or args.trials < 2 or args.concurrency < 1:
        parser.error("positive duration/concurrency and at least two trials are required")
    rows = workloads()
    results = {"platform": platform.platform(), "python": platform.python_version(),
               "bend": subprocess.check_output(["bend", "version"], text=True).strip(),
               "bun": subprocess.check_output(["bun", "--version"], text=True).strip(),
               "duration_seconds": args.seconds, "trials": args.trials, "concurrency": args.concurrency,
               "body_limit_bytes": 8388608, "lanes": {}}
    with tempfile.TemporaryDirectory(prefix="camber-raw-") as directory:
        temp = Path(directory).resolve()
        generated_start = time.perf_counter()
        source = "import Base\n\n" + "\n\n".join(
            f"def r{n}(id: U32) -> Bool:\n  match id:\n" + "".join(f"    case {i}:\n      True{{}}\n" for i in range(n)) + "    case _:\n      False{}"
            for n in (10, 100, 1000)) + "\n"
        (temp / "routes.bend").write_text(source)
        driver = os.path.relpath(ROOT / "camber/raw_bench.bend", temp)
        entry = temp / "baseline.bend"
        entry.write_text(f"import Base\nimport {driver} as Bench\nimport ./routes.bend as Routes\n\ndef main() -> IO(Unit):\n  Bench.run(~Routes.r10, ~Routes.r100, ~Routes.r1000)\n")
        results["registration_generation_seconds"] = time.perf_counter() - generated_start
        results["generated_registration_bytes"] = len(source.encode())
        for lane in ("native", "js"):
            executable = temp / ("baseline" if lane == "native" else "baseline.js")
            _, rss, build = guarded(["bend", str(entry), "-o", str(executable)], 180)
            command = [str(executable), "--threads", "1", "--gpu", "off"] if lane == "native" else ["bun", str(executable)]
            data = {"build_seconds": build, "sampled_build_peak_rss_kib": rss, "artifact_bytes": executable.stat().st_size,
                    "command": command[1:] if lane == "native" else ["bun", "<generated.js>"], "workloads": {}, "servers": {}}
            results["lanes"][lane] = data
            for row in rows:
                label, _, _, _, body, status, expected, _ = row
                iterations = 50 if len(body) > 65536 else 10000
                samples = []
                for _ in range(args.trials):
                    output, peak, wall = guarded(command + ["direct", label, str(iterations)], 60)
                    printed, seconds, nanos, checksum = output.strip().split("\t")
                    assert printed == label and int(checksum) == ((status + len(expected)) * iterations) % 2**32, output
                    samples.append({"microseconds_per_request": (int(seconds) + int(nanos) / 1e9) * 1e6 / iterations,
                                    "wall_seconds": wall, "sampled_peak_rss_kib": peak, "iterations": iterations})
                data["workloads"][label] = {"direct": samples}
                print(lane, label, "direct", statistics.median(x["microseconds_per_request"] for x in samples), flush=True)
            for profile in (0, 10, 100, 1000):
                selected = [row for row in rows if row[1] == profile]
                server = Server(command, profile, selected[0])
                try:
                    probes(server, profile)
                    for row in selected:
                        with server.peer() as peer:
                            exchange(peer, row)
                        saturation = [trial(server, row, args.seconds, args.concurrency) for _ in range(args.trials)]
                        rate = statistics.median(x["expected_responses_per_second"] for x in saturation) * .5
                        fixed = [trial(server, row, args.seconds, args.concurrency, rate) for _ in range(args.trials)]
                        data["workloads"][row[0]].update(saturation=saturation, fixed_rate=fixed)
                        print(lane, row[0], "live", round(rate * 2, 2), flush=True)
                finally:
                    server.close()
                data["servers"][str(profile)] = {"process_to_verified_ready_seconds": server.startup_seconds,
                                                 "sampled_peak_rss_kib": server.peak_kib, "cpu_seconds": server.cpu}
            args.output.write_text(json.dumps(results, indent=2) + "\n")
    print("Baseline recorded:", args.output)


if __name__ == "__main__":
    main()
