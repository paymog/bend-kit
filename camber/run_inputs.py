#!/usr/bin/env python3
"""Guarded native/JS direct+loopback checks; one compiler/runtime at a time."""
from pathlib import Path
import json
import socket
import tempfile
import threading
import time
from run_owner import ROOT, run


def cases():
    rows = []

    def add(name, target="/json", body=b"{}", status=200, media="application/json", encoding="-", auth="Bearer accepted", depth=64, expected=None, journal=None):
        method = "GET" if target.startswith(("/users/", "http://")) else "POST"
        if journal is None:
            journal = ["auth", "decode", "business"] if status < 400 else ["auth", "decode", "map"]
        rows.append(dict(name=name, method=method, target=target, body=body.hex(), status=status, media=media, encoding=encoding, auth=auth, depth=depth, expected=None if expected is None else expected.hex(), journal=journal))

    lookup = b'{"id":7,"limit":1,"tags":[],"empty_keys":[]}'
    add("path-percent-once", "/users/%37?limit=1", expected=lookup)
    add("absolute-form", "http://example.test/users/7?limit=1", expected=lookup)
    add("path-no-second-decode", "/users/%2537?limit=1", status=400)
    add("query-cannot-overwrite-path", "/users/7?limit=1&id=9", expected=lookup)
    add("path-without-query", "/users/7", expected=lookup)
    add("ordered-list-without-scalar", "/users/7?tag=a&tag=b", expected=b'{"id":7,"limit":1,"tags":["a","b"],"empty_keys":[]}')
    add("list-order-empty-first-equals", "/users/7?limit=1&&tag=a&tag=&tag&tag=x=y&tag=c+d&=x&=y&", expected=b'{"id":7,"limit":1,"tags":["a","","","x=y","c d"],"empty_keys":["x","y"]}')
    for value in ("abc", "4294967296", "-1", "+1", "1.0", "%D9%A1", "%2537"):
        add("path-invalid-" + value, "/users/" + value + "?limit=1", status=400)
    add("u32-max", "/users/4294967295?limit=4294967295", expected=b'{"id":4294967295,"limit":4294967295,"tags":[],"empty_keys":[]}')
    add("u32-leading-zero", "/users/0007?limit=01", expected=lookup)
    for query in ("limit=", "limit=4294967296", "limit=x", "limit=1&limit=1", "limit=1&%6cimit=2", "limit"):
        add("scalar-" + query, "/users/7?" + query, status=400)
    for query in ("tag=%", "tag=%GG", "tag=%C0%AF", "tag=%ED%A0%80", "tag=%FF", "tag=%00", "%00=x"):
        add("query-syntax-" + query, "/users/7?limit=1&" + query, status=400, journal=["map"])
    for path in ("%", "%FF", "%00", "a%2Fb"):
        add("path-syntax-" + path, "/users/" + path + "?limit=1", status=400, journal=["map"])
    add("auth-before-invalid-json", body=b"{", status=401, auth="-", media="-", journal=["auth"], expected=b"")
    add("auth-before-typed-path", "/users/abc?limit=1", status=401, auth="-", journal=["auth"], expected=b"")
    for media in ("application/json", "APPLICATION/JSON", "Application/Problem+Json", "application/vnd.example+json; version=2", "application/json; charset=UTF-8", 'application/json; charset="UTF-8"', 'application/json; profile="a;charset=latin1"; charset="UTF-8"', "application/json; ignored=x; CHARSET = utf-8"):
        add("json-media-" + media, media=media, expected=b"{}")
    for media in ("-", "text/json", "application/xml", "application/+json", "application/a b+json", "application/json; charset=latin1", 'application/json; charset="latin1"', "application/json; charset=utf-8; charset=latin1", 'application/json; charset="utf-8', "application/json; charset"):
        add("unsupported-media-" + media, media=media, status=415)
    add("identity-case", encoding="IDENTITY", expected=b"{}")
    add("identity-list", encoding="identity, IDENTITY", expected=b"{}")
    for encoding in ("gzip", "br", "identity,gzip"):
        add("encoding-" + encoding, encoding=encoding, status=415)
    bad = [b"", b" ", b"{", b"{}x", b"[1,]", b'"\xff"', b'"\xc0\xaf"', b'"\xed\xa0\x80"', b"\xef\xbb\xbf{}", b'"\\uD800"', b'"\\uDC00"', b'"\\uD800\\u0041"', b'{"name":1,"\\u006eame":2}', b'{"outer":{"x":1,"\\u0078":2}}', b'[{"x":1,"x":2}]', b'{"a":[{"x":1,"\\u0078":2}]}']
    for index, body in enumerate(bad):
        add(f"json-reject-{index}", body=body, status=400)
    add("same-key-different-object", body=b'[{"x":1},{"x":2}]', expected=b'[{"x":1},{"x":2}]')
    add("valid-surrogate-pair", body=b'"\\uD83D\\uDE00"', expected='"😀"'.encode())
    for number in (b"-0", b"1e+02", b"1.2300", b"9007199254740993", b"4294967296"):
        add("exact-number-" + number.decode(), body=number, expected=number)
    for number in (b"4294967296", b"-1", b"1.0", b"1e0", b'"1"'):
        add("checked-number-" + number.decode(), "/number", body=number, status=400)
    add("checked-number-max", "/number", body=b"4294967295", expected=b"4294967295")
    for depth, cap, status in ((64, 64, 200), (65, 64, 400), (2, 2, 200), (3, 2, 400), (1, 0, 400), (0, 0, 200)):
        body = b"[" * depth + b"0" + b"]" * depth
        add(f"depth-{depth}-cap-{cap}", body=body, depth=cap, status=status, expected=body if status == 200 else None)
    for media in ("text/plain", "TEXT/PLAIN; CHARSET=UTF-8", 'text/x-example; profile="a;b"; charset="utf-8"'):
        body = "café😀\0".encode()
        add("text-media-" + media, "/text", body=body, media=media, expected=body)
    add("text-empty", "/text", body=b"", media="text/plain", expected=b"")
    for media in ("-", "application/json", "text/", "text/a b", "text/plain; charset=latin1"):
        add("text-unsupported-" + media, "/text", media=media, status=415)
    add("text-encoding", "/text", media="text/plain", encoding="gzip", status=415)
    for body in (b"\xff", b"\x80", b"\xc0\xaf", b"\xed\xa0\x80", b"\xf4\x90\x80\x80", b"\xe2\x82"):
        add("text-invalid-" + body.hex(), "/text", body=body, media="text/plain", status=400)
    raw = b"\x00\xff\x80/\xc0\xaf"
    add("raw-binary-identical", "/raw", body=raw, media="-", expected=raw)
    add("raw-no-decompression", "/raw", body=raw, media="application/octet-stream", encoding="gzip", expected=raw)
    add("typed-creation", "/create", body=b'{"name":"Ada"}', status=201, expected=b'{"name":"Ada"}')
    for size, status in ((100, 201), (101, 400)):
        body = b'{"name":"' + "😀".encode() * size + b'"}'
        add(f"creation-unicode-scalars-{size}", "/create", body=body, status=status, expected=body if status == 201 else None)
    for body in (b"{}", b'{"name":""}', b'{"name":1}', b'{"wrong":"Ada"}', b'{"name":"Ada","extra":1}', b'{"name":"' + b"a" * 101 + b'"}'):
        add("domain-validation-" + body.hex()[:30], "/create", body=body, status=400)
    return rows


