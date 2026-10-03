"""Exercise the existing affine scoped application through actual HTTP framing."""
import concurrent.futures
import json
import socket
import struct
import tempfile
import time
from pathlib import Path

from run_dispatch import ROOT, guarded
from run_live import Peer
from run_surface import ALL_EXIT, AUTH_ENTER, DECODE, DOCUMENT, GROUP_EXIT, HANDLED, POLICIES, ROOT_ENTER, ROOT_EXIT, SEED, cases

ERROR_BODIES = {"bad-document": "invalid document", "unauthorized": "", "forbidden": "forbidden",
                "unsupported": "unsupported media type", "missing": "not found", "write": "store unavailable",
                "transform": "transform failed", "invalid-response": "invalid response", "bad-target": "invalid target", "method": ""}


def expected_body(body, trace):
    if body is not None:
        return body if isinstance(body, bytes) else body.encode()
    mapped = [event[1] for event in trace if isinstance(event, list) and event[0] == "map"]
    assert len(mapped) == 1, trace
    return ERROR_BODIES[mapped[0]].encode()


def connect(port, future):
    deadline = time.monotonic() + 5
    while True:
        try:
            return Peer(port)
        except ConnectionRefusedError:
            if future.done():
                future.result()
                raise AssertionError("server exited before accepting")
            if time.monotonic() >= deadline:
                raise TimeoutError("scoped server did not bind")
            time.sleep(.01)


def serve(command, journal, mode, fault, mapper, requests):
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        future = pool.submit(guarded, command + [str(journal), mode, fault, mapper, str(port), "1"], 25)
        peer = connect(port, future)
        try:
            for inputs, status, trace, policies, body in requests:
                payload = inputs.get("input_body", DOCUMENT)
                peer.send(inputs.get("method", "POST"), inputs.get("target", "/documents"),
                          payload if isinstance(payload, bytes) else payload.encode(), token=inputs.get("token", "Bearer alice"),
                          **{"content-type": inputs.get("media", "application/json"), "x-group-control": inputs.get("control", "")})
                fields = peer.response(status, expected_body(body, trace), head=inputs.get("method") == "HEAD")
                for policy in POLICIES:
                    assert fields.get("x-" + policy + "-policy", "") == ("yes" if policy in policies else ""), (policy, fields)
                assert fields.get("www-authenticate", "") == ("Bearer" if status == 401 else ""), fields
                assert fields.get("x-unsafe") is None and fields.get("injected") is None and fields.get("transfer-encoding") is None, fields
                if status in (405, 204):
                    assert fields.get("allow") == inputs.get("expected_allow", "POST"), fields
        finally:
            peer.close()
        stdout, rss, seconds = future.result()
    lines = stdout.splitlines()
    assert "SCOPED LIVE PASS" in lines and "LISTENER CLOSED" in lines, lines
    observed = [json.loads(line.removeprefix("TRACE ")) for line in lines if line.startswith("TRACE ")]
    assert observed == [row[2] for row in requests], observed
    reports = [json.loads(line) for line in lines if line.startswith('{"response":')]
    assert len(reports) == 1 and reports[0]["response"] is None, reports
    assert reports[0]["readback"].encode() == (SEED if mode == "r" else b""), reports
    return {"sampled_peak_rss_kib": rss, "wall_seconds": seconds}


def wait_for_write(journal):
    deadline = time.monotonic() + 3
    while journal.read_bytes() != b'{"owner":7}\n':
        if time.monotonic() >= deadline:
            raise TimeoutError("side effect was not observable before response release")
        time.sleep(.001)


def disconnect(command, journal):
    journal.write_bytes(b"")
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        future = pool.submit(guarded, command + [str(journal), "w", "", "normal", str(port), "1"], 25)
        peer = connect(port, future)
        try:
            peer.send("POST", "/documents", DOCUMENT.encode(), **{"x-delay-response": "yes"})
            wait_for_write(journal)
            peer.socket.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
        finally:
            peer.close()
        stdout, rss, wall = future.result()
    assert "RESPONSE HELD" in stdout and "SCOPED LIVE PASS" in stdout, stdout
    traces = [json.loads(line[6:]) for line in stdout.splitlines() if line.startswith("TRACE ")]
    assert traces == [HANDLED + ALL_EXIT], traces
    assert journal.read_bytes() == b'{"owner":7}\n', journal.read_bytes()
    print("disconnect after observed side effect: one receipt, returned handle, natural exit PASS", flush=True)
    return {"sampled_peak_rss_kib": rss, "wall_seconds": wall}


