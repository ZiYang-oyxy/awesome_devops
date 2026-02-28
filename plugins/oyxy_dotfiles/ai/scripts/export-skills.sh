#!/bin/bash
set -euo pipefail

LOCK_FILE="${1:-$HOME/.agents/.skill-lock.json}"
OUT_FILE="${2:-skills-manifest.json}"

if [[ ! -f "$LOCK_FILE" ]]; then
    echo "Lock file not found: $LOCK_FILE" >&2
    exit 1
fi

node - "$LOCK_FILE" "$OUT_FILE" <<'NODE'
const fs = require('fs');

const lockFile = process.argv[2];
const outFile = process.argv[3];

const raw = fs.readFileSync(lockFile, 'utf8');
const lock = JSON.parse(raw);
const skills = lock.skills || {};

const manifest = {
  version: 1,
  generatedAt: new Date().toISOString(),
  sourceLockFile: lockFile,
  skills: Object.entries(skills)
    .map(([name, meta]) => ({ name, source: meta.source }))
    .filter((item) => item.name && item.source)
    .sort((a, b) => a.name.localeCompare(b.name))
};

fs.writeFileSync(outFile, JSON.stringify(manifest, null, 2) + '\n');
console.log(`Exported ${manifest.skills.length} skills to ${outFile}`);
NODE
