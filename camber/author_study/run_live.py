#!/usr/bin/env python3
"""Exercise unchanged submitted dispatch over the existing finite HTTP transport."""
import argparse
import concurrent.futures
import http.client
import json
import shutil
import socket
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from run_dispatch import guarded
from run_surface_live import connect
from run import STUDY, SEED, POLICIES, TITLE, cases, check


def serve(executable, journal, mode, requests):
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    observations = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        future = pool.submit(guarded, [executable, journal, mode, str(port)], 25)
        peer = connect(port, future)
        try:
            for case in requests:
                inputs = case["inputs"]
                body = inputs.get("body", json.dumps(dict(title=TITLE, secret="CANARY", published=False)))
                peer.send(inputs.get("method", "POST"), inputs.get("target", "/publish"), body.encode(),
                          token=inputs.get("token", "Bearer alice"),
                          **{"content-type": inputs.get("media", "application/json")})
                status_line = peer.reader.readline().split()
                assert len(status_line) >= 2 and status_line[0] == b"HTTP/1.1", status_line
                headers = http.client.parse_headers(peer.reader)
                lengths = headers.get_all("content-length")
                assert lengths is not None and len(lengths) == 1, headers
                assert headers.get("transfer-encoding") is None, headers
                response_body = peer.reader.read(int(lengths[0])).decode("utf-8")
                response = dict(status=int(status_line[1]), body=response_body,
                                authenticate=headers.get("www-authenticate", ""), allow=headers.get("allow", ""))
                response.update({p: headers.get("x-" + p + "-policy", "") for p in POLICIES})
                observations.append(dict(response=response))
        finally:
            peer.close()
        stdout, rss, seconds = future.result()
    lines = stdout.splitlines()
    assert "STUDY LIVE PASS" in lines and "LISTENER CLOSED" in lines, stdout
    traces = [json.loads(line[6:]) for line in lines if line.startswith("TRACE ")]
    returned = [json.loads(line) for line in lines if line.startswith('{"response":')]
    assert len(traces) == len(requests) and len(returned) == 1, stdout
    expected_journal = SEED if mode == "r" else b""
    for case, observation, trace in zip(requests, observations, traces):
        observation["response"]["trace"] = trace
        observation["readback"] = returned[0]["readback"]
        # The shared oracle checks each request's write; this server can handle a sequence.
        write = observation["response"]["body"].encode() + b"\n" if case["owner"] is not None else b""
        check(case, observation, SEED if mode == "r" else write)
        if mode != "r":
            expected_journal += write
    assert journal.read_bytes() == expected_journal, (journal.read_bytes(), expected_journal)
    return dict(observations=observations, stdout=stdout, sampled_peak_rss_kib=rss, seconds=seconds)


def main(author, round_name):
    source = STUDY / author
    evidence = STUDY / "evidence" / author / round_name
    if not evidence.is_dir():
        raise ValueError("Run the direct judge first to preserve the submission")
    report = dict(author=author, round=round_name, scenarios=[])
    driver = source / "driver.bend"
    live = source / "live_driver.bend"
    shutil.copyfile(STUDY / "driver.bend", driver)
    shutil.copyfile(STUDY / "live_driver.bend", live)
    try:
        with tempfile.TemporaryDirectory(prefix="camber-author-live-") as directory:
            temp = Path(directory)
            executable = temp / "live"
            try:
                stdout, rss, seconds = guarded(["bend", live, "-o", executable], 120)
                report["build"] = dict(passed=True, stdout=stdout, sampled_peak_rss_kib=rss, seconds=seconds)
            except Exception as error:
                report["build"] = dict(passed=False, error=str(error))
                return
            for case in cases():
                journal = temp / case["name"]
                mode = case["inputs"].get("mode", "w")
                if mode == "r":
                    journal.write_bytes(SEED)
                result = dict(name=case["name"], passed=False)
                report["scenarios"].append(result)
                try:
                    result.update(serve(executable, journal, mode, [case]), passed=True)
                except Exception as error:
                    result["error"] = str(error)
                print(author, round_name, "live", case["name"], "PASS" if result["passed"] else "FAIL", flush=True)
            selected = [next(c for c in cases() if c["name"] == name) for name in ("alice", "bob")]
            public = next(c for c in cases() if c["name"] == "public")
            public = {**public, "inputs": {**public["inputs"], "mode": "w"}}
            selected.insert(1, public)
            result = dict(name="same-worker-principal-and-public-isolation", passed=False)
            report["scenarios"].append(result)
            try:
                result.update(serve(executable, temp / "sequence", "w", selected), passed=True)
            except Exception as error:
                result["error"] = str(error)
    finally:
        driver.unlink()
        live.unlink()
        report["passed"] = len(report["scenarios"]) == len(cases()) + 1 and all(row["passed"] for row in report["scenarios"])
        with (evidence / "live-results.json").open("x") as output:
            json.dump(report, output, indent=2)
            output.write("\n")
        print(author, round_name, "live overall", report["passed"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("author", choices=("grok", "opus"))
    parser.add_argument("--round", default="initial")
    args = parser.parse_args()
    if not args.round.replace("-", "").isalnum():
        parser.error("round must contain only letters, digits, or hyphens")
    main(args.author, args.round)
