# Keep-alive server for streams.bend: each GET gets a 64-byte body with Content-Length.
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BODY = bytes(i % 251 for i in range(64))
# One write per response, so Nagle never holds the body back.
RESPONSE = b"HTTP/1.1 200 OK\r\nContent-Length: 64\r\n\r\n" + BODY


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        self.wfile.write(RESPONSE)

    def log_message(self, *args):
        pass


port = int(sys.argv[1]) if len(sys.argv) > 1 else 18095
ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
