// commands benchmark in C: N new commands, then the same N as duplicates, each in one BEGIN IMMEDIATE transaction.
#include <sqlite3.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <assert.h>

static sqlite3* db;
static sqlite3_stmt *begin_, *commit_, *find, *readst, *save, *keep, *emit;

static double ms(struct timespec t0, struct timespec t1) {
  return (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6;
}

static void ok(int rc, int want) {
  if (rc != want) {
    fprintf(stderr, "sqlite: %s\n", sqlite3_errmsg(db));
    exit(1);
  }
}

static sqlite3_stmt* prepare(const char* sql) {
  sqlite3_stmt* st;
  ok(sqlite3_prepare_v2(db, sql, -1, &st, NULL), SQLITE_OK);
  return st;
}

static void exec(const char* sql) {
  ok(sqlite3_exec(db, sql, NULL, NULL, NULL), SQLITE_OK);
}

static void run(sqlite3_stmt* st) {
  ok(sqlite3_step(st), SQLITE_DONE);
  ok(sqlite3_reset(st), SQLITE_OK);
}

static void text(sqlite3_stmt* st, int i, const char* s) {
  ok(sqlite3_bind_text(st, i, s, -1, SQLITE_TRANSIENT), SQLITE_OK);
}

static void blob(sqlite3_stmt* st, int i, const char* s) {
  ok(sqlite3_bind_blob(st, i, s, (int)strlen(s), SQLITE_TRANSIENT), SQLITE_OK);
}

// A decimal blob column as a number.
static uint32_t num(sqlite3_stmt* st, int i) {
  const char* p = sqlite3_column_blob(st, i);
  int         n = sqlite3_column_bytes(st, i);
  uint32_t    v = 0;
  for (int k = 0; k < n; k += 1) v = v * 10 + (uint32_t)(p[k] - '0');
  return v;
}

// 1 for a new command, 2 for a duplicate, 0 for a conflict. *result is the recorded or new total.
static int handle(const char* id, const char* payload, uint32_t* result) {
  run(begin_);
  text(find, 1, id);
  int rc = sqlite3_step(find);
  if (rc == SQLITE_ROW) {
    const void* p    = sqlite3_column_blob(find, 0);
    int         same = (size_t)sqlite3_column_bytes(find, 0) == strlen(payload) && memcmp(p, payload, strlen(payload)) == 0;
    *result          = num(find, 2);
    ok(sqlite3_reset(find), SQLITE_OK);
    run(commit_);
    return same ? 2 : 0;
  }
  ok(rc, SQLITE_DONE);
  ok(sqlite3_reset(find), SQLITE_OK);
  blob(readst, 1, "total");
  rc = sqlite3_step(readst);
  if (rc != SQLITE_ROW) ok(rc, SQLITE_DONE);
  uint32_t total = rc == SQLITE_ROW ? num(readst, 0) : 0;
  ok(sqlite3_reset(readst), SQLITE_OK);
  total += (uint32_t)strtoul(payload, NULL, 10);
  char t[16], effect[32];
  snprintf(t, sizeof t, "%u", total);
  snprintf(effect, sizeof effect, "total=%u", total);
  blob(save, 1, "total");
  blob(save, 2, t);
  run(save);
  text(keep, 1, id);
  blob(keep, 2, payload);
  ok(sqlite3_bind_int64(keep, 3, 1), SQLITE_OK);
  blob(keep, 4, t);
  ok(sqlite3_bind_int64(keep, 5, 200), SQLITE_OK);
  run(keep);
  text(emit, 1, id);
  blob(emit, 2, effect);
  run(emit);
  run(commit_);
  *result = total;
  return 1;
}

// Command i has id cmd_i and amount (x_i >> 1) % 1000. h = h*31 + result.
static uint32_t pass(uint32_t n, int want) {
  uint32_t x = 1, h = 0, r;
  char     id[24], payload[16];
  for (uint32_t i = 0; i < n; i += 1) {
    snprintf(id, sizeof id, "cmd_%u", i);
    snprintf(payload, sizeof payload, "%u", (x >> 1) % 1000);
    if (handle(id, payload, &r) != want) {
      fprintf(stderr, "unexpected reply\n");
      exit(1);
    }
    h = h * 31 + r;
    x = x * 1664525u + 1013904223u;
  }
  return h;
}

static uint32_t range_handle(const char* id, int limit) {
  run(begin_);
  text(find, 1, id);
  ok(sqlite3_step(find), SQLITE_DONE);
  ok(sqlite3_reset(find), SQLITE_OK);
  sqlite3_stmt* scan = prepare("SELECT k, v FROM commands_rows WHERE k >= ? AND k < ? ORDER BY k");
  blob(scan, 1, "pick_");
  blob(scan, 2, "pick`");
  char rows[8][32];
  int count = 0, rc;
  while ((rc = sqlite3_step(scan)) == SQLITE_ROW) {
    if (count == limit) {
      ok(sqlite3_finalize(scan), SQLITE_OK);
      exec("ROLLBACK");
      return 18;
    }
    int nk = sqlite3_column_bytes(scan, 0), nv = sqlite3_column_bytes(scan, 1);
    assert(nk + nv + 3 <= (int)sizeof rows[0]);
    memcpy(rows[count], sqlite3_column_blob(scan, 0), nk);
    rows[count][nk] = '=';
    memcpy(rows[count] + nk + 1, sqlite3_column_blob(scan, 1), nv);
    rows[count][nk + nv + 1] = ';';
    rows[count][nk + nv + 2] = 0;
    count++;
  }
  ok(rc, SQLITE_DONE);
  ok(sqlite3_finalize(scan), SQLITE_OK);
  uint32_t h = 0;
  for (int i = 0; i < count; i++)
    for (const unsigned char* p = (const unsigned char*)rows[i]; *p; p++) h = h * 31 + *p;
  char result[16], payload[16];
  snprintf(result, sizeof result, "%u", h);
  snprintf(payload, sizeof payload, "%d", limit);
  text(keep, 1, id);
  blob(keep, 2, payload);
  ok(sqlite3_bind_int64(keep, 3, 1), SQLITE_OK);
  blob(keep, 4, result);
  ok(sqlite3_bind_int64(keep, 5, 200), SQLITE_OK);
  run(keep);
  run(commit_);
  return h;
}

static void ranges(uint32_t n, int count, const char* label) {
  exec("DELETE FROM commands_rows");
  exec("DELETE FROM commands_seen");
  exec("DELETE FROM commands_outbox");
  exec("INSERT INTO commands_rows WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i+1 FROM n WHERE i<7) SELECT CAST('pick_'||i AS BLOB), CAST(i+1 AS BLOB) FROM n");
  char sql[256];
  snprintf(sql, sizeof sql, "INSERT INTO commands_rows WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i+1 FROM n WHERE i<%d) SELECT CAST('z_'||i AS BLOB), CAST('100' AS BLOB) FROM n", count - 1);
  exec(sql);
  for (int overflow = 0; overflow <= 1; overflow++) {
    struct timespec t0, t1;
    uint32_t h = 0;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    for (uint32_t i = 0; i < n; i++) {
      char id[32];
      if (!overflow) snprintf(id, sizeof id, "range_%u", i);
      uint32_t r = range_handle(overflow ? "overflow" : id, overflow ? 7 : 8);
      assert(!overflow || r == 18);
      h = h * 31 + r;
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);
    printf("%s_%s\t%.3f\t%u\n", overflow ? "overflow" : "range", label, ms(t0, t1), h);
  }
  sqlite3_stmt* check = prepare("SELECT (SELECT count(*) FROM commands_seen), (SELECT count(*) FROM commands_outbox)");
  ok(sqlite3_step(check), SQLITE_ROW);
  assert(sqlite3_column_int64(check, 0) == n && sqlite3_column_int64(check, 1) == 0);
  ok(sqlite3_finalize(check), SQLITE_OK);
  assert(range_handle("overflow", 8) != 18);
}

int main(int argc, char** argv) {
  const char*     path = argc > 1 ? argv[1] : "out/c.db";
  uint32_t        n    = argc > 2 ? (uint32_t)strtoul(argv[2], NULL, 10) : 10000;
  struct timespec t0, t1;
  ok(sqlite3_open(path, &db), SQLITE_OK);
  printf("sqlite\t%s\n", sqlite3_libversion());
  exec("PRAGMA busy_timeout = 10000");
  exec("CREATE TABLE IF NOT EXISTS commands_rows (k BLOB PRIMARY KEY, v BLOB NOT NULL) WITHOUT ROWID");
  exec("CREATE TABLE IF NOT EXISTS commands_seen (id TEXT PRIMARY KEY, payload BLOB NOT NULL, kind INTEGER NOT NULL, result BLOB NOT NULL, at INTEGER NOT NULL)");
  exec("CREATE INDEX IF NOT EXISTS commands_seen_at ON commands_seen (at)");
  exec("CREATE TABLE IF NOT EXISTS commands_outbox (seq INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL, effect BLOB NOT NULL)");
  begin_  = prepare("BEGIN IMMEDIATE");
  commit_ = prepare("COMMIT");
  find    = prepare("SELECT payload, kind, result, at FROM commands_seen WHERE id = ?");
  readst  = prepare("SELECT v FROM commands_rows WHERE k = ?");
  save    = prepare("INSERT OR REPLACE INTO commands_rows (k, v) VALUES (?, ?)");
  keep    = prepare("INSERT INTO commands_seen (id, payload, kind, result, at) VALUES (?, ?, ?, ?, ?)");
  emit    = prepare("INSERT INTO commands_outbox (id, effect) VALUES (?, ?)");

  clock_gettime(CLOCK_MONOTONIC, &t0);
  pass(n, 1);
  clock_gettime(CLOCK_MONOTONIC, &t1);
  blob(readst, 1, "total");
  ok(sqlite3_step(readst), SQLITE_ROW);
  printf("fresh\t%.3f\t%u\n", ms(t0, t1), num(readst, 0));
  ok(sqlite3_reset(readst), SQLITE_OK);

  clock_gettime(CLOCK_MONOTONIC, &t0);
  uint32_t h = pass(n, 2);
  clock_gettime(CLOCK_MONOTONIC, &t1);
  printf("replay\t%.3f\t%u\n", ms(t0, t1), h);
  ranges(n, 100, "small");
  ranges(n, 100000, "large");

  sqlite3_stmt* all[] = {begin_, commit_, find, readst, save, keep, emit};
  for (size_t i = 0; i < sizeof all / sizeof *all; i += 1) sqlite3_finalize(all[i]);
  sqlite3_close(db);
  return 0;
}
