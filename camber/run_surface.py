#!/usr/bin/env python3
"""Exercise the provisional author surface; not a Camber release or transport gate."""
import json
import tempfile
from pathlib import Path

from run_dispatch import ROOT, guarded

ROOT_ENTER = [["before", 0, 1]]
AUTH_ENTER = ROOT_ENTER + [["before", 1, 1]]
GROUP_ENTER = AUTH_ENTER + [["before", 1, 2]]
ROUTE_ENTER = GROUP_ENTER + [["before", 2, 1]]
DECODE = ROUTE_ENTER + ["decode"]
HANDLED = DECODE + ["handle"]
DOCUMENT_EXIT = [["after", "document/second"], ["after", "document/first"]]
GROUP_EXIT = [["after", "users/second"], ["after", "users/first"]]
ROOT_EXIT = [["after", "root"]]
ALL_EXIT = DOCUMENT_EXIT + GROUP_EXIT + ROOT_EXIT
DOCUMENT = '{"doc":{"note":"héllo","n":1e+02}}'
POLICIES = ("root", "users", "document", "public", "ping")
SEED = b'{"seed":true}\n'


def case(name, status, trace, policies=(), body=None, owner=None, **inputs):
    return name, inputs, status, trace, policies, body, owner


def cases():
    rows = [
        case("typed-alice", 201, HANDLED + ALL_EXIT, ("root", "users", "document"), '{"owner":7,"doc":{"note":"héllo","n":1e+02}}', 7),
        case("typed-bob", 201, HANDLED + ALL_EXIT, ("root", "users", "document"), '{"owner":8,"doc":{"note":"héllo","n":1e+02}}', 8, token="Bearer bob"),
        case("escaped-key", 201, HANDLED + ALL_EXIT, ("root", "users", "document"), '{"owner":7,"doc":1}', 7, input_body='{"d\\u006fc":1}'),
        case("public-sibling", 200, ROOT_ENTER + [["before", 3, 1], ["after", "ping"], ["after", "public"]] + ROOT_EXIT, ("root", "public", "ping"), "public", method="GET", target="/public", token="", input_body="not JSON"),
        case("unknown-path", 404, ROOT_ENTER + [["map", "missing"]] + ROOT_EXIT, ("root",), target="/missing", token=""),
        case("auth-before-decode", 401, AUTH_ENTER + [["map", "unauthorized"]] + GROUP_EXIT + ROOT_EXIT, ("root", "users"), "", token="", input_body="not JSON"),
        case("group-early", 409, GROUP_ENTER + GROUP_EXIT + ROOT_EXIT, ("root", "users"), body="closed", control="early", input_body="not JSON"),
        case("group-reject", 403, GROUP_ENTER + [["map", "forbidden"]] + GROUP_EXIT + ROOT_EXIT, ("root", "users"), control="reject", input_body="not JSON"),
    ]
    public_trace = ROOT_ENTER + [["before", 3, 1], ["after", "ping"], ["after", "public"]] + ROOT_EXIT
    rows.extend([
        case("path-method-group", 405, GROUP_ENTER + [["map", "method"]] + GROUP_EXIT + ROOT_EXIT, ("root", "users"), "", method="GET", expected_allow="OPTIONS, POST"),
        case("path-options-group", 204, GROUP_ENTER + GROUP_EXIT + ROOT_EXIT, ("root", "users"), "", method="OPTIONS", expected_allow="OPTIONS, POST"),
        case("path-method-auth", 401, AUTH_ENTER + [["map", "unauthorized"]] + GROUP_EXIT + ROOT_EXIT, ("root", "users"), "", method="GET", token=""),
        case("path-options-auth", 401, AUTH_ENTER + [["map", "unauthorized"]] + GROUP_EXIT + ROOT_EXIT, ("root", "users"), "", method="OPTIONS", token=""),
        case("head-public", 200, public_trace, ("root", "public", "ping"), "public", method="HEAD", target="/public", token="", input_body="not JSON"),
        case("options-public", 204, ROOT_ENTER + [["before", 3, 1], ["after", "public"]] + ROOT_EXIT, ("root", "public"), "", method="OPTIONS", target="/public", expected_allow="GET, HEAD, OPTIONS"),
        case("options-star", 204, ROOT_ENTER + ROOT_EXIT, ("root",), "", method="OPTIONS", target="*", expected_allow="GET, HEAD, OPTIONS, POST"),
        case("star-misuse", 400, ROOT_ENTER + [["map", "bad-target"]] + ROOT_EXIT, ("root",), "invalid target", method="GET", target="*"),
        case("bad-path-escape", 400, ROOT_ENTER + [["map", "bad-target"]] + ROOT_EXIT, ("root",), "invalid target", target="/documents%GG"),
        case("bad-query-utf8", 400, ROOT_ENTER + [["map", "bad-target"]] + ROOT_EXIT, ("root",), "invalid target", method="GET", target="/public?x=%FF"),
        case("encoded-public", 200, public_trace, ("root", "public", "ping"), "public", method="GET", target="/pub%6Cic?tag=a&tag=b", token=""),
        case("absolute-public", 200, public_trace, ("root", "public", "ping"), "public", method="GET", target="http://example.test/public", token=""),
        case("trailing-slash-miss", 404, ROOT_ENTER + [["map", "missing"]] + ROOT_EXIT, ("root",), "not found", method="GET", target="/public/"),
        case("generated-group-early", 409, GROUP_ENTER + GROUP_EXIT + ROOT_EXIT, ("root", "users"), "closed", method="OPTIONS", control="early", input_body="not JSON"),
    ])
    for name, body in (
        ("malformed-json", "not JSON"),
        ("wrong-shape", "[]"),
        ("missing-field", "{}"),
        ("wrong-field", '{"other":1}'),
        ("extra-field", '{"doc":1,"other":2}'),
        ("duplicate-field", '{"doc":1,"doc":2}'),
    ):
        rows.append(case(name, 400, DECODE + [["map", "bad-document"]] + ALL_EXIT, ("root", "users", "document"), input_body=body))
    for name, media in (("missing-media", ""), ("unsupported-media", "text/plain")):
        rows.append(case(name, 415, ROUTE_ENTER + [["map", "unsupported"]] + ALL_EXIT, ("root", "users", "document"), media=media))
    rows.extend([
        case("real-write-failure", 503, HANDLED + [["map", "write"]] + ALL_EXIT, ("root", "users", "document"), mode="r"),
        case("transform-before-map", 500, HANDLED + DOCUMENT_EXIT[:1] + [["map", "transform"]], owner=7, fault="document/second"),
        case("group-transform-before-map", 500, HANDLED + DOCUMENT_EXIT + GROUP_EXIT[:1] + [["map", "transform"]], owner=7, fault="users/second"),
        case("transform-after-map", 500, AUTH_ENTER + [["map", "unauthorized"]] + GROUP_EXIT[:1], body="", token="", fault="users/second"),
        case("early-transform-failure", 500, GROUP_ENTER + GROUP_EXIT[:1] + [["map", "transform"]], control="early", fault="users/second"),
        case("mapper-fails", 500, DECODE + [["map", "bad-document"]], body="", mapper="fail", input_body="not JSON"),
        case("mapper-invalid", 500, DECODE + [["map", "bad-document"]], body="", mapper="invalid", input_body="not JSON"),
        case("transform-mapper-fails", 500, HANDLED + DOCUMENT_EXIT[:1] + [["map", "transform"]], body="", owner=7, fault="document/second", mapper="fail"),
        case("transform-mapper-invalid", 500, HANDLED + DOCUMENT_EXIT[:1] + [["map", "transform"]], body="", owner=7, fault="document/second", mapper="invalid"),
        case("validation-before-map", 500, HANDLED + ALL_EXIT + [["map", "invalid-response"]], owner=7, fault="invalid/root"),
        case("validation-after-map", 500, AUTH_ENTER + [["map", "unauthorized"]] + GROUP_EXIT + ROOT_EXIT, body="", token="", fault="invalid/root"),
    ])
    for fault in ("header/root", "framing/root", "name/root"):
        rows.append(case("unsafe-" + fault.split("/")[0], 500, HANDLED + ALL_EXIT + [["map", "invalid-response"]], owner=7, body="invalid response", fault=fault))
        rows.append(case("unsafe-" + fault.split("/")[0] + "-after-map", 500, AUTH_ENTER + [["map", "unauthorized"]] + GROUP_EXIT + ROOT_EXIT, body="", token="", fault=fault))
    return rows


