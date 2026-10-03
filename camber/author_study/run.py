#!/usr/bin/env python3
"""Judge immutable author submissions; never fix submitted code."""
import argparse
import copy
import hashlib
import json
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from run_dispatch import ROOT, guarded

STUDY = Path(__file__).resolve().parent
SEED = b'{"seed":true}\n'
POLICIES = ("root", "protected", "publish", "public")
ENTER = ["root-before", "auth", "decode"]
EXIT = ["publish-after", "protected-after", "root-after"]
TITLE = 'héllo\n"\\雪'


def cases():
    rows = []

    def add(name, status, trace, policies, expected_body=None, owner=None, title=TITLE, **inputs):
        rows.append(dict(name=name, status=status, trace=trace, policies=policies,
                         expected_body=expected_body, owner=owner, title=title, inputs=inputs))

    success = ENTER + ["handle"] + EXIT
    for name, owner, token, published in (("alice", 7, "Bearer alice", False),
                                          ("bob", 8, "Bearer bob", False),
                                          ("already-published", 7, "Bearer alice", True)):
        add(name, 201, success, ("root", "protected", "publish"), owner=owner,
            token=token, body=json.dumps(dict(title=TITLE, secret="CANARY", published=published)))
    for name, target in (("encoded-route", "/pub%6Cish?x=1&x=2"),
                          ("absolute-target", "http://example.test/publish")):
        add(name, 201, success, ("root", "protected", "publish"), owner=7, target=target)
    add("escaped-key", 201, success, ("root", "protected", "publish"), owner=7,
        title="plain", body='{"t\\u0069tle":"plain","secret":"CANARY","published":false}')
    for name, token in (("missing-auth", ""), ("wrong-auth", "Bearer mallory"),
                         ("wrong-scheme", "Basic alice")):
        add(name, 401, ["root-before", "auth", "map/unauthorized", "protected-after", "root-after"],
            ("root", "protected"), "", token=token, body="not JSON", mode="r")
    for name, body in (("malformed", "not JSON"), ("wrong-shape", "[]"),
                       ("missing-title", '{"secret":"CANARY","published":false}'),
                       ("missing-secret", '{"title":"plain","published":false}'),
                       ("missing-published", '{"title":"plain","secret":"CANARY"}'),
                       ("extra-owner", '{"title":"plain","secret":"CANARY","published":false,"owner":999}'),
                       ("title-type", '{"title":1,"secret":"CANARY","published":false}'),
                       ("secret-type", '{"title":"plain","secret":null,"published":false}'),
                       ("published-type", '{"title":"plain","secret":"CANARY","published":0}'),
                       ("duplicate-title", '{"title":"one","title":"two","secret":"CANARY","published":false}'),
                       ("escaped-duplicate", '{"title":"one","t\\u0069tle":"two","secret":"CANARY","published":false}'),
                       ("duplicate-secret", '{"title":"plain","secret":"one","secret":"two","published":false}'),
                       ("duplicate-published", '{"title":"plain","secret":"CANARY","published":false,"published":true}')):
        add(name, 400, ENTER + ["map/input"] + EXIT, ("root", "protected", "publish"),
            "invalid input", body=body, mode="r")
    for name, media in (("missing-media", ""), ("unsupported-media", "text/plain")):
        add(name, 415, ENTER + ["map/media"] + EXIT, ("root", "protected", "publish"),
            "unsupported media type", media=media, mode="r")
    add("real-write-failure", 503, ENTER + ["handle", "map/write"] + EXIT,
        ("root", "protected", "publish"), "store unavailable", mode="r")
    for name, target in (("public", "/public"), ("encoded-public", "/pub%6Cic?x=1")):
        add(name, 200, ["root-before", "public-before", "public-handle", "public-after", "root-after"],
            ("root", "public"), "public", method="GET", target=target, token="", body="not JSON", mode="r")
    add("missing-route", 404, ["root-before", "root-after"], ("root",), target="/missing", mode="r")
    add("wrong-method", 405, ["root-before", "root-after"], ("root",), "", method="GET", mode="r", allow="OPTIONS, POST")
    return rows


def check(case, observation, journal):
    response = observation["response"]
    assert response["status"] == case["status"], (case["name"], "status", response)
    assert response["trace"] == case["trace"], (case["name"], "trace", response)
    assert {p: response[p] for p in POLICIES} == {p: "yes" if p in case["policies"] else "" for p in POLICIES}, (case["name"], "policies", response)
    assert response["authenticate"] == ("Bearer" if case["status"] == 401 else ""), (case["name"], "authenticate", response)
    assert response["allow"] == case["inputs"].get("allow", ""), (case["name"], "allow", response)
    if case["owner"] is not None:
        expected = dict(owner=case["owner"], title=case["title"], published=True)
        assert json.loads(response["body"]) == expected, (case["name"], "public projection", response)
        assert journal == response["body"].encode() + b"\n", (case["name"], "journal", journal)
    elif case["expected_body"] is not None:
        assert response["body"] == case["expected_body"], (case["name"], "body", response)
    if case["inputs"].get("mode", "w") == "r":
        assert observation["readback"].encode() == SEED, (case["name"], "returned File", observation)
        assert journal == SEED, (case["name"], "unexpected write", journal)
    else:
        assert observation["readback"] == "", (case["name"], "readback", observation)
        if case["owner"] is None:
            assert journal == b"", (case["name"], "unexpected write", journal)


