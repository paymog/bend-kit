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

cd "$here"
if [ "${1:-native}" = js ]; then
  bend ca_check.bend -o "$dir/ca_check.js"
else
  bend ca_check.bend -o "$dir/ca_check"
fi
openssl s_server -accept 39445 -cert "$dir/server.pem" -key "$dir/server.key" \
  -tls1_2 -quiet -naccept 4 >"$dir/server.log" 2>&1 &
server=$!
sleep 1
if [ "${1:-native}" = js ]; then
  bun "$dir/ca_check.js" "$dir/ca.pem"
else
  "$dir/ca_check" "$dir/ca.pem"
fi
