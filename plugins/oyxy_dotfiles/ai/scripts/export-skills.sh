#!/bin/bash
set -euo pipefail

LOCK_FILE="${1:-$HOME/.agents/.skill-lock.json}"
OUT_FILE="${2:-skills-manifest.json}"
SKILLS_DIR="${3:-}"
DELETE_MISSING_SELECTION="${EXPORT_SKILLS_DELETE_MISSING:-}"
DELETE_NOT_LINKED_SELECTION="${EXPORT_SKILLS_DELETE_NOT_LINKED:-}"

if [[ ! -f "$LOCK_FILE" ]]; then
    echo "Lock file not found: $LOCK_FILE" >&2
    exit 1
fi

node - "$LOCK_FILE" "$OUT_FILE" "$SKILLS_DIR" "$DELETE_MISSING_SELECTION" "$DELETE_NOT_LINKED_SELECTION" <<'NODE'
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const readline = require('readline');

const lockFile = process.argv[2];
const outFile = process.argv[3];
const skillsDirArg = process.argv[4];
const deleteMissingSelectionArg = process.argv[5];
const deleteNotLinkedSelectionArg = process.argv[6];

const skillsDir = skillsDirArg || path.join(path.dirname(lockFile), 'skills');
let lock = JSON.parse(fs.readFileSync(lockFile, 'utf8'));
let skills = lock.skills || {};

function writeManifest(currentSkills) {
  const manifest = {
    version: 1,
    generatedAt: new Date().toISOString(),
    sourceLockFile: lockFile,
    skills: Object.entries(currentSkills)
      .map(([name, meta]) => ({ name, source: meta.source }))
      .filter((item) => item.name && item.source)
      .sort((a, b) => a.name.localeCompare(b.name))
  };

  fs.writeFileSync(outFile, JSON.stringify(manifest, null, 2) + '\n');
  console.log(`Exported ${manifest.skills.length} skills to ${outFile}`);
}

function parseSelection(input, missingSkills) {
  const trimmed = (input || '').trim();
  if (!trimmed || trimmed.toLowerCase() === 'none') return [];
  if (trimmed.toLowerCase() === 'all') return [...missingSkills];

  const tokens = trimmed.split(',').map((item) => item.trim()).filter(Boolean);
  if (tokens.length === 0) return [];

  const selected = new Set();
  for (const token of tokens) {
    if (/^\d+$/.test(token)) {
      const index = Number(token);
      if (index < 1 || index > missingSkills.length) {
        throw new Error(`Invalid selection index: ${token}`);
      }
      selected.add(missingSkills[index - 1]);
      continue;
    }

    if (!missingSkills.includes(token)) {
      throw new Error(`Invalid selection name: ${token}`);
    }
    selected.add(token);
  }

  return missingSkills.filter((name) => selected.has(name));
}

function prompt(question) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stderr
  });

  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

async function resolveSelection(candidates, selectionArg, description, envName) {
  if (selectionArg) {
    return parseSelection(selectionArg, candidates);
  }

  if (!process.stdin.isTTY) {
    process.stderr.write(
      `Warning: non-interactive input detected, skip deleting ${description}. ` +
      `Set ${envName}=all|none|1,3 to control this behavior.\n`
    );
    return [];
  }

  process.stderr.write(
    `Select ${description} to delete: enter "all", "none", a comma-separated list of ` +
    'indexes like "1,3", or exact skill names.\n'
  );
  const answer = await prompt('Delete selection: ');
  return parseSelection(answer, candidates);
}

function stripAnsi(text) {
  return text.replace(/\x1B\[[0-?]*[ -/]*[@-~]/g, '');
}

function findNotLinkedGlobalSkills() {
  let output;
  try {
    output = execFileSync('npx', ['skills', 'list', '-g'], {
      encoding: 'utf8',
      env: {
        ...process.env,
        FORCE_COLOR: '0',
        NO_COLOR: '1'
      },
      stdio: ['ignore', 'pipe', 'pipe']
    });
  } catch (error) {
    const message = error.stderr ? String(error.stderr).trim() : error.message;
    process.stderr.write(`Warning: failed to list global skills, skip not-linked scan: ${message}\n`);
    return [];
  }

  const notLinked = [];
  let currentSkill = null;
  for (const line of stripAnsi(output).split(/\r?\n/)) {
    const skillMatch = line.match(/^\s{2}([^\s]+)\s+(.+)$/);
    if (skillMatch) {
      currentSkill = skillMatch[1];
      continue;
    }

    if (currentSkill && /^\s*Agents:\s*not linked\s*$/.test(line)) {
      notLinked.push(currentSkill);
      currentSkill = null;
    }
  }

  return [...new Set(notLinked)].sort((a, b) => a.localeCompare(b));
}

function reloadLock() {
  lock = JSON.parse(fs.readFileSync(lockFile, 'utf8'));
  skills = lock.skills || {};
}

function removeGlobalSkills(selected) {
  if (selected.length === 0) return;

  execFileSync('npx', ['skills', 'remove', '-g', '-y', ...selected], {
    encoding: 'utf8',
    env: process.env,
    stdio: ['ignore', 'pipe', 'pipe']
  });

  selected.forEach((name) => {
    delete skills[name];
  });

  if (fs.existsSync(lockFile)) {
    reloadLock();
  }
}

if (!fs.existsSync(skillsDir) || !fs.statSync(skillsDir).isDirectory()) {
  process.stderr.write(`Warning: skills directory not found, skip disk scan: ${skillsDir}\n`);
  writeManifest(skills);
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

const missingInDisk = Object.keys(skills)
  .filter((name) => !diskSkills.includes(name))
  .sort((a, b) => a.localeCompare(b));

async function main() {
  if (missingInDisk.length > 0) {
    process.stderr.write(
      `Warning: ${missingInDisk.length} skill(s) missing on disk but present in lock file ${lockFile}:\n`
    );
    missingInDisk.forEach((name, index) => {
      process.stderr.write(`  ${index + 1}. ${name}\n`);
    });

    const selected = await resolveSelection(
      missingInDisk,
      deleteMissingSelectionArg,
      'stale lock skills',
      'EXPORT_SKILLS_DELETE_MISSING'
    );
    if (selected.length > 0) {
      selected.forEach((name) => {
        delete skills[name];
      });
      fs.writeFileSync(lockFile, JSON.stringify(lock, null, 2) + '\n');
      process.stderr.write(
        `Removed ${selected.length} stale skill(s) from lock file: ${selected.join(', ')}\n`
      );
    } else {
      process.stderr.write('No stale lock skills removed.\n');
    }
  }

  const notLinkedGlobalSkills = findNotLinkedGlobalSkills();
  if (notLinkedGlobalSkills.length > 0) {
    process.stderr.write(
      `Warning: ${notLinkedGlobalSkills.length} global skill(s) are not linked to any agent:\n`
    );
    notLinkedGlobalSkills.forEach((name, index) => {
      process.stderr.write(`  ${index + 1}. ${name}\n`);
    });

    const selected = await resolveSelection(
      notLinkedGlobalSkills,
      deleteNotLinkedSelectionArg,
      'not-linked global skills',
      'EXPORT_SKILLS_DELETE_NOT_LINKED'
    );
    if (selected.length > 0) {
      removeGlobalSkills(selected);
      process.stderr.write(
        `Removed ${selected.length} not-linked global skill(s): ${selected.join(', ')}\n`
      );
    } else {
      process.stderr.write('No not-linked global skills removed.\n');
    }
  }

  writeManifest(skills);
}

main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exit(1);
});
NODE
