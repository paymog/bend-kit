// SQLite
// ======
// JS twin of sqlite.c, through bun:ffi on the same libsqlite3.

// Copies of wire_words and wire_words_octets in wire/effs/wire.js; keep them in step.
function sqlite_words(b, n) {
  const w = Math.ceil(n / 4);
  let size = 1;
  while (size < w) {
    size *= 2;
  }
  const a = Array(size).fill(0);
  for (let i = 0; i < n; i += 1) {
    a[i >> 2] = (a[i >> 2] | (b[i] << (8 * (i & 3)))) >>> 0;
  }
  return { $: CID(Tuple), fst: n, snd: a };
}

function sqlite_words_octets(n, a) {
  n = Number(n);
  if (n > 4 * a.length) {
    return null;
  }
  const b = new Uint8Array(n);
  for (let i = 0; i < n; i += 1) {
    b[i] = (a[i >> 2] >>> (8 * (i & 3))) & 255;
  }
  return b;
}

// SQLite result codes.
const SQLITE_OK = 0;
const SQLITE_BUSY = 5;
const SQLITE_NOMEM = 7;
const SQLITE_CANTOPEN = 14;
const SQLITE_MISMATCH = 20;
const SQLITE_MISUSE = 21;
const SQLITE_RANGE = 25;
const SQLITE_ROW = 100;
const SQLITE_DONE = 101;

function sqlite_fail(code, why) {
  return { $: CID(Fail), error: io_tup(code, why) };
}

function sqlite_ok() {
  return io_done({ $: CID(Unit) });
}

// The library named by BEND_LIBSQLITE, else the first system path that loads; null if none does.
function sqlite_lib() {
  const st = sqlite_state();
  if (st.lib !== undefined) {
    return st.lib;
  }
  st.lib = null;
  const ffi = require("bun:ffi");
  const syms = {
    sqlite3_open_v2: { args: ["ptr", "ptr", "i32", "ptr"], returns: "i32" },
    sqlite3_close_v2: { args: ["ptr"], returns: "i32" },
    sqlite3_errmsg: { args: ["ptr"], returns: "cstring" },
    sqlite3_errstr: { args: ["i32"], returns: "cstring" },
    sqlite3_prepare_v2: { args: ["ptr", "ptr", "i32", "ptr", "ptr"], returns: "i32" },
    sqlite3_finalize: { args: ["ptr"], returns: "i32" },
    sqlite3_reset: { args: ["ptr"], returns: "i32" },
    sqlite3_step: { args: ["ptr"], returns: "i32" },
    sqlite3_bind_parameter_count: { args: ["ptr"], returns: "i32" },
    sqlite3_bind_int64: { args: ["ptr", "i32", "i64"], returns: "i32" },
    sqlite3_bind_null: { args: ["ptr", "i32"], returns: "i32" },
    sqlite3_bind_text: { args: ["ptr", "i32", "ptr", "i32", "i64"], returns: "i32" },
    sqlite3_bind_blob: { args: ["ptr", "i32", "ptr", "i32", "i64"], returns: "i32" },
    sqlite3_column_count: { args: ["ptr"], returns: "i32" },
    sqlite3_column_type: { args: ["ptr", "i32"], returns: "i32" },
    sqlite3_column_int64: { args: ["ptr", "i32"], returns: "i64" },
    sqlite3_column_text: { args: ["ptr", "i32"], returns: "ptr" },
    sqlite3_column_blob: { args: ["ptr", "i32"], returns: "ptr" },
    sqlite3_column_bytes: { args: ["ptr", "i32"], returns: "i32" },
  };
  const paths = [process.env.BEND_LIBSQLITE, "/usr/lib/libsqlite3.dylib",
    "/opt/homebrew/opt/sqlite/lib/libsqlite3.dylib", "libsqlite3.dylib", "libsqlite3.so.0"];
  for (const p of paths) {
    if (!p) {
      continue;
    }
    try {
      st.lib = { s: ffi.dlopen(p, syms).symbols, ffi };
      return st.lib;
    } catch {
      continue;
    }
  }
  return null;
}

