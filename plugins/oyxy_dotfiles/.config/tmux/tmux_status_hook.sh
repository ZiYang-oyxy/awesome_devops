#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/tmux_status_engine.sh"

resolve_pane_meta() {
    local pane_id="$1"
    tmux display-message -p -t "$pane_id" $'#{session_id}\t#{window_id}\t#{pane_id}\t#{session_name}' 2>/dev/null || true
}

summary_value() {
    local summary="$1"
    local key="$2"
    printf '%s\n' "$summary" | awk -v key="$key" -F '[=\t]' '
        {
            for (i = 1; i <= NF; i += 2) {
                if ($i == key && (i + 1) <= NF) {
                    print $(i + 1)
                    exit
                }
            }
        }
    '
}

ack_focus() {
    local pane_id="${1:-}"
    local window_id="${2:-}"
    local session_id="${3:-}"

    [[ -z "$pane_id" ]] && return 0

    if [[ -z "$session_id" || -z "$window_id" ]]; then
        local meta resolved_sid resolved_wid
        meta=$(tmux display-message -p -t "$pane_id" $'#{session_id}\t#{window_id}' 2>/dev/null || true)
        if [[ -n "$meta" ]]; then
            resolved_sid="${meta%%$'\t'*}"
            resolved_wid="${meta#*$'\t'}"
            [[ -z "$session_id" ]] && session_id="$resolved_sid"
            [[ -z "$window_id" ]] && window_id="$resolved_wid"
        fi
    fi

    local summary bell_count
    summary=$("$ENGINE" query summary --scope pane --id "$pane_id" 2>/dev/null || echo 'robot=0	bell=0')
    bell_count="$(summary_value "$summary" bell)"
    [[ "$bell_count" =~ ^[0-9]+$ ]] || bell_count=0

    if ((bell_count > 0)); then
        "$ENGINE" event ack \
            --pane-id "$pane_id" \
            --session-id "$session_id" \
            --window-id "$window_id" || true
        tmux refresh-client -S 2>/dev/null || true
    fi
}

select_pane_by_payload() {
    local payload_cwd="$1"
    local panes="$2"
    local pane_id=""

    if [[ -n "$payload_cwd" ]]; then
        pane_id=$(printf '%s\n' "$panes" | awk -F '\t' -v cwd="$payload_cwd" '$2 == cwd && $3 == "1" { print $1; exit }')
        if [[ -z "$pane_id" ]]; then
            pane_id=$(printf '%s\n' "$panes" | awk -F '\t' -v cwd="$payload_cwd" '$2 == cwd { print $1; exit }')
        fi
    fi

    if [[ -z "$pane_id" ]]; then
        pane_id=$(printf '%s\n' "$panes" | awk -F '\t' '$3 == "1" { print $1; exit }')
    fi

    if [[ -z "$pane_id" ]]; then
        pane_id=$(printf '%s\n' "$panes" | awk -F '\t' 'NF { print $1; exit }')
    fi

    printf '%s' "$pane_id"
}

notify_done() {
    local args=("$@")
    local payload=""
    if ((${#args[@]} > 0)); then
        payload="${args[${#args[@]}-1]}"
    fi

    local payload_cwd=""
    if [[ -n "$payload" && -x "$(command -v jq || true)" ]]; then
        payload_cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)
    fi

    local pane_id="${TMUX_PANE:-}"
    if [[ -z "$pane_id" ]]; then
        local panes
        panes=$(tmux list-panes -a -F $'#{pane_id}\t#{pane_current_path}\t#{pane_active}' 2>/dev/null || true)
        [[ -z "$panes" ]] && return 0
        pane_id=$(select_pane_by_payload "$payload_cwd" "$panes")
    fi

    [[ -z "$pane_id" ]] && return 0

    local meta session_id window_id session_name
    meta=$(resolve_pane_meta "$pane_id")
    [[ -z "$meta" ]] && return 0

    IFS=$'\t' read -r session_id window_id pane_id session_name <<< "$meta"
    [[ -z "$session_id" || -z "$window_id" || -z "$pane_id" ]] && return 0
    [[ -z "$session_name" ]] && session_name="$session_id"

    local task_id="pane:${pane_id}"
    "$ENGINE" event complete \
        --session-id "$session_id" \
        --window-id "$window_id" \
        --pane-id "$pane_id" \
        --task-id "$task_id" \
        --source "codex-notify" || true

    local active_client_panes
    active_client_panes=$(tmux list-clients -F '#{pane_id}' 2>/dev/null | awk 'NF { print }' | tr '\n' '\t' || true)
    if [[ "$active_client_panes" == *"${pane_id}"$'\t'* ]]; then
        "$ENGINE" event ack \
            --pane-id "$pane_id" \
            --session-id "$session_id" \
            --window-id "$window_id" || true
    fi

    tmux refresh-client -S 2>/dev/null || true

    if command -v osascript >/dev/null 2>&1; then
        local notify_title notify_body notify_title_escaped notify_body_escaped
        notify_title='Codex task completed'
        notify_body="session: ${session_name}, window: ${window_id}, pane: ${pane_id}"

        notify_title_escaped=${notify_title//\\/\\\\}
        notify_title_escaped=${notify_title_escaped//\"/\\\"}
        notify_body_escaped=${notify_body//\\/\\\\}
        notify_body_escaped=${notify_body_escaped//\"/\\\"}

        osascript -e "display notification \"${notify_body_escaped}\" with title \"${notify_title_escaped}\"" >/dev/null 2>&1 || true
    fi
}

main() {
    local action="${1:-}"
    shift || true

    case "$action" in
        ack-focus)
            ack_focus "$@"
            ;;
        notify-done)
            notify_done "$@"
            ;;
        *)
            exit 0
            ;;
    esac
}

main "$@"
