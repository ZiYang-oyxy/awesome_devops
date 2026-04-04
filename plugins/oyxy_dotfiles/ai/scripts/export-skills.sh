#!/bin/bash
set -euo pipefail

LOCK_FILE="${1:-$HOME/.agents/.skill-lock.json}"
OUT_FILE="${2:-skills-manifest.json}"
SKILLS_DIR="${3:-}"

if [[ ! -f "$LOCK_FILE" ]]; then
    echo "Lock file not found: $LOCK_FILE" >&2
    exit 1
fi

node - "$LOCK_FILE" "$OUT_FILE" "$SKILLS_DIR" <<'NODE'
const fs = require('fs');
const path = require('path');

const lockFile = process.argv[2];
const outFile = process.argv[3];
const skillsDirArg = process.argv[4];

const raw = fs.readFileSync(lockFile, 'utf8');
const lock = JSON.parse(raw);
const skills = lock.skills || {};
const skillsDir = skillsDirArg || path.join(path.dirname(lockFile), 'skills');

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

if (!fs.existsSync(skillsDir) || !fs.statSync(skillsDir).isDirectory()) {
  process.stderr.write(`Warning: skills directory not found, skip disk scan: ${skillsDir}\n`);
  process.exit(0);
}

const lockNames = new Set(Object.keys(skills));
const diskSkills = fs.readdirSync(skillsDir, { withFileTypes: true })
  .filter((entry) => entry.isDirectory() && !entry.name.startsWith('.'))
  .map((entry) => entry.name)
  .filter((name) => fs.existsSync(path.join(skillsDir, name, 'SKILL.md')))
  .sort((a, b) => a.localeCompare(b));

const missingFromLock = diskSkills.filter((name) => !lockNames.has(name));
if (missingFromLock.length > 0) {
  process.stderr.write(
    `Warning: ${missingFromLock.length} disk skill(s) missing from lock file ${lockFile}: ` +
    `${missingFromLock.join(', ')}\n`
  );
}
NODE
