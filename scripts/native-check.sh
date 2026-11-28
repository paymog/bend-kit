#!/usr/bin/env bash
# Compile and run check.bend, from the package folder, for packages that ship C
# effects; for webhooks: it links hairpin, http, and time from the hub, so its
# build fails if two versions of one C effect slip in (bendlang/bend#1533); and
# for commands: it drives SQLite through child processes; for f32array: it checks CPU fork-join; for bits: it checks streams past 512 MiB; for hash: it checks reference digests; for runner: it checks journal recovery.
# WebSocket checks Wire and libcrypto effects from sibling packages.
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
  [ ${#cs[@]} -eq 0 ] && [ "$d" != http ] && [ "$d" != webhooks ] && [ "$d" != commands ] && [ "$d" != f32array ] && [ "$d" != bits ] && [ "$d" != hash ] && [ "$d" != runner ] && [ "$d" != websocket ] && continue
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
    if [ "$d" = storage ]; then
      bend http_origin.bend -o "$out/origin"
      python3 http_origin_check.py "$out/origin"
      bend local_check.bend -o "$out/local"
      python3 local_check.py "$out/local"
    fi
    if [ "$d" = sqlite ]; then
      awk '/^typedef struct \{ u32 id; void\* ptr; \} SqliteSlot;/{on=1} /^static Term sqlite_unit/{on=0} on' effs/sqlite.c > "$out/sqlite_reg.h"
      cc -Wall -Wextra -Werror -O2 -I"$out" registry_check.c -o "$out/registry_check"
      "$out/registry_check"
    fi
  )
  rm -rf "$out"
  out=
done
