// CommonMark render benchmark: markdown-it (see README.md).
import MarkdownIt from "markdown-it";

const N = 100, R = 10;

function section(i: number): string {
  return `## Section ${i}\n\nSome *emphasis*, **strong**, \`code <tag>\`, and a [link](https://example.com/${i}?a=1&b=2 "title ${i}").\n` +
    `Text with &amp; entities &lt; and <span class="x">inline html</span>.\n\n` +
    `- item one\n- item two with \`code\`\n  - nested *item* ${i}\n\n1. first\n2. second\n\n` +
    `> A quote with **bold** text\n> across lines.\n\n\`\`\`python\ndef f(x):\n    return x < ${i}\n\`\`\`\n\n---\n\n`;
}

function fnv(s: string): number {
  let h = 2166136261;
  for (const b of new TextEncoder().encode(s)) h = Math.imul(h ^ b, 16777619) >>> 0;
  return h;
}

const doc = Array.from({ length: N }, (_, i) => section(i)).join("");
const md = new MarkdownIt("commonmark");
const chk = fnv(md.render(doc));
const t0 = performance.now();
let total = 0;
for (let r = 0; r < R; r++) total += md.render(doc).length;
const ms = performance.now() - t0;
console.log(`render\t${ms.toFixed(3)}\t${chk}`);
console.log(`len\trender\t${total}`);
