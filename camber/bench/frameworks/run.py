"""Matched loopback HTTP controls. Run manually; not a Camber release benchmark."""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))
from run_dispatch import ROOT, ENV, RSS_LIMIT_KIB, guarded
from run_lifecycle import generate
from run_raw import Server, exchange, probes, workloads


def rows():
    return workloads() + [("auth-reject", 0, "GET", "/hooks/5", b"", 401, b"", {"www-authenticate": "Bearer"})]


def overrides(row):
    return {"authorization": "wrong"} if row[0] == "auth-reject" else {}


def exact(server, row):
    with server.peer() as peer:
        exchange(peer, row, overrides(row))


def validate(sample, row):
    distribution = sample["statusCodeDistribution"]
    assert set(distribution) == {str(row[5])}, (row[0], distribution)
    count = sum(distribution.values())
    assert count > 0 and not sample["errorDistribution"], (row[0], sample)
    assert sample["summary"]["successRate"] == 1, sample
    assert sample["summary"]["totalData"] == count * len(row[6]), (row[0], sample["summary"])
    return count


def load(oha, server, row, temp, duration, connections, workers=2, rate=None):
    name, _, method, path, body, _, _, _ = row
    payload = temp / "payload.bin"
    payload.write_bytes(body)
    command = [str(oha), "--no-tui", "--output-format", "json", "--http-version", "1.1",
               "--worker-threads", str(workers), "--disable-compression", "-w", "-t", "5s",
               "-c", str(connections), "-z", f"{duration}s", "-m", method,
               "-H", "connection: keep-alive", "-H", "authorization: " + overrides(row).get("authorization", "Bearer alice"),
               "-H", f"content-length: {len(body)}", "-T", "application/octet-stream" if path == "/echo" else "application/json"]
    if body:
        command += ["-D", str(payload)]
    if rate is not None:
        command += ["-q", str(rate), "--latency-correction"]
    command += [f"http://127.0.0.1:{server.port}{path}"]
    server.sample()
    before = server.cpu
    started = time.monotonic()
    observed_rss = 0
    usage = None
    with tempfile.TemporaryFile(mode="w+t") as output, tempfile.TemporaryFile(mode="w+t") as errors:
        process = subprocess.Popen(command, stdout=output, stderr=errors, env=ENV)
        try:
            while True:
                pid, status, usage = os.wait4(process.pid, os.WNOHANG)
                if pid:
                    process.returncode = os.waitstatus_to_exitcode(status)
                    break
                fields = subprocess.run(["ps", "-o", "rss=", "-p", str(process.pid)], capture_output=True, text=True, timeout=5).stdout.strip()
                if fields:
                    observed_rss = max(observed_rss, int(fields))
                if observed_rss > RSS_LIMIT_KIB or time.monotonic() - started > duration + 20 or server.failure:
                    raise RuntimeError("load generator/server guard fired")
                time.sleep(.1)
        finally:
            if process.returncode is None:
                process.kill()
                _, status, usage = os.wait4(process.pid, 0)
                process.returncode = os.waitstatus_to_exitcode(status)
        output.seek(0)
        errors.seek(0)
        if process.returncode:
            raise RuntimeError(errors.read())
        sample = json.loads(output.read())
    count = validate(sample, row)
    server.sample()
    sample["measurement"] = {
        "requests": count, "server_cpu_seconds": server.cpu - before,
        "server_sampled_peak_rss_kib": server.peak_kib,
        "client_user_cpu_seconds": usage.ru_utime, "client_system_cpu_seconds": usage.ru_stime,
        "client_kernel_peak_rss_kib": usage.ru_maxrss / (1024 if sys.platform == "darwin" else 1),
        "client_wall_seconds": time.monotonic() - started, "connections": connections,
        "client_worker_threads": workers, "offered_requests_per_second": rate,
        "latency_correction": rate is not None,
    }
    return sample


def commands(temp):
    return {
        "bend-raw": ([str(temp / "bend-paired"), "--threads", "1", "--gpu", "off"], "raw-serve"),
        "bend-scoped": ([str(temp / "bend-paired"), "--threads", "1", "--gpu", "off"], "scoped-serve"),
        "rust-hyper": ([str(temp / "rust-target/release/camber-framework-control")], "raw"),
        "rust-axum": ([str(temp / "rust-target/release/camber-framework-control")], "framework"),
        "js-http": (["node", str(HERE / "server.js")], "raw"),
        "js-fastify": (["node", str(HERE / "server.js")], "framework"),
        "python-asgi": ([str(temp / "venv/bin/python"), "-B", str(HERE / "server.py")], "raw"),
        "python-fastapi": ([str(temp / "venv/bin/python"), "-B", str(HERE / "server.py")], "framework"),
    }