const SQLITE_NUL = "string contains NUL";
const SQLITE_MISSING = "sqlite needs libsqlite3; set BEND_LIBSQLITE to its path";

// Open databases and statements by id; ids start at 1 and are never reused, so a stale id finds nothing.
function sqlite_state() {
  return (globalThis.BEND_SQLITE ??= { lib: undefined, next_db: 1, next_stmt: 1, dbs: new Map(), stmts: new Map() });
}

// Databases and statements count separately; 0 when a count runs out.
function sqlite_id(st, key) {
  if (st[key] > 0xffffffff) {
    return 0;
  }
  const id = st[key];
  st[key] += 1;
  return id;
}

// UTF-8 octets, or null for a NUL.
function sqlite_utf8(s) {
  if (s.includes("\0")) {
    return null;
  }
  return new TextEncoder().encode(s);
}

// A NUL-terminated copy; ffi.ptr refuses an empty array, so this is never empty.
function sqlite_cstr(b) {
  const c = new Uint8Array(b.length + 1);
  c.set(b);
  return c;
}

// A pointer to b; ffi.ptr refuses an empty array.
function sqlite_in(ffi, b) {
  return ffi.ptr(b.length ? b : new Uint8Array(1));
}

function sqlite_err(l, db, rc) {
  return sqlite_fail(rc, String(l.s.sqlite3_errmsg(db)));
}

function sqlite_bad() {
  return sqlite_fail(SQLITE_MISUSE, "bad handle");
}

// The library and the statement, or a failure.
function sqlite_stmt(id) {
  const l = sqlite_lib();
  if (l === null) {
    return { fail: sqlite_fail(SQLITE_CANTOPEN, SQLITE_MISSING) };
  }
  const s = sqlite_state().stmts.get(id);
  return s === undefined ? { fail: sqlite_bad() } : { l, s };
}

function sqlite_open(path) {
  const l = sqlite_lib();
  if (l === null) {
    return sqlite_fail(SQLITE_CANTOPEN, SQLITE_MISSING);
  }
  const b = sqlite_utf8(path);
  if (b === null) {
    return sqlite_fail(SQLITE_MISUSE, SQLITE_NUL);
  }
  const st = sqlite_state();
  const id = sqlite_id(st, "next_db");
  if (id === 0) {
    return sqlite_fail(SQLITE_NOMEM, "out of handles");
  }
  const out = new BigUint64Array(1);
  const c = sqlite_cstr(b);
  // SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
  const rc = l.s.sqlite3_open_v2(l.ffi.ptr(c), l.ffi.ptr(out), 0x6, null);
  const db = Number(out[0]);
  if (rc !== SQLITE_OK) {
    const why = db ? String(l.s.sqlite3_errmsg(db)) : String(l.s.sqlite3_errstr(rc));
    if (db) {
      l.s.sqlite3_close_v2(db);
    }
    return sqlite_fail(rc, why);
  }
  st.dbs.set(id, { db, stmts: 0 });
  return io_done(id);
}

function sqlite_close(id) {
  const l = sqlite_lib();
  if (l === null) {
    return sqlite_fail(SQLITE_CANTOPEN, SQLITE_MISSING);
  }
  const st = sqlite_state();
  const d = st.dbs.get(id);
  if (d === undefined) {
    return sqlite_bad();
  }
  if (d.stmts > 0) {
    return sqlite_fail(SQLITE_BUSY, "database has open statements");
  }
  const rc = l.s.sqlite3_close_v2(d.db);
  if (rc !== SQLITE_OK) {
    return sqlite_err(l, d.db, rc);
  }
  st.dbs.delete(id);
  return sqlite_ok();
}

// ASCII whitespace, as SQLite's tokenizer skips it.
function sqlite_blank(b, from) {
  for (let i = from; i < b.length; i += 1) {
    const c = b[i];
    if (c !== 0x20 && c !== 0x09 && c !== 0x0a && c !== 0x0c && c !== 0x0d) {
      return false;
    }
  }
  return true;
}

