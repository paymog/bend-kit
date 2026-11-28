#!/usr/bin/env bash
# Install the pinned Bend for CI (linux-x64 or darwin-arm64). Optional prefix, else ~/.bend.
# Bump VER and both checksums together.
set -euo pipefail
VER=2.0.40
case "$(uname -sm)" in
  "Linux x86_64") platform=linux-x64; SHA=c9ff8d67bd903fb6ad9a26b43d8a62c01021de82a44d55ce4a3dcd4732113d6b; verify=(sha256sum -c) ;;
  "Darwin arm64") platform=darwin-arm64; SHA=b2be003b041eb6cfc65326be18f79eb2e0bae2189be79a18c507e661b4b6900b; verify=(shasum -a 256 -c) ;;
  *) echo "unsupported Bend CI platform: $(uname -sm)" >&2; exit 1 ;;
esac
dest=${1:-$HOME/.bend}
name="bend-$VER-$platform.tar.gz"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
url="https://github.com/bendlang/bend/releases/download/v$VER/$name"
for attempt in 1 2 3; do
  request=$url
  if [ "$attempt" -gt 1 ]; then
    request="$url?bend-ci=$(date +%s)-$$-$attempt"
  fi
  if curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL \
    --connect-timeout 15 --max-time 120 --dump-header "$tmp/headers" \
    --output "$tmp/$name" "$request"; then
    break
  else
    status=$?
  fi
  echo "Bend $VER $platform download attempt $attempt/3 failed (curl $status)." >&2
  if [ -f "$tmp/headers" ]; then
    awk '{
      sub(/\r$/, "")
      key = tolower($1)
      if (key ~ /^http\// || key ~ /^(date|server|age|via|x-cache|x-github-request-id|retry-after|x-ratelimit-remaining|x-ratelimit-reset):$/) print
    }' "$tmp/headers" >&2
  fi
  if [ "$attempt" -eq 3 ]; then
    echo "Bend download failed after 3 attempts: $url" >&2
    exit "$status"
  fi
  rm -f "$tmp/$name" "$tmp/headers"
  sleep "$((attempt * 2))"
done
echo "$SHA  $tmp/$name" | "${verify[@]}" -
tar -xzf "$tmp/$name" -C "$tmp"
mkdir -p "$dest/bin"
rm -rf "$dest/bend2" "$dest/guide"
mv "$tmp/bend/bend2" "$tmp/bend/guide" "$dest/"
mv -f "$tmp/bend/bin/bend" "$dest/bin/bend"
"$dest/bin/bend" version
