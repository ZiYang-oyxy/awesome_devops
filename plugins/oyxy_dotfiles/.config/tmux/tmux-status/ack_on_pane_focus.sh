#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:-}"
window_id="${2:-}"
session_id="${3:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/status_engine.sh"

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

"$ENGINE" event ack \
    --pane-id "$pane_id" \
    --session-id "$session_id" \
    --window-id "$window_id" || true

tmux refresh-client -S 2>/dev/null || true