function sqlite_prepare(dbid, sql) {
  const l = sqlite_lib();
  if (l === null) {
    return sqlite_fail(SQLITE_CANTOPEN, SQLITE_MISSING);
  }
  const st = sqlite_state();
  const d = st.dbs.get(dbid);
  if (d === undefined) {
    return sqlite_bad();
  }
  const b = sqlite_utf8(sql);
  if (b === null) {
    return sqlite_fail(SQLITE_MISUSE, SQLITE_NUL);
  }
  const c = sqlite_cstr(b);
  const base = l.ffi.ptr(c);
  const out = new BigUint64Array(2);
  const at = l.ffi.ptr(out);
  const rc = l.s.sqlite3_prepare_v2(d.db, base, b.length, at, at + 8);
  const stmt = Number(out[0]);
  if (rc !== SQLITE_OK) {
    return sqlite_err(l, d.db, rc);
  }
  if (!stmt) {
    return sqlite_fail(SQLITE_MISUSE, "SQL has no statement");
  }
  if (!sqlite_blank(b, Number(out[1]) - base)) {
    l.s.sqlite3_finalize(stmt);
    return sqlite_fail(SQLITE_MISUSE, "SQL has more than one statement");
  }
  const id = sqlite_id(st, "next_stmt");
  if (id === 0) {
    l.s.sqlite3_finalize(stmt);
    return sqlite_fail(SQLITE_NOMEM, "out of handles");
  }
  d.stmts += 1;
  st.stmts.set(id, { stmt, d, row: false });
  return io_done(id);
}

// The last step's error is already reported by step, so finalize and reset ignore it.
function sqlite_finalize(id) {
  const { l, s, fail } = sqlite_stmt(id);
  if (fail) {
    return fail;
  }
  l.s.sqlite3_finalize(s.stmt);
  sqlite_state().stmts.delete(id);
  s.d.stmts -= 1;
  return sqlite_ok();
}

function sqlite_reset(id) {
  const { l, s, fail } = sqlite_stmt(id);
  if (fail) {
    return fail;
  }
  l.s.sqlite3_reset(s.stmt);
  s.row = false;
  return sqlite_ok();
}

function sqlite_step(id) {
  const { l, s, fail } = sqlite_stmt(id);
  if (fail) {
    return fail;
  }
  const rc = l.s.sqlite3_step(s.stmt);
  s.row = rc === SQLITE_ROW;
  if (rc === SQLITE_ROW || rc === SQLITE_DONE) {
    return io_done(s.row);
  }
  return sqlite_err(l, s.d.db, rc);
}

// Checks the handle, the 1-based index, then octets(): a Uint8Array, or a failure. bind(l, stmt, b) gives the SQLite rc.
function sqlite_bind(id, index, octets, bind) {
  const { l, s, fail } = sqlite_stmt(id);
  if (fail) {
    return fail;
  }
  if (index < 1 || index > l.s.sqlite3_bind_parameter_count(s.stmt)) {
    return sqlite_fail(SQLITE_RANGE, "index out of range");
  }
  s.row = false;
  const b = octets();
  if (!(b instanceof Uint8Array)) {
    return b;
  }
  const rc = bind(l, s.stmt, b);
  return rc === SQLITE_OK ? sqlite_ok() : sqlite_err(l, s.d.db, rc);
}

const SQLITE_NO_OCTETS = new Uint8Array(0);
const sqlite_none = () => SQLITE_NO_OCTETS;

function sqlite_bind_int(id, index, value) {
  return sqlite_bind(id, index, sqlite_none, (l, stmt) => l.s.sqlite3_bind_int64(stmt, index, BigInt(value)));
}

function sqlite_bind_null(id, index) {
  return sqlite_bind(id, index, sqlite_none, (l, stmt) => l.s.sqlite3_bind_null(stmt, index));
}

// SQLITE_TRANSIENT (-1): SQLite copies the octets before the call returns.
function sqlite_bind_text(id, index, text) {
  const octets = () => sqlite_utf8(text) ?? sqlite_fail(SQLITE_MISUSE, SQLITE_NUL);
  return sqlite_bind(id, index, octets,
    (l, stmt, b) => l.s.sqlite3_bind_text(stmt, index, sqlite_in(l.ffi, b), b.length, -1));
}

