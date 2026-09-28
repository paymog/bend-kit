#!/usr/bin/env bash
# JWKS fetch and cache (jwks-check.bend) against python3's http.server on 127.0.0.1:8751. Run by hand.
set -euo pipefail
cd "$(dirname "$0")"
dir=$(mktemp -d)
printf '%s' '{"keys":[{"kty":"EC","kid":"a","use":"sig","alg":"ES256","crv":"P-256","x":"9t4qvevWR0PT1imu1uWzhhizqL-f17oeR51ogdKVOvE","y":"Hsxqs-vJ8ToY8rAiKGM0CSwqIfonuZ09cBkIsVN-DjI"}]}' > "$dir/a.json"
printf '%s' '{"keys":[{"kty":"EC","kid":"a","use":"sig","alg":"ES256","crv":"P-256","x":"9t4qvevWR0PT1imu1uWzhhizqL-f17oeR51ogdKVOvE","y":"Hsxqs-vJ8ToY8rAiKGM0CSwqIfonuZ09cBkIsVN-DjI"},{"kty":"EC","kid":"b","crv":"P-256","x":"DPVbrM615Y_NH0r57p302uvEdqx-dSvLWSUKsJyJsmU","y":"WTPpv8TRi7RhA6LRoq2yqQy_E9Cm8qNABrBkiWAbqE0"}]}' > "$dir/b.json"
python3 -m http.server 8751 --bind 127.0.0.1 --directory "$dir" 2> "$dir/log" &
pid=$!
trap 'kill $pid; rm -r "$dir"' EXIT
for _ in $(seq 50); do curl -s -o /dev/null http://127.0.0.1:8751/ && break; sleep 0.1; done
JWKS_DIR="$dir" bend jwks-check.bend
