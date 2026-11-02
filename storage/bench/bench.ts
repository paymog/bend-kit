// Storage benchmark: node:crypto SHA-256 and a Map (see README.md).
import { createHash } from "node:crypto";

const K = Number(process.argv[2] ?? 16);
type Obj = { kind: "file"; data: Buffer } | { kind: "end" } | { kind: "item"; child: string; rest: string };

function content(d: number, f: number): Buffer {
  const seed = d * 31 + f * 7;
  const b = Buffer.alloc(4096);
  for (let j = 0; j < 4096; j++) b[j] = (seed + j) & 255;
  return b;
}

function put(store: Map<string, Obj>, raw: Buffer, obj: Obj): string {
  const d = createHash("sha256").update(raw).digest("hex");
  if (!store.has(d)) store.set(d, obj);
  return d;
}

function listing(store: Map<string, Obj>, entries: [string, string][]): string {
  let rest = put(store, Buffer.from("end\n"), { kind: "end" });
  for (let i = entries.length - 1; i >= 0; i--) {
    const [name, child] = entries[i];
    rest = put(store, Buffer.from(`item ${child} ${rest} ${name}\n`), { kind: "item", child, rest });
  }
  return rest;
}

function load(store: Map<string, Obj>, d: string): number {
  const o = store.get(d)!;
  if (o.kind === "file") return o.data.length;
  if (o.kind === "end") return 0;
  return load(store, o.child) + load(store, o.rest);
}

const pad = (k: number) => String(k).padStart(2, "0");
const tree: [string, [string, Buffer][]][] = [];
for (let d = 0; d < K; d++) {
  const fs: [string, Buffer][] = [];
  for (let f = 0; f < K; f++) fs.push([`f${pad(f)}`, content(d, f)]);
  tree.push([`d${pad(d)}`, fs]);
}
const t0 = performance.now();
const store = new Map<string, Obj>();
const top: [string, string][] = [];
for (const [dname, fs] of tree) {
  const files: [string, string][] = fs.map(([fname, data]) => [
    fname,
    put(store, Buffer.concat([Buffer.from(`file ${data.length}\n`), data]), { kind: "file", data }),
  ]);
  top.push([dname, listing(store, files)]);
}
const root = listing(store, top);
const n = load(store, root);
const ms = performance.now() - t0;
console.log(`commit\t${ms.toFixed(3)}\t${root}\t${n}`);
