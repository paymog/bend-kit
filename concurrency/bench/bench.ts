// Concurrency benchmark: one CPU-bound job over 64 inputs, on 1 and 8 worker_threads (see README.md).
// Runs in Bun and Node. The file is both the main thread and each worker.
import { Worker, isMainThread, parentPort, workerData } from "node:worker_threads";

const N = 64;
const ROUNDS = 1 << 20;

function job(x: number): number {
  for (let i = 0; i < ROUNDS; i++) x = (Math.imul(x ^ (x >>> 13), 1664525) + 1013904223) >>> 0;
  return x;
}

function part(lo: number, hi: number): Promise<number[]> {
  const { promise, resolve, reject } = Promise.withResolvers<number[]>();
  const w = new Worker(new URL(import.meta.url), { workerData: { lo, hi } });
  w.once("message", resolve);
  w.once("error", reject);
  return promise;
}

async function op(name: string, workers: number): Promise<void> {
  const t0 = performance.now();
  const parts: Promise<number[]>[] = [];
  for (let w = 0; w < workers; w++) parts.push(part((N * w) / workers, (N * (w + 1)) / workers));
  const out = (await Promise.all(parts)).flat();
  const ms = performance.now() - t0;
  let h = 0;
  for (const x of out) h = (Math.imul(h, 31) + x) >>> 0;
  console.log(`${name}\t${ms.toFixed(1)}\t${h}`);
}

if (isMainThread) {
  await op("map_1", 1);
  await op("map_8", 8);
} else {
  const { lo, hi } = workerData as { lo: number; hi: number };
  const out: number[] = [];
  for (let i = lo; i < hi; i++) out.push(job(i));
  parentPort!.postMessage(out);
}
