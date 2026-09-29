// Postgres result decode benchmark in C with libpq (see README.md).
// libpq parses only what it reads from a connection, so a thread replays the recording over a Unix socket.
#include <libpq-fe.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

#define M(h, x) ((h) = (h) * 31u + (uint32_t)(x))

static char *data;
static long n;
static int lfd;

static void read_n(int fd, void *buf, size_t len) {
  for (size_t at = 0; at < len;) {
    ssize_t k = read(fd, (char *)buf + at, len - at);
    if (k <= 0) exit(5);
    at += k;
  }
}

static void write_n(int fd, const void *buf, size_t len) {
  for (size_t at = 0; at < len;) {
    ssize_t k = write(fd, (const char *)buf + at, len - at);
    if (k <= 0) exit(6);
    at += k;
  }
}

// Skips one message whose length word follows `skip` bytes (0 for the startup packet, 1 for a typed message).
static void drop(int fd, int skip) {
  unsigned char hd[5];
  read_n(fd, hd, skip + 4);
  uint32_t len = (uint32_t)hd[skip] << 24 | hd[skip + 1] << 16 | hd[skip + 2] << 8 | hd[skip + 3];
  char *body = malloc(len);
  read_n(fd, body, len - 4);
  free(body);
}

// AuthenticationOk, the ParameterStatus values libpq and psycopg read, BackendKeyData, ReadyForQuery.
static const char HELLO[] =
    "R\0\0\0\x08\0\0\0\0"
    "S\0\0\0\x19" "client_encoding\0UTF8\0"
    "S\0\0\0\x19" "server_encoding\0UTF8\0"
    "S\0\0\0\x18" "server_version\0" "18.0\0"
    "S\0\0\0\x23" "standard_conforming_strings\0on\0"
    "S\0\0\0\x19" "integer_datetimes\0on\0"
    "S\0\0\0\x12" "DateStyle\0ISO\0"
    "K\0\0\0\x0c\0\0\0\x01\0\0\0\x02"
    "Z\0\0\0\x05I";

static void *replay(void *arg) {
  (void)arg;
  int fd = accept(lfd, NULL, NULL);
  if (fd < 0) exit(7);
  drop(fd, 0);
  write_n(fd, HELLO, sizeof HELLO - 1);
  drop(fd, 1);  // the Query
  write_n(fd, data, n);
  char c;
  while (read(fd, &c, 1) > 0) {}  // until Terminate and close
  close(fd);
  return NULL;
}

int main(void) {
  FILE *f = fopen("out/result.pgwire", "rb");
  if (!f) return 1;
  fseek(f, 0, SEEK_END);
  n = ftell(f);
  rewind(f);
  data = malloc(n);
  if (fread(data, 1, n, f) != (size_t)n) return 1;
  fclose(f);

  char dir[] = "/tmp/pgbench.XXXXXX";
  if (!mkdtemp(dir)) return 1;
  struct sockaddr_un addr = {.sun_family = AF_UNIX};
  snprintf(addr.sun_path, sizeof addr.sun_path, "%s/.s.PGSQL.5432", dir);
  lfd = socket(AF_UNIX, SOCK_STREAM, 0);
  if (bind(lfd, (struct sockaddr *)&addr, sizeof addr) || listen(lfd, 1)) return 1;
  pthread_t t;
  pthread_create(&t, NULL, replay, NULL);

  char conninfo[256];
  snprintf(conninfo, sizeof conninfo, "host=%s port=5432 user=bench dbname=bench", dir);
  PGconn *conn = PQconnectdb(conninfo);
  if (PQstatus(conn) != CONNECTION_OK) {
    fprintf(stderr, "%s", PQerrorMessage(conn));
    return 2;
  }

  double t0 = now_ms();
  PGresult *res = PQexec(conn, "SELECT id, name, balance, note, active FROM accounts");
  double t1 = now_ms();
  if (PQresultStatus(res) != PGRES_TUPLES_OK) {
    fprintf(stderr, "%s", PQresultErrorMessage(res));
    return 3;
  }

  // The checksum in run.py.
  uint32_t h = 0;
  int cols = PQnfields(res), rows = PQntuples(res);
  M(h, 1);
  for (int c = 0; c < cols; c++) {
    const char *s = PQfname(res, c);
    size_t len = strlen(s);
    M(h, len);
    for (size_t i = 0; i < len; i++) M(h, (unsigned char)s[i]);
    M(h, PQftype(res, c));
  }
  M(h, 2);
  for (int r = 0; r < rows; r++) {
    M(h, 3);
    for (int c = 0; c < cols; c++) {
      if (PQgetisnull(res, r, c)) {
        M(h, 4);
        continue;
      }
      const char *s = PQgetvalue(res, r, c);
      int len = PQgetlength(res, r, c);
      M(h, 5);
      M(h, len);
      for (int i = 0; i < len; i++) M(h, (unsigned char)s[i]);
    }
    M(h, 6);
  }
  M(h, 7);
  const char *tag = PQcmdStatus(res);
  size_t len = strlen(tag);
  M(h, len);
  for (size_t i = 0; i < len; i++) M(h, (unsigned char)tag[i]);
  printf("decode\t%.3f\t%u\n", t1 - t0, h);

  PQclear(res);
  PQfinish(conn);
  pthread_join(t, NULL);
  unlink(addr.sun_path);
  rmdir(dir);
  free(data);
  return 0;
}
