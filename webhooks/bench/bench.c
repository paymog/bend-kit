// Webhook verify benchmark in C with OpenSSL HMAC-SHA256: one fixed message, 10,000 verifies (see README.md).
// C has no Standard Webhooks library, so this is the spec's verify written over OpenSSL's HMAC and base64.
#include <openssl/crypto.h>
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define N 10000
#define TOLERANCE 300L

static const char *ID = "msg_p5jXN8AQM9LWM0D4loKWxJek";
static const char *BODY = "{\"test\": 2432232314}";
static const char *SECRET = "MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw"; // whsec_ stripped

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

// 1 if ts is within TOLERANCE of now and some space-separated "v1,<base64>" in sigs matches HMAC(key, id.ts.body).
static int verify(const unsigned char *key, int klen, long now, const char *id, const char *ts, const char *sigs, const char *body) {
  char *end;
  long t = strtol(ts, &end, 10);
  if (end == ts || *end || now - t > TOLERANCE || t > now + TOLERANCE) return 0;
  char msg[1024];
  int mlen = snprintf(msg, sizeof msg, "%s.%s.%s", id, ts, body);
  if (mlen < 0 || mlen >= (int)sizeof msg) return 0;
  unsigned char mac[32];
  unsigned int maclen = 0;
  if (!HMAC(EVP_sha256(), key, klen, (unsigned char *)msg, mlen, mac, &maclen)) return 0;
  unsigned char want[45];
  int wlen = EVP_EncodeBlock(want, mac, maclen);
  for (const char *p = sigs; *p;) {
    const char *e = strchr(p, ' ');
    size_t len = e ? (size_t)(e - p) : strlen(p);
    if (len == 3 + (size_t)wlen && !strncmp(p, "v1,", 3) && !CRYPTO_memcmp(p + 3, want, wlen)) return 1;
    p += len + (e != NULL);
  }
  return 0;
}

int main(void) {
  // run.py signs the message at its start and passes the timestamp and signature in the environment.
  const char *ts = getenv("WEBHOOK_TS"), *sig = getenv("WEBHOOK_SIG");
  if (!ts || !sig) return 2;
  long now = time(NULL);
  unsigned char key[64];
  int klen = EVP_DecodeBlock(key, (const unsigned char *)SECRET, strlen(SECRET));
  // EVP_DecodeBlock counts '=' padding as zero bytes; drop them.
  for (const char *s = SECRET + strlen(SECRET); s > SECRET && s[-1] == '='; s--) klen--;
  int n = 0;
  double t0 = now_ms();
  for (int i = 0; i < N; i++) n += verify(key, klen, now, ID, ts, sig, BODY);
  double t1 = now_ms();
  printf("verify\t%.3f\t%d %s\n", t1 - t0, n, ID);
  return 0;
}
