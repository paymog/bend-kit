"""Parser combinator benchmark in Python: a JSON grammar on pyparsing (see README.md)."""
import json
import time

import pyparsing as pp

LBRACK, RBRACK, LBRACE, RBRACE, COLON, COMMA = map(pp.Suppress, "[]{}:,")
NUMBER = pp.Regex(r"-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?").set_parse_action(
    lambda t: float(t[0]) if any(c in t[0] for c in ".eE") else int(t[0])
)
STRING = pp.QuotedString('"', esc_char="\\", convert_whitespace_escapes=True)
value = pp.Forward()
array = pp.Group(LBRACK + pp.Optional(pp.DelimitedList(value)) + RBRACK).set_parse_action(lambda t: [t[0].as_list()])
member = pp.Group(STRING + COLON + value)
obj = pp.Group(LBRACE + pp.Optional(pp.DelimitedList(member)) + RBRACE).set_parse_action(
    lambda t: [{k: v for k, v in t[0]}]
)
value <<= (
    pp.Keyword("null").set_parse_action(pp.replace_with(None))
    | pp.Keyword("true").set_parse_action(pp.replace_with(True))
    | pp.Keyword("false").set_parse_action(pp.replace_with(False))
    | NUMBER
    | STRING
    | array
    | obj
)


def checksum(s):
    h = 0
    for c in s:
        h = (h * 31 + ord(c)) & 0xFFFFFFFF
    return (h + len(s)) & 0xFFFFFFFF


doc = open("out/doc.json").read()
t0 = time.perf_counter()
v = value.parse_string(doc, parse_all=True)[0]
ms = (time.perf_counter() - t0) * 1e3
out = json.dumps(v, separators=(",", ":"), ensure_ascii=False, sort_keys=True)
print(f"parse\t{ms:.3f}\t{checksum(out)}")
