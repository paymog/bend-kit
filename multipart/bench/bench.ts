// Multipart benchmark: Response.formData() in Bun and Node (see README.md).
// new Response(FormData) picks its own boundary, so its bytes cannot match the others: encode is left out.
const B = "bend-kit-0123456789abcdef0123456789abcdef";
const enc = new TextEncoder();

function blob(): Uint8Array {
  const b = new Uint8Array(1 << 20);
  let x = 1;
  for (let i = 0; i < b.length; i++) {
    x = (Math.imul(x, 1103515245) + 12345) >>> 0;
    b[i] = x >>> 24;
  }
  return b;
}

function body(): Uint8Array {
  const d = `--${B}\r\nContent-Disposition: form-data; name="`;
  const pieces = [
    enc.encode(`${d}title"\r\n\r\nhello multipart\r\n${d}blob"; filename="blob.bin"\r\nContent-Type: application/octet-stream\r\n\r\n`),
    blob(),
    enc.encode(`\r\n${d}note"\r\n\r\nend\r\n--${B}--\r\n`),
  ];
  const out = new Uint8Array(pieces.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const p of pieces) {
    out.set(p, at);
    at += p.length;
  }
  return out;
}

function chk(h: number, b: Uint8Array): number {
  for (let i = 0; i < b.length; i++) h = (Math.imul(h, 31) + b[i]) >>> 0;
  return h;
}

const input = body();
const t0 = performance.now();
const form = await new Response(input, { headers: { "content-type": `multipart/form-data; boundary=${B}` } }).formData();
const parts: [Uint8Array, Uint8Array][] = [];
for (const [name, v] of form) {
  const b = typeof v === "string" ? enc.encode(v) : new Uint8Array(await v.arrayBuffer());
  parts.push([enc.encode(name), b]);
}
const ms = performance.now() - t0;
let h = 0, n = 0;
for (const [name, b] of parts) {
  h = chk(chk(h, name), b);
  n += name.length + b.length;
}
console.log(`decode\t${ms.toFixed(3)}\t${(h + n) >>> 0}`);
