// Mustache render benchmark: mustache.js (see README.md).
import Mustache from "mustache";

const N = 200, R = 100;
const SRC = '<ul>\n{{#items}}\n  <li><a href="{{url}}">{{name}}</a>{{#tags}} [{{.}}]{{/tags}}</li>\n{{/items}}\n</ul>\n';
const ESC: Record<string, string> = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
// mustache.js also escapes / ` and =; the other programs escape only these five.
Mustache.escape = (s: string) => s.replace(/[&<>"']/g, (c) => ESC[c]);

function fnv(s: string): number {
  let h = 2166136261;
  for (const b of new TextEncoder().encode(s)) h = Math.imul(h ^ b, 16777619) >>> 0;
  return h;
}

const items = Array.from({ length: N }, (_, i) => ({
  name: `Item ${i} & co`,
  url: `/items/${i}?a=1&b="2"`,
  tags: i % 2 === 0 ? ["new", "<hot>"] : [],
}));
const ctx = { items };
Mustache.parse(SRC);
const chk = fnv(Mustache.render(SRC, ctx));
const t0 = performance.now();
let total = 0;
for (let r = 0; r < R; r++) total += Mustache.render(SRC, ctx).length;
const ms = performance.now() - t0;
console.log(`render\t${ms.toFixed(3)}\t${chk}`);
console.log(`len\trender\t${total}`);
