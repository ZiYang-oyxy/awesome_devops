#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/status_engine.sh"

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

meta=$(tmux display-message -p -t "$pane_id" '#{session_id}	#{window_id}	#{pane_id}	#{session_name}' 2>/dev/null || true)
[[ -z "$meta" ]] && exit 0
IFS=$'\t' read -r session_id window_id pane_id session_name <<< "$meta"
[[ -z "$session_id" || -z "$window_id" || -z "$pane_id" ]] && exit 0
[[ -z "$session_name" ]] && session_name="$session_id"
task_id="pane:${pane_id}"
"$ENGINE" event complete \
    --session-id "$session_id" \
    --window-id "$window_id" \
    --pane-id "$pane_id" \
    --task-id "$task_id" \
    --source "codex-notify" || true

# Keep previous behavior: if user is already focused on this pane, clear bell immediately.
active_client_panes=$(tmux list-clients -F '#{pane_id}' 2>/dev/null | awk 'NF { print }' | tr '\n' '\t' || true)
if [[ "$active_client_panes" == *"${pane_id}"$'\t'* ]]; then
    "$ENGINE" event ack \
        --pane-id "$pane_id" \
        --session-id "$session_id" \
        --window-id "$window_id" || true
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
