#!/usr/bin/env python3
"""Recheck shared transport outcomes while retaining historical gap evidence."""
import json
import shutil
import socket
import struct
import subprocess
import tempfile
from contextlib import ExitStack
from datetime import date
from pathlib import Path

from run_dispatch import ROOT, guarded
from run_live import Peer
from run_risks import event_time, observe


def free_port():
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        return reservation.getsockname()[1]


def admission(port, partial_count):
    def interact(process, wait_for):
        wait_for("READY")
        with ExitStack() as stack:
            held = Peer(port)
            stack.callback(held.close)
            held.send("GET", "/users/me", close=True, **{"x-hold": "yes"})
            wait_for("ENTER 0")
            # Reserve the fixture's release/control socket before exhausting admission.
            control = Peer(port)
            stack.callback(control.close)
            locally_sent = 0
            unsafe_partial_closes = []
            for index in range(partial_count):
                peer = socket.create_connection(("127.0.0.1", port), timeout=3)
                stack.callback(peer.close)
                try:
                    peer.sendall(b"POST /users HTTP/1.1\r\nHost: localhost\r\nContent-Length: 4096\r\nConnection: close\r\n\r\n" + b"x" * 1024)
                    locally_sent += 1
                except (ConnectionResetError, BrokenPipeError) as error:
                    unsafe_partial_closes.append({"index": index, "close": type(error).__name__})
            overflow = Peer(port)
            stack.callback(overflow.close)
            at_transport_cap = partial_count + 2 >= 128
            if at_transport_cap:
                try:
                    overflow.send("POST", "/users", b'{"name":"Cara"}', close=True)
                    assert overflow.reader.read(1) == b""
                    transport_overflow = "eof"
                except (ConnectionResetError, BrokenPipeError) as error:
                    transport_overflow = type(error).__name__
            else:
                overflow.send("POST", "/users", b'{"name":"Cara"}', close=True)
                overflow.response(503, b"")
                transport_overflow = "parsed-application-503"
            wait_for("LISTENER CLOSED")
            rejected = int(not at_transport_cap)
            counts = {"limit": 1, "busy": 1, "mask": 1, "completed": 0, "rejected": rejected}
            control.capacity(counts)
            listing = subprocess.run([shutil.which("lsof"), "-a", "-p", str(process.pid),
                                      "-iTCP", "-sTCP:ESTABLISHED", "-Fn"],
                                     capture_output=True, text=True, timeout=5)
            assert listing.returncode == 0 and process.poll() is None, listing.stderr
            endpoints = [line for line in listing.stdout.splitlines() if line.startswith("n") and f":{port}->" in line]
            control.send("POST", "/_release")
            control.response(204, b"")
            held.response(200, b'{"id":7,"name":"Alice"}')
            recovered = {"limit": 1, "busy": 0, "mask": 0, "completed": 1, "rejected": rejected}
            control.capacity(recovered)
            control.send("GET", "/_capacity", close=True)
            control.response(200, json.dumps(recovered, separators=(",", ":")).encode())
            return {"incomplete_body_peers_attempted": partial_count,
                    "partial_locally_completed_sendalls": locally_sent,
                    "partial_body_bytes_locally_sent": locally_sent * 1024,
                    "unsafe_partial_close_events": unsafe_partial_closes,
                    "active_handler_counts": counts, "recovered_counts": recovered,
                    "transport_overflow": transport_overflow, "admitted_connection_cap": 128,
                    "established_server_endpoints": len(endpoints), "endpoint_evidence": endpoints,
                    "exceeds_proposed_128_connection_default": len(endpoints) > 128}
    return interact


def writing(port, reset):
    def interact(process, wait_for):
        wait_for("READY")
        with socket.create_connection(("127.0.0.1", port), timeout=3) as peer:
            wait_for("WRITE_ARMED")
            if reset:
                peer.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
                peer.close()
                return {"client_reset_before_write": True, "response_bytes": None}
            chunks = []
            while True:
                block = peer.recv(4096)
                if not block:
                    break
                chunks.append(block)
            response = b"".join(chunks)
            head, body = response.split(b"\r\n\r\n", 1)
            assert head.startswith(b"HTTP/1.1 200 ") and body == b"ok", response
            return {"client_reset_before_write": False, "response_bytes": response.decode("ascii")}
    return interact


