#!/usr/bin/env bash
# Fail when a package imports a sibling at a version other than the sibling's
# VERSION at REF, or imports a sibling by hash. scripts/pins.allow lists the
# exceptions, one import target (bend-kit-<pkg>@<version> or 0x<hash>) per line;
# a line that no import in the kit uses fails too. Root and package README.md
# pins must name the package's VERSION in the working tree, unless allowed.
# When a VERSION differs from REF, print the importers of the old version: they
# re-pin after the publish. An evidence/ folder holds recorded artifacts, which
# keep the pins they ran with, so the scan skips it.
# Usage: scripts/pins.sh [REF [pkg...]]. REF defaults to HEAD, packages to all.
set -euo pipefail
cd "$(dirname "$0")/.."

ref=${1:-HEAD}
[ $# -gt 0 ] && shift
all=$(scripts/packages.sh)
[ $# -eq 0 ] && set -- $all
imports() { grep -rnE --include='*.bend' --exclude-dir=evidence '^[[:space:]]*import[[:space:]]+(bend-kit-|0x)' "$@" || true; }
targets() { sed -E 's/^[^:]*:[0-9]+:[[:space:]]*import[[:space:]]+([^/[:space:]]+).*/\1/' | sort -u; }
allow=$(sed 's/#.*//' scripts/pins.allow | awk 'NF { print $1 }')
hits=$(imports "$@")
every=$(imports $all)
bad=0
for target in $(targets <<<"$hits"); do
  grep -qxF "$target" <<<"$allow" && continue
  case $target in
    0x*) why="by hash; import the sibling by name" ;;
    *)
      name=${target%@*}
      name=${name#bend-kit-}
      want=$(git show "$ref:$name/VERSION" 2>/dev/null) || want=missing
      [ "${target#*@}" = "$want" ] && continue
      why="but $name/VERSION at $ref is $want"
      ;;
  esac
  grep -F "import $target/" <<<"$hits" | cut -d: -f1,2 | sed "s|\$|: imports $target $why|" >&2
  bad=1
done
used=$(targets <<<"$every")
for target in $allow; do
  grep -qxF "$target" <<<"$used" && continue
  echo "scripts/pins.allow: no import uses $target; remove the line" >&2
  bad=1
done
readmes=(README.md)
for d in $all; do
  [ ! -f "$d/README.md" ] || readmes+=("$d/README.md")
done
while IFS=: read -r file line target; do
  name=${target%@*}
  name=${name#bend-kit-}
  grep -qxF "$name" <<<"$all" || continue
  ver=${target#*@}
  grep -qxF "bend-kit-$name@$ver" <<<"$allow" && continue
  want=$(<"$name/VERSION")
  [ "$ver" = "$want" ] && continue
  echo "$file:$line: names $target but $name/VERSION is $want" >&2
  bad=1
done < <(grep -HnoE '[a-z0-9-]+@[0-9]+(\.[0-9]+)*' "${readmes[@]}" || true)
for d in $all; do
  old=$(git show "$ref:$d/VERSION" 2>/dev/null) || continue
  new=$(<"$d/VERSION")
  [ "$old" = "$new" ] && continue
  left=$(grep -F "import bend-kit-$d@$old/" <<<"$every" | cut -d: -f1 | sort -u || true)
  [ -n "$left" ] || continue
  echo "$d rises $old -> $new; re-pin after it publishes:"
  sed 's/^/  /' <<<"$left"
done
exit $bad
