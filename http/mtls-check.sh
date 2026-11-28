#!/bin/sh
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
dir=$(mktemp -d)
server=
phase="certificate fixtures"
step() {
  phase=$1
  printf '== mTLS %s: %s\n' "$lane" "$phase"
}
cleanup() {
  status=$?
  if [ -n "$server" ]; then kill "$server" 2>/dev/null || :; wait "$server" 2>/dev/null || :; fi
  if [ "$status" -ne 0 ]; then
    printf 'mTLS failed during %s (exit %s)\n' "$phase" "$status" >&2
    if [ -f "$dir/server.log" ]; then
      echo 'mTLS server diagnostics:' >&2
      cat "$dir/server.log" >&2
    fi
  fi
  rm -rf "$dir"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
lane=${1:-native}
step "certificate fixtures"

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
  step "compile $check ($lane)"
  if [ "${1:-native}" = js ]; then
    bend "$check.bend" -o "$dir/$check.js"
  else
    bend "$check.bend" -o "$dir/$check"
  fi
done
step "server startup"
python3 -u mtls-server.py "$dir/ca.pem" "$dir/server.pem" "$dir/server.key" "$dir/ports" >"$dir/server.log" 2>&1 &
server=$!
i=0
while [ ! -s "$dir/ports" ]; do
  kill -0 "$server" 2>/dev/null || { wait "$server" || exit $?; exit 1; }
  i=$((i + 1))
  [ "$i" -le 100 ] || { echo "timed out waiting for server ports" >&2; exit 1; }
  sleep 0.1
done
read -r port _ h2port streamport <"$dir/ports"
step "server upload assertion"
python3 mtls-server-check.py "$dir/ca.pem" "$dir/one.pem" "$dir/one.key" "$port"
if [ "${1:-native}" = js ]; then
  step "run check (js)"
  SSL_CERT_FILE="$dir/ca.pem" python3 "$here/../wire/loopback-run.py" bun "$dir/check.js"
  step "run mtls_check (js)"
  SSL_CERT_FILE="$dir/ca.pem" python3 "$here/../wire/loopback-run.py" bun "$dir/mtls_check.js" "$dir/one.pem" "$dir/one.key" "$dir/two.pem" "$dir/two.key" "https://localhost:$port"
  step "run h2_pool_check (js)"
  SSL_CERT_FILE="$dir/ca.pem" python3 "$here/../wire/loopback-run.py" bun "$dir/h2_pool_check.js" "https://localhost:$h2port" "https://localhost:$streamport"
else
  step "run check (native)"
  SSL_CERT_FILE="$dir/ca.pem" python3 "$here/../wire/loopback-run.py" "$dir/check"
  step "run mtls_check (native)"
  SSL_CERT_FILE="$dir/ca.pem" python3 "$here/../wire/loopback-run.py" "$dir/mtls_check" "$dir/one.pem" "$dir/one.key" "$dir/two.pem" "$dir/two.key" "https://localhost:$port"
  step "run h2_pool_check (native)"
  SSL_CERT_FILE="$dir/ca.pem" python3 "$here/../wire/loopback-run.py" "$dir/h2_pool_check" "https://localhost:$h2port" "https://localhost:$streamport"
fi
step "HTTP/2 server assertions"
[ "$(wc -l <"$dir/ports.streams" | tr -d ' ')" = 1 ] || {
  echo "expected all HTTP/2 streams on one connection" >&2
  exit 1
}
[ -s "$dir/ports.cancelled" ] || { echo "expected RST_STREAM(CANCEL)" >&2; exit 1; }
[ -s "$dir/ports.credit" ] || { cat "$dir/server.log" >&2; echo "expected consumption-driven receive credit" >&2; exit 1; }