function sqlite_bind_blob(id, index, len, words) {
  const octets = () => (Array.isArray(words) && len <= 0x7fffffff && sqlite_words_octets(len, words))
    || sqlite_fail(SQLITE_MISUSE, "blob length exceeds words");
  return sqlite_bind(id, index, octets,
    (l, stmt, b) => l.s.sqlite3_bind_blob(stmt, index, sqlite_in(l.ffi, b), b.length, -1));
}

// The library, statement, and column kind for a 0-based column of the current row, or a failure.
function sqlite_col(id, index) {
  const r = sqlite_stmt(id);
  if (r.fail) {
    return r;
  }
  if (!r.s.row) {
    return { fail: sqlite_fail(SQLITE_MISUSE, "no current row") };
  }
  if (index >= r.l.s.sqlite3_column_count(r.s.stmt)) {
    return { fail: sqlite_fail(SQLITE_RANGE, "index out of range") };
  }
  r.kind = r.l.s.sqlite3_column_type(r.s.stmt, index);
  return r;
}

// Octets of a text or blob column; SQLite gives NULL for an empty value.
function sqlite_col_octets(l, p, n) {
  return p && n > 0 ? new Uint8Array(l.ffi.toArrayBuffer(p, 0, n)).slice() : new Uint8Array(0);
}

function sqlite_column_kind(id, index) {
  const { kind, fail } = sqlite_col(id, index);
  return fail ?? io_done(kind);
}

function sqlite_column_int(id, index) {
  const { l, s, kind, fail } = sqlite_col(id, index);
  if (fail) {
    return fail;
  }
  if (kind !== 1) {
    return sqlite_fail(SQLITE_MISMATCH, "column kind mismatch");
  }
  const v = BigInt(l.s.sqlite3_column_int64(s.stmt, index));
  if (v < 0n || v > 0xffffffffn) {
    return sqlite_fail(SQLITE_MISMATCH, "integer outside U32");
  }
  return io_done(Number(v));
}

function sqlite_column_text(id, index) {
  const { l, s, kind, fail } = sqlite_col(id, index);
  if (fail) {
    return fail;
  }
  if (kind !== 3) {
    return sqlite_fail(SQLITE_MISMATCH, "column kind mismatch");
  }
  const p = l.s.sqlite3_column_text(s.stmt, index);
  const n = l.s.sqlite3_column_bytes(s.stmt, index);
  if (!p) {
    return sqlite_err(l, s.d.db, SQLITE_NOMEM);
  }
  return io_done(new TextDecoder().decode(sqlite_col_octets(l, p, n)));
}

function sqlite_column_blob(id, index) {
  const { l, s, kind, fail } = sqlite_col(id, index);
  if (fail) {
    return fail;
  }
  if (kind !== 4) {
    return sqlite_fail(SQLITE_MISMATCH, "column kind mismatch");
  }
  const p = l.s.sqlite3_column_blob(s.stmt, index);
  const n = l.s.sqlite3_column_bytes(s.stmt, index);
  const b = sqlite_col_octets(l, p, n);
  return io_done(sqlite_words(b, b.length));
}

io_eff(CID(db.open), sqlite_open);
io_eff(CID(db.close), sqlite_close);
io_eff(CID(stmt.prepare), sqlite_prepare);
io_eff(CID(stmt.finalize), sqlite_finalize);
io_eff(CID(stmt.bind.int), sqlite_bind_int);
io_eff(CID(stmt.bind.text), sqlite_bind_text);
io_eff(CID(stmt.bind.null), sqlite_bind_null);
io_eff(CID(stmt.bind.blob), sqlite_bind_blob);
io_eff(CID(stmt.step), sqlite_step);
io_eff(CID(stmt.reset), sqlite_reset);
io_eff(CID(stmt.column.kind), sqlite_column_kind);
io_eff(CID(stmt.column.int), sqlite_column_int);
io_eff(CID(stmt.column.text), sqlite_column_text);
io_eff(CID(stmt.column.blob), sqlite_column_blob);
