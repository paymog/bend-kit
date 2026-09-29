// Collections benchmark: JavaScript (see README.md). Ordered map, deque, and heap use js-sdsl.
import { Deque, OrderedMap, PriorityQueue } from "js-sdsl";
const L = Number(process.argv[2] ?? 20);
const N = 1 << L;

const lcg = (x: number) => (Math.imul(x, 1664525) + 1013904223) >>> 0;

function lap(name: string, t0: number, chk: number) {
  console.log(`${name}\t${(performance.now() - t0).toFixed(3)}\t${chk >>> 0}`);
}

let t0 = performance.now();
let x = 1;
let acc = 0;
const m = new Map<number, number>();
for (let i = 0; i < N; i++) {
  x = lcg(x);
  m.set(x, i);
}
lap("hmap_put", t0, m.size);

t0 = performance.now();
x = 1;
acc = 0;
for (let i = 0; i < N; i++) {
  x = lcg(x);
  acc = (acc + (m.get(x) ?? 0)) >>> 0;
}
lap("hmap_get", t0, acc);

t0 = performance.now();
const v: number[] = [];
for (let i = 0; i < N; i++) v.push(i);
lap("vec_push", t0, v.length);

t0 = performance.now();
x = 1;
acc = 0;
for (let i = 0; i < N; i++) {
  x = lcg(x);
  acc = (acc + v[x >>> (32 - L)]) >>> 0;
}
lap("vec_get", t0, acc);

t0 = performance.now();
const deque = new Deque<number>();
for (let i = 0; i < N; i++) deque.pushBack(i);
lap("deque_push", t0, deque.size());

t0 = performance.now();
acc = 0;
for (let i = 0; i < N / 2; i++) acc = (Math.imul(acc, 31) + deque.popFront()!) >>> 0;
for (let i = 0; i < N / 2; i++) acc = (Math.imul(acc, 31) + deque.popBack()!) >>> 0;
lap("deque_pop", t0, acc);

t0 = performance.now();
const heap = new PriorityQueue<number>([], (a, b) => a - b);
x = 1;
for (let i = 0; i < N; i++) {
  x = lcg(x);
  heap.push(x);
}
lap("heap_push", t0, heap.size());

t0 = performance.now();
acc = 0;
for (let i = 0; i < N; i++) acc = (Math.imul(acc, 31) + heap.pop()!) >>> 0;
lap("heap_pop", t0, acc);

t0 = performance.now();
const ordered = new OrderedMap<number, number>();
x = 1;
for (let i = 0; i < N; i++) {
  x = lcg(x);
  ordered.setElement(x, i);
}
lap("omap_put", t0, ordered.size());

t0 = performance.now();
x = 1;
acc = 0;
for (let i = 0; i < N; i++) {
  x = lcg(x);
  acc = (acc + (ordered.getElementByKey(x) ?? 0)) >>> 0;
}
lap("omap_get", t0, acc);
