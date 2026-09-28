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
openssl req -newkey rsa:2048 -nodes -subj '/CN=Bend client' \
  -addext 'extendedKeyUsage=clientAuth' \
  -keyout "$dir/client.key" -out "$dir/client.csr" >/dev/null 2>&1
openssl x509 -req -in "$dir/client.csr" -CA "$dir/ca.pem" -CAkey "$dir/ca.key" \
  -copy_extensions copy -days 1 -out "$dir/client.pem" >/dev/null 2>&1

cd "$here"
if [ "${1:-native}" = js ] || [ "${1:-native}" = linux ]; then
  bend check.bend -o "$dir/check.js"
else
  bend check.bend -o "$dir/check"
fi
if [ "${1:-native}" = linux ]; then
  docker run --rm -v "$dir:/w" oven/bun:1 sh -c '
    apt-get -qq update >/dev/null && apt-get -qq install -y openssl libssl3 ca-certificates >/dev/null 2>&1
    openssl s_server -accept 39444 -cert /w/server.pem -key /w/server.key \
      -CAfile /w/ca.pem -Verify 1 -tls1_2 -quiet -naccept 3 >/w/server.log 2>&1 &
    server=$!
    sleep 1
    SSL_CERT_FILE=/w/ca.pem bun /w/check.js /w/client.pem /w/client.key
    status=$?
    kill "$server" 2>/dev/null || :
    exit "$status"
  '
  exit
fi
openssl s_server -accept 39444 -cert "$dir/server.pem" -key "$dir/server.key" \
  -CAfile "$dir/ca.pem" -Verify 1 -tls1_2 -quiet -naccept 3 >"$dir/server.log" 2>&1 &
server=$!
sleep 1
if [ "${1:-native}" = js ]; then
  SSL_CERT_FILE="$dir/ca.pem" bun "$dir/check.js" "$dir/client.pem" "$dir/client.key"
else
  SSL_CERT_FILE="$dir/ca.pem" "$dir/check" "$dir/client.pem" "$dir/client.key"
fi
