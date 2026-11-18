#!/usr/bin/env bash
# Ownership-loss check for run.bounded, native and JS: with SIGCHLD ignored the
# kernel reaps children itself, so run.bounded must fail with ECHILD, start
# nothing and signal nothing. Run from the repo root or anywhere; needs bend,
# bun, and perl (to start the program with SIGCHLD ignored).
set -euo pipefail
cd "$(dirname "$0")"
out=$(mktemp -d)
trap 'rm -rf "$out" .process-ownership-marker' EXIT
rm -f .process-ownership-marker
ignore() { perl -e '$SIG{CHLD} = "IGNORE"; exec @ARGV or die "exec: $!"' "$@"; }

echo "== native process ownership"
bend ownership.bend -o "$out/ownership"
ignore "$out/ownership"
[ ! -e .process-ownership-marker ] || { echo "native: the command ran" >&2; exit 1; }

if command -v bun >/dev/null; then
  echo "== js process ownership"
  bend ownership.bend -o "$out/ownership.js"
  ignore bun "$out/ownership.js"
  [ ! -e .process-ownership-marker ] || { echo "js: the command ran" >&2; exit 1; }
fi
