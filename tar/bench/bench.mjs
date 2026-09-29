// Tar benchmark in JavaScript with tar-stream (see README.md). run.py copies this next to out/js/node_modules.
import { readFileSync } from "node:fs";
import tar from "tar-stream";

const data = readFileSync("out/input.tar");

async function decode(buf) {
  const ex = tar.extract();
  const ents = [];
  const done = (async () => {
    for await (const e of ex) {
      const { type, name } = e.header;
      if (type !== "file" && type !== "directory") throw new Error(`unexpected entry type ${type}`);
      const chunks = [];
      for await (const c of e) chunks.push(c);
      ents.push({ dir: type === "directory", name, data: Buffer.concat(chunks) });
    }
  })();
  ex.end(buf);
  await done;
  return ents;
}

// tar-stream writes a PAX header for a name that does not fit ustar.
async function encode(ents) {
  const p = tar.pack();
  const chunks = [];
  const done = (async () => {
    for await (const c of p) chunks.push(c);
  })();
  const mtime = new Date(0);
  for (const e of ents) {
    if (e.dir) p.entry({ name: e.name, type: "directory", mode: 0o755, mtime });
    else p.entry({ name: e.name, size: e.data.length, mode: 0o644, mtime }, e.data);
  }
  p.finalize();
  await done;
  return Buffer.concat(chunks);
}

// Checksum (see run.py): per entry fold kind, name bytes + length, file data bytes + length; add the count.
function fold(bs, h) {
  for (const b of bs) h = (Math.imul(h, 31) + b) >>> 0;
  return (Math.imul(h, 31) + bs.length) >>> 0;
}

function checksum(ents) {
  let h = 0;
  for (const e of ents) {
    let name = Buffer.from(e.name, "utf8");
    if (e.dir) {
      if (name.length && name[name.length - 1] === 0x2f) name = name.subarray(0, -1);
      h = fold(name, (Math.imul(h, 31) + 2) >>> 0);
    } else {
      h = fold(e.data, fold(name, (Math.imul(h, 31) + 1) >>> 0));
    }
  }
  return (h + ents.length) >>> 0;
}

const t0 = performance.now();
const ents = await decode(data);
const t1 = performance.now();
const out = await encode(ents);
const t2 = performance.now();

console.log(`decode\t${(t1 - t0).toFixed(3)}\t${checksum(ents)}`);
console.log(`encode\t${(t2 - t1).toFixed(3)}\t${checksum(await decode(out))}`);