def self_check():
    case = cases()[0]
    body = json.dumps(dict(owner=7, title=TITLE, published=True))
    observation = dict(response=dict(status=201, trace=case["trace"], body=body,
                                    root="yes", protected="yes", publish="yes", public="",
                                    authenticate="", allow=""), readback="")
    check(case, observation, body.encode() + b"\n")
    for field, wrong in (("status", 200), ("trace", []), ("public", "yes"),
                          ("body", json.dumps(dict(owner=7, title=TITLE, published=False))),
                          ("body", json.dumps(dict(owner=7, title=TITLE, published=True, secret="CANARY")))):
        bad = copy.deepcopy(observation)
        bad["response"][field] = wrong
        try:
            check(case, bad, bad["response"]["body"].encode() + b"\n")
        except AssertionError:
            continue
        raise AssertionError(("oracle accepted mutation", field, wrong))
    failed = next(c for c in cases() if c["name"] == "real-write-failure")
    recovered = dict(response=dict(status=503, trace=failed["trace"], body="store unavailable",
                                   root="yes", protected="yes", publish="yes", public="",
                                   authenticate="", allow=""), readback=SEED.decode())
    check(failed, recovered, SEED)
    recovered["readback"] = ""
    try:
        check(failed, recovered, SEED)
    except AssertionError:
        print("Oracle rejects wrong status, lifecycle, sibling leakage, unpublished output, secret leakage, and lost returned File.")
        return
    raise AssertionError("oracle accepted lost returned File")


def judge(author, round_name):
    source = STUDY / author
    evidence = STUDY / "evidence" / author / round_name
    evidence.mkdir(parents=True, exist_ok=False)
    report = dict(author=author, round=round_name, scenarios=[], commands=[], hashes={})
    for name in ("app.bend", "domain.bend", "PROOF.bend", "LAWS.bend"):
        data = (source / name).read_bytes()
        (evidence / name).write_bytes(data)
        report["hashes"][name] = hashlib.sha256(data).hexdigest()
    law_hashes = {hashlib.sha256((STUDY / a / "LAWS.bend").read_bytes()).hexdigest() for a in ("grok", "opus")}
    assert len(law_hashes) == 1, "authors' fixed law files differ"

    def command(argv, timeout):
        entry = dict(argv=[str(a) for a in argv])
        report["commands"].append(entry)
        try:
            stdout, rss, elapsed = guarded(argv, timeout)
            entry.update(passed=True, stdout=stdout, sampled_peak_rss_kib=rss, seconds=elapsed)
            return stdout
        except Exception as error:
            entry.update(passed=False, error=str(error))
            return None

    driver = source / "driver.bend"
    shutil.copyfile(STUDY / "driver.bend", driver)
    try:
        command(["bend", source / "PROOF.bend"], 120)
        if report["commands"][-1]["passed"]:
            command(["bend", source / "PROOF.bend", "--verdict"], 120)
        with tempfile.TemporaryDirectory(prefix="camber-author-study-") as directory:
            temp = Path(directory)
            executable = temp / "app"
            built = command(["bend", driver, "-o", executable], 120)
            if built is not None:
                for case in cases():
                    inputs = case["inputs"]
                    journal = temp / case["name"]
                    mode = inputs.get("mode", "w")
                    if mode == "r":
                        journal.write_bytes(SEED)
                    argv = [executable, journal, mode, inputs.get("method", "POST"),
                            inputs.get("target", "/publish"), inputs.get("token", "Bearer alice"),
                            inputs.get("media", "application/json"),
                            inputs.get("body", json.dumps(dict(title=TITLE, secret="CANARY", published=False)))]
                    stdout = command(argv, 15)
                    result = dict(name=case["name"], passed=False)
                    report["scenarios"].append(result)
                    if stdout is not None:
                        try:
                            observation = json.loads(stdout)
                            result["observation"] = observation
                            check(case, observation, journal.read_bytes())
                            result["passed"] = True
                        except Exception as error:
                            result["error"] = str(error)
                    print(author, round_name, case["name"], "PASS" if result["passed"] else "FAIL", flush=True)
    finally:
        driver.unlink()
        report["runtime_passed"] = len(report["scenarios"]) == len(cases()) and all(c["passed"] for c in report["scenarios"])
        (evidence / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(dict(author=author, round=round_name, runtime_passed=report["runtime_passed"],
                         passed_scenarios=sum(c["passed"] for c in report["scenarios"]), total_scenarios=len(cases()))))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("author", choices=("grok", "opus", "self-check"))
    parser.add_argument("--round", default="initial")
    args = parser.parse_args()
    if args.author == "self-check":
        self_check()
    else:
        if not args.round.replace("-", "").isalnum():
            parser.error("round must contain only letters, digits, or hyphens")
        judge(args.author, args.round)
