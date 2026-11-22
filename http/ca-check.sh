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
import os, select, socket, ssl, sys, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
cert, key, ports_path = sys.argv[1:4]
class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def do_GET(self):
        if self.path in ("/tunnel-pool", "/tunnel-stream"):
            if self.headers.get("Proxy-Authorization") is not None:
                self.send_error(400)
                return
            self.send_response(200)
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            route = b"pooled" if self.path == "/tunnel-pool" else b"streamed"
            for piece in (b"tunnel ", route, b" response complete"):
                self.wfile.write(f"{len(piece):x}\r\n".encode() + piece + b"\r\n")
                self.wfile.flush()
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()
            return
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
    def do_POST(self):
        body = bytearray()
        while True:
            line = self.rfile.readline()
            if not line:
                raise ConnectionError("upload ended before the final chunk")
            n = int(line.split(b";")[0], 16)
            piece = self.rfile.read(n)
            if len(piece) != n or self.rfile.read(2) != b"\r\n":
                raise ValueError("invalid upload chunk")
            body.extend(piece)
            if n == 0:
                break
        if self.path == "/tunnel":
            valid = (
                body == b"first\r\nsecond last"
                and self.headers.get("Transfer-Encoding") == "chunked"
                and self.headers.get("Proxy-Authorization") is None
            )
            reply = b"tunnel upload verified" if valid else b"invalid tunnel upload"
            status = 200 if valid else 400
        else:
            reply, status = b"ok", 200
        self.send_response(status)
        self.send_header("Content-Length", str(len(reply)))
        self.end_headers()
        self.wfile.write(reply)
    def log_message(self, fmt, *args):
        pass
s = ThreadingHTTPServer(("127.0.0.1", 0), H)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.minimum_version = ctx.maximum_version = ssl.TLSVersion.TLSv1_2
ctx.load_cert_chain(cert, key)
s.socket = ctx.wrap_socket(s.socket, server_side=True)
class Proxy(BaseHTTPRequestHandler):
    def do_CONNECT(self):
        if (
            self.path != f"localhost:{s.server_port}"
            or self.headers.get("Host") != self.path
            or self.headers.get("Proxy-Authorization") != "Basic dTpw"
        ):
            self.send_error(400)
            return
        with socket.create_connection(("127.0.0.1", s.server_port), timeout=5) as origin:
            self.connection.settimeout(5)
            with open(ports_path + ".connects", "a") as f:
                f.write("CONNECT\n")
            self.send_response(200, "Connection Established")
            self.end_headers()
            while True:
                ready, _, _ = select.select([self.connection, origin], [], [], 5)
                if not ready:
                    raise TimeoutError("CONNECT relay stalled")
                for source in ready:
                    data = source.recv(65536)
                    if not data:
                        return
                    target = origin if source is self.connection else self.connection
                    target.sendall(data)
    def log_message(self, fmt, *args):
        pass
proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
threading.Thread(target=proxy.serve_forever, daemon=True).start()
with open(ports_path + ".tmp", "w") as f:
    f.write(f"{s.server_port} {proxy.server_port}\n")
os.replace(ports_path + ".tmp", ports_path)
s.serve_forever()
PY

cd "$here"
if [ "${1:-native}" = js ]; then
  bend ca_check.bend -o "$dir/ca_check.js"
else
  bend ca_check.bend -o "$dir/ca_check"
fi
python3 "$dir/server.py" "$dir/server.pem" "$dir/server.key" "$dir/ports" >"$dir/server.log" 2>&1 &
server=$!
i=0
while [ ! -s "$dir/ports" ]; do
  i=$((i + 1))
  [ "$i" -le 100 ] || { cat "$dir/server.log" >&2; exit 1; }
  sleep 0.1
done
read -r port proxy_port <"$dir/ports"
if [ "${1:-native}" = js ]; then
  bun "$dir/ca_check.js" "$dir/ca.pem" "https://localhost:$port" "$port" "http://u:p@127.0.0.1:$proxy_port"
else
  "$dir/ca_check" "$dir/ca.pem" "https://localhost:$port" "$port" "http://u:p@127.0.0.1:$proxy_port"
fi
[ "$(wc -l <"$dir/ports.connects" | tr -d ' ')" = 3 ] || {
  echo "expected upload, pooled fetch, and response stream CONNECT tunnels" >&2
  exit 1
}
