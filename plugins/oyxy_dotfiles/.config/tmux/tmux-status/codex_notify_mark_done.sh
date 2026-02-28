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
session_name=$(tmux display-message -p -t "$pane_id" '#{session_name}' 2>/dev/null || true)
[[ -z "$session_name" ]] && session_name="$session_id"

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

# If this pane is currently attached to any active client, acknowledge immediately.
active_client_panes=$(tmux list-clients -F '#{pane_id}' 2>/dev/null | awk 'NF{print}' | tr '\n' '\t' || true)
if [[ "$active_client_panes" == *"${pane_id}"$'\t'* ]]; then
  state=$(cat "$CACHE_FILE" 2>/dev/null || true)
  [[ -z "$state" ]] && state='{"tasks":[]}'
  echo "$state" | jq \
    --arg task_id "$task_id" \
    --arg pid "$pane_id" \
    --argjson now "$now_ts" '
    .tasks = (
      (.tasks // [])
      | map(
          if ((.task_id // "") == $task_id or (.pane_id // "") == $pid) then
            .acknowledged = true | .updated_at = $now
          else
            .
          end
        )
    )
  ' > "$CACHE_FILE.tmp"
  mv "$CACHE_FILE.tmp" "$CACHE_FILE"
fi

tmux refresh-client -S 2>/dev/null || true

if command -v osascript >/dev/null 2>&1; then
  notify_title='Codex task completed'
  notify_body="session: ${session_name}, window: ${window_id}, pane: ${pane_id}"
  # Escape quotes/backslashes for AppleScript string literal.
  notify_title_escaped=${notify_title//\\/\\\\}
  notify_title_escaped=${notify_title_escaped//\"/\\\"}
  notify_body_escaped=${notify_body//\\/\\\\}
  notify_body_escaped=${notify_body_escaped//\"/\\\"}
  osascript -e "display notification \"${notify_body_escaped}\" with title \"${notify_title_escaped}\"" >/dev/null 2>&1 || true
fi
