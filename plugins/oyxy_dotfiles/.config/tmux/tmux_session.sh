#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANAGER="$SCRIPT_DIR/tmux_session_manager.py"
STATUSD="$SCRIPT_DIR/tmux_statusd.sh"
STATUS_HOOK="$SCRIPT_DIR/tmux_status_hook.sh"

is_non_negative_int() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+$ ]]
}

run_manager() {
    python3 "$MANAGER" "$@"
}

resolve_session_id_for_index() {
    local index="$1"
    local target_session_id=""

    target_session_id="$(tmux show-option -gqv "@session_${index}" 2>/dev/null || true)"
    if [[ -n "$target_session_id" ]]; then
        printf '%s' "$target_session_id"
        return 0
    fi

    target_session_id="$(
        tmux list-sessions -F $'#{session_id}\t#{session_name}' 2>/dev/null | \
            awk -F '\t' -v idx="$index" '$2 ~ ("^" idx "-") { print $1; exit }'
    )"
    if [[ -n "$target_session_id" ]]; then
        printf '%s' "$target_session_id"
        return 0
    fi

    tmux list-sessions -F $'#{session_id}\t#{session_name}\t#{session_created}' 2>/dev/null | \
        awk -F '\t' '
            {
                order = 999999999
                if ($2 ~ /^[0-9]+-/) {
                    split($2, parts, "-")
                    order = parts[1] + 0
                }
                printf "%010d\t%020d\t%s\n", order, $3 + 0, $1
            }
        ' | sort | awk -F '\t' -v idx="$index" 'NR == idx { print $3; exit }'
}

resolve_session_focus_meta() {
    local session_id="$1"
    tmux list-panes -t "${session_id}:" -F $'#{pane_active}\t#{pane_id}\t#{window_id}\t#{session_id}' 2>/dev/null | \
        awk -F '\t' '
            $1 == "1" {
                print $2 "\t" $3 "\t" $4
                found = 1
                exit
            }
            NF && fallback == "" {
                fallback = $2 "\t" $3 "\t" $4
            }
            END {
                if (!found && fallback != "") {
                    print fallback
                }
            }
        '
}

resolve_current_client_tty() {
    tmux display-message -p '#{client_tty}' 2>/dev/null || true
}

emit_session_selected() {
    local pane_id="${1:-}"
    local window_id="${2:-}"
    local session_id="${3:-}"
    local client_tty="${4:-}"

    [[ -x "$STATUSD" ]] || return 0
    "$STATUSD" emit session_selected \
        --pane "$pane_id" \
        --window "$window_id" \
        --session "$session_id" \
        --client-tty "$client_tty" \
        --source "tmux:switch" >/dev/null 2>&1 || true
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
    ((index >= 1)) || return 0

    local target_session_id target_meta pane_id window_id session_id client_tty
    target_session_id="$(resolve_session_id_for_index "$index")"
    [[ -n "$target_session_id" ]] || return 0

    target_meta="$(resolve_session_focus_meta "$target_session_id")"
    tmux switch-client -t "$target_session_id" 2>/dev/null || return 0
    client_tty="$(resolve_current_client_tty)"

    pane_id=""
    window_id=""
    session_id="$target_session_id"
    if [[ -n "$target_meta" ]]; then
        IFS=$'\t' read -r pane_id window_id session_id <<< "$target_meta"
        [[ -n "$session_id" ]] || session_id="$target_session_id"
    fi

    emit_session_selected "$pane_id" "$window_id" "$session_id" "$client_tty"
    if [[ -n "$pane_id" && -x "$STATUS_HOOK" ]]; then
        "$STATUS_HOOK" ack-focus "$pane_id" "$window_id" "$session_id" >/dev/null 2>&1 || true
    fi
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
