#!/usr/bin/env bash
# Type-check, prove, and run check.bend for the named packages (default: all).
set -euo pipefail
cd "$(dirname "$0")/.."

# Bend fails any check that imports @unsafe or foreign code. Accept that when
# no def matching $2 relies on it: the file type-checks and its laws hold.
verdict() {
  local out
  if out=$(bend "$1" --check-only 2>&1); then echo "$out"; return; fi
  echo "$out"
  printf '%s\n' "$out" | awk -v bad="$2" '
    NR == 1 { ok = $0 == "SOME PROOFS FAIL"; next }
    NR == 2 { ok = ok && /^Error: [0-9]+ defs? rel(y|ies) on unsafe or foreign code:$/; next }
    !/^- / || (bad != "" && $2 ~ bad) { ok = 0 }
    END { exit !ok }'
}

[ $# -eq 0 ] && set -- $(scripts/packages.sh)
for d in "$@"; do
  echo "== $d"
  (
    cd "$d"
    verdict "$d.bend" ""
    [ ! -f PROOF.bend ] || verdict PROOF.bend '^LAWS[.]'
    [ ! -f check.bend ] || bend check.bend
  )
done