def response(raw):
    head, body = raw.split(b"\r\n\r\n", 1)
    lines = head.split(b"\r\n")
    status = int(lines[0].split()[1])
    fields = [tuple(line.split(b": ", 1)) for line in lines[1:]]
    application = [(k.decode("latin1"), v.decode("latin1")) for k, v in fields if k.lower() not in (b"content-length", b"connection")]
    return status, sorted(application), body.hex()


def assert_case(case, receipt, journal):
    status, headers, body = receipt
    assert status == case["status"], (case["name"], receipt)
    if case["expected"] is not None:
        assert body == case["expected"], (case["name"], receipt)
    if status in (400, 415):
        problem = json.loads(bytes.fromhex(body))
        assert problem["status"] == status and problem["type"] == "about:blank", (case, problem)
        assert ("content-type", "application/problem+json") in headers, receipt
    assert journal == case["journal"], (case["name"], journal, case["journal"])
    assert journal.count("business") == (1 if status < 400 else 0), (case, journal)
    assert journal.count("map") <= 1, (case, journal)


def live(command, rows, journal, direct):
    receipts, failures = [], []

    def clients():
        try:
            deadline = time.monotonic() + 30
            first = None
            while first is None:
                try:
                    first = socket.create_connection(("127.0.0.1", 18335), timeout=1)
                except ConnectionRefusedError:
                    if time.monotonic() > deadline:
                        raise
                    time.sleep(0.05)
            offset = 0
            for index, case in enumerate(rows):
                connection = first if index == 0 else socket.create_connection(("127.0.0.1", 18335), timeout=5)
                body = bytes.fromhex(case["body"])
                fields = [("Host", "example.test"), ("Connection", "close"), ("Content-Length", str(len(body)))]
                for name, key in (("Content-Type", "media"), ("Content-Encoding", "encoding"), ("Authorization", "auth")):
                    if case[key] != "-":
                        fields.append((name, case[key]))
                raw = f'{case["method"]} {case["target"]} HTTP/1.1\r\n'.encode() + b"".join(f"{k}: {v}\r\n".encode() for k, v in fields) + b"\r\n" + body
                with connection:
                    connection.settimeout(15)
                    connection.sendall(raw)
                    chunks = []
                    while chunk := connection.recv(65536):
                        chunks.append(chunk)
                receipt = response(b"".join(chunks))
                events = journal.read_text().splitlines()
                observed = events[offset:]
                offset = len(events)
                assert_case(case, receipt, observed)
                assert receipt == direct[case["name"]], (case["name"], receipt, direct[case["name"]])
                receipts.append(dict(name=case["name"], response=receipt, journal=observed))
        except BaseException as error:
            failures.append(error)

    thread = threading.Thread(target=clients, daemon=True)
    thread.start()
    output = run(command, timeout=180)
    thread.join(timeout=20)
    assert not thread.is_alive(), "live client unfinished"
    if failures:
        raise failures[0]
    assert "CLOSED" in output, output
    assert len(receipts) == len(rows)
    return receipts


