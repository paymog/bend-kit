#include <nghttp2/nghttp2.h>
#include <stdint.h>
#include <stdio.h>

static int received(nghttp2_session *session, const nghttp2_frame *frame,
                    void *user_data) {
  uint32_t *sum = user_data;
  if (frame->hd.type == NGHTTP2_PING) {
    const uint8_t *p = frame->ping.opaque_data;
    uint32_t left = ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
                    ((uint32_t)p[2] << 8) | p[3];
    uint32_t right = ((uint32_t)p[4] << 24) | ((uint32_t)p[5] << 16) |
                     ((uint32_t)p[6] << 8) | p[7];
    *sum += left + right;
  }
  return 0;
}

int main(void) {
  const uint8_t settings[] = {0, 0, 0, 4, 0, 0, 0, 0, 0};
  const uint8_t ping[] = {0, 0, 8, 6, 1, 0, 0, 0, 0,
                          '1', '2', '3', '4', '5', '6', '7', '8'};
  nghttp2_session_callbacks *callbacks = NULL;
  nghttp2_session *session = NULL;
  uint32_t sum = 0;
  if (nghttp2_session_callbacks_new(&callbacks) != 0)
    return 1;
  nghttp2_session_callbacks_set_on_frame_recv_callback(callbacks, received);
  if (nghttp2_session_client_new(&session, callbacks, &sum) != 0)
    return 1;
  if (nghttp2_session_mem_recv2(session, settings, sizeof(settings)) !=
      sizeof(settings))
    return 1;
  for (int i = 0; i < 10000; ++i) {
    if (nghttp2_session_mem_recv2(session, ping, sizeof(ping)) != sizeof(ping))
      return 1;
  }
  printf("%u\n", sum);
  nghttp2_session_del(session);
  nghttp2_session_callbacks_del(callbacks);
  return 0;
}
