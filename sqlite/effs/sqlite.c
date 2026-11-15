// SQLite
// ======
// libsqlite3 loaded with dlopen. Databases and statements cross as ids that are never reused.
// Every failure is a SQLite result code with a message, as sqlite/effs/sqlite.js answers.

#ifndef SQLITE_EFFS
#define SQLITE_EFFS

#if defined(CID(db.open)) || defined(CID(db.close)) || defined(CID(stmt.prepare)) || defined(CID(stmt.finalize)) \
  || defined(CID(stmt.bind.text)) || defined(CID(stmt.bind.int)) || defined(CID(stmt.bind.null))                 \
  || defined(CID(stmt.bind.blob)) || defined(CID(stmt.step)) || defined(CID(stmt.reset))                          \
  || defined(CID(stmt.column.kind)) || defined(CID(stmt.column.text)) || defined(CID(stmt.column.int))            \
  || defined(CID(stmt.column.blob))
#include <dlfcn.h>

// SQLite result codes this file answers with itself.
#define SQLITE_BUSY     5
#define SQLITE_NOMEM    7
#define SQLITE_CANTOPEN 14
#define SQLITE_MISMATCH 20
#define SQLITE_MISUSE   21
#define SQLITE_RANGE    25
#define SQLITE_ROW      100
#define SQLITE_DONE     101

static struct {
  int         state;
  int         (*open)(const char*, void**, int, const char*);
  int         (*close)(void*);
  const char* (*errmsg)(void*);
  const char* (*errstr)(int);
  int         (*prepare)(void*, const char*, int, void**, const char**);
  int         (*finalize)(void*);
  int         (*reset)(void*);
  int         (*step)(void*);
  int         (*bind_text)(void*, int, const char*, uint64_t, void (*)(void*), unsigned char);
  int         (*bind_int)(void*, int, int64_t);
  int         (*bind_null)(void*, int);
  int         (*bind_blob)(void*, int, const void*, uint64_t, void (*)(void*));
  int         (*bind_count)(void*);
  int         (*column_count)(void*);
  int         (*column_type)(void*, int);
  const void* (*column_text)(void*, int);
  const void* (*column_blob)(void*, int);
  int         (*column_bytes)(void*, int);
  int64_t     (*column_int)(void*, int);
} sqlite_lib;

static bool sqlite_load(void) {
  if (sqlite_lib.state != 0) {
    return sqlite_lib.state > 0;
  }
  sqlite_lib.state  = -1;
  const char* paths[] = { "/usr/lib/libsqlite3.dylib", "/opt/homebrew/opt/sqlite/lib/libsqlite3.dylib",
    "libsqlite3.dylib", "libsqlite3.so.0" };
  const char* over = getenv("BEND_LIBSQLITE");
  void*       h    = over != NULL ? dlopen(over, RTLD_NOW | RTLD_LOCAL) : NULL;
  for (u64 i = 0; h == NULL && i < sizeof(paths) / sizeof(paths[0]); i += 1) {
    h = dlopen(paths[i], RTLD_NOW | RTLD_LOCAL);
  }
  if (h == NULL) {
    return false;
  }
  sqlite_lib.open         = dlsym(h, "sqlite3_open_v2");
  sqlite_lib.close        = dlsym(h, "sqlite3_close");
  sqlite_lib.errmsg       = dlsym(h, "sqlite3_errmsg");
  sqlite_lib.errstr       = dlsym(h, "sqlite3_errstr");
  sqlite_lib.prepare      = dlsym(h, "sqlite3_prepare_v2");
  sqlite_lib.finalize     = dlsym(h, "sqlite3_finalize");
  sqlite_lib.reset        = dlsym(h, "sqlite3_reset");
  sqlite_lib.step         = dlsym(h, "sqlite3_step");
  sqlite_lib.bind_text    = dlsym(h, "sqlite3_bind_text64");
  sqlite_lib.bind_int     = dlsym(h, "sqlite3_bind_int64");
  sqlite_lib.bind_null    = dlsym(h, "sqlite3_bind_null");
  sqlite_lib.bind_blob    = dlsym(h, "sqlite3_bind_blob64");
  sqlite_lib.bind_count   = dlsym(h, "sqlite3_bind_parameter_count");
  sqlite_lib.column_count = dlsym(h, "sqlite3_column_count");
  sqlite_lib.column_type  = dlsym(h, "sqlite3_column_type");
  sqlite_lib.column_text  = dlsym(h, "sqlite3_column_text");
  sqlite_lib.column_blob  = dlsym(h, "sqlite3_column_blob");
  sqlite_lib.column_bytes = dlsym(h, "sqlite3_column_bytes");
  sqlite_lib.column_int   = dlsym(h, "sqlite3_column_int64");
  bool ok = sqlite_lib.open && sqlite_lib.close && sqlite_lib.errmsg && sqlite_lib.errstr && sqlite_lib.prepare
    && sqlite_lib.finalize && sqlite_lib.reset && sqlite_lib.step && sqlite_lib.bind_text && sqlite_lib.bind_int
    && sqlite_lib.bind_null && sqlite_lib.bind_blob && sqlite_lib.bind_count && sqlite_lib.column_count
    && sqlite_lib.column_type && sqlite_lib.column_text && sqlite_lib.column_blob && sqlite_lib.column_bytes
    && sqlite_lib.column_int;
  sqlite_lib.state = ok ? 1 : -1;
  return ok;
}

