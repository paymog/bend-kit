#!/usr/bin/env bash
# Build the static site. Usage: site/build.sh [OUT] [BASE_URL]
set -euo pipefail
cd "$(dirname "$0")/.."

out=${1:-site/dist}
base=${2:-https://bend-kit.paymahn.workers.dev}

rm -rf "$out"
mkdir -p "$out" site/out
bend site/build.bend -o site/out/build
# shellcheck disable=SC2046
site/out/build . "$out" "$base" $(scripts/packages.sh)
bend site/playground/index.html -o "$out/playground"
cp site/style.css "$out/style.css"
touch "$out/.nojekyll"
python3 site/check.py "$out" "$base"
