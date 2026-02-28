#!/usr/bin/env bash
set -euo pipefail

CACHE_FILE="/tmp/tmux-tracker-cache.json"
CACHE_MAX_AGE=1

# Check if cache is fresh enough
if [[ -f "$CACHE_FILE" ]]; then
  if [[ "$OSTYPE" == darwin* ]]; then
    file_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
  else
    file_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
  fi
  if (( file_age < CACHE_MAX_AGE )); then
    exit 0
  fi
fi

# Simple lock using mkdir (atomic on all systems)
LOCK_DIR="/tmp/tmux-tracker-cache.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

if [[ ! -f "$CACHE_FILE" ]]; then
  printf '{"tasks":[]}\n' > "$CACHE_FILE.tmp"
  mv "$CACHE_FILE.tmp" "$CACHE_FILE"
  exit 0
fi

state=$(cat "$CACHE_FILE" 2>/dev/null || true)
if [[ -z "$state" ]]; then
  printf '{"tasks":[]}\n' > "$CACHE_FILE.tmp"
  mv "$CACHE_FILE.tmp" "$CACHE_FILE"
  exit 0
fi

now_ts=$(date +%s)
active_client_panes=$(tmux list-clients -F '#{pane_id}' 2>/dev/null | awk 'NF{print}' | tr '\n' '\t' || true)
# Prune completed+acknowledged rows for panes that no longer exist.
all_panes=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null | tr '\n' '\t' || true)
echo "$state" | jq --arg all_panes "$all_panes" --arg active_client_panes "$active_client_panes" --argjson now "$now_ts" '
  .tasks = (
    (.tasks // [])
    | map(
        . as $task |
        if (
          $task.status == "completed" and
          $task.acknowledged != true and
          ($active_client_panes | contains(($task.pane_id // "") + "\t"))
        ) then
          .acknowledged = true | .updated_at = $now
        else
          .
        end
      )
    | map(. as $task
        | select(
          (
            $task.status == "completed" and
            $task.acknowledged == true and
            ($task.pane_id // "") != "" and
            ($all_panes | contains(($task.pane_id // "") + "\t") | not)
          ) | not
        )
      )
  )
' > "$CACHE_FILE.tmp" 2>/dev/null && mv "$CACHE_FILE.tmp" "$CACHE_FILE" || true
