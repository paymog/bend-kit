// SigV4 signing benchmark in C with aws-c-auth, the AWS Common Runtime signer (see README.md).
#include <aws/auth/auth.h>
#include <aws/auth/credentials.h>
#include <aws/auth/signable.h>
#include <aws/auth/signing.h>
#include <aws/auth/signing_config.h>
#include <aws/auth/signing_result.h>
#include <aws/http/request_response.h>
#include <aws/io/stream.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#define N 10000

static char sig[128];

// With credentials in the config (no provider), aws_sign_request_aws signs before it returns.
static void done(struct aws_signing_result *result, int error_code, void *ud) {
  struct aws_string *s = NULL;
  if (error_code || aws_signing_result_get_property(result, g_aws_signature_property_name, &s) || !s) {
    snprintf(sig, sizeof sig, "failed %d", error_code);
    return;
  }
  snprintf(sig, sizeof sig, "%s", aws_string_c_str(s));
}

static double now_ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}

int main(void) {
  struct aws_allocator *a = aws_default_allocator();
  aws_auth_library_init(a);
  struct aws_credentials *creds = aws_credentials_new(a, aws_byte_cursor_from_c_str("AKIAIOSFODNN7EXAMPLE"),
    aws_byte_cursor_from_c_str("wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"), (struct aws_byte_cursor){0}, UINT64_MAX);
  // S3's settings, as the CRT S3 client uses: sign x-amz-content-sha256, encode the path once, no dot-segment normalization.
  struct aws_signing_config_aws cfg = {
    .config_type = AWS_SIGNING_CONFIG_AWS,
    .algorithm = AWS_SIGNING_ALGORITHM_V4,
    .signature_type = AWS_ST_HTTP_REQUEST_HEADERS,
    .region = aws_byte_cursor_from_c_str("us-east-1"),
    .service = aws_byte_cursor_from_c_str("s3"),
    .flags = {.use_double_uri_encode = false, .should_normalize_uri_path = false},
    .signed_body_header = AWS_SBHT_X_AMZ_CONTENT_SHA256,
    .credentials = creds,
  };
  aws_date_time_init_epoch_secs(&cfg.date, 1369353600); // 20130524T000000Z
  struct aws_byte_cursor body = aws_byte_cursor_from_c_str("Welcome to Amazon S3.");
  struct aws_http_header host = {.name = aws_byte_cursor_from_c_str("host"), .value = aws_byte_cursor_from_c_str("examplebucket.s3.amazonaws.com")};

  double t0 = now_ms();
  for (int i = 0; i < N; i++) {
    struct aws_http_message *req = aws_http_message_new_request(a);
    aws_http_message_set_request_method(req, aws_byte_cursor_from_c_str("PUT"));
    aws_http_message_set_request_path(req, aws_byte_cursor_from_c_str("/test.txt?x-id=PutObject"));
    aws_http_message_add_header(req, host);
    struct aws_input_stream *stream = aws_input_stream_new_from_cursor(a, &body);
    aws_http_message_set_body_stream(req, stream);
    struct aws_signable *signable = aws_signable_new_http_request(a, req);
    aws_sign_request_aws(a, signable, (struct aws_signing_config_base *)&cfg, done, NULL);
    aws_signable_destroy(signable);
    aws_input_stream_release(stream);
    aws_http_message_release(req);
  }
  double t1 = now_ms();
  printf("sign\t%.3f\t%s\n", t1 - t0, sig);

  aws_credentials_release(creds);
  aws_auth_library_clean_up();
  return 0;
}
