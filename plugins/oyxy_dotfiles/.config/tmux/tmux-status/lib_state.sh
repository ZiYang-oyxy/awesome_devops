#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib_lock.sh"

STATE_FILE="${TMUX_STATUS_STATE_FILE:-${TMUX_TRACKER_CACHE_FILE:-/tmp/tmux-status-state.v2.json}}"
LOCK_DIR="${TMUX_STATUS_LOCK_DIR:-/tmp/tmux-status-state.v2.lock}"
LOCK_STALE_SECONDS="${TMUX_STATUS_LOCK_STALE_SECONDS:-10}"

state_now_ts() {
    date +%s
}

state_default_json() {
    printf '{"version":2,"updated_at":0,"tasks":[]}\n'
}

state_bootstrap() {
    mkdir -p "$(dirname "$STATE_FILE")"
    if [[ -s "$STATE_FILE" ]]; then
        return 0
    fi
    local tmp_file
    tmp_file="${STATE_FILE}.tmp"
    state_default_json > "$tmp_file"
    mv "$tmp_file" "$STATE_FILE"
}

state_lock_acquire() {
    lock_acquire_dir "$LOCK_DIR" "$LOCK_STALE_SECONDS"
}

state_lock_release() {
    lock_release_dir "$LOCK_DIR"
}

state_read_json() {
    if [[ -s "$STATE_FILE" ]]; then
        cat "$STATE_FILE" 2>/dev/null || state_default_json
    else
        state_default_json
    fi
}

state_write_json() {
    local json="$1"
    mkdir -p "$(dirname "$STATE_FILE")"
    local tmp_file
    tmp_file="${STATE_FILE}.tmp"
    printf '%s\n' "$json" > "$tmp_file"
    mv "$tmp_file" "$STATE_FILE"
}

state_all_panes_tabbed() {
    tmux list-panes -a -F '#{pane_id}' 2>/dev/null | tr '\n' '\t' || true
}

state_prune_json() {
    local input_json="$1"
    local now_ts="${2:-$(state_now_ts)}"
    local all_panes
    all_panes=$(state_all_panes_tabbed)

    printf '%s' "$input_json" | jq \
        --arg all_panes "$all_panes" \
        --argjson now "$now_ts" '
        .version = 2
        | .tasks = (
            (.tasks // [])
            | map(
                select(
                    (
                        .status == "completed"
                        and .acknowledged == true
                        and (.pane_id // "") != ""
                        and ($all_panes | contains((.pane_id // "") + "\t") | not)
                    ) | not
                )
            )
        )
        | .updated_at = $now
    '
}
