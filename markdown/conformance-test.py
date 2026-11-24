#!/usr/bin/env python3
"""Check the differential gate without downloads, compilation, or renderers."""
import contextlib
import io
from pathlib import Path
import subprocess
import tempfile
from unittest.mock import patch

import conformance as checker


VERSION_CASES = [
    ({"section": "Entity and numeric character references", "example": 28,
      "markdown": "&nbsp &x; &#; &#x;\n&#87654321;\n&#abcdef0;\n&ThisIsNotDefined; &hi?;\n",
      "html": "<p>&amp;nbsp &amp;x; &amp;#; &amp;#x;\n&amp;#87654321;\n&amp;#abcdef0;\n&amp;ThisIsNotDefined; &amp;hi?;</p>\n"},
     "<p>&amp;nbsp &amp;x; &amp;#; &amp;#x;\n�\n&amp;#abcdef0;\n&amp;ThisIsNotDefined; &amp;hi?;</p>\n"),
    ({"section": "Emphasis and strong emphasis", "example": 354,
      "markdown": "*$*alpha.\n\n*£*bravo.\n\n*€*charlie.\n",
      "html": "<p>*$*alpha.</p>\n<p>*£*bravo.</p>\n<p>*€*charlie.</p>\n"},
     "<p>*$*alpha.</p>\n<p><em>£</em>bravo.</p>\n<p><em>€</em>charlie.</p>\n"),
]


def run(cases, reference, rendered, *, trailer=""):
    output = "".join(html + checker.END + "\n" for html in rendered) + trailer
    replies = [subprocess.CompletedProcess([], 0, "controlled reference\n")]
    replies.extend(subprocess.CompletedProcess([], 0, html.encode()) for html in reference)
    replies.extend((subprocess.CompletedProcess([], 0),
                    subprocess.CompletedProcess([], 0, output.encode())))
    with tempfile.TemporaryDirectory() as tmp, \
            patch.object(checker, "OUT", Path(tmp)), \
            patch.object(checker.sys, "argv", ["conformance.py", "--gfm-diff"]), \
            patch.object(checker, "differential_cases", return_value=[dict(t) for t in cases]), \
            patch.object(checker.urllib.request, "urlopen", side_effect=AssertionError("Unexpected download")), \
            patch.object(checker.subprocess, "run", side_effect=replies) as commands, \
            contextlib.redirect_stdout(io.StringIO()) as log:
        status = checker.main()
        assert commands.call_count == len(replies)
        return status, log.getvalue()


case = {"section": "GFM corpus", "example": "test", "markdown": "hello\n", "html": "<p>hello</p>\n"}
html = case["html"]
assert run([case], [html], [html])[0] == 0
status, log = run([case], [html], ["<p>wrong</p>\n"])
assert status == 1 and "FAIL test" in log

for rendered, trailer in [([], ""), ([html, html], ""), ([html], "trailing output"), ([], html)]:
    try:
        run([case], [html], rendered, trailer=trailer)
    except RuntimeError as error:
        assert "Expected 1 renderer results" in str(error)
    else:
        raise AssertionError("Accepted malformed renderer results")

for version_case, reference in VERSION_CASES:
    spec = version_case["html"]
    status, log = run([version_case], [reference], [spec])
    assert status == 0 and "1 explained version differences" in log
    for changed_reference, changed_rendered in [(reference + "x", spec), (reference, spec + "x")]:
        assert run([version_case], [changed_reference], [changed_rendered])[0] == 1
    for field, value in [("example", 999), ("section", "GFM corpus")]:
        altered = {**version_case, field: value}
        assert run([altered], [reference], [spec])[0] == 1

for checked in (False, True):
    attribute = 'checked="" ' if checked else ""
    reference = f'<ul>\n<li><input type="checkbox" {attribute}disabled="" /> task</li>\n</ul>\n'
    rendered = f'<ul>\n<li><input {attribute}disabled="" type="checkbox"> task</li>\n</ul>\n'
    assert run([case], [reference], [rendered])[0] == 0
    for changed_reference, changed_rendered in [
            (reference.replace("task", "other"), rendered),
            (reference, rendered.replace("task", "other")),
            (reference.replace('disabled=""', 'disabled="yes"'), rendered),
            (reference, rendered.replace('type="checkbox"', 'type="radio"'))]:
        assert run([case], [changed_reference], [changed_rendered])[0] == 1

print("PASS differential checker: mismatches, result counts, exact exceptions, and checkbox normalization")
