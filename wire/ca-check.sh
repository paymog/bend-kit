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

cd "$here"
if [ "${WIRE_LOOPBACK_ONLY:-0}" = 1 ]; then
  python3 -B "$here/loopback-run-test.py" --policy
fi
if [ "${1:-native}" = js ]; then
  bend ca_check.bend -o "$dir/ca_check.js"
  bend check.bend -o "$dir/check.js"
else
  bend ca_check.bend -o "$dir/ca_check"
  bend check.bend -o "$dir/check"
fi
if [ "${WIRE_LOOPBACK_ONLY:-0}" = 1 ]; then
  if [ "${1:-native}" = js ]; then
    bend loopback_check.bend -o "$dir/loopback.js"
    python3 "$here/loopback-run.py" bun "$dir/loopback.js"
  else
    bend loopback_check.bend -o "$dir/loopback"
    python3 "$here/loopback-run.py" "$dir/loopback"
  fi
fi
python3 "$here/tls-server.py" "$dir/server.pem" "$dir/server.key" "$dir/ports" >"$dir/server.log" 2>&1 &
server=$!
i=0
while [ ! -s "$dir/ports" ]; do
  i=$((i + 1))
  [ "$i" -le 100 ] || { cat "$dir/server.log" >&2; exit 1; }
  sleep 0.1
done
read -r port <"$dir/ports"
if [ "${1:-native}" = js ]; then
  python3 "$here/loopback-run.py" bun "$dir/ca_check.js" "$dir/ca.pem" "$port"
else
  python3 "$here/loopback-run.py" "$dir/ca_check" "$dir/ca.pem" "$port"
fi

for protocols in h2,http/1.1 http/1.1 ''; do
  kill "$server"
  wait "$server" 2>/dev/null || :
  rm "$dir/ports"
  WIRE_TEST_ALPN="$protocols" python3 "$here/tls-server.py" \
    "$dir/server.pem" "$dir/server.key" "$dir/ports" >"$dir/server.log" 2>&1 &
  server=$!
  i=0
  while [ ! -s "$dir/ports" ]; do
    i=$((i + 1))
    [ "$i" -le 100 ] || { cat "$dir/server.log" >&2; exit 1; }
    sleep 0.1
  done
  read -r port <"$dir/ports"
  status=0
  if [ "${1:-native}" = js ]; then
    SSL_CERT_FILE="$dir/ca.pem" python3 "$here/loopback-run.py" bun "$dir/check.js" "$port" >"$dir/alpn.log" 2>&1 || status=$?
  else
    SSL_CERT_FILE="$dir/ca.pem" python3 "$here/loopback-run.py" "$dir/check" "$port" >"$dir/alpn.log" 2>&1 || status=$?
  fi
  cat "$dir/alpn.log"
  if [ "$protocols" = h2,http/1.1 ]; then
    [ "$status" -eq 0 ]
    grep -q '^ok localhost alpn$' "$dir/alpn.log"
  else
    [ "$status" -eq 1 ]
    grep -q '^localhost alpn gave ' "$dir/alpn.log"
  fi
done

python3 -B "$here/../scripts/rss-check.py" python3 -B "$here/tls-close-check.py" "${1:-native}"
