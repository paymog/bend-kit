#!/usr/bin/env bash
# Compile and run check.bend for packages that ship C effects.
# One package at a time: do not fan this out.
set -euo pipefail
cd "$(dirname "$0")/.."

[ $# -eq 0 ] && set -- $(scripts/packages.sh)
out=
cleanup() { if [ -n "${out:-}" ]; then rm -rf "$out"; fi; }
trap cleanup EXIT
shopt -s nullglob
for d in "$@"; do
  cs=("$d"/effs/*.c)
  [ ${#cs[@]} -eq 0 ] && continue
  [ -f "$d/check.bend" ] || { echo "$d has C effects but no check.bend" >&2; exit 1; }
  echo "== native $d"
  out=$(mktemp -d)
  (
    cd "$d"
    bend check.bend -o "$out/check"
  )
  "$out/check"
  rm -rf "$out"
  out=
done
