#!/usr/bin/env bash
# Publish the named packages (default: all) as bend-kit-<pkg>@<VERSION>.
# A version already on the hub is skipped if its files match, and fails if
# they differ: the hub rejects a republish, so the change needs a new VERSION.
# With --check, publish nothing.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/verdict.sh

hub=${BEND_HUB:-https://hub.bend-lang.com}
check=false
[ "${1:-}" = --check ] && { check=true; shift; }
[ $# -eq 0 ] && set -- $(scripts/packages.sh)
fail=0
for d in "$@"; do
  entry=$d.bend
  if [ -f "$d/publish.bend" ]; then
    entry=publish.bend
    IFS= read -r description < "$d/$d.bend"
    IFS= read -r publish_description < "$d/$entry"
    if [ "$description" != "$publish_description" ]; then
      echo "$d/publish.bend must keep the first line of $d/$d.bend" >&2
      fail=1
      continue
    fi
    verdict "$d/$entry" ""
  fi
  named=bend-kit-$d@$(<"$d/VERSION")
  if hash=$(curl -fs "$hub/name/$named"); then
    metadata=$(curl -fs "$hub/package/$hash.json")
    if ! jq -e --arg entry "$entry" --arg rooted "$d/$entry" '.files | has($entry) or has($rooted)' <<<"$metadata" >/dev/null; then
      echo "$named is on the hub without $entry: raise $d/VERSION"
      fail=1
      continue
    fi
    files=$(jq -r '.files | keys[]' <<<"$metadata")
    for key in $files; do
      # A package published from the repo root stores archive/archive.bend, not archive.bend.
      file=$d/$key
      [ -f "$file" ] || file=$key
      if [ ! -f "$file" ] || ! curl -fs "$hub/$hash/$key" | cmp -s - "$file"; then
        echo "$named is on the hub, but $key differs: raise $d/VERSION"
        fail=1
        continue 2
      fi
    done
    echo "== $named is on the hub"
  elif $check; then
    echo "== $named will publish"
  else
    echo "== publish $named"
    # --publish takes only a LICENSE beside a published file, so copy the root one in.
    cp LICENSE "$d/LICENSE"
    (cd "$d" && bend "$entry" --publish "$named")
    rm "$d/LICENSE"
  fi
done
exit $fail
