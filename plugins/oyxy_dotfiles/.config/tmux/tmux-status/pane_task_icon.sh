#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:-}"
window_id="${2:-}"
pane_active="${3:-0}"
pane_cmd="${4:-}"

[[ -z "$pane_id" || -z "$window_id" ]] && exit 0
# Do not gate by pane_current_command: codex may appear as "node" in tmux.

CACHE_FILE="${TMUX_TRACKER_CACHE_FILE:-/tmp/tmux-tracker-cache.json}"
[[ ! -f "$CACHE_FILE" ]] && exit 0

state=$(cat "$CACHE_FILE" 2>/dev/null || true)
[[ -z "$state" ]] && exit 0

pane_match=$(echo "$state" | jq -r --arg pid "$pane_id" '
  any((.tasks // [])[]?; .status == "completed" and .acknowledged != true and ((.pane_id // "") == $pid or (.pane // "") == $pid))
' 2>/dev/null || echo "false")

if [[ "$pane_match" == "true" ]]; then
  printf '🔔'
fi
