#!/usr/bin/env bash
# Install the pinned Bend for CI (linux-x64). Optional prefix, else ~/.bend.
# Bump VER and SHA together.
set -euo pipefail
VER=2.0.36
SHA=02089dc0eed0fd5fd6d73c74cc9cffcb2c6638dd3b02ae83f7b8cc57fbe381ba
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
