#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/scripts" "$fixture/demo"
cp scripts/pins.sh "$fixture/scripts/pins.sh"
printf '#!/usr/bin/env bash\nprintf "demo\\n"\n' > "$fixture/scripts/packages.sh"
chmod +x "$fixture/scripts/packages.sh"
printf '1.2.3.4\n' > "$fixture/demo/VERSION"
: > "$fixture/scripts/pins.allow"
printf 'demo@1.2.3.4 and `bend-kit-demo@1.2.3.4`\n' > "$fixture/README.md"
printf 'import bend-kit-demo@1.2.3.4/demo.bend\n' > "$fixture/demo/README.md"
bash "$fixture/scripts/pins.sh" > "$fixture/output" 2>&1
for file in README.md demo/README.md; do
  for pin in demo@9.9.9.9 bend-kit-demo@9.9.9.9; do
    cp "$fixture/$file" "$fixture/saved"
    printf '\n%s\n' "$pin" >> "$fixture/$file"
    if bash "$fixture/scripts/pins.sh" HEAD other > "$fixture/output" 2>&1; then
      echo "accepted stale $pin in $file" >&2
      exit 1
    fi
    grep -qF "$file:" "$fixture/output"
    grep -qF "names $pin but demo/VERSION is 1.2.3.4" "$fixture/output"
    mv "$fixture/saved" "$fixture/$file"
  done
done
printf 'bend-kit-demo@9.9.9.9\n' > "$fixture/scripts/pins.allow"
printf 'import bend-kit-demo@9.9.9.9/demo.bend\n' > "$fixture/demo/demo.bend"
printf '\ndemo@9.9.9.9 and `bend-kit-demo@9.9.9.9`\n' >> "$fixture/README.md"
bash "$fixture/scripts/pins.sh" > "$fixture/output" 2>&1
printf '\nexternal-demo@9.9.9.9\n' >> "$fixture/demo/README.md"
bash "$fixture/scripts/pins.sh" > "$fixture/output" 2>&1
mkdir -p "$fixture/protobuf/bench" "$fixture/protobuf/evidence"
printf '#!/usr/bin/env bash\nprintf "demo\\nprotobuf\\n"\n' > "$fixture/scripts/packages.sh"
printf '0.1.0.0\n' > "$fixture/protobuf/VERSION"
printf '"bend-kit-demo@8.8.8.8/demo.bend"\n' > "$fixture/protobuf/evidence/old.py"
printf 'import bend-kit-demo@8.8.8.8/demo.bend\n' > "$fixture/protobuf/evidence/old.bend"
printf '"bend-kit-demo@8.8.8.8/demo.bend"\n' > "$fixture/protobuf/history.py"
for file in protobuf/generator.py protobuf/bench/run.py; do
  for template in 'imports = ["import bend-kit-demo@8.8.8.8/demo.bend as B"]' \
    "'import Base\\nimport bend-kit-demo@8.8.8.8/demo.bend as B\\n'" \
    'RUNTIME = "bend-kit-demo@8.8.8.8/demo.bend"'; do
    printf '%s\n' "$template" > "$fixture/$file"
    if bash "$fixture/scripts/pins.sh" HEAD protobuf > "$fixture/output" 2>&1; then
      echo "accepted stale generated import in $file" >&2
      exit 1
    fi
    grep -qF "$file:1: imports bend-kit-demo@8.8.8.8" "$fixture/output"
    printf 'bend-kit-demo@8.8.8.8\n' >> "$fixture/scripts/pins.allow"
    bash "$fixture/scripts/pins.sh" HEAD protobuf > "$fixture/output" 2>&1
    printf 'bend-kit-demo@9.9.9.9\n' > "$fixture/scripts/pins.allow"
    rm "$fixture/$file"
  done
done
printf '"import 0xabc/demo.bend"\n' > "$fixture/protobuf/generator.py"
if bash "$fixture/scripts/pins.sh" HEAD protobuf > "$fixture/output" 2>&1; then
  echo "accepted generated hash import" >&2
  exit 1
fi
grep -qF 'by hash; import the sibling by name' "$fixture/output"
echo 'README pin checks pass'
