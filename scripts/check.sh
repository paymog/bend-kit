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
  (
    cd "$d"
    verdict "$d.bend" ""
    if [ -f PROOF.bend ]; then
      if [ "$d" = http ]; then
        bend PROOF.bend --check-only
      else
        verdict PROOF.bend '^LAWS[.]'
      fi
    fi
    [ ! -f check.bend ] || bend check.bend
  )
done
