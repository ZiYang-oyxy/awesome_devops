#!/bin/bash
set -euo pipefail

MANIFEST_FILE="${1:-skills-manifest.json}"

if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "Manifest not found: $MANIFEST_FILE" >&2
    exit 1
fi

mapfile -t LINES < <(node - "$MANIFEST_FILE" <<'NODE'
const fs = require('fs');

const manifestFile = process.argv[2];
const raw = fs.readFileSync(manifestFile, 'utf8');
const manifest = JSON.parse(raw);

const skills = Array.isArray(manifest.skills) ? manifest.skills : [];
for (const item of skills) {
  if (!item || !item.name || !item.source) continue;
  process.stdout.write(`${item.name}\t${item.source}\n`);
}
NODE
)

if [[ ${#LINES[@]} -eq 0 ]]; then
    echo "No skills found in manifest: $MANIFEST_FILE" >&2
    exit 1
fi

echo "Installing ${#LINES[@]} skills from $MANIFEST_FILE"

for line in "${LINES[@]}"; do
    skill_name="${line%%$'\t'*}"
    skill_source="${line#*$'\t'}"

    echo "-> $skill_name ($skill_source)"
    npx -y skills add "$skill_source" -g -s "$skill_name" -y

done

echo "Done"
