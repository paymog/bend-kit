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

openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=Bend test CA' \
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

for name in one two; do
  openssl req -newkey rsa:2048 -nodes -subj "/CN=client-$name" \
    -addext 'extendedKeyUsage=clientAuth' \
    -keyout "$dir/$name.key" -out "$dir/$name.csr" >/dev/null 2>&1
  openssl x509 -req -in "$dir/$name.csr" -CA "$dir/ca.pem" -CAkey "$dir/ca.key" \
    -copy_extensions copy -days 1 -out "$dir/$name.pem" >/dev/null 2>&1
  openssl verify -x509_strict -CAfile "$dir/ca.pem" -purpose sslclient "$dir/$name.pem"
done

cd "$here"
# Separate emission units avoid Bend's host-stack limit: https://github.com/bendlang/bend/issues/2093
for check in check mtls_check h2_pool_check; do
  if [ "${1:-native}" = js ]; then
    bend "$check.bend" -o "$dir/$check.js"
  else
    bend "$check.bend" -o "$dir/$check"
  fi
done
python3 mtls-server.py "$dir/ca.pem" "$dir/server.pem" "$dir/server.key" "$dir/ports" >"$dir/server.log" 2>&1 &
server=$!
i=0
while [ ! -s "$dir/ports" ]; do
  i=$((i + 1))
  [ "$i" -le 100 ] || { cat "$dir/server.log" >&2; exit 1; }
  sleep 0.1
done
read -r port _ h2port streamport <"$dir/ports"
python3 mtls-server-check.py "$dir/ca.pem" "$dir/one.pem" "$dir/one.key" "$port"
if [ "${1:-native}" = js ]; then
  SSL_CERT_FILE="$dir/ca.pem" bun "$dir/check.js"
  SSL_CERT_FILE="$dir/ca.pem" bun "$dir/mtls_check.js" "$dir/one.pem" "$dir/one.key" "$dir/two.pem" "$dir/two.key" "https://localhost:$port"
  SSL_CERT_FILE="$dir/ca.pem" bun "$dir/h2_pool_check.js" "https://localhost:$h2port" "https://localhost:$streamport"
else
  SSL_CERT_FILE="$dir/ca.pem" "$dir/check"
  SSL_CERT_FILE="$dir/ca.pem" "$dir/mtls_check" "$dir/one.pem" "$dir/one.key" "$dir/two.pem" "$dir/two.key" "https://localhost:$port"
  SSL_CERT_FILE="$dir/ca.pem" "$dir/h2_pool_check" "https://localhost:$h2port" "https://localhost:$streamport"
fi
[ "$(wc -l <"$dir/ports.streams" | tr -d ' ')" = 1 ] || {
  echo "expected all HTTP/2 streams on one connection" >&2
  exit 1
}
[ -s "$dir/ports.cancelled" ] || { echo "expected RST_STREAM(CANCEL)" >&2; exit 1; }
