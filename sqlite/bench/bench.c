// SQLite benchmark in C: N prepared inserts in one transaction, then N primary-key reads, through libsqlite3.
#include <sqlite3.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static sqlite3* db;

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

int main(int argc, char** argv) {
  uint32_t        n = argc > 1 ? (uint32_t)strtoul(argv[1], NULL, 10) : 100000;
  struct timespec t0, t1;
  ok(sqlite3_open(":memory:", &db), SQLITE_OK);
  printf("sqlite\t%s\n", sqlite3_libversion());
  exec("CREATE TABLE t(k INTEGER PRIMARY KEY, v INTEGER NOT NULL)");

  sqlite3_stmt* ins = prepare("INSERT INTO t VALUES (?1, ?2)");
  uint32_t      x   = 1;
  clock_gettime(CLOCK_MONOTONIC, &t0);
  exec("BEGIN");
  for (uint32_t i = 0; i < n; i += 1) {
    ok(sqlite3_bind_int64(ins, 1, i), SQLITE_OK);
    ok(sqlite3_bind_int64(ins, 2, x >> 1), SQLITE_OK);
    ok(sqlite3_step(ins), SQLITE_DONE);
    ok(sqlite3_reset(ins), SQLITE_OK);
    x = x * 1664525u + 1013904223u;
  }
  exec("COMMIT");
  clock_gettime(CLOCK_MONOTONIC, &t1);
  sqlite3_finalize(ins);
  sqlite3_stmt* cnt = prepare("SELECT count(*) FROM t");
  ok(sqlite3_step(cnt), SQLITE_ROW);
  printf("insert\t%.3f\t%u\n", ms(t0, t1), (uint32_t)sqlite3_column_int64(cnt, 0));
  sqlite3_finalize(cnt);

  sqlite3_stmt* sel = prepare("SELECT v FROM t WHERE k = ?1");
  uint32_t      h   = 0;
  clock_gettime(CLOCK_MONOTONIC, &t0);
  for (uint32_t j = 0, k = 0; j < n; j += 1, k += 7919) {
    ok(sqlite3_bind_int64(sel, 1, k % n), SQLITE_OK);
    ok(sqlite3_step(sel), SQLITE_ROW);
    h = h * 31 + (uint32_t)sqlite3_column_int64(sel, 0);
    ok(sqlite3_reset(sel), SQLITE_OK);
  }
  clock_gettime(CLOCK_MONOTONIC, &t1);
  printf("select\t%.3f\t%u\n", ms(t0, t1), h);
  sqlite3_finalize(sel);
  sqlite3_close(db);
  return 0;
}
