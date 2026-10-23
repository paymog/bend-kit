// Migration benchmark with JSON.parse and JSON.stringify. Run with node or bun, after run.py writes out/doc.json.
import { readFileSync } from "node:fs";

type Fields = Record<string, unknown>;

const KEYS: Record<number, Record<string, true>> = {
  1: { version: true, id: true, plan: true, monthly_cents: true, active: true },
  2: { version: true, id: true, plan: true, cents: true, period: true, status: true, note: true },
  3: { version: true, id: true, plan: true, cents: true, period: true, status: true },
};
const PERIODS: Record<string, true> = { monthly: true, yearly: true };
const STATUSES: Record<string, true> = { active: true, paused: true, cancelled: true };

function fail(k: string): never {
  throw new Error(k);
}

function u32(r: Fields, k: string): number {
  const v = r[k];
  return typeof v === "number" && Number.isInteger(v) && v >= 0 && v < 2 ** 32 ? v : fail(k);
}

function text(r: Fields, k: string, allowed?: Record<string, true>): string {
  const v = r[k];
  return typeof v === "string" && (!allowed || Object.hasOwn(allowed, v)) ? v : fail(k);
}

function up(r: Fields) {
  const v = r.version;
  const keys = (typeof v === "number" && KEYS[v]) || fail("version");
  for (const k in r) if (!Object.hasOwn(keys, k)) fail(k);
  const id = u32(r, "id");
  const plan = text(r, "plan");
  let cents: number, period: string, status: string;
  if (v === 1) {
    if (typeof r.active !== "boolean") fail("active");
    cents = u32(r, "monthly_cents");
    period = "monthly";
    status = r.active ? "active" : "cancelled";
  } else {
    cents = u32(r, "cents");
    status = text(r, "status", STATUSES);
    period = v === 3 || "period" in r ? text(r, "period", PERIODS) : "monthly";
    if (v === 2 && "note" in r) text(r, "note");
  }
  if (!plan || cents === 0) fail("invalid");
  return { version: 3, id, plan, cents, period, status };
}

function chk(b: Uint8Array): number {
  let h = 0;
  for (let i = 0; i < b.length; i++) h = (Math.imul(h, 31) + b[i]) >>> 0;
  return (h + b.length) >>> 0;
}

const RAW = readFileSync("out/doc.json");
const t0 = performance.now();
const records: Fields[] = JSON.parse(new TextDecoder().decode(RAW));
const out = new TextEncoder().encode(JSON.stringify(records.map(up)));
const ms = performance.now() - t0;
console.log(`migrate\t${ms.toFixed(3)}\t${chk(out)}`);
