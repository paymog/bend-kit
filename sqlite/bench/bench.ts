// SQLite benchmark in Bun: N prepared inserts in one transaction, then N primary-key reads, through bun:sqlite.
import { Database } from "bun:sqlite";

const n = Number(process.argv[2] ?? 100000);
const db = new Database(":memory:");
console.log(`sqlite\t${db.query<{ v: string }, []>("SELECT sqlite_version() AS v").get()!.v}`);
db.run("CREATE TABLE t(k INTEGER PRIMARY KEY, v INTEGER NOT NULL)");

const ins = db.prepare<unknown, [number, number]>("INSERT INTO t VALUES (?1, ?2)");
let x = 1;
let t0 = performance.now();
db.run("BEGIN");
for (let i = 0; i < n; i += 1) {
  ins.run(i, x >>> 1);
  x = (Math.imul(x, 1664525) + 1013904223) >>> 0;
}
db.run("COMMIT");
let t1 = performance.now();
ins.finalize();
const count = db.query<{ c: number }, []>("SELECT count(*) AS c FROM t").get()!.c;
console.log(`insert\t${(t1 - t0).toFixed(3)}\t${count}`);

const sel = db.prepare<{ v: number }, [number]>("SELECT v FROM t WHERE k = ?1");
let h = 0;
t0 = performance.now();
for (let j = 0, k = 0; j < n; j += 1, k += 7919) {
  h = (Math.imul(h, 31) + sel.get(k % n)!.v) >>> 0;
}
t1 = performance.now();
console.log(`select\t${(t1 - t0).toFixed(3)}\t${h}`);
sel.finalize();
db.close();