def exercise(command, directory, lane):
    for name, inputs, status, trace, policies, body, owner in cases():
        journal = directory / f"{lane}-{name}"
        mode = inputs.get("mode", "w")
        if mode == "r":
            journal.write_bytes(SEED)
        arguments = [
            str(journal), mode, inputs.get("fault", ""), inputs.get("mapper", "normal"),
            inputs.get("method", "POST"), inputs.get("target", "/documents"),
            inputs.get("token", "Bearer alice"), inputs.get("media", "application/json"),
            inputs.get("input_body", DOCUMENT), inputs.get("control", ""),
        ]
        output, _, _ = guarded([*command, *arguments], 15)
        observation = json.loads(output)
        response = observation["response"]
        assert response["status"] == status, (name, response)
        assert response["trace"] == trace, (name, response)
        assert {key: response[key] for key in POLICIES} == {key: "yes" if key in policies else "" for key in POLICIES}, (name, response)
        assert response["authenticate"] == ("Bearer" if status == 401 else ""), (name, response)
        assert response["allow"] == inputs.get("expected_allow", ""), (name, response)
        if body is not None:
            assert response["body"] == body, (name, response)
        if mode == "r":
            assert observation["readback"].encode() == SEED, (name, observation)
            assert journal.read_bytes() == SEED, name
        else:
            assert observation["readback"] == "", (name, observation)
            expected = b"" if owner is None else f'{{"owner":{owner}}}\n'.encode()
            assert journal.read_bytes() == expected, (name, journal.read_bytes())
        print(f"{lane}/{name}: PASS", flush=True)


def main():
    with tempfile.TemporaryDirectory(prefix="camber-surface-") as directory:
        temp = Path(directory)
        for lane, suffix in (("native", ""), ("javascript", ".js")):
            executable = temp / ("surface" + suffix)
            _, rss, seconds = guarded(["bend", str(ROOT / "camber/surface_check.bend"), "-o", str(executable)], 120)
            print(f"{lane}/build: {seconds:.3f}s, sampled compiler RSS {rss / 1024:.2f} MiB", flush=True)
            command = [str(executable)] if lane == "native" else ["bun", str(executable)]
            exercise(command, temp, lane)


if __name__ == "__main__":
    main()
