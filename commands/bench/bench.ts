// commands benchmark in Bun: N new commands, then the same N as duplicates, each in one BEGIN IMMEDIATE transaction, through bun:sqlite.
import { Database } from "bun:sqlite";

const path = process.argv[2] ?? "out/bun.db";
const n = Number(process.argv[3] ?? 10000);
const db = new Database(path);
console.log(`sqlite\t${db.query<{ v: string }, []>("SELECT sqlite_version() AS v").get()!.v}`);
db.run("PRAGMA busy_timeout = 10000");
db.run("CREATE TABLE IF NOT EXISTS commands_rows (k BLOB PRIMARY KEY, v BLOB NOT NULL) WITHOUT ROWID");
db.run("CREATE TABLE IF NOT EXISTS commands_seen (id TEXT PRIMARY KEY, payload BLOB NOT NULL, kind INTEGER NOT NULL, result BLOB NOT NULL, at INTEGER NOT NULL)");
db.run("CREATE INDEX IF NOT EXISTS commands_seen_at ON commands_seen (at)");
db.run("CREATE TABLE IF NOT EXISTS commands_outbox (seq INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL, effect BLOB NOT NULL)");

const begin = db.prepare("BEGIN IMMEDIATE");
const commit = db.prepare("COMMIT");
const find = db.prepare<{ payload: Uint8Array; result: Uint8Array }, [string]>("SELECT payload, kind, result, at FROM commands_seen WHERE id = ?");
const read = db.prepare<{ v: Uint8Array }, [Buffer]>("SELECT v FROM commands_rows WHERE k = ?");
const save = db.prepare<unknown, [Buffer, Buffer]>("INSERT OR REPLACE INTO commands_rows (k, v) VALUES (?, ?)");
const keep = db.prepare<unknown, [string, Buffer, number, Buffer, number]>("INSERT INTO commands_seen (id, payload, kind, result, at) VALUES (?, ?, ?, ?, ?)");
const emit = db.prepare<unknown, [string, Buffer]>("INSERT INTO commands_outbox (id, effect) VALUES (?, ?)");
const dec = new TextDecoder();
const num = (b: Uint8Array) => Number(dec.decode(b));
const key = Buffer.from("total");

// 1 for a new command, 2 for a duplicate, 0 for a conflict, with the recorded or new total.
function handle(id: string, payload: Buffer): [number, number] {
  begin.run();
  const row = find.get(id);
  if (row) {
    commit.run();
    return [payload.equals(row.payload) ? 2 : 0, num(row.result)];
  }
  const prev = read.get(key);
  const total = ((prev ? num(prev.v) : 0) + num(payload)) >>> 0;
  const t = Buffer.from(String(total));
  save.run(key, t);
  keep.run(id, payload, 1, t, 200);
  emit.run(id, Buffer.from(`total=${total}`));
  commit.run();
  return [1, total];
}

// Command i has id cmd_i and amount (x_i >> 1) % 1000. h = h*31 + result.
function pass(want: number): number {
  let x = 1;
  let h = 0;
  for (let i = 0; i < n; i += 1) {
    const [kind, r] = handle(`cmd_${i}`, Buffer.from(String((x >>> 1) % 1000)));
    if (kind !== want) throw new Error("unexpected reply");
    h = (Math.imul(h, 31) + r) >>> 0;
    x = (Math.imul(x, 1664525) + 1013904223) >>> 0;
  }
  return h;
}

let t0 = performance.now();
pass(1);
let t1 = performance.now();
console.log(`fresh\t${(t1 - t0).toFixed(3)}\t${num(read.get(key)!.v)}`);
t0 = performance.now();
const h = pass(2);
t1 = performance.now();
console.log(`replay\t${(t1 - t0).toFixed(3)}\t${h}`);
db.close();
