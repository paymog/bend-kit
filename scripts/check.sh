#!/usr/bin/env bash
# Type-check, prove, and run check.bend for the named packages (default: all).
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/verdict.sh

[ $# -eq 0 ] && set -- $(scripts/packages.sh)
for d in "$@"; do
  echo "== $d"
  [ "$d" != camber ] || python3 camber/deploy/metadata_check.py
  [ "$d" != runner ] || python3 runner/migrate-test.py
  [ "$d" != http ] || python3 -B http/mtls-check-test.py
  (
    cd "$d"
    if [ "$d" = hairpin ]; then
      bend pure.bend --check-only
    else
      verdict "$d.bend" ""
    fi
    if [ -f PROOF.bend ]; then
      if [ "$d" = http ] || [ "$d" = hairpin ] || [ "$d" = storage ]; then
        bend PROOF.bend --check-only
      else
        verdict PROOF.bend '^LAWS[.]'
      fi
    fi
    [ ! -f check.bend ] || bend check.bend
    if [ "$d" = storage ]; then
      out=$(mktemp -d)
      trap 'rm -rf "$out"' EXIT
      bend http_origin.bend -o "$out/origin.js"
      python3 http_origin_check.py bun "$out/origin.js"
      bend local_check.bend -o "$out/local.js"
      python3 local_check.py bun "$out/local.js"
    fi
  )
done
