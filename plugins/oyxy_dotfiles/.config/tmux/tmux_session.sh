#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANAGER="$SCRIPT_DIR/tmux_session_manager.py"

is_non_negative_int() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+$ ]]
}

run_manager() {
    python3 "$MANAGER" "$@"
}

command_new() {
    local session_id
    session_id=$(tmux new-session -d -P -F '#{session_id}' 2>/dev/null || true)
    [[ -z "$session_id" ]] && return 0

    run_manager ensure
    tmux switch-client -t "$session_id"
}

command_created() {
    run_manager created
}

command_rename() {
    local label="${1:-}"
    [[ -z "$label" ]] && return 0
    run_manager rename "$label"
}

command_move() {
    local direction="${1:-}"
    [[ -z "$direction" ]] && return 0
    run_manager move "$direction"
}

command_move_window_to() {
    local index="${1:-}"
    is_non_negative_int "$index" || return 0
    run_manager move-window-to "$index"
}

command_switch() {
    local index="${1:-}"
    is_non_negative_int "$index" || return 0
    run_manager switch "$index"
}

command_ensure() {
    run_manager ensure
}

main() {
    local action="${1:-}"
    shift || true

    case "$action" in
        new)
            command_new "$@"
            ;;
        created)
            command_created "$@"
            ;;
        rename)
            command_rename "$@"
            ;;
        move)
            command_move "$@"
            ;;
        move-window-to)
            command_move_window_to "$@"
            ;;
        switch)
            command_switch "$@"
            ;;
        ensure)
            command_ensure "$@"
            ;;
        *)
            exit 0
            ;;
    esac
}

main "$@"
