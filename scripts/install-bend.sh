#!/usr/bin/env bash
# Install the pinned Bend for CI (linux-x64) into ~/.bend. Bump VER and SHA together.
set -euo pipefail
VER=2.0.31
SHA=f7dbecc8ef5991fe15d9953b8b33911bc62a120c735e2e5902aa031e22055bad
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