// SQLITE_TRANSIENT: SQLite copies the bound bytes before the call returns.
#define SQLITE_COPY ((void (*)(void*))(intptr_t)-1)

typedef struct { void* db; u32 live; } SqliteDb;
typedef struct { void* st; SqliteDb* db; bool row; } SqliteSt;

// Slot id holds the record, NULL once released; id 0 is never used.
// ponytail: one pointer per id ever made, never shrunk; a hash map if programs make billions of handles.
typedef struct { void** at; u32 next; u32 cap; } SqliteReg;
static SqliteReg sqlite_dbs;
static SqliteReg sqlite_sts;

// 0 when the ids have run out.
static u32 sqlite_put(SqliteReg* r, void* p) {
  r->next = r->next == 0 ? 1 : r->next;
  if (r->next == UINT32_MAX) {
    return 0;
  }
  if (r->next >= r->cap) {
    r->cap = r->cap == 0 ? 64 : r->cap > UINT32_MAX / 2 ? UINT32_MAX : r->cap * 2;
    r->at  = io_mem(realloc(r->at, sizeof(void*) * r->cap));
  }
  r->at[r->next] = p;
  return r->next++;
}

static void* sqlite_get(SqliteReg* r, u32 id) {
  return id != 0 && id < r->next ? r->at[id] : NULL;
}

static Term sqlite_unit(Env e) {
  return io_done(e, term_pak(CID(Unit), 0));
}

static Term sqlite_bad(Env e) {
  return io_fail(e, SQLITE_MISUSE, "bad handle");
}

static Term sqlite_nul(Env e) {
  return io_fail(e, SQLITE_MISUSE, "string contains NUL");
}

static Term sqlite_range(Env e) {
  return io_fail(e, SQLITE_RANGE, "index out of range");
}

// The SQLite failure rc with the database's message.
static Term sqlite_err(Env e, void* db, int rc) {
  return io_fail(e, (u32)rc, sqlite_lib.errmsg(db));
}

static Term sqlite_bound(Env e, SqliteSt* s, int rc) {
  return rc == 0 ? sqlite_unit(e) : sqlite_err(e, s->db->db, rc);
}

// The statement for a bind at 1-based index i, or NULL with *r set. A bind ends the current row.
static SqliteSt* sqlite_bind_at(Env e, u32 id, u32 i, Term* r) {
  SqliteSt* s = sqlite_get(&sqlite_sts, id);
  if (s == NULL) {
    *r = sqlite_bad(e);
    return NULL;
  }
  if (i == 0 || i > (u32)sqlite_lib.bind_count(s->st)) {
    *r = sqlite_range(e);
    return NULL;
  }
  s->row = false;
  return s;
}

// The statement for a read of 0-based column i on the current row, or NULL with *r set.
static SqliteSt* sqlite_column_at(Env e, u32 id, u32 i, Term* r) {
  SqliteSt* s = sqlite_get(&sqlite_sts, id);
  *r          = s == NULL ? sqlite_bad(e)
       : !s->row          ? io_fail(e, SQLITE_MISUSE, "no current row")
       : i >= (u32)sqlite_lib.column_count(s->st) ? sqlite_range(e)
                                                  : 0;
  return *r == 0 ? s : NULL;
}

// The column of kind k, or NULL with *r set. Kinds: 1 integer, 2 float, 3 text, 4 blob, 5 null.
static SqliteSt* sqlite_column_of(Env e, u32 id, u32 i, int k, Term* r) {
  SqliteSt* s = sqlite_column_at(e, id, i, r);
  if (s != NULL && sqlite_lib.column_type(s->st, (int)i) != k) {
    *r = io_fail(e, SQLITE_MISMATCH, "column kind mismatch");
    return NULL;
  }
  return s;
}

