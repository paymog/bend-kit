#include <nghttp2/nghttp2.h>
#include <stdint.h>
#include <stdio.h>

int main(void) {
  static const uint8_t block[] = "\x82\x86\x84\x41\x0f" "www.example.com";
  const size_t length = sizeof(block) - 1;
  nghttp2_hd_inflater *decoder;
  uint32_t checksum = 0;
  if (nghttp2_hd_inflate_new(&decoder) != 0) return 1;

  for (int i = 0; i < 1000; i++) {
    size_t offset = 0;
    for (;;) {
      nghttp2_nv field;
      int flags = 0;
      nghttp2_ssize consumed = nghttp2_hd_inflate_hd3(decoder, &field, &flags,
                                                         block + offset, length - offset, 1);
      if (consumed < 0) return 2;
      offset += (size_t)consumed;
      if (flags & NGHTTP2_HD_INFLATE_EMIT) {
        for (size_t j = 0; j < field.namelen; j++) checksum += field.name[j];
        for (size_t j = 0; j < field.valuelen; j++) checksum += field.value[j];
      }
      if (flags & NGHTTP2_HD_INFLATE_FINAL) break;
      if (consumed == 0 && !(flags & NGHTTP2_HD_INFLATE_EMIT)) return 3;
    }
    if (offset != length || nghttp2_hd_inflate_end_headers(decoder) != 0) return 4;
  }

  nghttp2_hd_inflate_del(decoder);
  printf("%u\n", checksum);
  return 0;
}
