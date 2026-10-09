#!/usr/bin/env bash
# Install a Bend release (linux-x64) for CI.
# The default pin type-checks. C effects call the two-argument io_eff of
# Bend 2.0.36, so native checks pass --native and a prefix. Bump a pin
# and its SHA together.
set -euo pipefail
VER=2.0.35
SHA=63039d1a119f716767ac5a7d8fe0717cfacf219c6c253c35192148e0dade722f
if [ "${1:-}" = --native ]; then
  VER=2.0.36
  SHA=02089dc0eed0fd5fd6d73c74cc9cffcb2c6638dd3b02ae83f7b8cc57fbe381ba
  shift
fi
dest=${1:-$HOME/.bend}
name="bend-$VER-linux-x64.tar.gz"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL -o "$tmp/$name" \
  "https://github.com/bendlang/bend/releases/download/v$VER/$name"
echo "$SHA  $tmp/$name" | sha256sum -c -
tar -xzf "$tmp/$name" -C "$tmp"
mkdir -p "$dest/bin"
rm -rf "$dest/bend2" "$dest/guide"
mv "$tmp/bend/bend2" "$tmp/bend/guide" "$dest/"
mv -f "$tmp/bend/bin/bend" "$dest/bin/bend"
"$dest/bin/bend" version