#endif

#ifdef CID(db.open)

Term db_open_run(Env e, Term* f, IoWork* w) {
  u64   n    = 0;
  char* path = io_cstr(e, f[0], &n);
  if (!sqlite_load()) {
    free(path);
    return io_fail(e, SQLITE_CANTOPEN, "sqlite needs libsqlite3; set BEND_LIBSQLITE to its path");
  }
  if (io_nul(path, n)) {
    free(path);
    return sqlite_nul(e);
  }
  void* db = NULL;
  int   rc = sqlite_lib.open(path, &db, 0x2 | 0x4, NULL);  // SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
  free(path);
  if (rc != 0) {
    Term r = db != NULL ? sqlite_err(e, db, rc) : io_fail(e, (u32)rc, sqlite_lib.errstr(rc));
    sqlite_lib.close(db);
    return r;
  }
  SqliteDb* d = io_mem(malloc(sizeof(SqliteDb)));
  *d          = (SqliteDb){ db, 0 };
  u32 id      = sqlite_put(&sqlite_dbs, d);
  if (id == 0) {
    sqlite_lib.close(db);
    free(d);
    return io_fail(e, SQLITE_NOMEM, "out of handles");
  }
  return io_done(e, (Term)id);
}

static void __attribute__((constructor)) db_open_use(void) {
  io_eff(CID(db.open), db_open_run);
}

#endif

#ifdef CID(db.close)

Term db_close_run(Env e, Term* f, IoWork* w) {
  u32       id = (u32)f[0];
  SqliteDb* d  = sqlite_get(&sqlite_dbs, id);
  if (d == NULL) {
    return sqlite_bad(e);
  }
  if (d->live != 0) {
    return io_fail(e, SQLITE_BUSY, "database has open statements");
  }
  int rc = sqlite_lib.close(d->db);
  if (rc != 0) {
    return sqlite_err(e, d->db, rc);
  }
  free(d);
  sqlite_dbs.at[id] = NULL;
  return sqlite_unit(e);
}

static void __attribute__((constructor)) db_close_use(void) {
  io_eff(CID(db.close), db_close_run);
}

#endif

#ifdef CID(stmt.prepare)

// Exactly one statement: the text after it may only be ASCII whitespace.
Term stmt_prepare_run(Env e, Term* f, IoWork* w) {
  u64       n   = 0;
  char*     sql = io_cstr(e, f[1], &n);
  SqliteDb* d   = sqlite_get(&sqlite_dbs, (u32)f[0]);
  if (d == NULL || io_nul(sql, n)) {
    free(sql);
    return d == NULL ? sqlite_bad(e) : sqlite_nul(e);
  }
  void*       st   = NULL;
  const char* tail = NULL;
  int         rc   = sqlite_lib.prepare(d->db, sql, -1, &st, &tail);
  if (rc != 0) {
    free(sql);
    return sqlite_err(e, d->db, rc);
  }
  while (st != NULL && tail != NULL && *tail != 0 && strchr(" \t\n\r\f", *tail) != NULL) {
    tail += 1;
  }
  bool more = st != NULL && tail != NULL && *tail != 0;
  free(sql);
  if (st == NULL || more) {
    sqlite_lib.finalize(st);
    return io_fail(e, SQLITE_MISUSE, st == NULL ? "SQL has no statement" : "SQL has more than one statement");
  }
  SqliteSt* s = io_mem(malloc(sizeof(SqliteSt)));
  *s          = (SqliteSt){ st, d, false };
  u32 id      = sqlite_put(&sqlite_sts, s);
  if (id == 0) {
    sqlite_lib.finalize(st);
    free(s);
    return io_fail(e, SQLITE_NOMEM, "out of handles");
  }
  d->live += 1;
  return io_done(e, (Term)id);
}

static void __attribute__((constructor)) stmt_prepare_use(void) {
  io_eff(CID(stmt.prepare), stmt_prepare_run);
}

#endif

#ifdef CID(stmt.finalize)

// The rc of sqlite3_finalize repeats the last step's failure, already answered; the statement goes either way.
Term stmt_finalize_run(Env e, Term* f, IoWork* w) {
  u32       id = (u32)f[0];
  SqliteSt* s  = sqlite_get(&sqlite_sts, id);
  if (s == NULL) {
    return sqlite_bad(e);
  }
  sqlite_lib.finalize(s->st);
  s->db->live -= 1;
  free(s);
  sqlite_sts.at[id] = NULL;
  return sqlite_unit(e);
}

