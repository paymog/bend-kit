#!/usr/bin/env bash
# Install the pinned Bend for CI (linux-x64 or darwin-arm64). Optional prefix, else ~/.bend.
# Bump VER and both checksums together.
set -euo pipefail
VER=2.0.38
case "$(uname -sm)" in
  "Linux x86_64") platform=linux-x64; SHA=f19d088b079c9e1a8834ecd153b7d58c11a5f8f9ab1bdb78dbc96a6bf49aaa81; verify=(sha256sum -c) ;;
  "Darwin arm64") platform=darwin-arm64; SHA=9d5331d01e82dac40dd012953e78221f533f7df7ad7e16b07f1f7bd0dcd088dd; verify=(shasum -a 256 -c) ;;
  *) echo "unsupported Bend CI platform: $(uname -sm)" >&2; exit 1 ;;
esac
dest=${1:-$HOME/.bend}
name="bend-$VER-$platform.tar.gz"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL -o "$tmp/$name" \
  "https://github.com/bendlang/bend/releases/download/v$VER/$name"
echo "$SHA  $tmp/$name" | "${verify[@]}" -
tar -xzf "$tmp/$name" -C "$tmp"
mkdir -p "$dest/bin"
rm -rf "$dest/bend2" "$dest/guide"
mv "$tmp/bend/bend2" "$tmp/bend/guide" "$dest/"
mv -f "$tmp/bend/bin/bend" "$dest/bin/bend"
"$dest/bin/bend" version
