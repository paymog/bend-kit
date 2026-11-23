#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
work=$(mktemp -d)
server=
cleanup() {
  if [ -n "$server" ]; then
    kill "$server" 2>/dev/null || true
    wait "$server" 2>/dev/null || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT
bend version
python3 -B ../scripts/rss-check.py bend demo.bend -o "$work/demo"
"$work/demo" > "$work/demo.log" 2>&1 &
server=$!
curl -s --retry 20 --retry-connrefused --retry-delay 1 -o /dev/null http://127.0.0.1:18080/
test "$(curl -s --data-binary @../README.md http://127.0.0.1:18080/hi)" = /hi
test "$(curl --http1.1 -sv -o /dev/null -o /dev/null http://127.0.0.1:18080/one http://127.0.0.1:18080/two 2>&1 | grep -cE 'Re-?using existing (http: )?connection')" = 1
python3 -B - <<'PY'
import socket

with socket.create_connection(("127.0.0.1", 18080), timeout=5) as sock:
    sock.sendall(b"GET /old HTTP/1.0\r\n\r\n")
    data = bytearray()
    while chunk := sock.recv(65536):
        data.extend(chunk)
    assert data.partition(b"\r\n\r\n")[2] == b"/old", data
PY
curl -s -o /dev/null -w '%{http_code}' -H 'Transfer-Encoding: gzip' -d x http://127.0.0.1:18080/ | grep -qx 400
curl -s -o /dev/null -w '%{http_code}' -H "X-A: $(head -c 70000 /dev/zero | tr '\0' a)" http://127.0.0.1:18080/ | grep -qx 431
python3 -B reject_check.py
kill "$server"
wait "$server" 2>/dev/null || true
server=
echo 'serving smoke passed'
python3 -B ../scripts/rss-check.py bend stream_demo.bend -o "$work/stream_demo"
python3 -B stream_check.py "$work/stream_demo"
python3 -B ../scripts/rss-check.py bend write_demo.bend -o "$work/write_demo"
python3 -B write_check.py "$work/write_demo"
