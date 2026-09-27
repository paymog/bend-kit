#!/usr/bin/env bash
# Publish the named packages (default: all) as bend-kit-<pkg>@<VERSION>.
# A version already on the hub is skipped if its files match, and fails if
# they differ: the hub rejects a republish, so the change needs a new VERSION.
# With --check, publish nothing.
set -euo pipefail
cd "$(dirname "$0")/.."

hub=${BEND_HUB:-https://hub.bend-lang.com}
check=false
[ "${1:-}" = --check ] && { check=true; shift; }
[ $# -eq 0 ] && set -- $(scripts/packages.sh)
fail=0
for d in "$@"; do
  named=bend-kit-$d@$(<"$d/VERSION")
  if hash=$(curl -fs "$hub/name/$named"); then
    files=$(curl -fs "$hub/package/$hash.json" | jq -r '.files | keys[]')
    for f in $files; do
      f=$d/$f
      if ! curl -fs "$hub/$hash/${f#"$d/"}" | cmp -s - "$f"; then
        echo "$named is on the hub, but $f differs: raise $d/VERSION"
        fail=1
        continue 2
      fi
    done
    echo "== $named is on the hub"
  elif $check; then
    echo "== $named will publish"
  else
    echo "== publish $named"
    (cd "$d" && bend "$d.bend" --publish "$named")
  fi
done
exit $fail