def main():
    if shutil.which("lsof") is None:
        raise RuntimeError("lsof is required to count actual accepted server endpoints")
    results = {"date": date.today().isoformat(), "bend": guarded(["bend", "version"], 20)[0].strip(),
               "bun": guarded(["bun", "--version"], 20)[0].strip(), "lanes": {}}
    target = ROOT / "camber/transport_outcome_results.json"
    with tempfile.TemporaryDirectory(prefix="camber-transport-risks-") as directory:
        temp = Path(directory)
        for lane, suffix in (("native", ""), ("javascript", ".js")):
            binary = temp / ("probe" + suffix)
            _, rss, seconds = guarded(["bend", ROOT / "camber/transport_probe.bend", "-o", binary], 180)
            command = [str(binary), "--threads", "1", "--gpu", "off"] if lane == "native" else ["bun", str(binary)]
            data = {"build_seconds": seconds, "sampled_build_peak_rss_kib": rss, "cases": {}}
            results["lanes"][lane] = data
            with socket.socket() as occupied:
                occupied.bind(("127.0.0.1", 0))
                occupied.listen(1)
                path = temp / (lane + "-startup")
                record = observe(command + ["startup", str(path), str(occupied.getsockname()[1]), "1"], path)
                record["resource_files_created"] = {kind: Path(str(path) + "-" + kind + "-0").exists() for kind in ("store", "audit")}
                record["readiness_reported"] = event_time(record, "READY") is not None
                record["explicit_bundle_close_markers"] = [event for event in record["events"] if event["text"].startswith("CLOSED ")]
                data["cases"]["startup_bind_failure"] = record
                target.write_text(json.dumps(results, indent=2) + "\n")
                assert all(record["resource_files_created"].values()), record
                print(f"{lane}/startup: returncode={record['returncode']}; readiness={record['readiness_reported']}", flush=True)
            for partial in (1, 129):
                port, path = free_port(), temp / f"{lane}-admission-{partial}"
                record = observe(command + ["admission", str(path), str(port), str(partial + 3)], path, admission(port, partial))
                record["audit_bytes"] = Path(str(path) + "-audit-0").read_text()
                record["explicit_bundle_close_observed"] = event_time(record, "CLOSED 0") is not None
                data["cases"][f"admission_{partial}_incomplete"] = record
                target.write_text(json.dumps(results, indent=2) + "\n")
                assert record["returncode"] == 0 and record["audit_bytes"] == "" and record["explicit_bundle_close_observed"], record
                assert 2 <= record["established_server_endpoints"] <= 128, record
                print(f"{lane}/admission-{partial}: {record['established_server_endpoints']} endpoints; one busy worker", flush=True)
            for reset in (False, True):
                port, path = free_port(), temp / f"{lane}-write-{reset}"
                record = observe(command + ["write", str(path), str(port), "1"], path, writing(port, reset))
                record["raw_write_succeeded"] = event_time(record, "WRITE_SUCCEEDED") is not None
                record["raw_write_failed"] = event_time(record, "WRITE_FAILED") is not None
                record["public_turn_close"] = event_time(record, "PUBLIC_TURN_CLOSE") is not None
                record["public_write_accepted"] = event_time(record, "PUBLIC_WRITE_ACCEPTED") is not None
                record["public_write_failed"] = event_time(record, "PUBLIC_WRITE_FAILED") is not None
                data["cases"]["write_reset" if reset else "write_healthy"] = record
                target.write_text(json.dumps(results, indent=2) + "\n")
                assert record["returncode"] == 0 and (record["raw_write_failed"] if reset else record["raw_write_succeeded"]), record
                assert record["public_write_failed"] == record["raw_write_failed"], record
                assert record["public_write_accepted"] == record["raw_write_succeeded"], record
                print(f"{lane}/write-reset-{reset}: raw_failure={record['raw_write_failed']}; public_close={record['public_turn_close']}", flush=True)


if __name__ == "__main__":
    main()
