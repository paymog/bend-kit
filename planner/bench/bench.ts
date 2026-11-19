// Planner benchmark: the toposort package (see README.md).
import toposort from "toposort";

const rounds = Number(process.argv[2] ?? 4);
const n = 1000;
const tasks: [string, string[]][] = [];
for (let i = 0; i < n; i++) {
  const deps: string[] = [];
  for (let j = i + 1; j < Math.min(i + 4, n); j++) deps.push(`n${j}`);
  tasks.push([`n${i}`, deps]);
}
let chk = 0;
const t0 = performance.now();
for (let r = 0; r < rounds; r++) {
  const edges: [string, string][] = [];
  for (const [node, deps] of tasks) for (const d of deps) edges.push([d, node]);
  for (const node of toposort(edges)) chk = (chk + 1 + Number(node.slice(1))) >>> 0;
}
const t1 = performance.now();
console.log(`plan\t${(t1 - t0).toFixed(3)}\t${chk}`);
