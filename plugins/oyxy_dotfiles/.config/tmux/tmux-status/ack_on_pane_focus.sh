#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:-}"
window_id="${2:-}"
session_id="${3:-}"

[[ -z "$pane_id" ]] && exit 0

# Some tmux hooks provide empty session/window formats; resolve from pane id.
if [[ -z "$session_id" || -z "$window_id" ]]; then
  meta=$(tmux display-message -p -t "$pane_id" '#{session_id}	#{window_id}' 2>/dev/null || true)
  if [[ -n "$meta" ]]; then
    resolved_sid="${meta%%	*}"
    resolved_wid="${meta#*	}"
    [[ -z "$session_id" ]] && session_id="$resolved_sid"
    [[ -z "$window_id" ]] && window_id="$resolved_wid"
  fi
fi

CACHE_FILE="${TMUX_TRACKER_CACHE_FILE:-/tmp/tmux-tracker-cache.json}"
LOCK_DIR="/tmp/tmux-tracker-cache.lock"
[[ ! -f "$CACHE_FILE" ]] && exit 0

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

state=$(cat "$CACHE_FILE" 2>/dev/null || true)
[[ -z "$state" ]] && exit 0

now_ts=$(date +%s)
all_panes=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null | tr '\n' '\t' || true)

echo "$state" | jq \
  --arg sid "$session_id" \
  --arg wid "$window_id" \
  --arg pid "$pane_id" \
  --arg all_panes "$all_panes" \
  --argjson now "$now_ts" '
  .tasks = (
    (.tasks // [])
    | map(
        if (
          (.pane_id // "") == $pid and
          (
            ($sid != "" and $wid != "" and (.window_id // "") == $wid and (.session_id // "") == $sid) or
            ($sid == "" or $wid == "")
          )
        ) then
          .acknowledged = true | .updated_at = $now
        else
          .
        end
      )
    | map(
        . as $task
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
' > "$CACHE_FILE.tmp"
mv "$CACHE_FILE.tmp" "$CACHE_FILE"

tmux refresh-client -S 2>/dev/null || true
