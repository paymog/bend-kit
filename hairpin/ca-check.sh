#!/bin/sh
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
dir=$(mktemp -d)
server=
cleanup() {
  if [ -n "$server" ]; then kill "$server" 2>/dev/null || :; wait "$server" 2>/dev/null || :; fi
  rm -rf "$dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=Bend private CA' \
  -addext 'basicConstraints=critical,CA:TRUE' \
  -addext 'keyUsage=critical,keyCertSign,cRLSign' \
  -keyout "$dir/ca.key" -out "$dir/ca.pem" >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -subj '/CN=localhost' \
  -addext 'subjectAltName=DNS:localhost' -addext 'extendedKeyUsage=serverAuth' \
  -keyout "$dir/server.key" -out "$dir/server.csr" >/dev/null 2>&1
openssl x509 -req -in "$dir/server.csr" -CA "$dir/ca.pem" -CAkey "$dir/ca.key" \
  -CAcreateserial -copy_extensions copy -days 1 -out "$dir/server.pem" >/dev/null 2>&1
openssl verify -x509_strict -CAfile "$dir/ca.pem" -purpose sslserver \
  -verify_hostname localhost "$dir/server.pem"

cat >"$dir/server.py" <<'PY'
import os, ssl, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
cert, key, ports_path = sys.argv[1:4]
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
s = ThreadingHTTPServer(("127.0.0.1", 0), H)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.minimum_version = ctx.maximum_version = ssl.TLSVersion.TLSv1_2
ctx.load_cert_chain(cert, key)
s.socket = ctx.wrap_socket(s.socket, server_side=True)
with open(ports_path + ".tmp", "w") as f:
    f.write(f"{s.server_port}\n")
os.replace(ports_path + ".tmp", ports_path)
s.serve_forever()
PY

cd "$here"
# Separate emission units bound compilation: https://github.com/bendlang/bend/issues/2093
for check in ca_check ca_stream_check; do
  if [ "${1:-native}" = js ]; then
    bend "$check.bend" -o "$dir/$check.js"
  else
    bend "$check.bend" -o "$dir/$check"
  fi
done
if [ "${WIRE_LOOPBACK_ONLY:-0}" = 1 ]; then
  if [ "${1:-native}" = js ]; then
    bend ../wire/loopback_check.bend -o "$dir/loopback.js"
    python3 "$here/../wire/loopback-run.py" bun "$dir/loopback.js"
  else
    bend ../wire/loopback_check.bend -o "$dir/loopback"
    python3 "$here/../wire/loopback-run.py" "$dir/loopback"
  fi
fi
python3 "$dir/server.py" "$dir/server.pem" "$dir/server.key" "$dir/ports" >"$dir/server.log" 2>&1 &
server=$!
i=0
while [ ! -s "$dir/ports" ]; do
  i=$((i + 1))
  [ "$i" -le 100 ] || { cat "$dir/server.log" >&2; exit 1; }
  sleep 0.1
done
read -r port <"$dir/ports"
for check in ca_check ca_stream_check; do
  if [ "${1:-native}" = js ]; then
    python3 "$here/../wire/loopback-run.py" bun "$dir/$check.js" "$dir/ca.pem" "https://localhost:$port/"
  else
    python3 "$here/../wire/loopback-run.py" "$dir/$check" "$dir/ca.pem" "https://localhost:$port/"
  fi
done
