// Regex benchmark in JavaScript (RegExp). See README.md.
const SIZE = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : 1 << 20;
const ONLY = process.argv[3];
const REDOS_N = 100_000;

function text(size: number): string {
  const e = size - 50;
  const h = size - 20;
  return (
    "x".repeat(e) +
    "user@host.com" +
    "x".repeat(h - e - 13) +
    "helloworld12" +
    "x".repeat(size - h - 12)
  );
}

function groupSpan(m: RegExpExecArray, i: number): [number, number] {
  if (i === 0) return [m.index, m.index + m[0].length];
  const g = m[i];
  if (g === undefined) return [-1, -1];
  const off = m[0].indexOf(g);
  if (off < 0) return [-1, -1];
  const start = m.index + off;
  return [start, start + g.length];
}

function chkGroups(m: RegExpExecArray | null, n: number): number {
  if (m === null) return 0;
  let h = 0;
  for (let i = 0; i < n; i++) {
    const [start, end] = groupSpan(m, i);
    if (start < 0) h = Math.imul(h, 31) >>> 0;
    else {
      h = (Math.imul(h, 31) + start) >>> 0;
      h = (Math.imul(h, 31) + end) >>> 0;
    }
  }
  return h >>> 0;
}

function lap(name: string, t0: number, chk: number) {
  console.log(`${name}\t${(performance.now() - t0).toFixed(3)}\t${chk}`);
}

function want(name: string) {
  return ONLY === undefined || ONLY === name;
}

const s = text(SIZE);
const reHello = /hello\w+/;
const reEmail = /(\w+)@(\w+)\.com/;
const reRedos = /(a*)*b/;
const reX = /x/;
const reEarly = /(x)x/;
const reLive = /xy/;
if (want("is_match")) {
  let t0 = performance.now();
  let hit = reHello.test(s);
  lap("is_match", t0, hit ? 1 : 0);
}
if (want("is_match_early")) {
  let t0 = performance.now();
  let hit = reX.test(s);
  lap("is_match_early", t0, hit ? 1 : 0);
}
if (want("is_match_live")) {
  let t0 = performance.now();
  let hit = reLive.test(s);
  lap("is_match_live", t0, hit ? 1 : 0);
}
if (want("find_captures")) {
  let t0 = performance.now();
  let m = reEmail.exec(s);
  lap("find_captures", t0, chkGroups(m, 3));
}
if (want("find_early")) {
  let t0 = performance.now();
  let m = reEarly.exec(s);
  lap("find_early", t0, chkGroups(m, 2));
}
if (want("redos")) {
  let t0 = performance.now();
  let m = reRedos.exec("a".repeat(REDOS_N));
  lap("redos", t0, chkGroups(m, 1));
}
if (want("large")) {
  const sLarge = "x".repeat(1000) + "y";
  const reLarge = /(?:x?){1000}y/;
  let t0 = performance.now();
  let m = reLarge.exec(sLarge);
  lap("large", t0, chkGroups(m, 1));
}
