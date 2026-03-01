#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib_state.sh"

query_robot_count() {
    local scope="$1"
    local target_id="$2"
    [[ -z "$scope" || -z "$target_id" ]] && {
        printf '0'
        return 0
    }

    local panes
    panes=$(tmux list-panes -a -F '#{session_id}	#{window_id}	#{pane_current_command}' 2>/dev/null || true)
    [[ -z "$panes" ]] && {
        printf '0'
        return 0
    }

    printf '%s\n' "$panes" | awk -F '\t' -v scope="$scope" -v target="$target_id" '
        function is_codex_command(cmd, normalized) {
            normalized = tolower(cmd)
            if (normalized == "codex") {
                return 1
            }
            if (index(normalized, "codex-") == 1) {
                return 1
            }
            if (index(normalized, "codex_") == 1) {
                return 1
            }
            return 0
        }

        (scope == "session" && $1 == target && is_codex_command($3)) { count++ }
        (scope == "window" && $2 == target && is_codex_command($3)) { count++ }
        END { print count + 0 }
    '
}

query_bell_count() {
    local scope="$1"
    local target_id="$2"
    [[ -z "$scope" || -z "$target_id" ]] && {
        printf '0'
        return 0
    }

    local state count
    state=$(state_read_json)
    count=$(printf '%s' "$state" | jq -r --arg scope "$scope" --arg target "$target_id" '
        [
            (.tasks // [])[]?
            | select(.status == "completed" and .acknowledged != true)
            | select(
                ($scope == "session" and (.session_id // "") == $target)
                or
                ($scope == "window" and (.window_id // "") == $target)
            )
        ] | length
    ' 2>/dev/null || echo 0)

    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    printf '%s' "$count"
}

query_bell_pane_flag() {
    local pane_id="$1"
    [[ -z "$pane_id" ]] && {
        printf '0'
        return 0
    }

    local state matched
    state=$(state_read_json)
    matched=$(printf '%s' "$state" | jq -r --arg pid "$pane_id" '
        any(
            (.tasks // [])[]?;
            .status == "completed"
            and .acknowledged != true
            and (.pane_id // "") == $pid
        )
    ' 2>/dev/null || echo "false")

    if [[ "$matched" == "true" ]]; then
        printf '1'
    else
        printf '0'
    fi
}