def prepare(temp):
    if shutil.disk_usage(ROOT).free < 25 * 1024**3:
        raise RuntimeError("insufficient disk headroom for Bend and swap")
    build = {}
    entry = generate(temp)
    _, rss, seconds = guarded(["bend", str(entry), "-o", str(temp / "bend-paired")], 180)
    build["bend"] = {"seconds": seconds, "sampled_peak_rss_kib": rss}
    guarded(["cargo", "build", "--release", "--locked", "--manifest-path", str(HERE / "rust/Cargo.toml"), "--target-dir", str(temp / "rust-target")], 600)
    guarded(["bun", "install", "--frozen-lockfile", "--cwd", str(HERE)], 120)
    guarded(["uv", "venv", str(temp / "venv")], 60)
    guarded(["uv", "pip", "install", "--python", str(temp / "venv/bin/python"), "-r", str(HERE / "requirements.txt")], 180)
    return build


def save(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n")


def experiment(temp, oha, output, duration, trials, concurrency, reused):
    data = {"platform": platform.platform(), "python": platform.python_version(),
            "bend": subprocess.check_output(["bend", "version"], text=True).strip(),
            "node": subprocess.check_output(["node", "--version"], text=True).strip(),
            "rust": subprocess.check_output(["rustc", "--version"], text=True).strip(),
            "oha": subprocess.check_output([str(oha), "--version"], text=True).strip(),
            "duration_seconds": duration, "trials": trials, "connections": concurrency,
            "client_worker_threads": 2, "body_limit_bytes": 8388608,
            "prepared_artifacts_reused": reused, "calibration": {}, "fixed_rates": {}, "results": {}, "generator_scaling": {}}
    save(output, data)
    variants = commands(temp)
    all_rows = rows()
    for implementation, (command, operation) in variants.items():
        data["calibration"][implementation] = {}
        for profile in (0, 10, 100, 1000):
            selected = [r for r in all_rows if r[1] == profile]
            server = Server(command, profile, selected[0], operation=operation)
            try:
                probes(server, profile)
                for row in selected:
                    exact(server, row)
                    sample = load(oha, server, row, temp, 1, concurrency)
                    data["calibration"][implementation][row[0]] = sample
                    print("calibrate", implementation, row[0], round(sample["summary"]["requestsPerSec"]), flush=True)
                    save(output, data)
            finally:
                server.close()
    for row in all_rows:
        lowest = min(data["calibration"][name][row[0]]["summary"]["requestsPerSec"] for name in variants)
        data["fixed_rates"][row[0]] = max(1, int(lowest * .5))
    save(output, data)
    command, operation = variants["rust-hyper"]
    server = Server(command, 0, all_rows[0], operation=operation)
    try:
        for workers in (1, 2, 4):
            data["generator_scaling"][str(workers)] = [load(oha, server, all_rows[0], temp, duration, concurrency, workers) for _ in range(trials)]
            save(output, data)
    finally:
        server.close()
    for repeat in range(trials):
        order = list(variants) if repeat % 2 == 0 else list(reversed(variants))
        for profile in (0, 10, 100, 1000):
            selected = [r for r in all_rows if r[1] == profile]
            for implementation in order:
                command, operation = variants[implementation]
                server = Server(command, profile, selected[0], operation=operation)
                try:
                    for row in selected:
                        exact(server, row)
                        load(oha, server, row, temp, .5, concurrency)
                        result = data["results"].setdefault(implementation, {}).setdefault(row[0], {"closed_loop": [], "fixed_rate": []})
                        result["closed_loop"].append(load(oha, server, row, temp, duration, concurrency))
                        result["fixed_rate"].append(load(oha, server, row, temp, duration, concurrency, rate=data["fixed_rates"][row[0]]))
                        exact(server, row)
                        save(output, data)
                        print("measure", repeat + 1, implementation, row[0], "PASS", flush=True)
                finally:
                    server.close()
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--oha", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--duration", type=float, default=2)
    parser.add_argument("--trials", type=int, default=3)
    parser.add_argument("--connections", type=int, default=16)
    parser.add_argument("--prepared", type=Path, help="Reuse explicitly prepared scratch; does not claim a fresh build")
    args = parser.parse_args()
    if min(args.duration, args.trials, args.connections) <= 0:
        parser.error("duration, trials, and connections must be positive")
    if args.prepared:
        experiment(args.prepared.resolve(), args.oha.resolve(), args.output, args.duration, args.trials, args.connections, True)
    else:
        with tempfile.TemporaryDirectory(prefix="camber-frameworks-") as directory:
            temp = Path(directory).resolve()
            build = prepare(temp)
            data = experiment(temp, args.oha.resolve(), args.output, args.duration, args.trials, args.connections, False)
            data["build"] = build
            save(args.output, data)


if __name__ == "__main__":
    main()
