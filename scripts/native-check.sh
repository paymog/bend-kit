#!/usr/bin/env bash
# Compile and run check.bend, from the package folder, for packages that ship C
# effects; for webhooks: it links hairpin, http, and time from the hub, so its
# build fails if two versions of one C effect slip in (bendlang/bend#1533); and
# for commands: it drives SQLite through child processes; for f32array: it checks CPU fork-join; for bits: it checks streams past 512 MiB; for hash: it checks reference digests.
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
  [ ${#cs[@]} -eq 0 ] && [ "$d" != http ] && [ "$d" != webhooks ] && [ "$d" != commands ] && [ "$d" != f32array ] && [ "$d" != bits ] && [ "$d" != hash ] && continue
  [ -f "$d/check.bend" ] || { echo "$d has C effects but no check.bend" >&2; exit 1; }
  echo "== native $d"
  out=$(mktemp -d)
  (
    cd "$d"
    checks=(check)
    # Separate emission units bound compilation: https://github.com/bendlang/bend/issues/2093
    [ "$d" != webhooks ] || checks=(signature_check delivery_check)
    for check in "${checks[@]}"; do
      bend "$check.bend" -o "$out/$check"
      if [ "$d" = f32array ]; then
        "$out/$check" +RTS --threads 8
      else
        "$out/$check"
      fi
    done
    if [ "$d" = bits ]; then
      bend large-check.bend -o "$out/large-check"
      "$out/large-check" 0
      "$out/large-check" 27
    fi
  )
  rm -rf "$out"
  out=
done