static void __attribute__((constructor)) stmt_finalize_use(void) {
  io_eff(CID(stmt.finalize), stmt_finalize_run);
}

#endif

#ifdef CID(stmt.bind.text)

Term stmt_bind_text_run(Env e, Term* f, IoWork* w) {
  u64       n    = 0;
  char*     text = io_cstr(e, f[2], &n);
  Term      r    = 0;
  SqliteSt* s    = sqlite_bind_at(e, (u32)f[0], (u32)f[1], &r);
  if (s != NULL) {
    r = io_nul(text, n) ? sqlite_nul(e)
      : sqlite_bound(e, s, sqlite_lib.bind_text(s->st, (int)(u32)f[1], text, n, SQLITE_COPY, 1));  // SQLITE_UTF8
  }
  free(text);
  return r;
}

static void __attribute__((constructor)) stmt_bind_text_use(void) {
  io_eff(CID(stmt.bind.text), stmt_bind_text_run);
}

#endif

#ifdef CID(stmt.bind.int)

Term stmt_bind_int_run(Env e, Term* f, IoWork* w) {
  Term      r = 0;
  SqliteSt* s = sqlite_bind_at(e, (u32)f[0], (u32)f[1], &r);
  return s == NULL ? r : sqlite_bound(e, s, sqlite_lib.bind_int(s->st, (int)(u32)f[1], (int64_t)(u32)f[2]));
}

static void __attribute__((constructor)) stmt_bind_int_use(void) {
  io_eff(CID(stmt.bind.int), stmt_bind_int_run);
}

#endif

#ifdef CID(stmt.bind.null)

Term stmt_bind_null_run(Env e, Term* f, IoWork* w) {
  Term      r = 0;
  SqliteSt* s = sqlite_bind_at(e, (u32)f[0], (u32)f[1], &r);
  return s == NULL ? r : sqlite_bound(e, s, sqlite_lib.bind_null(s->st, (int)(u32)f[1]));
}

static void __attribute__((constructor)) stmt_bind_null_use(void) {
  io_eff(CID(stmt.bind.null), stmt_bind_null_run);
}

#endif

#ifdef CID(stmt.bind.blob)

// f is stmt, index, len, words: len octets packed little-endian, four to a word.
// Copy of wire_words_octets in wire/effs/wire.c; keep them in step.
Term stmt_bind_blob_run(Env e, Term* f, IoWork* w) {
  u64*  H   = e.mem;
  Term  a   = f[3];
  u64   n   = (u64)(u32)f[2];
  bool  bad = term_tag(a) != TAG_BUF || n > (4ull << blk_cls(a)) || n > 0x7fffffff;
  u64   len = bad ? 0 : n;
  char* buf = io_mem(malloc(len + 1));
  u64   l   = bad ? 0 : blk_loc(H, a);
  for (u64 i = 0; i < len; i += 1) {
    buf[i] = (char)(blk_read(H, false, l, (u32)(i / 4)) >> (8 * (i % 4)));
  }
  term_drop(e, a);
  Term      r = 0;
  SqliteSt* s = sqlite_bind_at(e, (u32)f[0], (u32)f[1], &r);
  if (s != NULL) {
    r = bad ? io_fail(e, SQLITE_MISUSE, "blob length exceeds words")
      : sqlite_bound(e, s, sqlite_lib.bind_blob(s->st, (int)(u32)f[1], buf, len, SQLITE_COPY));
  }
  free(buf);
  return r;
}

static void __attribute__((constructor)) stmt_bind_blob_use(void) {
  io_eff(CID(stmt.bind.blob), stmt_bind_blob_run);
}

#endif

#ifdef CID(stmt.step)

// True: a row is ready. False: done. A failure keeps the statement for reset or finalize.
Term stmt_step_run(Env e, Term* f, IoWork* w) {
  SqliteSt* s = sqlite_get(&sqlite_sts, (u32)f[0]);
  if (s == NULL) {
    return sqlite_bad(e);
  }
  int rc = sqlite_lib.step(s->st);
  s->row = rc == SQLITE_ROW;
  return rc == SQLITE_ROW ? io_done(e, term_pak(CID(True), 0))
    : rc == SQLITE_DONE   ? io_done(e, term_pak(CID(False), 0))
                          : sqlite_err(e, s->db->db, rc);
}

