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
  -keyout "$dir/ca.key" -out "$dir/ca.pem" >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -subj '/CN=localhost' \
  -addext 'subjectAltName=DNS:localhost' -addext 'extendedKeyUsage=serverAuth' \
  -keyout "$dir/server.key" -out "$dir/server.csr" >/dev/null 2>&1
openssl x509 -req -in "$dir/server.csr" -CA "$dir/ca.pem" -CAkey "$dir/ca.key" \
  -CAcreateserial -copy_extensions copy -days 1 -out "$dir/server.pem" >/dev/null 2>&1

for name in one two; do
  openssl req -newkey rsa:2048 -nodes -subj "/CN=client-$name" \
    -addext 'extendedKeyUsage=clientAuth' \
    -keyout "$dir/$name.key" -out "$dir/$name.csr" >/dev/null 2>&1
  openssl x509 -req -in "$dir/$name.csr" -CA "$dir/ca.pem" -CAkey "$dir/ca.key" \
    -copy_extensions copy -days 1 -out "$dir/$name.pem" >/dev/null 2>&1
done

cd "$here"
if [ "${1:-native}" = js ]; then
  bend check.bend -o "$dir/check.js"
else
  bend check.bend -o "$dir/check"
fi
python3 mtls-server.py "$dir/ca.pem" "$dir/server.pem" "$dir/server.key" >"$dir/server.log" 2>&1 &
server=$!
sleep 1
if [ "${1:-native}" = js ]; then
  SSL_CERT_FILE="$dir/ca.pem" bun "$dir/check.js" "$dir/one.pem" "$dir/one.key" "$dir/two.pem" "$dir/two.key"
else
  SSL_CERT_FILE="$dir/ca.pem" "$dir/check" "$dir/one.pem" "$dir/one.key" "$dir/two.pem" "$dir/two.key"
fi
