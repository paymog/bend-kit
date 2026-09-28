// 1000 sequential GETs on one libcurl easy handle, which keeps its connection alive.
#include <curl/curl.h>
#include <stdint.h>
#include <stdio.h>
#include <time.h>

static size_t count(char *p, size_t size, size_t n, void *acc) {
  *(size_t *)acc += size * n;
  return size * n;
}

int main(void) {
  curl_global_init(CURL_GLOBAL_DEFAULT);
  CURL *c = curl_easy_init();
  struct curl_slist *h = curl_slist_append(NULL, "x-bench: 1");
  CURLU *u = curl_url();
  curl_url_set(u, CURLUPART_URL, "http://127.0.0.1:47840/api/", 0);
  curl_url_set(u, CURLUPART_URL, "item", 0);
  char *url;
  curl_url_get(u, CURLUPART_URL, &url, 0);
  size_t len = 0;
  curl_easy_setopt(c, CURLOPT_URL, url);
  curl_easy_setopt(c, CURLOPT_HTTPHEADER, h);
  curl_easy_setopt(c, CURLOPT_WRITEFUNCTION, count);
  curl_easy_setopt(c, CURLOPT_WRITEDATA, &len);
  uint32_t sum = 0;
  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);
  for (int i = 0; i < 1000; i++) {
    len = 0;
    long status = 0;
    if (curl_easy_perform(c) == CURLE_OK) {
      curl_easy_getinfo(c, CURLINFO_RESPONSE_CODE, &status);
      sum += (uint32_t)status + (uint32_t)len;
    }
  }
  clock_gettime(CLOCK_MONOTONIC, &t1);
  double ms = (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6;
  printf("get_1000\t%.3f\t%u\n", ms, sum);
  curl_free(url);
  curl_url_cleanup(u);
  curl_slist_free_all(h);
  curl_easy_cleanup(c);
  curl_global_cleanup();
  return 0;
}
