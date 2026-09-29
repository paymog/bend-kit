// BigInt benchmark: the C side, with OpenSSL BIGNUM (see README.md).
#include <openssl/bn.h>
#include <openssl/crypto.h>
#include <stdio.h>
#include <time.h>

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

int main(void) {
  const char *M = "170141183460469231731687303715884105727";
  const char *X = "123456789012345678901234567890123456789";
  const char *A = "98765432109876543210987654321098765432";
  const int n = 64;
  BN_CTX *ctx = BN_CTX_new();
  BIGNUM *m = NULL, *x = NULL, *a = NULL, *acc = BN_new(), *y = BN_new(), *q = BN_new();

  double t0 = now_ms();
  if (!BN_dec2bn(&m, M) || !BN_dec2bn(&x, X) || !BN_dec2bn(&a, A)) return 1;
  if (!BN_copy(acc, x)) return 1;
  for (int i = 0; i < n; i++) {
    BN_mul(y, x, x, ctx);
    BN_add(y, y, a);
    BN_div(q, x, y, m, ctx);
    BN_add(acc, acc, x);
  }
  char *chk = BN_bn2dec(acc);
  printf("modsq\t%.3f\t%s\n", now_ms() - t0, chk);

  OPENSSL_free(chk);
  BN_free(m), BN_free(x), BN_free(a), BN_free(acc), BN_free(y), BN_free(q);
  BN_CTX_free(ctx);
  return 0;
}
