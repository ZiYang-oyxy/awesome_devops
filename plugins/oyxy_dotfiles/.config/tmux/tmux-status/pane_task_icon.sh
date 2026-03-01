#!/usr/bin/env bash
set -euo pipefail

pane_id="${1:-}"
window_id="${2:-}"
pane_active="${3:-0}"
pane_cmd="${4:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/status_engine.sh"

[[ -z "$pane_id" || -z "$window_id" ]] && exit 0
# Bell icon only depends on task state bound to pane id.

unset pane_active pane_cmd
pane_match=$("$ENGINE" query flag --scope pane --id "$pane_id" --kind bell 2>/dev/null || echo 0)
if [[ "$pane_match" == "1" ]]; then
    printf '🔔'
fi
