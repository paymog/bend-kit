import assert from 'node:assert/strict';
import {readFileSync, unlinkSync} from 'node:fs';
import {writeHeapSnapshot} from 'node:v8';
import Z from './out/memory/zlib.mjs';

const [manifest, countText] = process.argv.slice(2);
const fixture = JSON.parse(readFileSync(manifest));
const count = Number(countText);
const call = (name, ...args) => Z[name](...args);
const checksum = bytes => bytes.reduce((n, c) => (Math.imul(n, 31) + c) >>> 0, 0);
const packed = bytes => {
  const buf = Array(2 ** Math.ceil(Math.log2(Math.max(1, Math.ceil(bytes.length / 4))))).fill(0);
  bytes.forEach((c, i) => { buf[i >>> 2] = (buf[i >>> 2] | c << (8 * (i % 4))) >>> 0; });
  return buf;
};
const unpack = (buf, n) => Array.from({length: n}, (_, i) => buf[i >>> 2] >>> (8 * (i % 4)) & 255);
const tables = st => st.mode.$ === 'MoCodes' ? [st.mode.lit, st.mode.dist] : [];
function tableCount(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return 0;
  return Number(value.$ === 'Huff') + Object.values(value).reduce((n, v) => n + tableCount(v), 0);
}

// Count only the measured objects and their element storage, not VM maps or prototypes.
function heapBytes(groups) {
  Object.assign(globalThis, groups);
  globalThis.gc();
  const path = writeHeapSnapshot(`${manifest}.${process.pid}.heapsnapshot`);
  const text = readFileSync(path, 'utf8');
  unlinkSync(path);
  const {snapshot, nodes, edges, strings} = JSON.parse(text);
  const nf = snapshot.meta.node_fields, ef = snapshot.meta.edge_fields;
  const nw = nf.length, ew = ef.length;
  const offsets = new Map();
  let at = 0;
  for (let n = 0; n < nodes.length; n += nw) {
    offsets.set(n, at);
    at += nodes[n + nf.indexOf('edge_count')] * ew;
  }
  function children(n) {
    const result = [];
    const end = offsets.get(n) + nodes[n + nf.indexOf('edge_count')] * ew;
    for (let e = offsets.get(n); e < end; e += ew) {
      const type = snapshot.meta.edge_types[0][edges[e]];
      const name = strings[edges[e + 1]];
      if (type === 'element' || type === 'property' && ['table', 'sub'].includes(name) ||
          type === 'internal' && name === 'elements') result.push(edges[e + 2]);
    }
    return result;
  }
  const result = {};
  for (const name of Object.keys(groups)) {
    const roots = [];
    for (let e = 0; e < edges.length; e += ew) {
      if (snapshot.meta.edge_types[0][edges[e]] === 'property' && strings[edges[e + 1]] === name)
        roots.push(edges[e + 2]);
    }
    assert.equal(new Set(roots).size, 1, name);
    const pending = children(roots[0]), seen = new Set();
    let bytes = 0;
    while (pending.length) {
      const n = pending.pop();
      if (seen.has(n)) continue;
      seen.add(n);
      bytes += nodes[n + nf.indexOf('self_size')];
      pending.push(...children(n));
    }
    // The category list's own backing store is not part of the workload.
    const backing = children(roots[0]).filter(n =>
      snapshot.meta.node_types[0][nodes[n]] === 'array');
    for (const n of backing) bytes -= nodes[n + nf.indexOf('self_size')];
    result[name] = bytes;
    delete globalThis[name];
  }
  return result;
}

let states = [];
const boundaries = [];
if (fixture.lens) {
  const key = Object.keys(Z).find(k => k.endsWith('bits:Huff.from_lens'));
  assert(key);
  for (let i = 0; i < count; i++) {
    const lens = fixture.lens.reduceRight((tail, head) => ({$: 'Con', head, tail}), {$: 'Nil'});
    const h = call(key, false, lens);
    assert.equal(h.$, 'Some');
    states.push({mode: {$: 'MoCodes', lit: h.value}});
  }
} else {
  const bytes = [...readFileSync(fixture.path)];
  for (let i = 0; i < count; i++) {
    let st = {$: 'Is', br: {$: 'Br', r: {$: 'Reader', buf: packed(bytes),
      total: bytes.length * 8, left: bytes.length * 8 - 80, last: {$: 'None'}}, bad: false},
      o: {$: 'Out', buf: [0], dep: 0, n: 0}, mode: {$: 'MoHead'}, last: false};
    st = call('inf.go', 1, st);
    while (st.o.n < 256 && st.mode.$ === 'MoCodes') st = call('inf.go', 1, st);
    assert.equal(st.mode.$, 'MoCodes');
    states.push(st);
  }
}
const hs = fixture.lens ? states.map(st => st.mode.lit) : states.flatMap(tables);
assert.equal(new Set(hs.flatMap(h => [h.table, h.sub])).size, hs.length * 2);
const groups = {retained_tables: hs,
  retained_inputs: fixture.lens ? [] : states.map(st => st.br.r.buf),
  retained_outputs: fixture.lens ? [] : states.map(st => st.o.buf)};
const heap = heapBytes(groups);
const entries = hs.reduce((n, h) => n + h.table.length + h.sub.length, 0);
if (!fixture.lens) {
  for (let i = 0; i < states.length; i++) {
    let st = states[i], block = 0;
    while (st.mode.$ !== 'MoDone') {
      st = call('inf.go', 1, st);
      assert.notEqual(st.mode.$, 'MoBad');
      if (st.mode.$ === 'MoHead' || st.mode.$ === 'MoDone') {
        assert.equal(tableCount(st), 0);
        boundaries.push({stream: i, block: block++, mode: st.mode.$, tables: tableCount(st)});
      }
    }
    assert.equal(checksum(unpack(st.o.buf, st.o.n)), fixture.checksum);
    states[i] = call('inf.result', st);
    assert.equal(states[i].$, 'Some');
  }
  // Exercise the real gzip member transition, including a following member.
  let gz = {$: 'GzMore', acc: {$: 'Bytes', len: 0, buf: [0]},
    src: {$: 'Bytes', len: fixture.members_bytes, buf: packed([...readFileSync(fixture.members_path)])}, at: 0};
  for (let member = 0; member < 2; member++) {
    gz = call('gz.step', call('gz.member', gz.src, gz.at), gz.acc);
    assert.equal(gz.$, member === 0 ? 'GzMore' : 'GzDone');
    assert.equal(tableCount(gz), 0);
    boundaries.push({member, mode: gz.$, tables: tableCount(gz)});
  }
  assert.equal(checksum(unpack(gz.out.buf, gz.out.len)), fixture.members_checksum);
}
console.log(JSON.stringify({streams: count, tables: hs.length, entries, heap_bytes: heap,
  checksum: fixture.checksum ?? null, boundaries, node: process.version, v8: process.versions.v8}));
