// Parser combinator benchmark in JavaScript: a JSON grammar on Parsimmon (see README.md).
import P from "parsimmon";

const ws = P.regexp(/[ \t\n\r]*/);
const tok = <T>(p: P.Parser<T>) => p.skip(ws);
const esc: Record<string, string> = { '"': '"', "\\": "\\", "/": "/", b: "\b", f: "\f", n: "\n", r: "\r", t: "\t" };
const str = P.regexp(/"((?:\\.|[^"\\\u0000-\u001f])*)"/, 1).map((s) =>
  s.replace(/\\(u[0-9a-fA-F]{4}|.)/g, (_, e) => (e.length === 5 ? String.fromCharCode(parseInt(e.slice(1), 16)) : esc[e])),
);

const J: P.Language = P.createLanguage({
  value: (r) => P.alt(r.object, r.array, r.string, r.number, r.null, r.true, r.false),
  lbrace: () => tok(P.string("{")),
  rbrace: () => tok(P.string("}")),
  lbracket: () => tok(P.string("[")),
  rbracket: () => tok(P.string("]")),
  comma: () => tok(P.string(",")),
  colon: () => tok(P.string(":")),
  null: () => tok(P.string("null")).result(null),
  true: () => tok(P.string("true")).result(true),
  false: () => tok(P.string("false")).result(false),
  string: () => tok(str),
  number: () => tok(P.regexp(/-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?/)).map(Number),
  array: (r) => r.lbracket.then(r.value.sepBy(r.comma)).skip(r.rbracket),
  pair: (r) => P.seq(r.string.skip(r.colon), r.value),
  object: (r) =>
    r.lbrace
      .then(r.pair.sepBy(r.comma))
      .skip(r.rbrace)
      .map((kv: [string, unknown][]) => Object.fromEntries(kv)),
});

function checksum(s: string): number {
  let h = 0;
  let n = 0;
  for (const c of s) {
    h = (Math.imul(h, 31) + c.codePointAt(0)!) >>> 0;
    n++;
  }
  return (h + n) >>> 0;
}

const doc = await Bun.file("out/doc.json").text();
const t0 = performance.now();
const v = ws.then(J.value).tryParse(doc);
const ms = performance.now() - t0;
// The document's keys are already sorted, and objects keep insertion order.
console.log(`parse\t${ms.toFixed(3)}\t${checksum(JSON.stringify(v))}`);
