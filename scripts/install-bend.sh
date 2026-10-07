#!/usr/bin/env bash
# Install the pinned Bend for CI (linux-x64) into ~/.bend. Bump VER and SHA together.
set -euo pipefail
VER=2.0.35
SHA=63039d1a119f716767ac5a7d8fe0717cfacf219c6c253c35192148e0dade722f
name="bend-$VER-linux-x64.tar.gz"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL -o "$tmp/$name" \
  "https://github.com/bendlang/bend/releases/download/v$VER/$name"
echo "$SHA  $tmp/$name" | sha256sum -c -
tar -xzf "$tmp/$name" -C "$tmp"
mkdir -p ~/.bend/bin
rm -rf ~/.bend/bend2 ~/.bend/guide
mv "$tmp/bend/bend2" "$tmp/bend/guide" ~/.bend/
mv -f "$tmp/bend/bin/bend" ~/.bend/bin/bend
~/.bend/bin/bend version
