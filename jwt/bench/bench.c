// JWT verify benchmark in C with libjwt 3: one fixed HS256 and one fixed RS256 token (see README.md).
#include <jwt.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define N 10000

static const char SECRET[] = "bend-kit-jwt-bench-hs256-secret-0123456789";
static const char PEM[] =
  "-----BEGIN PUBLIC KEY-----\n"
  "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnAfhVvP/esxVFB9kHsuw\n"
  "I83x79PE8FzlNOOogtlz08Pwjjf14zxEB46KHCy344mFXAFGuerTLiqRXlxd2/i8\n"
  "ITk4L6hCsktjri3VBK+KkTii7dh9LbqwE083DHLL5TyUr+1Br7KmIzP76T2VaQ2c\n"
  "7l+Iv8IAH8COhDf4x8raeTFDP67DyxsoHmxBdkSEKbdG9Tbl17fw44uxnqHko/5y\n"
  "FmfFuzgjQ1NhQ0yymUC5uzdS+s333dXwMjxl+k/BQvcfEYc0EdaUiwrgtSBrgkqd\n"
  "wpLIyVPQ59xLs5KDBEdNtRGv98IuBzwIImco3i8Ad+YB826w3NrehEinid91F7eg\n"
  "yQIDAQAB\n"
  "-----END PUBLIC KEY-----\n";
static const char HS256[] = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiZW5kLWtpdCIsIm5hbWUiOiJCZW5jaCBVc2VyIiwiYWRtaW4iOnRydWUsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjo0MTAyNDQ0ODAwfQ.DiAMBIAhI-CRSG3YSeQgSUn9D0fEYLlpbvvw5Ogd7GI";
static const char RS256[] = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiZW5kLWtpdCIsIm5hbWUiOiJCZW5jaCBVc2VyIiwiYWRtaW4iOnRydWUsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjo0MTAyNDQ0ODAwfQ.Hmu8V5e7RcP-BEzxtCkvda0si-bTm8UbP-yhSTvLdZq0i1gORUFRsS8_F8qJCLsjOf1cH6EsCUb4y7Sh1F4b_FMDrwtlSBAEnR1riEikfg_Yu63SDUPRnY9bdI3QJ933aPJcL1t-D3yX7_nBA2IDau8Tag26nmLNSlM3yYmPROVEtxpDm26YVwESoIaS_kCzmVqzmAdqnCkLPloDdTeWaWkeRwmYmJkXmftSLj4ZqqkgtYWhTMeq6AhXUK53NVW_4oXEhVSH0cbLlxLRDX-dFSk8mdaaT4WoRNLurQuf9kInVNudrRv-a5cxUMjifN-sJHq9RZrbvVBnhInwdEWymw";

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

// libjwt hands the parsed token to a callback before it checks the signature,
// so the callback only records iat; it counts after jwt_checker_verify returns 0.
static int grab_iat(jwt_t *jwt, jwt_config_t *cfg) {
  jwt_value_t v;
  jwt_set_GET_INT(&v, "iat");
  if (jwt_claim_get(jwt, &v) != JWT_VALUE_ERR_NONE) return 1;
  *(uint32_t *)cfg->ctx = (uint32_t)v.int_val;
  return 0;
}

static void run(const char *op, const char *token, const char *key, size_t len, unsigned int flags, jwt_alg_t alg) {
  jwk_set_t *set = jwks_create_fromkey(key, len, flags);
  if (set == NULL || jwks_error_any(set)) { fprintf(stderr, "%s: key: %s\n", op, set ? jwks_error_msg(set) : "NULL"); exit(1); }
  jwt_checker_t *c = jwt_checker_new();
  uint32_t iat = 0, s = 0;
  if (jwt_checker_setkey(c, alg, jwks_item_get(set, 0)) || jwt_checker_setcb(c, grab_iat, &iat)) {
    fprintf(stderr, "%s: %s\n", op, jwt_checker_error_msg(c)); exit(1);
  }
  double t0 = now_ms();
  for (int i = 0; i < N; i++) {
    if (jwt_checker_verify(c, token)) { fprintf(stderr, "%s: %s\n", op, jwt_checker_error_msg(c)); exit(1); }
    s += iat;
  }
  printf("%s\t%.3f\t%u\n", op, now_ms() - t0, s);
  jwt_checker_free(c);
  jwks_free(set);
}

int main(void) {
  run("hs256", HS256, SECRET, strlen(SECRET), JWK_KEY_TRY_HMAC, JWT_ALG_HS256);
  run("rs256", RS256, PEM, strlen(PEM), JWK_KEY_NONE, JWT_ALG_RS256);
  return 0;
}