def queued_requests(command, journal):
    journal.write_bytes(b"")
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        future = pool.submit(guarded, command + [str(journal), "w", "", "normal", str(port), "2"], 25)
        first, second = connect(port, future), connect(port, future)
        try:
            first.send("POST", "/documents", DOCUMENT.encode(), **{"x-delay-response": "yes"})
            wait_for_write(journal)
            second.send("POST", "/documents", b"not JSON", token="Bearer bob")
            first.response(201, '{"owner":7,"doc":{"note":"héllo","n":1e+02}}'.encode())
            second.response(400, b"invalid document")
        finally:
            first.close()
            second.close()
        stdout, rss, wall = future.result()
    traces = [json.loads(line[6:]) for line in stdout.splitlines() if line.startswith("TRACE ")]
    assert traces == [HANDLED + ALL_EXIT, DECODE + [["map", "bad-document"]] + ALL_EXIT], traces
    assert "SCOPED LIVE PASS" in stdout and journal.read_bytes() == b'{"owner":7}\n', stdout
    print("queued principals, rejection, and single affine handle return PASS", flush=True)
    return {"sampled_peak_rss_kib": rss, "wall_seconds": wall}


def exercise(command, directory, lane):
    results = {}
    for name, inputs, status, trace, policies, body, owner in cases():
        journal = directory / f"{lane}-{name}"
        mode = inputs.get("mode", "w")
        if mode == "r":
            journal.write_bytes(SEED)
        results[name] = serve(command, journal, mode, inputs.get("fault", ""), inputs.get("mapper", "normal"),
                              [(inputs, status, trace, policies, body)])
        expected = SEED if mode == "r" else b"" if owner is None else f'{{"owner":{owner}}}\n'.encode()
        assert journal.read_bytes() == expected, (name, journal.read_bytes(), expected)
        print(lane, name, "scoped direct contract over socket PASS", flush=True)
    journal = directory / f"{lane}-sequence"
    requests = [
        ({"token": "", "input_body": "not JSON"}, 401, AUTH_ENTER + [["map", "unauthorized"]] + GROUP_EXIT + ROOT_EXIT, ("root", "users"), ""),
        ({}, 201, HANDLED + ALL_EXIT, ("root", "users", "document"), '{"owner":7,"doc":{"note":"héllo","n":1e+02}}'),
        ({"method": "GET", "target": "/public", "token": "", "input_body": "not JSON"}, 200,
         ROOT_ENTER + [["before", 3, 1], ["after", "ping"], ["after", "public"]] + ROOT_EXIT,
         ("root", "public", "ping"), "public"),
        ({"token": "Bearer bob"}, 201, HANDLED + ALL_EXIT, ("root", "users", "document"), '{"owner":8,"doc":{"note":"héllo","n":1e+02}}'),
    ]
    results["same-worker-principal-isolation"] = serve(command, journal, "w", "", "normal", requests)
    assert journal.read_bytes() == b'{"owner":7}\n{"owner":8}\n', journal.read_bytes()
    print(lane, "same-worker principal/sibling isolation and handle reuse PASS", flush=True)
    results["disconnect-after-side-effect"] = disconnect(command, directory / f"{lane}-disconnect")
    results["queued-principal-and-failure-isolation"] = queued_requests(command, directory / f"{lane}-concurrent")
    echo_trace = ROOT_ENTER + [["before", 3, 1], "handle", ["after", "public"]] + ROOT_EXIT
    binary = bytes(range(256))
    echo_requests = [
        ({"target": "/echo", "input_body": binary * 256, "media": "application/octet-stream"}, 200, echo_trace, ("root", "public"), binary * 256),
        ({"target": "/echo", "input_body": binary * 16384, "media": "application/octet-stream"}, 200, echo_trace, ("root", "public"), binary * 16384),
        ({"method": "GET", "target": "/echo", "input_body": b""}, 405, ROOT_ENTER + ROOT_EXIT, ("root",), b""),
    ]
    journal = directory / f"{lane}-plain-author"
    results["plain-author-packed-body"] = serve(command, journal, "w", "", "normal", echo_requests)
    assert journal.read_bytes() == b"", journal.read_bytes()
    print(lane, "author-owned plain handler: binary 64 KiB/4 MiB and method rejection PASS", flush=True)
    return results


def main():
    with tempfile.TemporaryDirectory(prefix="camber-scoped-live-") as directory:
        temp = Path(directory)
        results = {}
        for lane, suffix in (("native", ""), ("js", ".js")):
            executable = temp / ("scoped" + suffix)
            _, rss, seconds = guarded(["bend", str(ROOT / "camber/surface_live.bend"), "-o", str(executable)], 180)
            command = [str(executable), "--threads", "1", "--gpu", "off"] if lane == "native" else ["bun", str(executable)]
            results[lane] = {"build_seconds": seconds, "sampled_build_peak_rss_kib": rss,
                             "scenarios": exercise(command, temp, lane)}
        (ROOT / "camber/router_surface_live_results.json").write_text(json.dumps(results, indent=2) + "\n")


if __name__ == "__main__":
    main()
