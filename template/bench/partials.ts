import Mustache from "mustache";

const escapes: Record<string, string> = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
Mustache.escape = (s: string) => s.replace(/[&<>"']/g, c => escapes[c]);
const src = "{{#items}}\n  {{>p}}\n{{/items}}";
const encoder = new TextEncoder();
for (const [name, n, p] of [
  ["large", 16, "猫😀 {{v}}\n\n{{{v}}}\n".repeat(128)],
  ["nested", 200, "猫\n{{v}}\n\n  {{>q}}\n"],
] as const) {
  const ctx = { v: "é猫😀 & <", items: Array.from({ length: n }, () => ({ x: true })) };
  const ps = { p, q: "😀\n\n{{{v}}}\n" };
  Mustache.parse(src);
  Mustache.parse(ps.p);
  Mustache.parse(ps.q);
  let hash = 2166136261;
  for (const b of encoder.encode(Mustache.render(src, ctx, ps))) hash = Math.imul(hash ^ b, 16777619) >>> 0;
  const start = performance.now();
  let total = 0;
  for (let i = 0; i < 100; i++) total += encoder.encode(Mustache.render(src, ctx, ps)).length;
  console.log(`chk\t${name}\t${hash}\nlen\t${name}\t${total}\nms\t${name}\t${performance.now() - start}`);
}
