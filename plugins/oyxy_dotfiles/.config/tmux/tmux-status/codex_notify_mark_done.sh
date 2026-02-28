#!/usr/bin/env bash
set -euo pipefail

CACHE_FILE="${TMUX_TRACKER_CACHE_FILE:-/tmp/tmux-tracker-cache.json}"
LOCK_DIR="/tmp/tmux-tracker-cache.lock"

# Legacy notify appends the JSON payload as the last argument.
payload="${@: -1}"
payload_cwd=""
if [[ -n "$payload" ]]; then
  payload_cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)
fi

pane_id="${TMUX_PANE:-}"

# Fallback: when TMUX_PANE is missing, infer pane by cwd first.
if [[ -z "$pane_id" ]]; then
  if [[ -n "$payload_cwd" ]]; then
    pane_id=$(tmux list-panes -a -F '#{pane_id}	#{pane_current_path}	#{pane_active}' 2>/dev/null \
      | awk -F '\t' -v cwd="$payload_cwd" '$2==cwd && $3=="1"{print $1; exit}')
    if [[ -z "$pane_id" ]]; then
      pane_id=$(tmux list-panes -a -F '#{pane_id}	#{pane_current_path}' 2>/dev/null \
        | awk -F '\t' -v cwd="$payload_cwd" '$2==cwd{print $1; exit}')
    fi
  fi
fi

if [[ -z "$pane_id" ]]; then
  pane_id=$(tmux list-panes -a -F '#{pane_id}	#{pane_active}' 2>/dev/null \
    | awk -F '\t' '$2=="1"{print $1; exit}')
fi

if [[ -z "$pane_id" ]]; then
  pane_id=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null | head -n1)
fi

[[ -z "$pane_id" ]] && exit 0

meta=$(tmux display-message -p -t "$pane_id" '#{session_id}	#{window_id}	#{pane_id}' 2>/dev/null || true)
[[ -z "$meta" ]] && exit 0
IFS=$'\t' read -r session_id window_id pane_id <<< "$meta"
[[ -z "$session_id" || -z "$window_id" || -z "$pane_id" ]] && exit 0

mkdir -p "$(dirname "$CACHE_FILE")"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

if [[ ! -f "$CACHE_FILE" ]]; then
  printf '{"tasks":[]}\n' > "$CACHE_FILE"
fi

state=$(cat "$CACHE_FILE" 2>/dev/null || true)
[[ -z "$state" ]] && state='{"tasks":[]}'
now_ts=$(date +%s)
task_id="pane:${pane_id}"

echo "$state" | jq \
  --arg task_id "$task_id" \
  --arg sid "$session_id" \
  --arg wid "$window_id" \
  --arg pid "$pane_id" \
  --argjson now "$now_ts" '
  .tasks = (
    ((.tasks // []) | map(select((.task_id // "") != $task_id and (.pane_id // "") != $pid)))
    + [{
      task_id: $task_id,
      session_id: $sid,
      window_id: $wid,
      pane_id: $pid,
      status: "completed",
      acknowledged: false,
      updated_at: $now,
      source: "codex-notify"
    }]
  )
' > "$CACHE_FILE.tmp"
mv "$CACHE_FILE.tmp" "$CACHE_FILE"

tmux refresh-client -S 2>/dev/null || true
