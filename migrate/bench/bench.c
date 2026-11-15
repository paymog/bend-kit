// Migration benchmark in C with cJSON (see README.md).
#include <cjson/cJSON.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

// Checksum: h = h*31 + b, u32, then add the length.
static unsigned chk(const char *s) {
  unsigned h = 0;
  size_t n = strlen(s);
  for (size_t i = 0; i < n; i++) h = h * 31 + (unsigned char)s[i];
  return h + (unsigned)n;
}

static const char *KEYS[4][8] = {
    {0},
    {"version", "id", "plan", "monthly_cents", "active", 0},
    {"version", "id", "plan", "cents", "period", "status", "note", 0},
    {"version", "id", "plan", "cents", "period", "status", 0},
};

static int in(const char *s, const char *const *xs) {
  for (; *xs; xs++)
    if (!strcmp(s, *xs)) return 1;
  return 0;
}

static int u32_of(const cJSON *r, const char *k, double *out) {
  const cJSON *v = cJSON_GetObjectItemCaseSensitive(r, k);
  if (!cJSON_IsNumber(v) || v->valuedouble < 0 || v->valuedouble > 4294967295.0 || floor(v->valuedouble) != v->valuedouble) return 0;
  *out = v->valuedouble;
  return 1;
}

static const char *text(const cJSON *r, const char *k, const char *const *allowed) {
  const cJSON *v = cJSON_GetObjectItemCaseSensitive(r, k);
  if (!cJSON_IsString(v) || (allowed && !in(v->valuestring, allowed))) return 0;
  return v->valuestring;
}

static const char *PERIODS[] = {"monthly", "yearly", 0};
static const char *STATUSES[] = {"active", "paused", "cancelled", 0};

static cJSON *up(const cJSON *r) {
  double v, id, cents;
  if (!cJSON_IsObject(r) || !u32_of(r, "version", &v) || v < 1 || v > 3) return 0;
  const cJSON *f;
  cJSON_ArrayForEach(f, r) if (!in(f->string, KEYS[(int)v])) return 0;
  const char *plan = text(r, "plan", 0), *period = "monthly", *status;
  if (!u32_of(r, "id", &id) || !plan) return 0;
  if (v == 1) {
    const cJSON *a = cJSON_GetObjectItemCaseSensitive(r, "active");
    if (!cJSON_IsBool(a) || !u32_of(r, "monthly_cents", &cents)) return 0;
    status = cJSON_IsTrue(a) ? "active" : "cancelled";
  } else {
    if (!u32_of(r, "cents", &cents) || !(status = text(r, "status", STATUSES))) return 0;
    if ((v == 3 || cJSON_HasObjectItem(r, "period")) && !(period = text(r, "period", PERIODS))) return 0;
    if (v == 2 && cJSON_HasObjectItem(r, "note") && !text(r, "note", 0)) return 0;
  }
  if (!*plan || cents == 0) return 0;
  cJSON *o = cJSON_CreateObject();
  cJSON_AddNumberToObject(o, "version", 3);
  cJSON_AddNumberToObject(o, "id", id);
  cJSON_AddStringToObject(o, "plan", plan);
  cJSON_AddNumberToObject(o, "cents", cents);
  cJSON_AddStringToObject(o, "period", period);
  cJSON_AddStringToObject(o, "status", status);
  return o;
}

int main(void) {
  FILE *fp = fopen("out/doc.json", "rb");
  if (!fp) return 1;
  fseek(fp, 0, SEEK_END);
  long n = ftell(fp);
  rewind(fp);
  char *data = malloc(n);
  if (fread(data, 1, n, fp) != (size_t)n) return 1;
  fclose(fp);

  double t0 = now_ms();
  cJSON *doc = cJSON_ParseWithLength(data, n);
  if (!cJSON_IsArray(doc)) return 2;
  cJSON *outv = cJSON_CreateArray();
  const cJSON *r;
  cJSON_ArrayForEach(r, doc) {
    cJSON *o = up(r);
    if (!o) return 3;
    cJSON_AddItemToArray(outv, o);
  }
  char *out = cJSON_PrintUnformatted(outv);
  double t1 = now_ms();
  if (!out) return 4;
  printf("migrate\t%.3f\t%u\n", t1 - t0, chk(out));

  free(out);
  cJSON_Delete(outv);
  cJSON_Delete(doc);
  free(data);
  return 0;
}
