#!/bin/sh
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
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
openssl req -newkey rsa:2048 -nodes -subj '/CN=Bend client' \
  -addext 'extendedKeyUsage=clientAuth' \
  -keyout "$dir/client.key" -out "$dir/client.csr" >/dev/null 2>&1
openssl x509 -req -in "$dir/client.csr" -CA "$dir/ca.pem" -CAkey "$dir/ca.key" \
  -copy_extensions copy -days 1 -out "$dir/client.pem" >/dev/null 2>&1
openssl verify -x509_strict -CAfile "$dir/ca.pem" -purpose sslclient "$dir/client.pem"

cd "$here"
if [ "${1:-native}" = js ] || [ "${1:-native}" = linux ]; then
  bend check.bend -o "$dir/check.js"
else
  bend check.bend -o "$dir/check"
fi
if [ "${1:-native}" = linux ]; then
  docker run --rm -v "$dir:/w" -v "$here/tls-server.py:/w/server.py:ro" oven/bun:1 sh -c '
    set -eu
    apt-get -qq update >/dev/null && apt-get -qq install -y python3 libssl3 ca-certificates >/dev/null 2>&1
    python3 /w/server.py /w/server.pem /w/server.key /w/ports /w/ca.pem >/w/server.log 2>&1 &
    server=$!
    trap '\''kill "$server" 2>/dev/null || :'\'' EXIT INT TERM
    i=0
    while [ ! -s /w/ports ]; do
      i=$((i + 1))
      [ "$i" -le 100 ] || { cat /w/server.log >&2; exit 1; }
      sleep 0.1
    done
    read -r port </w/ports
    SSL_CERT_FILE=/w/ca.pem bun /w/check.js /w/client.pem /w/client.key "$port"
    kill "$server" 2>/dev/null || :
  '
  exit
fi
python3 "$here/tls-server.py" "$dir/server.pem" "$dir/server.key" "$dir/ports" "$dir/ca.pem" >"$dir/server.log" 2>&1 &
server=$!
i=0
while [ ! -s "$dir/ports" ]; do
  i=$((i + 1))
  [ "$i" -le 100 ] || { cat "$dir/server.log" >&2; exit 1; }
  sleep 0.1
done
read -r port <"$dir/ports"
if [ "${1:-native}" = js ]; then
  SSL_CERT_FILE="$dir/ca.pem" python3 "$here/loopback-run.py" bun "$dir/check.js" "$dir/client.pem" "$dir/client.key" "$port"
else
  SSL_CERT_FILE="$dir/ca.pem" python3 "$here/loopback-run.py" "$dir/check" "$dir/client.pem" "$dir/client.key" "$port"
fi