def main():
    evidence = {"model": "openai-codex/gpt-6.1-sol", "reasoning": "medium", "cases": [], "lanes": {}, "adverse": []}
    rows = cases()
    assert len({case["name"] for case in rows}) == len(rows), "duplicate case names"
    evidence["cases"] = rows
    try:
        run(["bash", "scripts/check.sh", "camber"])
        run(["bash", "scripts/publish.sh", "--check", "camber"])
        with tempfile.TemporaryDirectory(prefix="camber-inputs-") as temp:
            temp = Path(temp)
            for extension, lane in (("", "native"), (".js", "js")):
                binary = temp / ("inputs" + extension)
                run(["bend", "camber/input_check.bend", "-o", str(binary)])
                command = [str(binary)] if not extension else ["bun", str(binary)]
                direct, receipts = {}, []
                evidence["lanes"][lane] = {"direct": receipts, "live": []}
                for index, case in enumerate(rows):
                    journal = temp / f"{lane}-direct-{index}.journal"
                    output = run(command + ["direct", case["method"], case["target"], case["media"], case["encoding"], case["auth"], case["body"], str(case["depth"]), str(journal)], timeout=30)
                    lines = [line[9:] for line in output.splitlines() if line.startswith("RESPONSE ")]
                    assert len(lines) == 1, output
                    receipt = response(bytes.fromhex(lines[0]))
                    observed = journal.read_text().splitlines() if journal.exists() else []
                    assert_case(case, receipt, observed)
                    direct[case["name"]] = receipt
                    receipts.append(dict(name=case["name"], response=receipt, journal=observed))
                for cap in sorted({case["depth"] for case in rows}):
                    subset = [case for case in rows if case["depth"] == cap]
                    journal = temp / f"{lane}-live-{cap}.journal"
                    evidence["lanes"][lane]["live"].extend(live(command + ["live", "18335", str(len(subset)), str(cap), str(journal)], subset, journal, direct))
                for source in ("check", "dispatch_check", "response_check", "scoped_check", "response_live"):
                    binary = temp / (source + extension)
                    run(["bend", f"camber/{source}.bend", "-o", str(binary)])
                    command = [str(binary)] if not extension else ["bun", str(binary)]
                    if source == "response_live":
                        from run_response import live as response_live
                        response_live(command)
                    else:
                        run(command)
        evidence["status"] = "PASS"
        print(f"typed inputs: {len(rows)} cases x native/JS x direct/live; journals and exact responses: PASS")
    except BaseException as error:
        evidence["status"] = "FAIL"
        evidence["adverse"].append(repr(error))
        raise
    finally:
        (ROOT / "camber/input_results.json").write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