static void __attribute__((constructor)) stmt_step_use(void) {
  io_eff(CID(stmt.step), stmt_step_run);
}

#endif

#ifdef CID(stmt.reset)

// The rc of sqlite3_reset repeats the last step's failure, already answered; the reset happens either way.
Term stmt_reset_run(Env e, Term* f, IoWork* w) {
  SqliteSt* s = sqlite_get(&sqlite_sts, (u32)f[0]);
  if (s == NULL) {
    return sqlite_bad(e);
  }
  sqlite_lib.reset(s->st);
  s->row = false;
  return sqlite_unit(e);
}

static void __attribute__((constructor)) stmt_reset_use(void) {
  io_eff(CID(stmt.reset), stmt_reset_run);
}

#endif

#ifdef CID(stmt.column.kind)

Term stmt_column_kind_run(Env e, Term* f, IoWork* w) {
  Term      r = 0;
  SqliteSt* s = sqlite_column_at(e, (u32)f[0], (u32)f[1], &r);
  return s == NULL ? r : io_done(e, (Term)(u32)sqlite_lib.column_type(s->st, (int)(u32)f[1]));
}

static void __attribute__((constructor)) stmt_column_kind_use(void) {
  io_eff(CID(stmt.column.kind), stmt_column_kind_run);
}

#endif

#ifdef CID(stmt.column.text)

Term stmt_column_text_run(Env e, Term* f, IoWork* w) {
  Term      r = 0;
  int       i = (int)(u32)f[1];
  SqliteSt* s = sqlite_column_of(e, (u32)f[0], (u32)f[1], 3, &r);
  if (s == NULL) {
    return r;
  }
  const char* p = sqlite_lib.column_text(s->st, i);  // before column_bytes, as SQLite asks
  u64         n = (u64)sqlite_lib.column_bytes(s->st, i);
  return p == NULL ? io_fail(e, SQLITE_NOMEM, sqlite_lib.errmsg(s->db->db)) : io_done(e, io_str(e, p, n));
}

static void __attribute__((constructor)) stmt_column_text_use(void) {
  io_eff(CID(stmt.column.text), stmt_column_text_run);
}

#endif

#ifdef CID(stmt.column.int)

Term stmt_column_int_run(Env e, Term* f, IoWork* w) {
  Term      r = 0;
  SqliteSt* s = sqlite_column_of(e, (u32)f[0], (u32)f[1], 1, &r);
  if (s == NULL) {
    return r;
  }
  int64_t v = sqlite_lib.column_int(s->st, (int)(u32)f[1]);
  return v < 0 || v > UINT32_MAX ? io_fail(e, SQLITE_MISMATCH, "integer outside U32") : io_done(e, (Term)(u32)v);
}

static void __attribute__((constructor)) stmt_column_int_use(void) {
  io_eff(CID(stmt.column.int), stmt_column_int_run);
}

#endif

#ifdef CID(stmt.column.blob)

// The blob as (len, words). Copy of wire_words in wire/effs/wire.c; keep them in step.
Term stmt_column_blob_run(Env e, Term* f, IoWork* w) {
  Term      r = 0;
  int       i = (int)(u32)f[1];
  SqliteSt* s = sqlite_column_of(e, (u32)f[0], (u32)f[1], 4, &r);
  if (s == NULL) {
    return r;
  }
  const char* p    = sqlite_lib.column_blob(s->st, i);  // before column_bytes, as SQLite asks
  u64         n    = (u64)sqlite_lib.column_bytes(s->st, i);
  u64         wn   = (n + 3) / 4;
  u64         d    = 0;
  Term        zero = 0;
  if (p == NULL && n != 0) {
    return io_fail(e, SQLITE_NOMEM, sqlite_lib.errmsg(s->db->db));
  }
  while ((1ull << d) < wn) {
    d += 1;
  }
  Term a = blk_new(e, false, d, 0, 1, &zero);
  u64  l = blk_loc(e.mem, a);
  for (u64 k = 0; k < wn; k += 1) {
    u32 x = 0;
    for (u64 j = 0; j < 4 && 4 * k + j < n; j += 1) {
      x |= (u32)(uint8_t)p[4 * k + j] << (8 * j);
    }
    blk_write(e.mem, false, l, (u32)k, x);
  }
  return io_done(e, io_tup(e, (Term)n, a));
}

static void __attribute__((constructor)) stmt_column_blob_use(void) {
  io_eff(CID(stmt.column.blob), stmt_column_blob_run);
}

#endif

#endif
