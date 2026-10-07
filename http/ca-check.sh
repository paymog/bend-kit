#!/bin/sh
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
dir=$(mktemp -d)
server=
cleanup() {
  if [ -n "$server" ]; then kill "$server" 2>/dev/null || :; wait "$server" 2>/dev/null || :; fi
  rm -rf "$dir"
}
trap cleanup EXIT INT TERM

openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=Bend private CA' \
  -addext 'basicConstraints=critical,CA:TRUE' \
  -keyout "$dir/ca.key" -out "$dir/ca.pem" >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -subj '/CN=localhost' \
  -addext 'subjectAltName=DNS:localhost' -addext 'extendedKeyUsage=serverAuth' \
  -keyout "$dir/server.key" -out "$dir/server.csr" >/dev/null 2>&1
openssl x509 -req -in "$dir/server.csr" -CA "$dir/ca.pem" -CAkey "$dir/ca.key" \
  -CAcreateserial -copy_extensions copy -days 1 -out "$dir/server.pem" >/dev/null 2>&1

cat >"$dir/server.py" <<'PY'
import ssl, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
cert, key = sys.argv[1:3]
class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def do_GET(self):
        if self.path == "/go":
            body, status, loc = b"", 302, "/ok"
        else:
            body, status, loc = b"ok", 200, None
        self.send_response(status)
        if loc:
            self.send_header("Location", loc)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, fmt, *args):
        pass
s = ThreadingHTTPServer(("127.0.0.1", 39446), H)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.minimum_version = ctx.maximum_version = ssl.TLSVersion.TLSv1_2
ctx.load_cert_chain(cert, key)
s.socket = ctx.wrap_socket(s.socket, server_side=True)
s.serve_forever()
PY

cd "$here"
if [ "${1:-native}" = js ]; then
  bend ca_check.bend -o "$dir/ca_check.js"
else
  bend ca_check.bend -o "$dir/ca_check"
fi
python3 "$dir/server.py" "$dir/server.pem" "$dir/server.key" >"$dir/server.log" 2>&1 &
server=$!
sleep 1
if [ "${1:-native}" = js ]; then
  bun "$dir/ca_check.js" "$dir/ca.pem"
else
  "$dir/ca_check" "$dir/ca.pem"
fi
